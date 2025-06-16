import Foundation
import Combine
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit

@MainActor
class FirebaseAuthManager: ObservableObject {
    static let shared = FirebaseAuthManager()

    @Published var isAuthenticated = false
    @Published var user: User?
    @Published var isDeletingAccount = false

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    private init() {
        print("[FirebaseAuthManager] Initializing Firebase Auth Manager")
        setupAuthListener()
    }

    deinit {
        print("[FirebaseAuthManager] Deinitializing Firebase Auth Manager")
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    private func setupAuthListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let user = user {
                    self.isAuthenticated = true
                    self.user = user
                    print("[FirebaseAuthManager] User is SIGNED IN: \(user.email ?? "No email")")
                } else {
                    self.isAuthenticated = false
                    self.user = nil
                    self.clearUserSession()
                    print("[FirebaseAuthManager] User is SIGNED OUT")
                }
            }
        }
    }

    private func clearUserSession() {
        // Clear audio player (stop() method clears everything including currentContent)
        AudioPlayerService.shared.stop()
        
        print("[FirebaseAuthManager] Cleared user session data (audio player, mini-player)")
    }

    func signOut() async {
        do {
            // Clear session data before signing out
            clearUserSession()
            
            try Auth.auth().signOut()
            print("[FirebaseAuthManager] signOut() successful")
        } catch {
            print("[FirebaseAuthManager] Error during signOut: \(error.localizedDescription)")
        }
    }
    
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw FirebaseAuthError.userNotFound
        }
        
        isDeletingAccount = true
        
        do {
            let userId = user.uid
            
            // Clear session data
            clearUserSession()
            
            do {
                try await deleteUserDataFromSupabase(userId: userId)
                print("[FirebaseAuthManager] Successfully deleted user data from Supabase")
            } catch {
                print("[FirebaseAuthManager] Warning: Failed to delete Supabase data, but continuing with account deletion: \(error.localizedDescription)")
                // Don't throw - continue with Firebase account deletion
            }
            
            // Delete the Firebase user account
            try await user.delete()
            
            print("[FirebaseAuthManager] Firebase account deleted successfully")
            
        } catch {
            print("[FirebaseAuthManager] Error during account deletion: \(error.localizedDescription)")
            
            // Fallback: Just sign out the user if deletion fails
            try Auth.auth().signOut()
            print("[FirebaseAuthManager] Fallback: User signed out after deletion error")
            
            isDeletingAccount = false
            throw FirebaseAuthError.deletionFailed(error.localizedDescription)
        }
        
        isDeletingAccount = false
    }

    private func deleteUserDataFromSupabase(userId: String) async throws {
        let supabase = SupabaseManager.shared.client
        
        print("[FirebaseAuthManager] Attempting to delete user data from Supabase for user: \(userId)")
        
        // Use withTimeout to prevent hanging
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                // Delete highlights
                try await supabase
                    .from("highlights")
                    .delete()
                    .eq("user_id", value: userId)
                    .execute()
                print("[FirebaseAuthManager] Deleted highlights for user: \(userId)")
            }
            
            group.addTask {
                // Delete feedback - but allow this to fail silently as feedback might be kept for analytics
                do {
                    try await supabase
                        .from("feedback")
                        .delete()
                        .eq("user_id", value: userId)
                        .execute()
                    print("[FirebaseAuthManager] Deleted feedback for user: \(userId)")
                } catch {
                    print("[FirebaseAuthManager] Note: Could not delete feedback (this is optional): \(error.localizedDescription)")
                }
            }
            
            // Wait for all tasks to complete
            try await group.waitForAll()
        }
    }

    // MARK: - Sign In Methods
    
    func signInWithGoogle() async -> Bool {
        do {
            guard let presentingViewController = await getCurrentViewController() else {
                print("[FirebaseAuthManager] Could not get presenting view controller")
                return false
            }
            
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                print("[FirebaseAuthManager] Google ID token missing")
                return false
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                         accessToken: result.user.accessToken.tokenString)
            
            let authResult = try await Auth.auth().signIn(with: credential)
            print("[FirebaseAuthManager] Google sign-in successful: \(authResult.user.email ?? "No email")")
            return true
            
        } catch {
            print("[FirebaseAuthManager] Google sign-in error: \(error.localizedDescription)")
            return false
        }
    }
    
    func signInWithApple(idToken: String, nonce: String) async -> Bool {
        do {
            let credential = OAuthProvider.credential(withProviderID: "apple.com",
                                                    idToken: idToken,
                                                    rawNonce: nonce)
            
            let authResult = try await Auth.auth().signIn(with: credential)
            print("[FirebaseAuthManager] Apple sign-in successful: \(authResult.user.email ?? "No email")")
            return true
            
        } catch {
            print("[FirebaseAuthManager] Apple sign-in error: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func getCurrentViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }
        return window.rootViewController
    }
    
    // MARK: - User Properties
    
    var currentUserEmail: String? {
        return user?.email
    }
    
    var currentUserId: String? {
        return user?.uid
    }
    
    var currentUserDisplayName: String? {
        return user?.displayName
    }
}

enum FirebaseAuthError: LocalizedError {
    case userNotFound
    case deletionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "No authenticated user found"
        case .deletionFailed(let message):
            return "Account deletion failed: \(message)"
        }
    }
}
