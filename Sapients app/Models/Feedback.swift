import Foundation

struct Feedback: Codable {
    let id: UUID?
    let userId: String?
    let message: String
    let createdAt: Date?
    let userEmail: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case message
        case createdAt = "created_at"
        case userEmail = "user_email"
    }
    
    init(userId: String?, message: String, userEmail: String?) {
        self.id = nil
        self.userId = userId
        self.message = message
        self.createdAt = nil
        self.userEmail = userEmail
    }
}