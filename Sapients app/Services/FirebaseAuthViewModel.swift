import Foundation
import Combine
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit

@MainActor
class FirebaseAuthViewModel: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var currentNonce: String?
    private let authManager = FirebaseAuthManager.shared

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
            let success = await authManager.signInWithApple(idToken: idTokenString, nonce: nonce)
            
            await MainActor.run {
                self.isLoading = false
                if !success {
                    self.errorMessage = "Apple Sign-In failed. Please try again."
                } else {
                    self.errorMessage = nil
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

        let success = await authManager.signInWithGoogle()
        
        await MainActor.run {
            self.isLoading = false
            if !success {
                self.errorMessage = "Google Sign-In failed. Please try again."
            } else {
                self.errorMessage = nil
            }
        }
        
        return success
    }
    
    func signOut() async {
        isLoading = true
        errorMessage = nil
        
        await authManager.signOut()
        
        // Also sign out from Google
        GIDSignIn.sharedInstance.signOut()
        
        await MainActor.run {
            self.isLoading = false
        }
    }
}