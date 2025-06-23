import Foundation
import Supabase
import Combine

@MainActor
class ContentRepository: ObservableObject {
    private let supabase = SupabaseManager.shared.client
    
    @Published var contents: [Content] = []
    @Published var transcriptions: [Transcription] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var currentContentIdForTranscriptions: UUID? // Tracks content ID for current transcriptions
    
    // MARK: - Content Operations
    func fetchAllContent() async {
        self.isLoading = true
        self.error = nil
        
        do {
            let response: [Content] = try await supabase
                .from("content")
                .select("id, title, description, audio_url, image_url, created_at, transcription_url")
                .lte("created_at", value: todayDateString()) // Simple date comparison
                .order("created_at", ascending: false)
                .execute()
                .value
            
            print("📅 Found \(response.count) content items available for today")
            self.contents = response
            self.isLoading = false
        } catch {
            print("❌ Error fetching all content: \(error)")
            self.error = error
            self.isLoading = false
        }
    }
    
    // MARK: - Transcription Operations
    func fetchTranscriptions(for contentId: UUID, from transcriptionPath: String?) async {
        // Clear old transcriptions if they are for a different content item or if current ID is nil
        if self.currentContentIdForTranscriptions != contentId {
            self.transcriptions = []
            // print("[DIAG_REPO] Clearing transcriptions, new content ID: \(contentId), old: \(String(describing: self.currentContentIdForTranscriptions))")
        }
        // Update the content ID we are fetching for *before* the async network call
        // Or, update it only on successful fetch to avoid inconsistent state if fetch fails mid-way.
        // For simplicity now, we'll set it and rely on clearing if path is nil or fetch fails.
        self.currentContentIdForTranscriptions = contentId
        // self.isLoading = true // Removed: ContentDetailView uses its own isLoadingTranscription state
        self.error = nil
        
        guard let path = transcriptionPath, !path.isEmpty else {
            print("No transcription path provided for contentId: \(contentId).")
            self.transcriptions = [] // Clear existing transcriptions
            self.error = nil // Clear previous errors
            return
        }

        // Bucket is "transcriptions" (plural). Strip prefix if included in path.
        let cleanPath: String
        if path.hasPrefix("transcriptions/") {
            cleanPath = String(path.dropFirst("transcriptions/".count))
        } else {
            cleanPath = path
        }

        guard let csvUrl = getPublicURL(for: cleanPath, bucket: "transcriptions") else {
            print("Could not get public URL for transcription CSV: \(path)")
            self.transcriptions = [] // Ensure it's empty if no path
            self.error = NSError(domain: "ContentRepository", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid CSV URL or no path provided for content ID: \(contentId)"])
            // self.currentContentIdForTranscriptions = contentId // Already set, or set to nil if we consider this a 'failed to load' state for this ID
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: csvUrl)
            guard let csvString = String(data: data, encoding: .utf8) else {
                print("Could not decode CSV data to string.")
                self.transcriptions = []
                self.error = NSError(domain: "ContentRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "CSV decoding error"])
                return
            }

            var parsedTranscriptions: [Transcription] = []
            let lines = csvString.split(whereSeparator: \.isNewline)
            
            // Skip header row if present - adjust if your CSV doesn't have a header
            // Or, more robustly, check if the first line looks like a header
            var dataLines = lines
            if let firstLine = lines.first, firstLine.contains("Start (s)") && firstLine.contains("End (s)") && firstLine.contains("Segment") {
                dataLines.removeFirst()
            }

            for line in dataLines {
                let columns = line.split(separator: ",", maxSplits: 2, omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                
                guard columns.count == 3,
                      let startTime = Float(columns[0]),
                      let endTime = Float(columns[1]) else {
                    print("Skipping malformed CSV line: \(line)")
                    continue
                }
                
                let text = columns[2].trimmingCharacters(in: CharacterSet(charactersIn: "\"")) // Remove surrounding quotes if any

                let transcription = Transcription(
                    id: UUID(),
                    contentId: contentId,
                    text: text,
                    startTime: startTime,
                    endTime: endTime,
                    createdAt: Date()
                )
                parsedTranscriptions.append(transcription)
            }
            
            self.transcriptions = parsedTranscriptions
            self.error = nil
            self.currentContentIdForTranscriptions = contentId // Confirm content ID on successful load
            // print("[DIAG_REPO] Successfully parsed \(parsedTranscriptions.count) transcriptions for \(contentId) from \(path)")
        } catch {
            print("Error fetching or parsing CSV: \(error.localizedDescription)")
            self.transcriptions = []
            self.error = error
        }
    }
    
    // MARK: - Storage Operations
    func getPublicURL(for path: String, bucket: String) -> URL? {
        return try? supabase.storage.from(bucket).getPublicURL(path: path)
    }
    
    // MARK: - Daily Content Operations
    func fetchDailyContent() async throws -> Content? {
        self.isLoading = true
        self.error = nil

        do {
            let todayString = todayDateString()
            
            print("📅 Looking for content for today: \(todayString)")
            
            // First try to get content scheduled for today
            var response: [Content] = try await supabase
                .from("content")
                .select("id, title, description, audio_url, image_url, created_at, transcription_url")
                .eq("created_at", value: todayString) // Exact date match
                .limit(1)
                .execute()
                .value
            
            if let todayEpisode = response.first {
                print("📅 Found today's episode: \(todayEpisode.title)")
                self.isLoading = false
                return todayEpisode
            }
            
            // If no content for today, get the latest available content
            print("📅 No content for today, looking for latest available...")
            response = try await supabase
                .from("content")
                .select("id, title, description, audio_url, image_url, created_at, transcription_url")
                .lte("created_at", value: todayString) // Available by today
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            
            if let latestContent = response.first {
                print("📅 Showing latest available: \(latestContent.title)")
                self.isLoading = false
                return latestContent
            }
            
            print("📅 No content available yet")
            self.isLoading = false
            return nil
            
        } catch {
            print("📅 Error fetching daily content: \(error)")
            self.error = error
            self.isLoading = false
            throw error
        }
    }
    
    func hasContentForDate(_ date: Date) async -> Bool {
        do {
            let dateString = dateToString(date)
            
            let response: [Content] = try await supabase
                .from("content")
                .select("id", count: .exact)
                .eq("created_at", value: dateString)
                .execute()
                .value
            
            return !response.isEmpty
        } catch {
            print("Error checking for content on date: \(error)")
            return false
        }
    }
    
    func getContentForDate(_ date: Date) async -> Content? {
        do {
            let dateString = dateToString(date)
            
            let response: [Content] = try await supabase
                .from("content")
                .select("id, title, description, audio_url, image_url, created_at, transcription_url")
                .eq("created_at", value: dateString)
                .limit(1)
                .execute()
                .value
            
            return response.first
        } catch {
            print("Error fetching content for date: \(error)")
            return nil
        }
    }
    
    // MARK: - Single Episode fetch
    func fetchEpisode(by id: UUID) async -> Content? {
        do {
            let res: Content = try await supabase
                .from("episodes")
                .select("id, title, description, audio_url, image_url, created_at, transcription_url, collection_id")
                .eq("id", value: id.uuidString)
                .single()
                .execute()
                .value
            return res
        } catch {
            print("❌ Failed to fetch episode by ID: \(error)")
            return nil
        }
    }
    
    // MARK: - Helper Methods
    private func todayDateString() -> String {
        return dateToString(Date())
    }
    
    private func dateToString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current // Use user's timezone
        return formatter.string(from: date)
    }
}
