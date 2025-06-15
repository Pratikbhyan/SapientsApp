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
    
    // UI State
    @State private var currentFontSizePreset: FontSizePreset = .medium
    @State private var dragOffset: CGFloat = 0
    @State private var showAddNoteDialog = false
    @State private var tappedTranscriptionText = ""
    @State private var isSeekingFromTap = false
    @State private var isUpdatingFromPlayer = false
    // SIMPLIFIED: Navigation state
    @State private var userHasScrolledAway = false
    @State private var showNavigationButton = false

    @State private var lastAutoScrollIndex: Int? = nil

    // Constants
    private let fadeOutHeight: CGFloat = 40
    private let dismissThreshold: CGFloat = 100
    private let availableRates: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ZStack {
                transcriptionArea
                
                // SIMPLIFIED: Navigation button overlay
                if showNavigationButton {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: returnToCurrentSegment) {
                                HStack(spacing: 8) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 14))
                                    Text("Now Playing")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.blue.opacity(0.9))
                                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
                                )
                                .foregroundColor(.white)
                            }
                            .padding(.trailing, 20)
                        }
                        .padding(.bottom, 100) // Above audio controls
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
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
                if let transcriptionIndex = repository.transcriptions.firstIndex(where: { $0.text == tappedTranscriptionText }) {
                    let startTime = repository.transcriptions[transcriptionIndex].startTime
                    HighlightRepository.shared.add(tappedTranscriptionText, to: content.title, contentId: content.id, startTime: startTime)
                } else {
                    HighlightRepository.shared.add(tappedTranscriptionText, to: content.title, contentId: content.id)
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .onAppear {
            loadTranscriptionsIfNeeded()
        }
        // FIXED: Restore simple transcription updates
        .onChange(of: audioPlayer.currentTime) { _, _ in
            if !isSeekingFromTap {
                audioPlayer.updateCurrentTranscription(transcriptions: repository.transcriptions)
            }
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
    
    // SIMPLIFIED: Return to current segment
    func returnToCurrentSegment() {
        userHasScrolledAway = false
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
            showNavigationButton = false
        }
    }

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
        .padding(.top, safeAreaInsets.top == 0 ? 5 : safeAreaInsets.top)
        .padding(.bottom, 6)
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
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(repository.transcriptions.indices, id: \.self) { index in
                                let transcription = repository.transcriptions[index]
                                transcriptionTile(for: transcription, index: index, proxy: proxy)
                                    .drawingGroup()
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
                    .scrollTargetLayout()
                    .scrollIndicators(.hidden)
                    .mask(fadeGradientMask)
                    .onChange(of: audioPlayer.currentTranscriptionIndex) { _, newValue in
                        guard !isSeekingFromTap else { return }
                        
                        if newValue >= 0 && newValue < repository.transcriptions.count {
                            if !userHasScrolledAway {
                                if lastAutoScrollIndex == nil || abs(newValue - (lastAutoScrollIndex ?? 0)) > 1 {
                                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                                        proxy.scrollTo(newValue, anchor: .center)
                                    }
                                    lastAutoScrollIndex = newValue
                                }
                            } else {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showNavigationButton = true
                                }
                            }
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { _ in
                                if !isSeekingFromTap {
                                    userHasScrolledAway = true
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showNavigationButton = true
                                    }
                                }
                            }
                    )
                    .onChange(of: userHasScrolledAway) { _, hasScrolledAway in
                        if !hasScrolledAway && audioPlayer.currentTranscriptionIndex >= 0 {
                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                                proxy.scrollTo(audioPlayer.currentTranscriptionIndex, anchor: .center)
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
            .textSelection(.disabled)
            .allowsHitTesting(true)
            .background(Color.clear)
            .compositingGroup()
            .clipped()
            .onTapGesture {
                UIMenuController.shared.hideMenu()
                
                isSeekingFromTap = true
                userHasScrolledAway = false // Reset when user seeks
                
                withAnimation(.easeInOut(duration: 0.2)) {
                    showNavigationButton = false
                }
                
                audioPlayer.seek(to: TimeInterval(transcription.startTime))
                audioPlayer.currentTranscriptionIndex = index
                
                if !audioPlayer.isPlaying {
                    audioPlayer.play()
                }
                
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                    proxy.scrollTo(index, anchor: .center)
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { 
                    isSeekingFromTap = false
                }
            }
            .onLongPressGesture(minimumDuration: 0.6) {
                UIMenuController.shared.hideMenu()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                tappedTranscriptionText = transcription.text
                showAddNoteDialog = true
            }
            .contextMenu {
                Button(action: {
                    HighlightRepository.shared.add(transcription.text, to: content.title, contentId: content.id, startTime: transcription.startTime)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    Label("Add to Highlights", systemImage: "highlighter")
                }
                
                Button(action: {
                    UIPasteboard.general.string = transcription.text
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    Label("Copy Text", systemImage: "doc.on.doc")
                }
                
                Button(action: {
                    shareTranscriptionText(transcription.text)
                }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
    }

    private var fadeGradientMask: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.black)
            
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .black, location: 0.0),
                    .init(color: .black.opacity(0.8), location: 0.3),
                    .init(color: .black.opacity(0.4), location: 0.7),
                    .init(color: .clear, location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: fadeOutHeight)
        }
        .drawingGroup()
    }

    var maskGradient: some View {
        fadeGradientMask
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

    private func shareTranscriptionText(_ text: String) {
        UIMenuController.shared.hideMenu()
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            
            if let topController = window.rootViewController {
                var presentedController = topController
                while let presented = presentedController.presentedViewController {
                    presentedController = presented
                }
                
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = window
                    popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                
                presentedController.present(activityVC, animated: true)
            }
        }
    }
}

struct DetailedAudioControls: View {
    let content: Content
    @ObservedObject var audioPlayer: AudioPlayerService

    @State private var sliderValue: Double = 0
    @State private var isEditingSlider: Bool = false
    @State private var justSeeked: Bool = false
    @State private var lastSliderUpdate: Date = Date()

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
                guard !isEditingSlider && !justSeeked else { return }
                
                let now = Date()
                // Only update slider every 0.5 seconds when not actively seeking
                if now.timeIntervalSince(lastSliderUpdate) > 0.5 {
                    sliderValue = newTime
                    lastSliderUpdate = now
                }
            }
            .onAppear {
                sliderValue = audioPlayer.currentTime
                lastSliderUpdate = Date()
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
            lastSliderUpdate = Date() // Reset timer after manual seek
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
