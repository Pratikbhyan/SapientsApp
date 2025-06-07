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
            print("AuthViewModel: Did not receive ASAuthorizationAppleIDCredential.")
            return
        }

        print("AuthViewModel: Apple ID Credential received.")
        print("AuthViewModel: User Identifier: \(appleIDCredential.user)")
        if let fullName = appleIDCredential.fullName {
            print("AuthViewModel: Full Name provided by Apple: Given: \(fullName.givenName ?? "nil"), Family: \(fullName.familyName ?? "nil"), Middle: \(fullName.middleName ?? "nil"), Prefix: \(fullName.namePrefix ?? "nil"), Suffix: \(fullName.nameSuffix ?? "nil"), Nickname: \(fullName.nickname ?? "nil")")
        } else {
            print("AuthViewModel: Full Name not provided by Apple.")
        }
        if let email = appleIDCredential.email {
            print("AuthViewModel: Email provided by Apple: \(email)")
        } else {
            print("AuthViewModel: Email not provided by Apple.")
        }

        guard let nonce = currentNonce else {
            self.errorMessage = "Invalid state: A login callback was received, but no login request was sent."
            print("AuthViewModel: Current nonce is nil.")
            return
        }
        guard let appleIDToken = appleIDCredential.identityToken else {
            self.errorMessage = "Unable to fetch identity token."
            print("AuthViewModel: Apple ID Token is nil.")
            return
        }
        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            self.errorMessage = "Unable to serialize token string from data: \(appleIDToken.debugDescription)"
            print("AuthViewModel: Could not convert Apple ID Token data to string.")
            return
        }

        Task {
            isLoading = true
            errorMessage = nil
            do {
                print("AuthViewModel: Attempting Supabase sign-in with Apple ID token.")
                _ = try await supabase.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: idTokenString, nonce: nonce))
                print("AuthViewModel: Successfully signed in with Apple via Supabase.")

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
                        print("AuthViewModel: Preparing to update 'full_name' with: \(combinedFullName)")
                    } else {
                        print("AuthViewModel: No name parts to combine from Apple's fullName.")
                    }
                } else {
                    print("AuthViewModel: appleIDCredential.fullName was nil, cannot update 'full_name'.")
                }

                if let email = appleIDCredential.email, !email.isEmpty {
                    metadataToUpdate["email"] = .string(email)
                    print("AuthViewModel: Preparing to update 'email' with: \(email)")
                } else {
                    print("AuthViewModel: appleIDCredential.email was nil or empty, cannot update 'email' in metadata.")
                }
                
                if !metadataToUpdate.isEmpty {
                    print("AuthViewModel: Attempting to update user metadata in Supabase with: \(metadataToUpdate)")
                    do {
                        let userAttributes = UserAttributes(data: metadataToUpdate)
                        _ = try await supabase.auth.update(user: userAttributes)
                        print("AuthViewModel: Successfully updated user metadata for Apple Sign-In.")
                    } catch {
                        print("AuthViewModel: Warning: Error updating user metadata for Apple Sign-In: \(error.localizedDescription). User is signed in, but metadata update failed.")
                    }
                } else {
                    print("AuthViewModel: No metadata to update for Supabase user.")
                }
            } catch {
                print("AuthViewModel: Error signing in with Apple via Supabase: \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Sign in with Apple errored: \(error)")
        self.errorMessage = error.localizedDescription
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding Methods
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
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

        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        let presentingViewController = windowScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController

        guard let rootViewController = presentingViewController else {
            print("Could not get root view controller for Google Sign-In.")
            self.errorMessage = "Could not get root view controller for Google Sign-In."
            self.isLoading = false
            return false
        }
        
        do {
            try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            guard let googleUser = GIDSignIn.sharedInstance.currentUser else {
                print("Google Sign-In failed or was cancelled, currentUser is nil.")
                self.errorMessage = "Google Sign-In failed or was cancelled by user."
                self.isLoading = false
                return false
            }
            
            guard let idToken = googleUser.idToken?.tokenString else {
                print("Google ID token missing after successful sign-in.")
                self.errorMessage = "Google ID token missing."
                self.isLoading = false
                return false
            }
            
            try await supabase.auth.signInWithIdToken(credentials: .init(provider: .google, idToken: idToken, nonce: nil))
            
            print("Successfully signed in with Google.")
            self.isLoading = false
            return true
        } catch {
            print("Error signing in with Google: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
            self.isLoading = false
            return false
        }
    }
    
    // MARK: - Sign Out
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
