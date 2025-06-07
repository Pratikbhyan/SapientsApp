import SwiftUI
import AVFoundation
import UIKit

struct ContentDetailView: View {
    let content: Content

    @ObservedObject var repository: ContentRepository
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @EnvironmentObject private var miniState: MiniPlayerState
    @StateObject private var subscriptionService = SubscriptionService.shared

    init(content: Content, repository: ContentRepository) {
        self.content = content
        self.repository = repository
        print("[DIAG] ContentDetailView init: Title - \(content.title)")
    }
    
    @State private var showPlayer = false
    @State private var isLoadingTranscription: Bool = false
    @State private var showSubscriptionSheet = false
    
    private var currentDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: content.effectiveSortDate)
    }
    
    private var isContentFree: Bool {
        return subscriptionService.isContentFree(content, in: repository.contents)
    }
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) { 
                InitialView(
                    content: content,
                    currentDate: currentDate,
                    repository: repository,
                    audioPlayer: audioPlayer,
                    showPlayer: $showPlayer,
                    onPlayTapped: {
                        // Check subscription before playing
                        if isContentFree {
                            Task {
                                await playContent()
                            }
                        } else {
                            showSubscriptionSheet = true
                        }
                    }
                )
            }
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.systemBackground))
        }
        .sheet(isPresented: $showPlayer) {
            ZStack {
                BlurredBackgroundView()
                    .edgesIgnoringSafeArea(.all)
                
                PlayingView(
                    content: content,
                    repository: repository,
                    audioPlayer: audioPlayer,
                    isLoadingTranscription: $isLoadingTranscription,
                    onDismissTapped: { showPlayer = false }
                )
            }
            .preferredColorScheme(.dark)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSubscriptionSheet) {
            SubscriptionView()
        }
        .onAppear {
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
            if audioPlayer.hasLoadedTrack && !miniState.isPresentingFullPlayer {
                miniState.isVisible = true
            }
            
            print("[DIAG] ContentDetailView ON_DISAPPEAR: Title - \(content.title), miniState.isVisible: \(miniState.isVisible), miniState.isPresentingFullPlayer: \(miniState.isPresentingFullPlayer)")
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    private func playContent() async {
        guard let newAudioURL = repository.getPublicURL(for: content.audioUrl, bucket: "audio") else {
            print("ContentDetailView: Could not get audio URL for \(content.title)")
            return
        }

        audioPlayer.loadAudio(from: newAudioURL, for: content)
        audioPlayer.play()

        showPlayer = true

        print("ContentDetailView: Fetching transcriptions for \(content.title)")
        self.isLoadingTranscription = true
        await repository.fetchTranscriptions(for: content.id, from: content.transcriptionUrl)
        self.isLoadingTranscription = false
    }
}

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

struct InitialView: View {
    let content: Content
    let currentDate: String
    @ObservedObject var repository: ContentRepository
    @ObservedObject var audioPlayer: AudioPlayerService
    @Binding var showPlayer: Bool
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
                                Button(action: {
                                    if audioPlayer.currentContent?.id == content.id && audioPlayer.isPlaying {
                                        audioPlayer.pause()
                                    } else if audioPlayer.currentContent?.id == content.id && !audioPlayer.isPlaying {
                                        showPlayer = true
                                        audioPlayer.play()
                                    } else {
                                        // Different content - trigger onPlayTapped (which does subscription check)
                                        onPlayTapped()
                                    }
                                }) {
                                    HStack {
                                        let isCurrentlyPlaying = audioPlayer.currentContent?.id == content.id && audioPlayer.isPlaying
                                        let isCurrentButPaused = audioPlayer.currentContent?.id == content.id && !audioPlayer.isPlaying
                                        
                                        Image(systemName: isCurrentlyPlaying ? "pause.fill" : "play.fill")
                                        
                                        Text({
                                            if isCurrentlyPlaying {
                                                return "Pause Episode"
                                            } else if isCurrentButPaused {
                                                return "Resume Episode"
                                            } else {
                                                return "Play Episode"
                                            }
                                        }())
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
