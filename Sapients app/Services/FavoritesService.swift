import Foundation
import Combine
import Supabase

class FavoritesService: ObservableObject {
    static let shared = FavoritesService()

    @Published var favoriteIDs: [UUID] = []
    @Published var isLoading = false
    
    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }
    
    private var authManager: AuthManager {
        AuthManager.shared
    }
    
    private var cancellables = Set<AnyCancellable>()

    private init() {
        Task { @MainActor in
            setupAuthenticationListener()
        }
    }
    
    @MainActor
    private func setupAuthenticationListener() {
        // Listen for authentication changes on main actor
        authManager.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    // Add a small delay to ensure user object is populated
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        Task {
                            await self?.loadUserFavorites()
                        }
                    }
                } else {
                    self?.favoriteIDs = []
                }
            }
            .store(in: &cancellables)
        
        // Also listen for user changes (in case user ID changes)
        authManager.$user
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                let isAuthenticated = self?.authManager.isAuthenticated ?? false
                
                if let userId = user?.id, isAuthenticated {
                    Task {
                        await self?.loadUserFavorites()
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods
    
    func isFavorite(contentId: UUID) -> Bool {
        return favoriteIDs.contains(contentId)
    }

    func addFavorite(contentId: UUID) {
        guard !isFavorite(contentId: contentId) else { 
            return 
        }
        
        Task {
            await addFavoriteToSupabase(contentId: contentId)
        }
    }

    func removeFavorite(contentId: UUID) {
        Task {
            await removeFavoriteFromSupabase(contentId: contentId)
        }
    }

    func toggleFavorite(contentId: UUID) {
        if isFavorite(contentId: contentId) {
            removeFavorite(contentId: contentId)
        } else {
            addFavorite(contentId: contentId)
        }
    }
    
    func refreshFavorites() async {
        await loadUserFavorites()
    }
    
    // MARK: - Supabase Operations
    
    @MainActor
    private func loadUserFavorites() async {
        guard authManager.isAuthenticated, let userId = authManager.user?.id else {
            favoriteIDs = []
            return
        }
        
        isLoading = true
        
        do {
            let response: [UserFavorite] = try await supabase
                .from("user_favorites")
                .select("id, user_id, content_id, created_at")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            
            favoriteIDs = response.map { $0.contentId }
            
        } catch {
            favoriteIDs = []
        }
        
        isLoading = false
    }
    
    @MainActor
    private func addFavoriteToSupabase(contentId: UUID) async {
        guard let userId = authManager.user?.id else { 
            return 
        }
        
        // Optimistically update UI
        favoriteIDs.append(contentId)
        
        do {
            let favoriteData = UserFavoriteInsert(userId: userId, contentId: contentId)
            
            let response = try await supabase
                .from("user_favorites")
                .insert(favoriteData)
                .execute()
            
        } catch {
            // Revert optimistic update on error
            favoriteIDs.removeAll { $0 == contentId }
        }
    }
    
    @MainActor
    private func removeFavoriteFromSupabase(contentId: UUID) async {
        guard let userId = authManager.user?.id else { 
            return 
        }
        
        // Optimistically update UI
        favoriteIDs.removeAll { $0 == contentId }
        
        do {
            let response = try await supabase
                .from("user_favorites")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("content_id", value: contentId.uuidString)
                .execute()
            
        } catch {
            // Revert optimistic update on error
            favoriteIDs.append(contentId)
        }
    }
    
    // MARK: - Migration from Local Storage (Optional)
    
    func migrateLocalFavoritesToSupabase() async {
        // This method can be called once to migrate existing local favorites
        guard let data = UserDefaults.standard.data(forKey: "favoriteContentIDs"),
              let localFavorites = try? JSONDecoder().decode([UUID].self, from: data),
              !localFavorites.isEmpty else { return }
        
        for contentId in localFavorites {
            await addFavoriteToSupabase(contentId: contentId)
        }
        
        // Clear local storage after migration
        UserDefaults.standard.removeObject(forKey: "favoriteContentIDs")
    }
}

// MARK: - Data Models

struct UserFavorite: Codable {
    let id: UUID
    let userId: UUID
    let contentId: UUID
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case contentId = "content_id"
        case createdAt = "created_at"
    }
}

struct UserFavoriteInsert: Codable {
    let userId: UUID
    let contentId: UUID
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case contentId = "content_id"
    }
}
