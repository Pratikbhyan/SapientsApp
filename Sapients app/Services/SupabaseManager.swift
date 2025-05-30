import Foundation
import Supabase
import CryptoKit

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        // TODO: Replace with your actual Supabase URL and anon key
        guard let supabaseURL = URL(string: "https://ryvgngwdmjmacefljhll.supabase.co") else {
            fatalError("Invalid Supabase URL - Please update SupabaseManager.swift with your project URL")
        }
        
        // Initialize AuthOptions relying on the SDK's default storage mechanism.
        // For iOS, this should default to a persistent store (like GoTrueLocalStorage with UserDefaults).
        let authOptions = SupabaseClientOptions.AuthOptions(
            autoRefreshToken: true
        )

        let options = SupabaseClientOptions(
            db: SupabaseClientOptions.DatabaseOptions(schema: "public"),
            auth: authOptions
            // Other options like global, functions, realtime are omitted for simplicity;
            // they can be added if specifically needed and if their structure is known for this SDK version.
        )

        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ5dmduZ3dkbWptYWNlZmxqaGxsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgwNDMxOTIsImV4cCI6MjA2MzYxOTE5Mn0.AbhN-Pp4e-wNS9ofL4OtlGnPU9h8UHYYn5nNqCJ_cvM",
            options: options
        )
    }

    // MARK: - Apple Sign-In Nonce Generation
    // Adapted from https://firebase.google.com/docs/auth/ios/apple#sign_in_with_apple
    // Generates a random nonce string.
    func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError(
                "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
            )
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            // Pick a character from the set, wrapping around if needed.
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    // Generates a SHA256 hash of the nonce string.
    @available(iOS 13.0, *)
    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        let hashString = hashed.compactMap { String(format: "%02x", $0) }.joined()
        return hashString
    }
} 