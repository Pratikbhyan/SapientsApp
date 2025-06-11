import Foundation
import Combine
import Supabase 
import GoogleSignIn 
import AuthenticationServices 
import CryptoKit 

@MainActor
class AuthViewModel: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var supabase: SupabaseClient {
        SupabaseManager.shared.client
    }

    private var currentNonce: String?

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
        isLoading = true
        errorMessage = nil
        
        let nonce = randomNonceString()
        currentNonce = nonce
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce) 

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

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            self.errorMessage = "Apple Sign-In credential issue."
            self.isLoading = false
            return
        }

        guard let nonce = currentNonce else {
            self.errorMessage = "Invalid state: A login callback was received, but no login request was sent."
            self.isLoading = false
            return
        }
        
        guard let appleIDToken = appleIDCredential.identityToken else {
            self.errorMessage = "Unable to fetch identity token."
            self.isLoading = false
            return
        }
        
        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            self.errorMessage = "Unable to serialize token string from data."
            self.isLoading = false
            return
        }

        Task {
            do {
                let response = try await supabase.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .apple, 
                        idToken: idTokenString, 
                        nonce: nonce
                    )
                )

                var metadataToUpdate: [String: AnyJSON] = [:]

                if let fullName = appleIDCredential.fullName {
                    var nameParts: [String] = []
                    if let givenName = fullName.givenName, !givenName.isEmpty {
                        nameParts.append(givenName)
                    }
                    if let familyName = fullName.familyName, !familyName.isEmpty {
                        nameParts.append(familyName)
                    }
                    if !nameParts.isEmpty {
                        let combinedFullName = nameParts.joined(separator: " ")
                        metadataToUpdate["full_name"] = .string(combinedFullName)
                    }
                }

                if let email = appleIDCredential.email, !email.isEmpty {
                    metadataToUpdate["email"] = .string(email)
                }
                
                if !metadataToUpdate.isEmpty {
                    do {
                        let userAttributes = UserAttributes(data: metadataToUpdate)
                        _ = try await supabase.auth.update(user: userAttributes)
                    } catch {
                        // Silently handle metadata update errors
                    }
                }
                
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = nil
                }
                
            } catch {
                let errorDescription = error.localizedDescription
                
                await MainActor.run {
                    if errorDescription.contains("unexpected_failure") || errorDescription.contains("500") {
                        self.errorMessage = "Apple Sign-In service temporarily unavailable. Please try again later."
                    } else if errorDescription.contains("invalid_request") {
                        self.errorMessage = "Apple Sign-In configuration error. Please contact support."
                    } else if errorDescription.contains("network") || errorDescription.contains("connection") {
                        self.errorMessage = "Network error. Please check your connection and try again."
                    } else {
                        self.errorMessage = "Apple Sign-In failed. Please try again."
                    }
                    self.isLoading = false
                }
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                self.errorMessage = nil 
            case .failed:
                self.errorMessage = "Apple Sign-In failed. Please try again."
            case .invalidResponse:
                self.errorMessage = "Invalid response from Apple. Please try again."
            case .notHandled:
                self.errorMessage = "Apple Sign-In not handled. Please try again."
            case .unknown:
                self.errorMessage = "Unknown Apple Sign-In error. Please try again."
            @unknown default:
                self.errorMessage = "Apple Sign-In error. Please try again."
            }
        } else {
            self.errorMessage = "Apple Sign-In error. Please try again."
        }
        
        self.isLoading = false
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            fatalError("No active window scene found for Apple Sign-In presentation anchor.")
        }
        return window
    }

    func signInWithGoogle() async -> Bool {
        isLoading = true
        errorMessage = nil

        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        let presentingViewController = windowScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController

        guard let rootViewController = presentingViewController else {
            self.errorMessage = "Could not get root view controller for Google Sign-In."
            self.isLoading = false
            return false
        }
        
        do {
            try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            guard let googleUser = GIDSignIn.sharedInstance.currentUser else {
                self.errorMessage = "Google Sign-In failed or was cancelled by user."
                self.isLoading = false
                return false
            }
            
            guard let idToken = googleUser.idToken?.tokenString else {
                self.errorMessage = "Google ID token missing."
                self.isLoading = false
                return false
            }
            
            try await supabase.auth.signInWithIdToken(credentials: .init(provider: .google, idToken: idToken, nonce: nil))
            
            self.isLoading = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
            return false
        }
    }
    
    func signOut() async {
        isLoading = true
        errorMessage = nil
        do {
            try await supabase.auth.signOut()
            GIDSignIn.sharedInstance.signOut()
            print("Successfully signed out from Supabase and Google.")
        } catch {
            print("Error signing out: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
