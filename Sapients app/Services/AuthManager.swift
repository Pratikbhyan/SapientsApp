import Foundation
import Combine
import Supabase // This will require Supabase to be correctly linked

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated = false
    @Published var user: User? // Supabase User model

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
                        print("[AuthManager] User is SIGNED OUT.")
                    case .passwordRecovery:
                        // Handle password recovery if needed, for now, doesn't change isAuthenticated
                        print("[AuthManager] Password recovery event.")
                    case .initialSession:
                        // .initialSession is typically handled by checkInitialAuthState upon app launch.
                        // However, if it's emitted by authStateChanges, we can log it or update state if necessary.
                        print("[AuthManager] Auth event: .initialSession. Current session: \(String(describing: state.session))")
                        if let session = state.session, !session.accessToken.isEmpty, session.user != nil {
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
                        if let session = state.session, !session.accessToken.isEmpty, session.user != nil {
                            // self.isAuthenticated = true // Uncomment if appropriate for unhandled events
                            // self.user = session.user
                        } else if state.event == .signedOut { // Ensure signedOut is definitely handled if it falls here
                             self.isAuthenticated = false
                             self.user = nil
                        }
                    }
                }
            }
            print("[AuthManager] Auth state changes stream completed or broken.")
        }
    }

    func checkInitialAuthState() {
        Task {
            do {
                let session = try await supabase.auth.session
                // Check if the session and token are valid
                if !session.accessToken.isEmpty && session.user != nil {
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

    // Add other auth methods like signOut here if they should also update AuthManager's state
    // For example, the signOut from AuthViewModel could call a method here or AuthManager could handle signOut directly.

    func signOut() async {
        do {
            try await supabase.auth.signOut()
            // The authStateChanges listener in AuthManager should automatically update 
            // isAuthenticated and user properties upon successful sign out.
            print("[AuthManager] signOut() called, Supabase signOut attempted.")
        } catch {
            print("[AuthManager] Error during signOut: \(error.localizedDescription)")
            // Even if signOut fails, ensure UI reflects an attempt or error state if necessary.
            // However, authStateChanges should ideally handle the state based on Supabase events.
        }
    }
}
