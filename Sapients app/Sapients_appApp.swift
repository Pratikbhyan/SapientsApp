//
//  Sapients_appApp.swift
//  Sapients app
//
//  Created by Pratik Bhyan on 23/05/25.
//

import SwiftUI
import GoogleSignIn
import FirebaseCore
import FirebaseAuth

// Enum to identify tabs
enum TabIdentifier {
    case library, highlights
}

@main
struct Sapients_appApp: App {
    @StateObject private var authManager = FirebaseAuthManager.shared
    @StateObject private var contentRepository = ContentRepository()
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @StateObject private var miniPlayerState = MiniPlayerState(player: AudioPlayerService.shared)
    @StateObject private var quickNotesRepository = QuickNotesRepository.shared
    @StateObject private var storeKit = StoreKitService.shared
    @State private var selectedTab: TabIdentifier = .library
    @State private var isLoadingTranscription = false

    init() {
        FirebaseApp.configure()
        configureGoogleSignIn()
        forceDarkMode()
    }

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .bottom) {
                mainContent
                    .preferredColorScheme(.dark)
                
                // Unified draggable full-player ↔︎ mini-player container
                MiniPlayerBarView()
            }
            .environmentObject(authManager)
            .environmentObject(contentRepository)
            .environmentObject(audioPlayer)
            .environmentObject(miniPlayerState)
            .environmentObject(quickNotesRepository)
            .environmentObject(storeKit)
            .fullScreenCover(isPresented: $miniPlayerState.isPresentingFullPlayer) {
                fullPlayerSheet
            }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if authManager.isAuthenticated {
            TabView(selection: $selectedTab) {
                CollectionsListView()
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
                        miniPlayerState.dismissFullPlayer()
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
