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
            let response: [Content] = try await supabase
                .from("content")
                .select()
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
        self.isLoading = true
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
            self.isLoading = false
        } catch {
            self.error = error
            self.isLoading = false
        }
    }
    
    // MARK: - Storage Operations
    func getPublicURL(for path: String, bucket: String) -> URL? {
        return try? supabase.storage.from(bucket).getPublicURL(path: path)
    }
    
    // MARK: - Daily Content Operations
    func fetchDailyContent() async throws -> Content? {
        DispatchQueue.main.async {
            self.isLoading = true 
            self.error = nil
        }

        do {
            let response: [Content] = try await supabase
                .from("content")
                .select()
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value

            DispatchQueue.main.async {
                self.isLoading = false
            }
            return response.first
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
            }
            throw error
        }
    }
} 