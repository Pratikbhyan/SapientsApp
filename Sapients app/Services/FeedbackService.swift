import Foundation
import Supabase
import FirebaseAuth

class FeedbackService: ObservableObject {
    static let shared = FeedbackService()
    private let client = SupabaseManager.shared.client
    
    private init() {}
    
    @MainActor
    func submitFeedback(_ message: String) async throws {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FeedbackError.emptyMessage
        }
        
        guard let firebaseUser = Auth.auth().currentUser else {
            throw FeedbackError.userNotAuthenticated
        }
        
        let userId = firebaseUser.uid
        let userEmail = firebaseUser.email
        
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
    case userNotAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .emptyMessage:
            return "Please enter your feedback before sending."
        case .submissionFailed:
            return "Failed to submit feedback. Please try again."
        case .userNotAuthenticated:
            return "You must be signed in to submit feedback."
        }
    }
}
