import SwiftUI
import AVFoundation
import UIKit

struct TileFramePrefKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

enum FontSizeLevel: CaseIterable, Identifiable {
    case small, medium, large
    
    var id: Self { self }
    
    var size: CGFloat {
        switch self {
        case .small: return 20    // Was medium (20pt) - now small
        case .medium: return 24   // Was large (24pt) - now medium and default
        case .large: return 28    // New larger size - now large
        }
    }
    
    func next() -> FontSizeLevel {
        let allCases = Self.allCases
        guard let currentIndex = allCases.firstIndex(of: self) else { return .medium }
        let nextIndex = allCases.index(after: currentIndex)
        return allCases.indices.contains(nextIndex) ? allCases[nextIndex] : allCases.first!
    }
}

enum FontFamily: CaseIterable, Identifiable {
    case system, rounded, serif, mono
    
    var id: Self { self }
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .rounded: return "Rounded"
        case .serif: return "Serif"
        case .mono: return "Mono"
        }
    }
    
    func design() -> Font.Design {
        switch self {
        case .system: return .default
        case .rounded: return .rounded
        case .serif: return .serif
        case .mono: return .monospaced
        }
    }
    
    func next() -> FontFamily {
        let allCases = Self.allCases
        guard let currentIndex = allCases.firstIndex(of: self) else { return .system }
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
    @State private var currentFontSize: FontSizeLevel = .medium
    @State private var currentFontFamily: FontFamily = .system
    @State private var dragOffset: CGFloat = 0
    @State private var showAddNoteDialog = false
    @State private var tappedTranscriptionText = ""
    @State private var isSeekingFromTap = false
    @State private var pendingSeekIndex: Int? = nil
    @State private var showFontFamilyBubble = false
    // Auto‑scroll management
    @State private var autoScrollEnabled: Bool = true
    @State private var showReturnButton: Bool = false
    @State private var visibleIndices: Set<Int> = []
    @State private var scrollViewHeight: CGFloat = 0
    @State private var tappedIndex: Int? = nil

    // Constants
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
                if let transcriptionIndex = repository.transcriptions.firstIndex(where: { $0.text == tappedTranscriptionText }) {
                    let startTime = repository.transcriptions[transcriptionIndex].startTime
                    HighlightRepository.shared.add(tappedTranscriptionText, to: content.title, contentId: content.id, startTime: startTime)
                } else {
                    HighlightRepository.shared.add(tappedTranscriptionText, to: content.title, contentId: content.id)
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .toolbar(.hidden, for: .tabBar)
        .ignoresSafeArea()
        .onAppear {
            loadTranscriptionsIfNeeded()
        }
        .onChange(of: audioPlayer.currentTime) { _, _ in
            audioPlayer.updateCurrentTranscription(transcriptions: repository.transcriptions)
            if let pending = pendingSeekIndex,
               audioPlayer.currentTranscriptionIndex == pending {
                pendingSeekIndex = nil
            }
        }
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
            HStack {
                Spacer()
                
                ZStack {
                    if showFontFamilyBubble {
                        HStack(spacing: 8) {
                            ForEach(FontFamily.allCases) { family in
                                Button(family.displayName) {
                                    currentFontFamily = family
                                    showFontFamilyBubble = false
                                }
                                .font(.caption)
                                .foregroundColor(currentFontFamily == family ? .blue : .white.opacity(0.8))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(currentFontFamily == family ? Color.white.opacity(0.2) : Color.clear)
                                )
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.8))
                                .shadow(radius: 4)
                        )
                        .offset(x: -80, y: 0) 
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(1)
                    }
                    
                    Button(action: {
                        currentFontSize = currentFontSize.next()
                    }) {
                        Image(systemName: "textformat.size")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .onLongPressGesture(minimumDuration: 0.5) {
                        withAnimation(.spring(response: 0.3)) {
                            showFontFamilyBubble.toggle()
                        }
                    }
                }
                
                Spacer()
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
        .onTapGesture {
            if showFontFamilyBubble {
                withAnimation(.spring(response: 0.3)) {
                    showFontFamilyBubble = false
                }
            }
        }
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
                GeometryReader { geometry in
                    ScrollViewReader { proxy in
                        ZStack(alignment: .bottomTrailing) {
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(repository.transcriptions.indices, id: \.self) { index in
                                        let transcription = repository.transcriptions[index]
                                        transcriptionTile(for: transcription, index: index, proxy: proxy)
                                            .drawingGroup()
                                        if index < repository.transcriptions.count - 1 {
                                            Text(" ")
                                                .font(.system(size: currentFontSize.size * 0.6, design: currentFontFamily.design()))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }
                                .padding(.top, 10)
                                .padding(.bottom, fadeOutHeight + 5)
                            }
                            .scrollIndicators(.hidden)
                            .coordinateSpace(name: "TranscriptSpace")
                            .onPreferenceChange(TileFramePrefKey.self) { frames in
                                let visible = frames.filter { _, frame in
                                    let minY = frame.minY
                                    let maxY = frame.maxY
                                    return maxY > 0 && minY < scrollViewHeight
                                }
                                visibleIndices = Set(visible.keys)
                                updateReturnButton()
                            }
                            .simultaneousGesture(
                                DragGesture().onChanged { _ in
                                    if autoScrollEnabled {
                                        autoScrollEnabled = false
                                    }
                                    updateReturnButton()
                                    if showFontFamilyBubble {
                                        withAnimation(.spring(response: 0.3)) {
                                            showFontFamilyBubble = false
                                        }
                                    }
                                }
                            )
                            .mask(fadeGradientMask)
                            .onChange(of: audioPlayer.currentTranscriptionIndex) { _, newValue in
                                guard autoScrollEnabled, !isSeekingFromTap else { return }
                                if newValue >= 0 && newValue < repository.transcriptions.count {
                                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                                        proxy.scrollTo(newValue, anchor: .center)
                                    }
                                }
                                updateReturnButton()
                            }
                            .onChange(of: visibleIndices) { _, _ in
                                updateReturnButton()
                            }
                            .onAppear {
                                if audioPlayer.currentTranscriptionIndex >= 0 && audioPlayer.currentTranscriptionIndex < repository.transcriptions.count {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                                            proxy.scrollTo(audioPlayer.currentTranscriptionIndex, anchor: .center)
                                        }
                                    }
                                }
                            }
                            
                            if showReturnButton {
                                let minVisible = visibleIndices.min() ?? 0
                                let maxVisible = visibleIndices.max() ?? 0
                                let currentIndex = audioPlayer.currentTranscriptionIndex
                                
                                if currentIndex < minVisible || currentIndex > maxVisible {
                                    let arrowName = currentIndex < minVisible ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
                                    Button(action: {
                                        autoScrollEnabled = true
                                        showReturnButton = false
                                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                                            if audioPlayer.currentTranscriptionIndex >= 0 {
                                                proxy.scrollTo(audioPlayer.currentTranscriptionIndex, anchor: .center)
                                            }
                                        }
                                    }) {
                                        Image(systemName: arrowName)
                                            .font(.system(size: 44))
                                            .foregroundColor(.white)
                                            .shadow(radius: 4)
                                            .padding(.trailing, 16)
                                            .padding(.bottom, 16)
                                    }
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                    }
                    .onAppear {
                        scrollViewHeight = geometry.size.height
                    }
                    .onChange(of: geometry.size) { _, newSize in
                        scrollViewHeight = newSize.height
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .layoutPriority(1)
    }

    @ViewBuilder
    func transcriptionTile(for transcription: Transcription, index: Int, proxy: Any) -> some View {
        let isCurrentlyPlaying = audioPlayer.currentTranscriptionIndex == index
        let isPendingSeek = pendingSeekIndex == index
        let isHighlighted = isCurrentlyPlaying || isPendingSeek

        Text(transcription.text)
            .fontWeight(.regular)
            .font(.system(size: currentFontSize.size, weight: .regular, design: currentFontFamily.design()))
            .foregroundColor(isHighlighted ? .white : .white.opacity(0.35))
            .lineSpacing(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .id(index)
            .textSelection(.disabled)
            .allowsHitTesting(true)
            .scaleEffect(isPendingSeek ? 1.02 : 1.0)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: TileFramePrefKey.self,
                                    value: [index: geo.frame(in: .named("TranscriptSpace"))])
                }
            )
            .compositingGroup()
            .clipped()
            .onTapGesture {
                UIMenuController.shared.hideMenu()
                
                if showFontFamilyBubble {
                    withAnimation(.spring(response: 0.3)) {
                        showFontFamilyBubble = false
                    }
                }
                
                pendingSeekIndex = index
                
                audioPlayer.seek(to: TimeInterval(transcription.startTime))
                audioPlayer.currentTranscriptionIndex = index
                autoScrollEnabled = true
                showReturnButton = false
                
                if !audioPlayer.isPlaying {
                    audioPlayer.play()
                }
                
                isSeekingFromTap = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isSeekingFromTap = false
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    pendingSeekIndex = nil
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
            .animation(.easeInOut(duration: 0.2), value: isHighlighted)
            .animation(.easeInOut(duration: 0.15), value: isPendingSeek)
    }

    func updateReturnButton() {
        guard !autoScrollEnabled else {
            showReturnButton = false
            return
        }
        showReturnButton = !visibleIndices.contains(audioPlayer.currentTranscriptionIndex)
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
            lastSliderUpdate = Date()
            
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
