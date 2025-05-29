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
    
    // MARK: - Content Operations
    func fetchAllContent() async {
        self.isLoading = true
        self.error = nil
        
        do {
            let now = ISO8601DateFormatter().string(from: Date())

            let response: [Content] = try await supabase
                .from("content")
                .select("id, title, description, audio_url, image_url, created_at, publish_on") // Explicitly select all needed columns including publish_on
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
    func fetchTranscriptions(for contentId: UUID) async {
        // self.isLoading = true // Removed: ContentDetailView uses its own isLoadingTranscription state
        self.error = nil
        
        do {
            let response: [Transcription] = try await supabase
                .from("transcriptions")
                .select()
                .eq("content_id", value: contentId)
                .order("start_time")
                .execute()
                .value
            
            self.transcriptions = response
            // self.isLoading = false // Removed
        } catch {
            self.error = error
            // self.isLoading = false // Removed, error state is sufficient here
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
            let response: [Content] = try await supabase
                .from("content")
                .select()
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value

            self.isLoading = false
            return response.first
        } catch {
            self.error = error
            self.isLoading = false
            throw error
        }
    }
} 