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
            let now = ISO8601DateFormatter().string(from: Date())

            let response: [Content] = try await supabase
                .from("content")
                .select("id, title, description, audio_url, image_url, created_at, publish_on, transcription_url") // Explicitly select all needed columns including publish_on
                .or("publish_on.lte.\(now),publish_on.is.null") // publish_on <= now OR publish_on IS NULL
                .order("created_at", ascending: false) // Keep existing order or adjust as needed
                .execute()
                .value
            
            self.contents = response
            self.isLoading = false
        } catch {
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

        // Assuming CSVs are in a bucket named "transcriptions_csv" or similar.
        // Please adjust "transcriptions_csv" if your bucket name is different.
        guard let csvUrl = getPublicURL(for: path, bucket: "transcription") else { // Corrected bucket name
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
            // Get today's date in user's timezone
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
            
            // Format dates for Supabase query (ISO 8601 format)
            let formatter = ISO8601DateFormatter()
            let todayString = formatter.string(from: today)
            let tomorrowString = formatter.string(from: tomorrow)
            
            // First try to get content scheduled for today (using publish_on)
            var response: [Content] = try await supabase
                .from("content")
                .select("id, title, description, audio_url, image_url, created_at, publish_on, transcription_url")
                .gte("publish_on", value: todayString)
                .lt("publish_on", value: tomorrowString)
                .order("publish_on", ascending: false)
                .limit(1)
                .execute()
                .value
            
            // If no content scheduled for today, get the latest available content
            if response.isEmpty {
                let now = formatter.string(from: Date())
                response = try await supabase
                    .from("content")
                    .select("id, title, description, audio_url, image_url, created_at, publish_on, transcription_url")
                    .or("publish_on.lte.\(now),publish_on.is.null")
                    .order("created_at", ascending: false)
                    .limit(1)
                    .execute()
                    .value
            }

            self.isLoading = false
            return response.first
        } catch {
            self.error = error
            self.isLoading = false
            throw error
        }
    }
    
    func hasContentForDate(_ date: Date) async -> Bool {
        do {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let formatter = ISO8601DateFormatter()
            let startString = formatter.string(from: startOfDay)
            let endString = formatter.string(from: endOfDay)
            
            // Check for content scheduled for this specific date
            let response: [Content] = try await supabase
                .from("content")
                .select("id", count: .exact)
                .gte("publish_on", value: startString)
                .lt("publish_on", value: endString)
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
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let formatter = ISO8601DateFormatter()
            let startString = formatter.string(from: startOfDay)
            let endString = formatter.string(from: endOfDay)
            
            let response: [Content] = try await supabase
                .from("content")
                .select("id, title, description, audio_url, image_url, created_at, publish_on, transcription_url")
                .gte("publish_on", value: startString)
                .lt("publish_on", value: endString)
                .order("publish_on", ascending: false)
                .limit(1)
                .execute()
                .value
            
            return response.first
        } catch {
            print("Error fetching content for date: \(error)")
            return nil
        }
    }
}
