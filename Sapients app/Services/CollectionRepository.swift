import Foundation
import Supabase
import Combine

@MainActor
class CollectionRepository: ObservableObject {
    private let supabase = SupabaseManager.shared.client

    @Published var collections: [Collection] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?

    // Fetch all collections
    func fetchAllCollections() async {
        self.isLoading = true
        self.error = nil
        do {
            let response: [Collection] = try await supabase
                .from("collections")
                .select("id, title, description, image_url, created_at")
                .order("created_at", ascending: false)
                .execute()
                .value
            self.collections = response
            self.isLoading = false
        } catch {
            self.error = error
            self.isLoading = false
        }
    }

    // Fetch episodes for a given collection id
    func fetchEpisodes(for collectionId: UUID) async throws -> [Content] {
        do {
            let response: [Content] = try await supabase
                .from("episodes")
                .select("id, title, description, audio_url, image_url, created_at, transcript_url, collection_id")
                .eq("collection_id", value: collectionId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            return response
        } catch {
            throw error
        }
    }
} 