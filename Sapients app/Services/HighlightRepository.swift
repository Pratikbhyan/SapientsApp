import Foundation
import Combine

@MainActor
class HighlightRepository: ObservableObject {
    static let shared = HighlightRepository()
    
    @Published var groups: [HighlightGroup] = []
    
    private let fileName = "highlightGroups.json"
    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory,
                                 in: .userDomainMask).first!
        .appendingPathComponent(fileName)
    }
    
    private init() {
        load()
    }
    
    // Add a highlight to a group (creates the group if needed)
    func add(_ text: String,
             to title: String,
             thumbnailName: String? = nil) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        if let idx = groups.firstIndex(where: { $0.title == title }) {
            // Existing group → prepend for recency
            groups[idx].segments.insert(HighlightSegment(text: text),
                                        at: 0)
        } else {
            // New group
            let new = HighlightGroup(title: title,
                                     thumbnailName: thumbnailName,
                                     segments: [HighlightSegment(text: text)])
            groups.insert(new, at: 0)
        }
        save()
    }
    
    func deleteGroup(_ group: HighlightGroup) {
        groups.removeAll { $0.id == group.id }
        save()
    }
    
    func deleteSegment(group: HighlightGroup,
                       segment: HighlightSegment) {
        guard let gIdx = groups.firstIndex(of: group) else { return }
        guard let sIdx = groups[gIdx].segments.firstIndex(of: segment) else { return }
        groups[gIdx].segments.remove(at: sIdx)
        
        // Remove empty groups
        if groups[gIdx].segments.isEmpty {
            groups.remove(at: gIdx)
        }
        save()
    }
    
    // MARK: - Persistence
    
    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(groups) {
            try? data.write(to: fileURL,
                            options: [.atomicWrite])
        }
    }
    
    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let loaded = try? decoder.decode([HighlightGroup].self,
                                            from: data) {
            groups = loaded
        }
    }
}