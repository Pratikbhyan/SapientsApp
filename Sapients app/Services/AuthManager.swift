import Foundation
import Combine
import Supabase // This will require Supabase to be correctly linked

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated = false
    @Published var user: User? // Supabase User model
    @Published var isDeletingAccount = false

    private var authStateListenerTask: Task<Void, Never>?
    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    private init() { // Made private to enforce singleton via .shared
        print("[AuthManager] Initializing and setting up auth state listener.")
        checkInitialAuthState() // Check session on init
        setupAuthListener()     // Start listening for changes
    }

    deinit {
        print("[AuthManager] Deinitializing and cancelling auth state listener task.")
        authStateListenerTask?.cancel()
    }

    private func setupAuthListener() {
        authStateListenerTask = Task {
            for await state in supabase.auth.authStateChanges {
                if Task.isCancelled {
                    print("[AuthManager] Auth state listener task cancelled.")
                    return
                }
                print("[AuthManager] Received auth state change: \(state.event)")
                await MainActor.run { // Ensure UI updates are on the main thread
                    switch state.event {
                    case .signedIn, .tokenRefreshed, .userUpdated:
                        self.isAuthenticated = true
                        self.user = state.session?.user
                        print("[AuthManager] User is SIGNED IN or session REFRESHED. User: \(String(describing: self.user?.email))")
                    case .signedOut:
                        self.isAuthenticated = false
                        self.user = nil
                        self.clearUserSession()
                        print("[AuthManager] User is SIGNED OUT.")
                    case .passwordRecovery:
                        // Handle password recovery if needed, for now, doesn't change isAuthenticated
                        print("[AuthManager] Password recovery event.")
                    case .initialSession:
                        // .initialSession is typically handled by checkInitialAuthState upon app launch.
                        // However, if it's emitted by authStateChanges, we can log it or update state if necessary.
                        print("[AuthManager] Auth event: .initialSession. Current session: \(String(describing: state.session))")
                        if let session = state.session, !session.accessToken.isEmpty {
                            self.isAuthenticated = true
                            self.user = session.user
                        } else {
                            // If .initialSession implies no valid user, ensure logged out state.
                            // This might be redundant if checkInitialAuthState already handled it.
                            // self.isAuthenticated = false
                            // self.user = nil
                        }
                    default:
                        // Catch any other events not explicitly handled.
                        print("[AuthManager] Auth event: \(state.event) (default case). Current session: \(String(describing: state.session))")
                        // You might want to re-evaluate authentication status based on the session present in unhandled events.
                        if let session = state.session, !session.accessToken.isEmpty {
                            // self.isAuthenticated = true // Uncomment if appropriate for unhandled events
                            // self.user = session.user
                        } else if state.event == .signedOut { // Ensure signedOut is definitely handled if it falls here
                             self.isAuthenticated = false
                             self.user = nil
                             self.clearUserSession()
                        }
                    }
                }
            }
            print("[AuthManager] Auth state changes stream completed or broken.")
        }
    }

    private func clearUserSession() {
        // Clear audio player (stop() method clears everything including currentContent)
        AudioPlayerService.shared.stop()
        
        print("[AuthManager] Cleared user session data (audio player, mini-player)")
    }

    func checkInitialAuthState() {
        Task {
            do {
                let session = try await supabase.auth.session
                // Check if the session and token are valid
                if !session.accessToken.isEmpty {
                    await MainActor.run {
                        self.isAuthenticated = true
                        self.user = session.user
                        print("[AuthManager] Initial auth state: SIGNED IN. User: \(String(describing: self.user?.email))")
                    }
                } else {
                     await MainActor.run {
                        self.isAuthenticated = false
                        self.user = nil
                        print("[AuthManager] Initial auth state: SIGNED OUT (session token empty or user nil).")
                    }
                }
            } catch {
                await MainActor.run {
                    self.isAuthenticated = false
                    self.user = nil
                    print("[AuthManager] Initial auth state: SIGNED OUT (error fetching session: \(error.localizedDescription)).")
                }
            }
        }
    }

    func signOut() async {
        do {
            // Clear session data before signing out
            clearUserSession()
            
            try await supabase.auth.signOut()
            print("[AuthManager] signOut() called, Supabase signOut attempted.")
        } catch {
            print("[AuthManager] Error during signOut: \(error.localizedDescription)")
        }
    }
    
    func deleteAccount() async throws {
        guard let user = user else {
            throw AuthError.userNotFound
        }
        
        isDeletingAccount = true
        
        do {
            // Call the database function to delete the user completely
            let response: PostgrestResponse<[String: AnyJSON]> = try await supabase
                .rpc("delete_user_account")
                .execute()
            
            print("[AuthManager] delete_user_account function executed")
            
            // Clear session data
            clearUserSession()
            
            // The user should be automatically signed out since they're deleted
            // But let's ensure the local state is updated
            self.isAuthenticated = false
            self.user = nil
            
            print("[AuthManager] Account deleted successfully from Supabase")
            
        } catch {
            print("[AuthManager] Error during account deletion: \(error.localizedDescription)")
            
            // Fallback: Just sign out the user if deletion fails
            try await supabase.auth.signOut()
            print("[AuthManager] Fallback: User signed out after deletion error")
            
            isDeletingAccount = false
            throw AuthError.deletionFailed(error.localizedDescription)
        }
        
        isDeletingAccount = false
    }
}

enum AuthError: LocalizedError {
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
