// MiniPlayerView.swift
import SwiftUI

struct MiniPlayerView: View {
    let content: Content
    @ObservedObject var audioPlayer: AudioPlayerService
    @ObservedObject var repository: ContentRepository
    var onTap: () -> Void // Closure to handle tap, likely to re-open full player

    var body: some View {
        HStack(spacing: 10) {
            // Thumbnail Image
            if let imageUrlString = content.imageUrl,
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
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .padding(8)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(4)
            }

            // Title
            Text(content.title)
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(Color(UIColor.label)) // Adapts to light/dark mode

            Spacer()

            // Play/Pause Button
            Button(action: {
                audioPlayer.togglePlayPause()
            }) {
                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundColor(Color(UIColor.label))
            }
            .padding(.trailing, 5)

            // Optional: Close button for miniplayer
            // Button(action: {
            //     audioPlayer.pause() // Stop playback
            //     // You'll need a way to tell ContentListView to hide the miniplayer,
            //     // perhaps by setting showMiniPlayer to false through another binding or callback.
            // }) {
            //     Image(systemName: "xmark")
            //         .font(.caption.weight(.bold))
            //         .foregroundColor(Color(UIColor.secondaryLabel))
            // }

        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(.thinMaterial) // Or .regularMaterial
        .cornerRadius(12)
        .shadow(radius: 3)
        .padding(.horizontal) // Outer padding for the miniplayer from screen edges
        .padding(.bottom, 50) // Adjust to avoid tab bar or other elements
        .onTapGesture {
            onTap() // Action to expand back to full player
        }
    }
}

struct MiniPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        // Create mock data for preview
        let mockContent = Content(
            id: UUID(),
            title: "A Long Title That Might Get Truncated",
            description: "Sample description",
            audioUrl: "sample.mp3",
            imageUrl: nil, // Or a placeholder URL
            createdAt: Date(),
            publishOn: Date(),
            transcriptionUrl: "sample.csv"
        )
        let mockAudioPlayer = AudioPlayerService.shared // Use shared instance
        let mockRepository = ContentRepository() // Use a fresh instance for preview

        // Simulate playing state
        // mockAudioPlayer.isPlaying = true
        // mockAudioPlayer.duration = 180 // 3 minutes
        // mockAudioPlayer.currentTime = 60 // 1 minute in

        return MiniPlayerView(
            content: mockContent,
            audioPlayer: mockAudioPlayer,
            repository: mockRepository,
            onTap: { print("Miniplayer tapped") }
        )
        .padding()
        .background(Color.gray.opacity(0.2)) // Simulate a background
        .previewLayout(.sizeThatFits)
    }
}
