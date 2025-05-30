import Foundation
import Combine
import Supabase // This will cause an error until the SDK is correctly linked
import GoogleSignIn // For Google Sign-In
import AuthenticationServices // For Apple Sign-In
import CryptoKit // For SHA256 hashing

@MainActor
class AuthViewModel: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    @Published var isLoading = false
    @Published var errorMessage: String?
    // @Published var isUserLoggedIn = false // This state is now managed by AuthManager

    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    
    // MARK: - Sign in with Apple
    private var currentNonce: String?

    // Utility to generate a random nonce for Apple Sign-In
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate random bytes. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    func signInWithApple() {
        let nonce = randomNonceString()
        currentNonce = nonce
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce) // SHA256 hash of the nonce

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
        return hashString
    }

    // MARK: - ASAuthorizationControllerDelegate Methods
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            self.errorMessage = "Apple Sign-In credential issue."
            return
        }

        guard let nonce = currentNonce else {
            self.errorMessage = "Invalid state: A login callback was received, but no login request was sent."
            return
        }
        guard let appleIDToken = appleIDCredential.identityToken else {
            self.errorMessage = "Unable to fetch identity token."
            return
        }
        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            self.errorMessage = "Unable to serialize token string from data: \(appleIDToken.debugDescription)"
            return
        }

        Task {
            isLoading = true
            errorMessage = nil
            do {
                try await supabase.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: idTokenString, nonce: nonce))
                // self.isUserLoggedIn = true // AuthManager handles this state change
                print("Successfully signed in with Apple.")
            } catch {
                print("Error signing in with Apple via Supabase: \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Handle error.
        print("Sign in with Apple errored: \(error)")
        self.errorMessage = error.localizedDescription
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding Methods
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Return the window of your app
        // This requires access to the scene, which can be tricky in a pure ViewModel.
        // A common approach is to pass it in or get it from UIApplication.shared.
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            fatalError("No active window scene found for Apple Sign-In presentation anchor.")
        }
        return window
    }

    // MARK: - Sign in with Google
    func signInWithGoogle() async -> Bool {
        isLoading = true
        errorMessage = nil

        // Get the root view controller (already on @MainActor)
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        let presentingViewController = windowScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController

        guard let rootViewController = presentingViewController else {
            print("Could not get root view controller for Google Sign-In.")
            self.errorMessage = "Could not get root view controller for Google Sign-In."
            self.isLoading = false
            return false // Return false on guard failure
        }
        
        // Removed the outer Task here, as the function is already async.
            do {
                try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
                
                guard let googleUser = GIDSignIn.sharedInstance.currentUser else {
                    print("Google Sign-In failed or was cancelled, currentUser is nil.")
                    self.errorMessage = "Google Sign-In failed or was cancelled by user."
                    self.isLoading = false
                    return false // Return false
                }
                
                guard let idToken = googleUser.idToken?.tokenString else {
                    print("Google ID token missing after successful sign-in.")
                    self.errorMessage = "Google ID token missing."
                    self.isLoading = false
                    return false // Return false
                }
                
                // Nonce might not be strictly necessary if "Skip nonce checks" is enabled in Supabase Google provider settings,
                // but it's good practice if available or if you disable skip nonce checks later.
                // For now, we'll pass nil as we are skipping nonce checks in Supabase.
                try await supabase.auth.signInWithIdToken(credentials: .init(provider: .google, idToken: idToken, nonce: nil))
                
                print("Successfully signed in with Google.")
                // self.isUserLoggedIn = true // AuthManager handles this state change
                self.isLoading = false
                return true // Return true on success
            } catch {
                print("Error signing in with Google: \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                return false // Return false on error
            }
        // isLoading is set within the do/catch block now
    }
    
    // MARK: - Sign Out
    func signOut() async {
        isLoading = true
        errorMessage = nil
        do {
            try await supabase.auth.signOut() // Sign out from Supabase
            GIDSignIn.sharedInstance.signOut() // Sign out from Google
            // isUserLoggedIn = false // AuthManager handles this state change
            print("Successfully signed out from Supabase and Google.")
        } catch {
            print("Error signing out: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
