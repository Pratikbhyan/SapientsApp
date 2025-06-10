import SwiftUI
import UIKit

struct MiniPlayerView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @EnvironmentObject private var miniState: MiniPlayerState
    @EnvironmentObject private var repository: ContentRepository // For image URL

    @State private var yOffset: CGFloat = 0
    @State private var keyboardVisible: Bool = false
    private let dismissThreshold: CGFloat = 50 // How far user needs to drag to dismiss

    var body: some View {
        if miniState.isVisible && audioPlayer.currentContent != nil && !keyboardVisible {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    // Artwork
                    if let content = audioPlayer.currentContent,
                       let imageUrlString = content.imageUrl,
                       let imageURL = repository.getPublicURL(for: imageUrlString, bucket: "images") {
                        CachedAsyncImage(url: imageURL) {
                            DefaultPlaceholder()
                                .frame(width: 40, height: 40)
                        }
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .cornerRadius(4)
                        .clipped()
                    } else {
                        Image(systemName: "music.note")
                            .resizable().scaledToFit().frame(width: 20, height: 20)
                            .padding(10)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(Color.gray)
                            .cornerRadius(4)
                    }

                    // Title
                    Text(audioPlayer.currentContent?.title ?? "Not Playing")
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                        .foregroundColor(Color(UIColor.label))

                    Spacer()

                    Button(action: { 
                        if !audioPlayer.isBuffering {
                            audioPlayer.togglePlayPause() 
                        }
                    }) {
                        Group {
                            if audioPlayer.isBuffering {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(UIColor.label)))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(Color(UIColor.label))
                            }
                        }
                        .frame(width: 40, height: 40) // Increase tap area
                    }
                    .disabled(audioPlayer.isBuffering)

                    // Close Button
                    Button(action: {
                        withAnimation {
                            audioPlayer.stop() // Stop audio and hide via hasLoadedTrack
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(UIColor.secondaryLabel))
                            .frame(width: 40, height: 40) // Increase tap area
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(.thinMaterial) // Or .regularMaterial, .ultraThinMaterial
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
            .padding(.horizontal)
            .padding(.bottom, (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.bottom ?? 0 > 0 ? 50 : 8) // Adjust bottom padding based on safe area (e.g., for TabView)
            .offset(y: yOffset)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    keyboardVisible = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    keyboardVisible = false
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow dragging downwards
                        if value.translation.height > 0 {
                            self.yOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > dismissThreshold {
                            withAnimation(.spring()) {
                                audioPlayer.stop() // Stop audio and hide via hasLoadedTrack
                                self.yOffset = 0 // Reset offset
                            }
                        } else {
                            withAnimation(.spring()) {
                                self.yOffset = 0 // Snap back
                            }
                        }
                    }
            )
            .onTapGesture {
                withAnimation {
                    miniState.isPresentingFullPlayer = true
                }
                print("MiniPlayer tapped - setting isPresentingFullPlayer to true.")
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: miniState.isVisible) // Animation for appear/disappear
            .animation(.spring(), value: yOffset) // Animation for drag offset
        }
    }
}

struct MiniPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        // Create mock services and states for preview
        let audioPlayer = AudioPlayerService.shared
        let miniState = MiniPlayerState(player: audioPlayer)
        let repository = ContentRepository()

        // Simulate a loaded track for preview
        let mockContent = Content(
            id: UUID(),
            title: "Preview Track Title - A Very Long Title Indeed That Should Be Truncated",
            description: "Preview Description",
            audioUrl: "example.mp3",
            imageUrl: nil, // Test with no image
            createdAt: Date(),
            publishOn: Date(),
            transcriptionUrl: "example.csv"
        )
        audioPlayer.currentContent = mockContent
        audioPlayer.hasLoadedTrack = true
        audioPlayer.isPlaying = false
        audioPlayer.duration = 240 // 4 minutes
        audioPlayer.currentTime = 60  // 1 minute in
        miniState.isVisible = true

        return ZStack(alignment: .bottom) {
            // Simulate some background content
            Color.gray.opacity(0.1).edgesIgnoringSafeArea(.all)
            Text("Main App Content Area")
            
            MiniPlayerView()
                .environmentObject(audioPlayer)
                .environmentObject(miniState)
                .environmentObject(repository)
        }
    }
}
