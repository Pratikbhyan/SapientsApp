//
//  Sapients_appApp.swift
//  Sapients app
//
//  Created by Pratik Bhyan on 23/05/25.
//

import SwiftUI
import Supabase
import GoogleSignIn
import UserNotifications

// Enum to identify tabs
enum TabIdentifier {
    case nowPlaying, library, quickNotes
}

@main
struct Sapients_appApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var contentRepository = ContentRepository()
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @StateObject private var miniPlayerState = MiniPlayerState(player: AudioPlayerService.shared)
    @StateObject private var quickNotesRepository = QuickNotesRepository.shared
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var storeKit = StoreKitService.shared
    @State private var selectedTab: TabIdentifier = .nowPlaying // Default tab

    init() {
        configureGoogleSignIn()
        setupNotificationHandling()
    }

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .bottom) {
                mainContent
                
                // MiniPlayerView overlay
                if miniPlayerState.isVisible && !miniPlayerState.isPresentingFullPlayer && selectedTab != .nowPlaying {
                    MiniPlayerView()
                }
            }
            .sheet(isPresented: $miniPlayerState.isPresentingFullPlayer) {
                fullPlayerSheet
            }
            .environmentObject(authManager)
            .environmentObject(contentRepository)
            .environmentObject(audioPlayer)
            .environmentObject(miniPlayerState)
            .environmentObject(quickNotesRepository)
            .environmentObject(notificationService)
            .environmentObject(storeKit)
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        Group {
            if authManager.isAuthenticated {
                TabView(selection: $selectedTab) {
                    // Tab 1: Now Playing (loads daily content)
                    DailyContentViewLoader()
                        .tag(TabIdentifier.nowPlaying)
                        .tabItem {
                            Label("Now Playing", systemImage: "play.circle.fill")
                        }

                    // Tab 2: Content List (Browse)
                    NavigationView {
                        ContentListView()
                    }
                    .tag(TabIdentifier.library)
                    .tabItem {
                        Label("Library", systemImage: "music.note.list")
                    }

                    // Tab 3: Quick Notes
                    QuickNotesView()
                        .tag(TabIdentifier.quickNotes)
                        .tabItem {
                            Label("Quick Notes", systemImage: "note.text")
                        }
                }
                .onChange(of: selectedTab) { _, newTab in
                    if newTab == .nowPlaying {
                        miniPlayerState.isVisible = false
                    } else {
                        // For other tabs, MiniPlayerState's internal logic
                        // (based on hasLoadedTrack) will determine actual visibility.
                        // We just signal that it *can* be visible from the tab's perspective.
                        miniPlayerState.isVisible = audioPlayer.hasLoadedTrack
                    }
                }
                .onAppear {
                    notificationService.setupDailyNotifications()
                    
                    Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { _ in
                        notificationService.refreshNotifications()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .dailyEpisodeNotificationTapped)) { _ in
                    selectedTab = .nowPlaying
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
    }
    
    @ViewBuilder
    private var fullPlayerSheet: some View {
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
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .environmentObject(authManager)
            .environmentObject(contentRepository)
            .environmentObject(audioPlayer)
            .environmentObject(miniPlayerState)
            .environmentObject(quickNotesRepository)
        } else {
            Color.black
                .onAppear {
                    print("ERROR: PlayingView presented without content!")
                    miniPlayerState.isPresentingFullPlayer = false
                }
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
    
    private func setupNotificationHandling() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    static let shared = NotificationDelegate()
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        
        if let type = userInfo["type"] as? String, type == "daily_episode" {
            print("User tapped daily episode notification")
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .dailyEpisodeNotificationTapped, object: nil)
            }
        }
        
        completionHandler()
    }
}

extension Notification.Name {
    static let dailyEpisodeNotificationTapped = Notification.Name("dailyEpisodeNotificationTapped")
}
