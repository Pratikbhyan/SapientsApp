//
//  Sapients_appApp.swift
//  Sapients app
//
//  Created by Pratik Bhyan on 23/05/25.
//

import SwiftUI
import Supabase
import GoogleSignIn

@main
struct Sapients_appApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var contentRepository = ContentRepository()
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @StateObject private var miniPlayerState = MiniPlayerState(player: AudioPlayerService.shared)
    @StateObject private var quickNotesRepository = QuickNotesRepository.shared

    init() {
        configureGoogleSignIn()
    }

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .bottom) {
                Group {
                    if authManager.isAuthenticated {
                        TabView {
                            // Tab 1: Now Playing (loads daily content)
                            DailyContentViewLoader()
                                .tabItem {
                                    Label("Now Playing", systemImage: "play.circle.fill")
                                }

                            // Tab 2: Content List (Browse)
                            NavigationView {
                                ContentListView()
                            }
                            .tabItem {
                                Label("Library", systemImage: "music.note.list")
                            }

                            // Tab 3: Quick Notes
                            QuickNotesView()
                                .tabItem {
                                    Label("Quick Notes", systemImage: "note.text")
                                }
                        }
                    } else {
                        LoginView()
                    }
                }
                .onOpenURL { url in
                    Task {
                        do {
                            try await SupabaseManager.shared.client.auth.session(from: url)
                            print("Deep link processed by Supabase via onOpenURL. AuthManager will handle state update.")
                        } catch {
                            print("Error processing deeplink in onOpenURL: \(error.localizedDescription)")
                        }
                    }
                }

                // MiniPlayerView overlay
                if miniPlayerState.isVisible {
                    MiniPlayerView()
                }
            }
            .fullScreenCover(isPresented: $miniPlayerState.isPresentingFullPlayer) {
                if let contentToPlay = audioPlayer.currentContent {
                    ZStack {
                        // Add consistent background for miniplayer-opened PlayingView
                        BlurredBackgroundView()
                            .edgesIgnoringSafeArea(.all)
                        
                        PlayingView(
                            content: contentToPlay,
                            repository: contentRepository,
                            audioPlayer: audioPlayer,
                            isLoadingTranscription: .constant(false),
                            onDismissTapped: {
                                miniPlayerState.isPresentingFullPlayer = false
                            }
                        )
                    }
                    .preferredColorScheme(.dark)
                    .environmentObject(authManager)
                    .environmentObject(contentRepository)
                    .environmentObject(audioPlayer)
                    .environmentObject(miniPlayerState)
                    .environmentObject(quickNotesRepository)
                }
            }
            .environmentObject(authManager)
            .environmentObject(contentRepository)
            .environmentObject(audioPlayer)
            .environmentObject(miniPlayerState)
            .environmentObject(quickNotesRepository)
        }
    }

    private func configureGoogleSignIn() {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "CLIENT_ID") as? String ??
                             Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            
            if let path = Bundle.main.path(forResource: "GoogleService-Info 2", ofType: "plist"),
               let dict = NSDictionary(contentsOfFile: path),
               let idFromPlist = dict["CLIENT_ID"] as? String {
                GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: idFromPlist)
                print("Google Sign-In configured with CLIENT_ID from GoogleService-Info.plist: \(idFromPlist)")
            } else {
                let hardcodedClientID = "453563946840-cg1tu8jkc4uomltcqooc5adifkqg8f4i.apps.googleusercontent.com"
                GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: hardcodedClientID)
                print("Google Sign-In configured with HARDCODED CLIENT_ID: \(hardcodedClientID). Consider fixing Info.plist or GoogleService-Info.plist.")
            }
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        print("Google Sign-In configured with CLIENT_ID from main Info.plist: \(clientID)")
    }
}
