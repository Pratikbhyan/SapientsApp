import SwiftUI
import AVFoundation // Likely needed for AudioPlayerService and time formatting
import UIKit // For UIApplication

// MARK: - Font Size Presets
enum FontSizePreset: CaseIterable, Identifiable {
    case small, medium, large

    var id: Self { self }

    var size: CGFloat {
        switch self {
        case .small: return 18
        case .medium: return 20 // Current default
        case .large: return 23
        }
    }

    // Optional: If you want the button to show S, M, L
    /*
    var displayName: String {
        switch self {
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        }
    }
    */

    func next() -> FontSizePreset {
        let allCases = Self.allCases
        guard let currentIndex = allCases.firstIndex(of: self) else { return .medium }
        let nextIndex = allCases.index(after: currentIndex)
        return allCases.indices.contains(nextIndex) ? allCases[nextIndex] : allCases.first!
    }
}

// MARK: - Playing View (More Compact Vertically)
struct PlayingView: View {
    let content: Content // Add the content property
    @ObservedObject var repository: ContentRepository
    @ObservedObject var audioPlayer: AudioPlayerService
    @EnvironmentObject var miniPlayerState: MiniPlayerState // Add direct access to miniPlayerState
    @Binding var isLoadingTranscription: Bool
    var onDismissTapped: () -> Void
    
    @State private var currentFontSizePreset: FontSizePreset = .medium // State for font size

    private let fadeOutHeight: CGFloat = 40

    var body: some View {
        VStack(spacing: 0) {
                HStack {
                    Button(action: onDismissTapped) { 
                        Image(systemName: "chevron.backward")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer() 
                    Button(action: { currentFontSizePreset = currentFontSizePreset.next() }) {
                        Image(systemName: "textformat.size")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            .padding(.horizontal, 20)
            .padding(.top, (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.top ?? 15)
            .padding(.bottom, 8) 

            Group {
                if isLoadingTranscription && repository.transcriptions.isEmpty { 
                    ProgressView("Loading Transcription...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .foregroundColor(.white.opacity(0.8))
                        .padding()
                        .frame(maxHeight: .infinity)
                } else if repository.transcriptions.isEmpty {
                    Text("No transcription available.")
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.6))
                        .padding()
                        .frame(maxHeight: .infinity)
                } else {
                    ScrollViewReader { scrollViewProxy in
                            ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(repository.transcriptions.indices, id: \.self) { index in
                                    let transcription = repository.transcriptions[index]
                                    let isHighlighted = audioPlayer.currentTranscriptionIndex == index
                                    let baseFontSize = currentFontSizePreset.size
                                    let currentTextSize = isHighlighted ? (baseFontSize * 1.4) : baseFontSize 

                                    Text(transcription.text)
                                        .fontWeight(isHighlighted ? .bold : .regular)  
                                        .font(.system(size: currentTextSize))
                                        .foregroundColor(isHighlighted ? .white.opacity(0.95) : .white.opacity(0.7)) 
                                        .lineSpacing(isHighlighted ? 8 : 6) 
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .id(index)
                                        .onTapGesture { 
                                            audioPlayer.seek(to: TimeInterval(transcription.startTime))
                                            if !audioPlayer.isPlaying { audioPlayer.play() }
                                        }

                                    if index < repository.transcriptions.count - 1 {
                                        Text(" ")
                                            .font(.system(size: baseFontSize * 0.6)) 
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                            .padding(.top, 10)
                            .padding(.bottom, fadeOutHeight + 5)
                        }

                        .mask(
                            VStack(spacing: 0) {
                                Rectangle().fill(Color.black)
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.black, Color.black.opacity(0.0)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: fadeOutHeight)
                            }
                        )
                        .onChange(of: audioPlayer.currentTranscriptionIndex) { oldValue, newValue in
                            let effectiveIndex = newValue 
                            if effectiveIndex >= 0 && effectiveIndex < repository.transcriptions.count {
                                withAnimation(.easeInOut) {
                                    scrollViewProxy.scrollTo(effectiveIndex, anchor: .center)
                                }
                            }
                        }
                    }
                    .layoutPriority(1)
                }
            }
            .padding(.horizontal, 20) 
            .layoutPriority(1) 

            DetailedAudioControls(content: content, audioPlayer: audioPlayer)
                .padding(.horizontal, 20)
                .padding(.bottom, (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.bottom ?? 8)
        }
        .frame(maxWidth: .infinity) 
        .foregroundColor(.white)
    }
}

// MARK: - Detailed Audio Controls
struct DetailedAudioControls: View {
    let content: Content 
    @State private var controlsOffsetX: CGFloat = 0 
    @StateObject private var favoritesService = FavoritesService.shared 
    @ObservedObject var audioPlayer: AudioPlayerService
    @State private var sliderValue: Double = 0
    @State private var isEditingSlider: Bool = false
    @State private var justSeeked: Bool = false

    private let availableRates: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        VStack(spacing: 10) { 
            Slider(
                value: $sliderValue,
                in: 0...max(audioPlayer.duration, 1),
                onEditingChanged: { editing in
                    if editing {
                        isEditingSlider = true
                        justSeeked = false
                    } else {
                        isEditingSlider = false
                        audioPlayer.seek(to: sliderValue)
                        justSeeked = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            justSeeked = false
                        }
                    }
                }
            )
            .accentColor(.white.opacity(0.8))
            .padding(.vertical, 5)
            .onChange(of: audioPlayer.currentTime) { _, newTime in
                if !isEditingSlider && !justSeeked {
                    sliderValue = newTime
                }
            }
            .onAppear {
                sliderValue = audioPlayer.currentTime
            }
            
            HStack { 
                Text(formatTime(sliderValue))
                Spacer()
                Text(formatTime(audioPlayer.duration))
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.7))
            
            HStack {
                Menu {
                    ForEach(availableRates, id: \.self) { rate in
                        Button(action: {
                            audioPlayer.setPlaybackRate(to: rate)
                        }) {
                            Text(String(format: "%.2fx", rate))
                        }
                    }
                } label: {
                    Text(String(format: "%.2fx", audioPlayer.currentPlaybackRate))
                        .font(.caption)
                        .padding(8)
                        .background(Color.black.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundColor(.white)
                }
                .padding(.leading, 20) 
                Spacer() 

                HStack(spacing: 40) {
                    Button(action: { audioPlayer.seek(to: max(0, audioPlayer.currentTime - 10)) }) {
                        Image(systemName: "gobackward.10")
                            .font(.title2)
                    }
                    
                    Button(action: { audioPlayer.togglePlayPause() }) {
                        Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 58, height: 58)
                    }
                    
                    Button(action: { audioPlayer.seek(to: min(audioPlayer.duration, audioPlayer.currentTime + 10)) }) {
                        Image(systemName: "goforward.10")
                            .font(.title2)
                    }
                } 

                Spacer() 

                Button(action: {
                    favoritesService.toggleFavorite(contentId: content.id)
                    print("Favorite button tapped. Is favorited: \(favoritesService.isFavorite(contentId: content.id))")
                }) {
                    Image(systemName: favoritesService.isFavorite(contentId: content.id) ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundColor(favoritesService.isFavorite(contentId: content.id) ? .pink : .white)
                }
                .padding(.trailing, 20) 

            } 
            .foregroundColor(.white.opacity(0.9)) 
            .offset(x: controlsOffsetX) 
            
        } 
        .padding(.top, 20)
        .padding(.bottom, 5)
    } 
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
} 
