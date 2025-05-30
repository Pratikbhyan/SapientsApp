import Foundation

struct Content: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let description: String?
    let audioUrl: String
    let imageUrl: String?
    let createdAt: Date
    let publishOn: Date? // New field, make it optional
    
    var effectiveSortDate: Date {
        return publishOn ?? createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case audioUrl = "audio_url"
        case imageUrl = "image_url"
        case createdAt = "created_at"
        case publishOn = "publish_on"
    }
} 