//
//  Sapients_appApp.swift
//  Sapients app
//
//  Created by Pratik Bhyan on 23/05/25.
//

import SwiftUI
import GoogleSignIn

// Enum to identify tabs
enum TabIdentifier {
    case nowPlaying, library, highlights
}

@main
struct Sapients_appApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var contentRepository = ContentRepository()
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @StateObject private var miniPlayerState = MiniPlayerState(player: AudioPlayerService.shared)
    @StateObject private var quickNotesRepository = QuickNotesRepository.shared
    @StateObject private var storeKit = StoreKitService.shared
    @State private var selectedTab: TabIdentifier = .nowPlaying
    @State private var isLoadingTranscription = false

    init() {
        configureGoogleSignIn()
        forceDarkMode()
    }

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .bottom) {
                mainContent
                    .preferredColorScheme(.dark)
                
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
            .environmentObject(storeKit)
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
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if authManager.isAuthenticated {
            TabView(selection: $selectedTab) {
                DailyContentViewLoader()
                    .tag(TabIdentifier.nowPlaying)
                    .tabItem {
                        Label("Now Playing", systemImage: "play.circle")
                    }
                
                ContentListView()
                    .tag(TabIdentifier.library)
                    .tabItem {
                        Label("Library", systemImage: "books.vertical")
                    }
                
                QuickNotesView()
                    .tag(TabIdentifier.highlights)
                    .tabItem {
                        Label("Highlights", systemImage: "highlighter")
                    }
            }
            .tint(.accentColor)
            .onAppear {
                // Configure translucent tab bar appearance
                let tabBarAppearance = UITabBarAppearance()
                tabBarAppearance.configureWithTransparentBackground()
                
                // Make background more translucent
                tabBarAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
                tabBarAppearance.backgroundColor = UIColor.black.withAlphaComponent(0.1)
                
                // Configure colors - white for selected, gray for normal
                tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor.secondaryLabel
                tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.secondaryLabel]
                tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor.white
                tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]
                
                // Also configure compact layout for smaller devices
                tabBarAppearance.compactInlineLayoutAppearance.normal.iconColor = UIColor.secondaryLabel
                tabBarAppearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.secondaryLabel]
                tabBarAppearance.compactInlineLayoutAppearance.selected.iconColor = UIColor.white
                tabBarAppearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]
                
                // Apply the same appearance to both standard and scrollEdge
                UITabBar.appearance().standardAppearance = tabBarAppearance
                UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
                
                forceDarkMode()
            }
            .onChange(of: selectedTab) { _, newTab in
                if newTab == .nowPlaying {
                    miniPlayerState.isVisible = false
                } else {
                    miniPlayerState.isVisible = audioPlayer.hasLoadedTrack
                }
            }
        } else {
            LoginView()
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
                    isLoadingTranscription: $isLoadingTranscription,
                    onDismissTapped: {
                        miniPlayerState.isPresentingFullPlayer = false
                    }
                )
            }
        }
    }
    
    // Google Sign-In configuration
    private func configureGoogleSignIn() {
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let clientID = dict["GIDClientID"] as? String {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            print("Google Sign-In configured with CLIENT_ID from Info.plist: \(clientID)")
            return
        }
        
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
    }

    private func forceDarkMode() {
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.forEach { window in
                    window.overrideUserInterfaceStyle = .dark
                }
            }
        }
        
        DispatchQueue.main.async {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .forEach { windowScene in
                    windowScene.windows.forEach { window in
                        window.overrideUserInterfaceStyle = .dark
                    }
                }
            }
        }
    }


extension Notification.Name {
    static let dailyEpisodeNotificationTapped = Notification.Name("dailyEpisodeNotificationTapped")
}
