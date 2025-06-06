import SwiftUI
import AVFoundation


struct ContentDetailView: View {
    let content: Content

    @ObservedObject var repository: ContentRepository // Passed in
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @EnvironmentObject private var miniState: MiniPlayerState

    init(content: Content, repository: ContentRepository) {
        self.content = content
        self.repository = repository // Assign passed-in repository
        print("[DIAG] ContentDetailView init: Title - \(content.title)")
    }
    
    @State private var isPlayingViewActive: Bool = false
    @State private var isLoadingTranscription: Bool = false

    private var currentDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: Date())
    }
    
    var body: some View {
        ZStack {
            // Blurred background, shown only when PlayingView is active
            if isPlayingViewActive {
                BlurredBackgroundView() // No longer needs content/repository
            }

            // Main content area
            VStack(alignment: .leading, spacing: 0) { // Reverted to .leading, children will manage padding
                if !isPlayingViewActive {
                    InitialView(
                        content: content,
                        currentDate: currentDate,
                        repository: repository,
                        audioPlayer: audioPlayer,
                        onPlayTapped: {
                            Task {
                                guard let newAudioURL = repository.getPublicURL(for: content.audioUrl, bucket: "audio") else {
                                    print("ContentDetailView: Could not get audio URL for \(content.title)")
                                    // Optionally show an error to the user
                                    return
                                }

                                // Load audio only if it's a different URL or not loaded yet
                                audioPlayer.loadAudio(from: newAudioURL, for: content) // Pass content here
                                audioPlayer.play()

                                // Fetch transcriptions
                                print("ContentDetailView: Fetching transcriptions for \(content.title)")
                                isLoadingTranscription = true
                                await repository.fetchTranscriptions(for: content.id, from: content.transcriptionUrl)
                                isLoadingTranscription = false
                                
                                // Transition to PlayingView
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isPlayingViewActive = true
                                }
                            }
                        }
                    )
                } else {
                    PlayingView(
                        content: content,
                        repository: repository,
                        audioPlayer: audioPlayer,
                        isLoadingTranscription: $isLoadingTranscription,
                        onDismissTapped: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPlayingViewActive = false
                                // miniState.isVisible will be handled by ContentDetailView's onDisappear
                            }
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity) // Ensure this VStack takes full width
            // Apply a background to the VStack for InitialView to prevent transparency issues
            // Clear background for PlayingView as it has its own blurred background.
            .background(isPlayingViewActive ? Color.clear : Color(UIColor.systemBackground))
        }
        .onAppear {
            // Hide mini player when detail view appears
            miniState.isVisible = false
            
            Task {
                if repository.transcriptions.isEmpty || repository.currentContentIdForTranscriptions != content.id {
                    print("ContentDetailView: Fetching transcriptions on appear for \(content.title)")
                    isLoadingTranscription = true
                    await repository.fetchTranscriptions(for: content.id, from: content.transcriptionUrl)
                    isLoadingTranscription = false
                    repository.currentContentIdForTranscriptions = content.id
                }
            }
        }
        .onDisappear {
            // Mini player visibility is now handled automatically by MiniPlayerState
            // when hasLoadedTrack is true
            
            if miniState.isPresentingFullPlayer {
                miniState.isPresentingFullPlayer = false
            }
            print("[DIAG] ContentDetailView ON_DISAPPEAR: Title - \(content.title), miniState.isVisible: \(miniState.isVisible), miniState.isPresentingFullPlayer: \(miniState.isPresentingFullPlayer)")
        }
        .onChange(of: audioPlayer.currentTime) { _, _ in
            if isPlayingViewActive {
                audioPlayer.updateCurrentTranscription(transcriptions: repository.transcriptions)
            }
        }
        .edgesIgnoringSafeArea(isPlayingViewActive ? .all : [])
        .preferredColorScheme(isPlayingViewActive ? .dark : nil)
    }
}

// MARK: - Blurred Background
struct BlurredBackgroundView: View {
    @State private var randomBaseColor: Color = Color.clear

    private func generateRandomDarkColor() -> Color {
        return Color(
            hue: Double.random(in: 0...1),
            saturation: Double.random(in: 0.3...0.6),
            brightness: Double.random(in: 0.2...0.4)
        )
    }

    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                randomBaseColor.opacity(0.6),
                randomBaseColor.lerp(to: .black, t: 0.85)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .onAppear {
            if randomBaseColor == .clear {
                randomBaseColor = generateRandomDarkColor()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .blur(radius: 30)
        .edgesIgnoringSafeArea(.all)
    }
}

extension Color {
    func lerp(to: Color, t: CGFloat) -> Color {
        let t = max(0, min(1, t))
        guard let C1 = self.cgColor?.components, let C2 = to.cgColor?.components else { return self }

        let r = C1[0] + (C2[0] - C1[0]) * t
        let g = C1[1] + (C2[1] - C1[1]) * t
        let b = C1[2] + (C2[2] - C1[2]) * t
        let a = (C1.count > 3 ? C1[3] : 1.0) + ((C2.count > 3 ? C2[3] : 1.0) - (C1.count > 3 ? C1[3] : 1.0)) * t
        
        return Color(red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
    }
}

// MARK: - Initial View (Home Screen Card)
struct InitialView: View {
    let content: Content
    let currentDate: String
    @ObservedObject var repository: ContentRepository
    @ObservedObject var audioPlayer: AudioPlayerService
    var onPlayTapped: () -> Void

    @State private var paddingBelowDescription: CGFloat = 5.0
    
    private var overlayGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.black.opacity(0.6),
                Color.black.opacity(0.1),
                Color.black.opacity(0.1),
                Color.black.opacity(0.7)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                let screenHeight = geometry.size.height
                let topSafeArea = geometry.safeAreaInsets.top
                let bottomSafeArea = geometry.safeAreaInsets.bottom

                let titleTopPercentage: CGFloat = 0.05
                let playButtonBottomPercentage: CGFloat = 0.12
                
                ZStack {
                    // Background Layer
                    ZStack {
                        if let imageUrlString = content.imageUrl,
                           let imageURL = repository.getPublicURL(for: imageUrlString, bucket: "images") {
                            CachedAsyncImage(url: imageURL) {
                                Color.clear.overlay(ProgressView().scaleEffect(1.5))
                            }
                            .scaledToFill()
                        } else {
                            VStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .resizable().scaledToFit().frame(width: 40, height: 40)
                                    .foregroundColor(.white.opacity(0.6))
                                Text("Image not found")
                                    .font(.caption).foregroundColor(.white.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }

                        overlayGradient
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()

                    // Foreground Layer
                    VStack(spacing: 0) {
                        VStack {
                            Spacer().frame(height:15)
                            Text("Sapients")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(currentDate)
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .padding(.top, topSafeArea + (screenHeight * titleTopPercentage))
                        .frame(maxWidth: .infinity, alignment: .center)

                        Spacer()

                        VStack(spacing: 5) {
                            VStack {
                                Text(content.description ?? content.title)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 30)
                                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 2)
                            }
                            .padding(.bottom, paddingBelowDescription)
                            .padding(.bottom, paddingBelowDescription)

                            VStack {
                                Button(action: onPlayTapped) {
                                    HStack {
                                        Image(systemName: "play.fill")
                                        Text("Play Episode")
                                            .fontWeight(.semibold)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 30)
                                    .background(Color.white.opacity(0.45))
                                    .foregroundColor(.white)
                                    .cornerRadius(25)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 25)
                                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.bottom, bottomSafeArea + (screenHeight * playButtonBottomPercentage))
                        .frame(maxWidth: .infinity, alignment: .center)

                    }
                    .padding(.horizontal, 20)

                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .foregroundColor(.white)
    }
}

#if DEBUG
struct ContentDetailView_Previews_FinalLayout: PreviewProvider {
    static var previews: some View {
        let mockContent = Content(
            id: UUID(),
            title: "The Subtle Art of Not Giving a F*ck",
            description: "A Counterintuitive Approach to Living a Good Life",
            audioUrl: "sample.mp3",
            imageUrl: "sample.jpg",
            createdAt: Date(),
            publishOn: nil,
            transcriptionUrl: nil
        )
        
        let mockRepo = ContentRepository()

        ContentDetailView(content: mockContent, repository: mockRepo)
    }
}
#endif
