//
//  Sapients_appApp.swift
//  Sapients app
//
//  Created by Pratik Bhyan on 23/05/25.
//

import SwiftUI
import Supabase

import GoogleSignIn // Make sure this is imported

@main
struct Sapients_appApp: App {
    @State private var isUserLoggedIn: Bool = false // Or load from Keychain/UserDefaults

    init() { // Add an init method
        configureGoogleSignIn()
    }

    var body: some Scene {
        WindowGroup {
            Group { // Grouping the conditional content to apply .onOpenURL
                if isUserLoggedIn {
                    TabView {
                        // Tab 1: Now Playing (loads daily content)
                        DailyContentViewLoader()
                            .tabItem {
                                Label("Now Playing", systemImage: "play.circle.fill")
                            }

                        // Tab 2: Content List (Browse)
                        NavigationView { // This NavigationView is for the Library tab
                            ContentListView() // ContentListView now correctly has no internal NavigationView
                        }
                        .tabItem {
                            Label("Library", systemImage: "music.note.list")
                        }
                    } // Closes TabView
                } else {
                    LoginView(isUserLoggedIn: $isUserLoggedIn)
                }
            }
            .onOpenURL { url in
                Task {
                    do {
                        // Let Supabase process the URL (e.g., extract tokens, set session)
                        try await SupabaseManager.shared.client.auth.session(from: url)
                        
                        // After Supabase processes it, check the current session state
                        // to update the app's login status.
                        let currentSession = try? await SupabaseManager.shared.client.auth.session
                        self.isUserLoggedIn = (currentSession != nil && currentSession?.user != nil)
                        
                        if self.isUserLoggedIn {
                            print("Deep link processed, user is logged in via onOpenURL.")
                        } else {
                            print("Deep link processed via onOpenURL, but no active session found.")
                        }
                    } catch {
                        print("Error processing deeplink in onOpenURL: \(error.localizedDescription)")
                        self.isUserLoggedIn = false // Ensure logged out state on error
                    }
                }
            }
        }
    }

    private func configureGoogleSignIn() {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "CLIENT_ID") as? String ??
                             Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else { // Check main Info.plist first
            
            // Fallback to trying to read from GoogleService-Info.plist path if direct read fails
            // IMPORTANT: Ensure your GoogleService-Info.plist name is correct here
            if let path = Bundle.main.path(forResource: "GoogleService-Info 2", ofType: "plist"),
               let dict = NSDictionary(contentsOfFile: path),
               let idFromPlist = dict["CLIENT_ID"] as? String {
                GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: idFromPlist)
                print("Google Sign-In configured with CLIENT_ID from GoogleService-Info.plist: \(idFromPlist)")
            } else {
                // If still not found, use the hardcoded one as a last resort (less ideal)
                let hardcodedClientID = "453563946840-cg1tu8jkc4uomltcqooc5adifkqg8f4i.apps.googleusercontent.com" // Use your actual ID
                GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: hardcodedClientID)
                print("Google Sign-In configured with HARDCODED CLIENT_ID: \(hardcodedClientID). Consider fixing Info.plist or GoogleService-Info.plist.")
                 //assertionFailure("Could not find CLIENT_ID in GoogleService-Info.plist or main Info.plist for Google Sign-In configuration.")
            }
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        print("Google Sign-In configured with CLIENT_ID from main Info.plist: \(clientID)")
    }
}
