import SwiftUI
import AVFoundation
import UIKit


enum FontSizePreset: CaseIterable, Identifiable {
    case small, medium, large

    var id: Self { self }

    var size: CGFloat {
        switch self {
        case .small: return 18
        case .medium: return 20 
        case .large: return 23
        }
    }

    func next() -> FontSizePreset {
        let allCases = Self.allCases
        guard let currentIndex = allCases.firstIndex(of: self) else { return .medium }
        let nextIndex = allCases.index(after: currentIndex)
        return allCases.indices.contains(nextIndex) ? allCases[nextIndex] : allCases.first!
    }
}

struct PlayingView: View {
    let content: Content 
    @ObservedObject var repository: ContentRepository
    @ObservedObject var audioPlayer: AudioPlayerService
    @EnvironmentObject var miniPlayerState: MiniPlayerState 
    @Binding var isLoadingTranscription: Bool
    var onDismissTapped: () -> Void
    
    @State private var currentFontSizePreset: FontSizePreset = .medium 
    @State private var dragOffset: CGFloat = 0
    @State private var showAddNoteDialog = false
    @State private var tappedTranscriptionText = ""
    @State private var isSeekingFromTap = false

    private let fadeOutHeight: CGFloat = 40
    private let dismissThreshold: CGFloat = 100
    private let availableRates: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            transcriptionArea
            DetailedAudioControls(content: content, audioPlayer: audioPlayer) 
                .padding(.horizontal, 20)
                .padding(.bottom, safeAreaInsets.bottom == 0 ? 8 : safeAreaInsets.bottom)
        }
        .frame(maxWidth: .infinity) 
        .foregroundColor(.white)
        .offset(y: dragOffset)
        .background(Color.clear)
        .gesture(
            DragGesture(coordinateSpace: .global)
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > dismissThreshold {
                        withAnimation(.spring()) {
                            onDismissTapped()
                        }
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .confirmationDialog("Add to Highlights?", isPresented: $showAddNoteDialog, titleVisibility: .visible) {
            Button("Add") {
                HighlightRepository.shared.add(tappedTranscriptionText, to: content.title)
            }
            Button("Cancel", role: .cancel) { }
        }
        .onAppear {
            loadTranscriptionsIfNeeded()
        }
        .onChange(of: audioPlayer.currentTime) { _, _ in
            audioPlayer.updateCurrentTranscription(transcriptions: repository.transcriptions)
        }
        .toolbar(.hidden, for: .tabBar)
        .ignoresSafeArea()
        .onAppear { 
            adjustMiniPlayerVisibility(isAppearing: true) 
        }
        .onDisappear { 
            adjustMiniPlayerVisibility(isAppearing: false) 
        }
    }
}

private extension PlayingView {
    var safeAreaInsets: UIEdgeInsets {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first { $0.isKeyWindow }?.safeAreaInsets ?? .zero
    }

    var topBar: some View {
        ZStack {
            Button(action: { currentFontSizePreset = currentFontSizePreset.next() }) {
                Image(systemName: "textformat.size")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
            }

            HStack {
                Button(action: onDismissTapped) {
                    Image(systemName: "chevron.backward")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
                Menu {
                    ForEach(availableRates, id: \.self) { rate in
                        Button(action: { audioPlayer.setPlaybackRate(to: rate) }) {
                            Text(String(format: "%.2fx", rate))
                        }
                    }
                } label: {
                    Image(systemName: "speedometer")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, safeAreaInsets.top == 0 ? 15 : safeAreaInsets.top)
        .padding(.bottom, 8)
    }

    var transcriptionArea: some View {
        Group {
            if isLoadingTranscription && repository.transcriptions.isEmpty { 
                ProgressView("Loading Transcription…")
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
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(repository.transcriptions.indices, id: \.self) { index in
                                let transcription = repository.transcriptions[index]
                                transcriptionTile(for: transcription, index: index, proxy: proxy)
                                if index < repository.transcriptions.count - 1 {
                                    Text(" ") 
                                        .font(.system(size: currentFontSizePreset.size * 0.6)) 
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
                    .onChange(of: audioPlayer.currentTranscriptionIndex) { _, newValue in
                        guard !isSeekingFromTap else { return } 
                        if newValue >= 0 && newValue < repository.transcriptions.count {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(newValue, anchor: .center)
                            }
                        }
                    }
                }
                .layoutPriority(1)
                .padding(.horizontal, 20) 
            }
        }
        .layoutPriority(1) 
    }

    @ViewBuilder
    func transcriptionTile(for transcription: Transcription, index: Int, proxy: ScrollViewProxy) -> some View {
        let isHighlighted = audioPlayer.currentTranscriptionIndex == index
        let baseFont = currentFontSizePreset.size
        let fontSize = isHighlighted ? baseFont * 1.4 : baseFont

        Text(transcription.text)
            .fontWeight(isHighlighted ? .bold : .regular)  
            .font(.system(size: fontSize))
            .foregroundColor(isHighlighted ? .white.opacity(0.95) : .white.opacity(0.7)) 
            .lineSpacing(isHighlighted ? 8 : 6) 
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .id(index)
            .onTapGesture { 
                isSeekingFromTap = true
                audioPlayer.seek(to: TimeInterval(transcription.startTime))
                audioPlayer.currentTranscriptionIndex = index 
                if !audioPlayer.isPlaying { 
                    audioPlayer.play() 
                }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(index, anchor: .center)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { isSeekingFromTap = false }
            }
            .onLongPressGesture(minimumDuration: 0.6) {
                guard isHighlighted else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                tappedTranscriptionText = transcription.text
                showAddNoteDialog = true
            }
    }

    var maskGradient: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.black)
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.black.opacity(0.0)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: fadeOutHeight)
        }
    }

    var viewDragGesture: some Gesture {
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                if value.translation.height > 0 { 
                    dragOffset = value.translation.height
                }
            }
            .onEnded { value in
                if value.translation.height > dismissThreshold {
                    withAnimation(.spring()) { 
                        onDismissTapped()
                    }
                } else {
                    withAnimation(.spring()) { 
                        dragOffset = 0
                    }
                }
            }
    }

    func loadTranscriptionsIfNeeded() {
        if repository.transcriptions.isEmpty || repository.currentContentIdForTranscriptions != content.id {
            Task {
                isLoadingTranscription = true
                await repository.fetchTranscriptions(for: content.id, from: content.transcriptionUrl)
                isLoadingTranscription = false
                repository.currentContentIdForTranscriptions = content.id
            }
        }
    }

    func adjustMiniPlayerVisibility(isAppearing: Bool) {
        if #unavailable(iOS 16.0) {
            UITabBar.appearance().isHidden = isAppearing
        }
        if isAppearing {
            miniPlayerState.isVisible = false
        } else {
            miniPlayerState.isVisible = audioPlayer.hasLoadedTrack && !miniPlayerState.isPresentingFullPlayer
        }
    }
}

struct DetailedAudioControls: View {
    let content: Content 
    @ObservedObject var audioPlayer: AudioPlayerService

    @State private var sliderValue: Double = 0
    @State private var isEditingSlider: Bool = false
    @State private var justSeeked: Bool = false

    var body: some View {
        VStack(spacing: 10) { 
            Slider(
                value: $sliderValue,
                in: 0...max(audioPlayer.duration, 1),
                onEditingChanged: sliderEditingChanged
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
                Spacer() 
                HStack(spacing: 40) {
                    Button(action: { audioPlayer.seek(to: max(0, audioPlayer.currentTime - 10)) }) {
                        Image(systemName: "gobackward.10")
                            .font(.title2)
                    }
                    
                    Button(action: togglePlayPause) {
                        Group {
                            if audioPlayer.isBuffering {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                            } else {
                                Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            }
                        }
                        .frame(width: 58, height: 58)
                    }
                    .disabled(audioPlayer.isBuffering)
                    
                    Button(action: { audioPlayer.seek(to: min(audioPlayer.duration, audioPlayer.currentTime + 10)) }) {
                        Image(systemName: "goforward.10")
                            .font(.title2)
                    }
                } 

                Spacer() 
            } 
            .foregroundColor(.white.opacity(0.9)) 
        } 
        .padding(.top, 20)
        .padding(.bottom, 5)
    } 
    
    private func sliderEditingChanged(_ editing: Bool) {
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

    private func togglePlayPause() {
        if !audioPlayer.isBuffering { 
            audioPlayer.togglePlayPause() 
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
