import Foundation

struct Transcription: Identifiable, Codable {
    let id: UUID
    let contentId: UUID
    let text: String
    let startTime: Float
    let endTime: Float
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case contentId = "content_id"
        case text
        case startTime = "start_time"
        case endTime = "end_time"
        case createdAt = "created_at"
    }
} 