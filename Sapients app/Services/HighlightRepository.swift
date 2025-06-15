import Foundation
import Combine
import Supabase

@MainActor
class HighlightRepository: ObservableObject {
    static let shared = HighlightRepository()
    
    @Published var groups: [HighlightGroup] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let supabase = SupabaseManager.shared.client
    private let fileName = "highlightGroups.json"
    
    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory,
                                 in: .userDomainMask).first!
        .appendingPathComponent(fileName)
    }
    
    private init() {
        Task {
            await loadHighlights()
        }
    }
    
    // MARK: - Public Methods
    
    func add(_ text: String, to title: String, thumbnailName: String? = nil, contentId: UUID? = nil, startTime: Float? = nil) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        print("🟡 DEBUG: Adding highlight - text: '\(text)', title: '\(title)', contentId: \(contentId?.uuidString ?? "nil"), startTime: \(startTime ?? 0)")
        
        let newSegment = HighlightSegment(text: text, startTime: startTime)
        
        // Update local state immediately for responsive UI
        if let idx = groups.firstIndex(where: { $0.title == title }) {
            groups[idx].segments.insert(newSegment, at: 0)
            groups[idx].segments.sort { first, second in
                // If both have start times, sort by start time
                if let firstTime = first.startTime, let secondTime = second.startTime {
                    return firstTime < secondTime
                }
                // If only one has start time, prioritize it
                if first.startTime != nil && second.startTime == nil {
                    return true
                }
                if first.startTime == nil && second.startTime != nil {
                    return false
                }
                // If neither has start time, sort by date added (newest first)
                return first.dateAdded > second.dateAdded
            }
        } else {
            let newGroup = HighlightGroup(title: title, thumbnailName: thumbnailName, segments: [newSegment])
            groups.insert(newGroup, at: 0)
        }
        
        // Sync to backend
        Task {
            await saveHighlightToBackend(segment: newSegment, contentTitle: title, contentId: contentId)
        }
        
        // Save local backup
        saveToLocal()
    }
    
    func deleteGroup(_ group: HighlightGroup) {
        groups.removeAll { $0.id == group.id }
        
        // Delete all highlights in this group from backend
        Task {
            await deleteGroupFromBackend(groupTitle: group.title)
        }
        
        saveToLocal()
    }
    
    func deleteSegment(group: HighlightGroup, segment: HighlightSegment) {
        guard let gIdx = groups.firstIndex(of: group) else { return }
        guard let sIdx = groups[gIdx].segments.firstIndex(of: segment) else { return }
        
        groups[gIdx].segments.remove(at: sIdx)
        
        // Remove empty groups
        if groups[gIdx].segments.isEmpty {
            groups.remove(at: gIdx)
        }
        
        // Delete from backend
        Task {
            await deleteHighlightFromBackend(highlightId: segment.id)
        }
        
        saveToLocal()
    }
    
    func refreshHighlights() async {
        await loadHighlights()
    }
    
    // MARK: - Backend Sync Methods
    
    private func loadHighlights() async {
        print("🟡 DEBUG: Loading highlights from backend...")
        
        guard let userId = await getCurrentUserId() else {
            print("🔴 DEBUG: No user ID found, loading from local")
            loadFromLocal() // Fallback to local if not authenticated
            return
        }
        
        print("🟢 DEBUG: Found user ID: \(userId)")
        
        isLoading = true
        error = nil
        
        do {
            print("🟡 DEBUG: Fetching highlights from Supabase...")
            let highlights: [SupabaseHighlight] = try await supabase
                .from("highlights")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            print("🟢 DEBUG: Successfully fetched \(highlights.count) highlights from backend")
            
            // Convert to local model and group by content title
            await convertAndGroupHighlights(highlights)
            
            // Save local backup
            saveToLocal()
            
        } catch {
            print("🔴 DEBUG: Error loading highlights from backend: \(error)")
            print("🔴 DEBUG: Error details: \(error.localizedDescription)")
            self.error = "Failed to load highlights: \(error.localizedDescription)"
            
            // Fallback to local storage
            loadFromLocal()
        }
        
        isLoading = false
    }
    
    private func saveHighlightToBackend(segment: HighlightSegment, contentTitle: String, contentId: UUID?) async {
        print("🟡 DEBUG: Saving highlight to backend...")
        
        guard let userId = await getCurrentUserId() else {
            print("🔴 DEBUG: No user ID found, cannot save to backend")
            return
        }
        
        print("🟢 DEBUG: User ID for saving: \(userId)")
        
        do {
            let supabaseHighlight = SupabaseHighlight(
                from: segment,
                userId: userId,
                contentId: contentId,
                contentTitle: contentTitle
            )
            
            print("🟡 DEBUG: Attempting to insert highlight: \(supabaseHighlight)")
            
            let result: SupabaseHighlight = try await supabase
                .from("highlights")
                .insert(supabaseHighlight)
                .select()
                .single()
                .execute()
                .value
            
            print("🟢 DEBUG: Highlight saved to backend successfully: \(result.id)")
            
        } catch {
            print("🔴 DEBUG: Error saving highlight to backend: \(error)")
            print("🔴 DEBUG: Error details: \(error.localizedDescription)")
            if let supabaseError = error as? Error {
                print("🔴 DEBUG: Full error: \(supabaseError)")
            }
            self.error = "Failed to save highlight: \(error.localizedDescription)"
        }
    }
    
    private func deleteHighlightFromBackend(highlightId: UUID) async {
        print("🟡 DEBUG: Deleting highlight from backend: \(highlightId)")
        
        guard await getCurrentUserId() != nil else {
            print("🔴 DEBUG: No user ID found, cannot delete from backend")
            return
        }
        
        do {
            try await supabase
                .from("highlights")
                .delete()
                .eq("id", value: highlightId)
                .execute()
            
            print("🟢 DEBUG: Highlight deleted from backend successfully")
            
        } catch {
            print("🔴 DEBUG: Error deleting highlight from backend: \(error)")
            self.error = "Failed to delete highlight: \(error.localizedDescription)"
        }
    }
    
    private func deleteGroupFromBackend(groupTitle: String) async {
        print("🟡 DEBUG: Deleting highlight group from backend: \(groupTitle)")
        
        guard let userId = await getCurrentUserId() else {
            print("🔴 DEBUG: No user ID found, cannot delete group from backend")
            return
        }
        
        do {
            try await supabase
                .from("highlights")
                .delete()
                .eq("user_id", value: userId)
                .eq("content_title", value: groupTitle)
                .execute()
            
            print("🟢 DEBUG: Highlight group deleted from backend successfully")
            
        } catch {
            print("🔴 DEBUG: Error deleting highlight group from backend: \(error)")
            self.error = "Failed to delete highlight group: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentUserId() async -> UUID? {
        do {
            let session = try await supabase.auth.session
            print("🟢 DEBUG: Found user session: \(session.user.id)")
            return session.user.id
        } catch {
            print("🔴 DEBUG: No authenticated user found: \(error)")
            return nil
        }
    }
    
    private func convertAndGroupHighlights(_ highlights: [SupabaseHighlight]) async {
        print("🟡 DEBUG: Converting \(highlights.count) highlights to groups")
        
        var groupedHighlights: [String: [HighlightSegment]] = [:]
        
        // Group highlights by content title
        for highlight in highlights {
            let segment = HighlightSegment(from: highlight)
            if groupedHighlights[highlight.contentTitle] != nil {
                groupedHighlights[highlight.contentTitle]?.append(segment)
            } else {
                groupedHighlights[highlight.contentTitle] = [segment]
            }
        }
        
        // Convert to HighlightGroup array with proper sorting
        groups = groupedHighlights.map { (title, segments) in
            let sortedSegments = segments.sorted { first, second in
                // If both have start times, sort by start time (ascending - story order)
                if let firstTime = first.startTime, let secondTime = second.startTime {
                    return firstTime < secondTime
                }
                // If only one has start time, prioritize it
                if first.startTime != nil && second.startTime == nil {
                    return true
                }
                if first.startTime == nil && second.startTime != nil {
                    return false
                }
                // If neither has start time, sort by date added (newest first)
                return first.dateAdded > second.dateAdded
            }
            
            return HighlightGroup(
                title: title,
                thumbnailName: nil,
                segments: sortedSegments
            )
        }.sorted { $0.segments.first?.dateAdded ?? Date.distantPast > $1.segments.first?.dateAdded ?? Date.distantPast }
        
        print("🟢 DEBUG: Created \(groups.count) highlight groups with natural story ordering")
    }
    
    // MARK: - Local Storage (Backup)
    
    private func saveToLocal() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(groups) {
            try? data.write(to: fileURL, options: [.atomicWrite])
            print("🟢 DEBUG: Saved \(groups.count) groups to local storage")
        }
    }
    
    private func loadFromLocal() {
        guard let data = try? Data(contentsOf: fileURL) else { 
            print("🟡 DEBUG: No local highlights file found")
            return 
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let loaded = try? decoder.decode([HighlightGroup].self, from: data) {
            groups = loaded
            print("🟢 DEBUG: Loaded \(groups.count) groups from local storage")
        }
    }
}
