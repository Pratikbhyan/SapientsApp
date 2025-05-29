import Foundation
import Combine

class FavoritesService: ObservableObject {
    static let shared = FavoritesService()

    private let favoritesKey = "favoriteContentIDs"
    private var userDefaults: UserDefaults

    @Published var favoriteIDs: [UUID] = []

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.favoriteIDs = loadFavoriteIDs()
    }

    private func loadFavoriteIDs() -> [UUID] {
        guard let data = userDefaults.data(forKey: favoritesKey) else { return [] }
        do {
            return try JSONDecoder().decode([UUID].self, from: data)
        } catch {
            print("Error decoding favorite IDs: \(error)")
            return []
        }
    }

    private func saveFavoriteIDs() {
        do {
            let data = try JSONEncoder().encode(favoriteIDs)
            userDefaults.set(data, forKey: favoritesKey)
        } catch {
            print("Error encoding favorite IDs: \(error)")
        }
    }

    func isFavorite(contentId: UUID) -> Bool {
        return favoriteIDs.contains(contentId)
    }

    func addFavorite(contentId: UUID) {
        guard !isFavorite(contentId: contentId) else { return }
        favoriteIDs.append(contentId)
        saveFavoriteIDs()
    }

    func removeFavorite(contentId: UUID) {
        favoriteIDs.removeAll { $0 == contentId }
        saveFavoriteIDs()
    }

    func toggleFavorite(contentId: UUID) {
        if isFavorite(contentId: contentId) {
            removeFavorite(contentId: contentId)
        } else {
            addFavorite(contentId: contentId)
        }
    }
}
