import Foundation
import Supabase

class FeedbackService: ObservableObject {
    static let shared = FeedbackService()
    private let client = SupabaseManager.shared.client
    
    private init() {}
    
    @MainActor
    func submitFeedback(_ message: String) async throws {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FeedbackError.emptyMessage
        }
        
        // Get current user info
        let currentUser = try await client.auth.session.user
        let userId = currentUser.id.uuidString
        let userEmail = currentUser.email
        
        let feedback = Feedback(
            userId: userId,
            message: message.trimmingCharacters(in: .whitespacesAndNewlines),
            userEmail: userEmail
        )
        
        try await client
            .from("feedback")
            .insert(feedback)
            .execute()
    }
}

enum FeedbackError: LocalizedError {
    case emptyMessage
    case submissionFailed
    
    var errorDescription: String? {
        switch self {
        case .emptyMessage:
            return "Please enter your feedback before sending."
        case .submissionFailed:
            return "Failed to submit feedback. Please try again."
        }
    }
}