import SwiftUI

struct MiniPlayerBarView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @EnvironmentObject private var miniState: MiniPlayerState
    @EnvironmentObject private var repo: ContentRepository

    private let barHeight: CGFloat = 56
    private let verticalOffset: CGFloat = 14

    var body: some View {
        if miniState.isVisible, let content = audioPlayer.currentContent {
            HStack(spacing: 12) {
                // Artwork
                if let imgPath = content.imageUrl,
                   let url = repo.getPublicURL(for: imgPath, bucket: "images") {
                    CachedAsyncImage(url: url) { Color.gray }
                        .frame(width: 48, height: 48)
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 48, height: 48)
                }
                
                // Title and status
                VStack(alignment: .leading, spacing: 2) {
                    Text(content.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    Text(audioPlayer.isPlaying ? "Playing" : "Paused")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Play/pause button
                Button(action: { audioPlayer.togglePlayPause() }) {
                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .frame(height: barHeight)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 12)
            .padding(.bottom, safeAreaBottom + verticalOffset)
            .onTapGesture {
                miniState.presentFullPlayer()
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.3), value: miniState.isVisible)
        }
    }

    private var safeAreaBottom: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.keyWindow?.safeAreaInsets.bottom ?? 0
    }
} 