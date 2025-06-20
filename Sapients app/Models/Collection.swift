import Foundation

struct Collection: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let description: String?
    let imageUrl: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case imageUrl = "image_url"
        case createdAt = "created_at"
    }
} 