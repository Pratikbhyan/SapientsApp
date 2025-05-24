import Foundation
import Supabase
import Combine

class ContentRepository: ObservableObject {
    private let supabase = SupabaseManager.shared.client
    
    @Published var contents: [Content] = []
    @Published var transcriptions: [Transcription] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Content Operations
    func fetchAllContent() async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            let response: [Content] = try await supabase
                .from("content")
                .select()
                .execute()
                .value
            
            DispatchQueue.main.async {
                self.contents = response
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Transcription Operations
    func fetchTranscriptions(for contentId: UUID) async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            let response: [Transcription] = try await supabase
                .from("transcriptions")
                .select()
                .eq("content_id", value: contentId)
                .order("start_time")
                .execute()
                .value
            
            DispatchQueue.main.async {
                self.transcriptions = response
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Storage Operations
    func getPublicURL(for path: String, bucket: String) -> URL? {
        return supabase.storage.from(bucket).getPublicURL(path: path)
    }
} 