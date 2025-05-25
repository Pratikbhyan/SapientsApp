import SwiftUI
import AVFoundation

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

struct ContentDetailView: View {
    let content: Content
    
    @StateObject private var repository = ContentRepository()
    @StateObject private var audioPlayer = AudioPlayerService.shared
    
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
                                // Ensure transcriptions are loaded before switching to playing view
                                if repository.transcriptions.isEmpty {
                                   isLoadingTranscription = true
                                   // Make sure ContentRepository is being correctly injected or initialized
                                   // if this await call relies on an instance that might not be ready.
                                   await repository.fetchTranscriptions(for: content.id)
                                   isLoadingTranscription = false
                                }
                                // Allow playing if audio is loaded, even if transcriptions fail or are empty
                                if audioPlayer.duration > 0 {
                                   audioPlayer.play()
                                   withAnimation(.easeInOut(duration: 0.3)) {
                                       isPlayingViewActive = true
                                   }
                                } else {
                                    // Handle case where audio might not be ready (duration is 0)
                                    print("Error: Audio not ready or no transcriptions available.")
                                    // Optionally, try to load audio again or show an error.
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
            // Load audio when the view first appears
            if let audioUrl = repository.getPublicURL(for: content.audioUrl, bucket: "audio") {
                audioPlayer.loadAudio(from: audioUrl)
            }
            // Pre-fetch transcriptions
            Task {
                if repository.transcriptions.isEmpty {
                    isLoadingTranscription = true
                    await repository.fetchTranscriptions(for: content.id)
                    isLoadingTranscription = false
                }
            }
        }
        .onDisappear {
            audioPlayer.pause() // Pause audio if the view disappears completely
        }
        .onChange(of: audioPlayer.currentTime) { // Corrected onChange for iOS 17+
            if isPlayingViewActive {
                audioPlayer.updateCurrentTranscription(transcriptions: repository.transcriptions)
            }
        }
        // Ignore safe area for PlayingView to allow full-screen background,
        // but respect it for InitialView.
        .edgesIgnoringSafeArea(isPlayingViewActive ? .all : [])
        .preferredColorScheme(isPlayingViewActive ? .dark : nil)
    }
}

// MARK: - Blurred Background
struct BlurredBackgroundView: View {
    // content and repository are no longer strictly needed if we don't use the image
    // let content: Content 
    // @ObservedObject var repository: ContentRepository

    @State private var randomBaseColor: Color = Color.clear // Initial placeholder

    // Helper to generate a pleasant random dark color
    private func generateRandomDarkColor() -> Color {
        // Generate colors that are not too dark or too garish
        // Hue: full spectrum, Saturation: moderate, Brightness: moderate to high
        return Color(
            hue: Double.random(in: 0...1),
            saturation: Double.random(in: 0.3...0.6), // Lower saturation for darker feel
            brightness: Double.random(in: 0.2...0.4)  // Lower brightness for darker colors
        )
    }

    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                randomBaseColor.opacity(0.6), // Top: random dark color, slightly transparent
                randomBaseColor.lerp(to: .black, t: 0.85) // Bottom: random dark color heavily blended towards black, ensuring it's very dark
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .onAppear {
            if randomBaseColor == .clear { // Generate color only once
                randomBaseColor = generateRandomDarkColor()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure Gradient fills available space
        // .clipped() // Not strictly necessary for a gradient, but harmless
        .blur(radius: 30) // Increased blur radius for a softer effect with colors
        // .overlay(Color.black.opacity(0.1)) // Optional: very subtle overall dimming if needed
        .edgesIgnoringSafeArea(.all)
    }
}

// Helper extension for Color to linearly interpolate (lerp)
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
    @ObservedObject var audioPlayer: AudioPlayerService // Keep if play button directly interacts
    var onPlayTapped: () -> Void

    // spaceBelowTitleDate is no longer needed as the main spacer will be flexible.
    @State private var paddingBelowDescription: CGFloat = 4.0 // Adjust for space between description and play button
    
    // To make text more readable on various images, add a subtle gradient overlay
    private var overlayGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.black.opacity(0.6), // Darker at the top
                Color.black.opacity(0.1), // Fading towards middle
                Color.black.opacity(0.1), // Fading towards middle
                Color.black.opacity(0.7)  // Darker at the bottom for controls/description
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        ZStack { // New outermost ZStack to ensure GeometryReader gets full screen size
            GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let topSafeArea = geometry.safeAreaInsets.top
            let bottomSafeArea = geometry.safeAreaInsets.bottom

            // Define percentage-based paddings. Adjust these percentages as needed.
            let titleTopPercentage: CGFloat = 0.05 // 5% of screen height from top safe area edge
            let playButtonBottomPercentage: CGFloat = 0.12 // 12% of screen height from bottom safe area edge (allows space for tab bar)
            
            ZStack { // This is the main ZStack filling GeometryReader
                // --- Background Layer (Image + Gradient) ---
                ZStack {
                    // Image part
                    if let imageUrlString = content.imageUrl, // Assuming content.imageUrl is String?
                       let imageURL = repository.getPublicURL(for: imageUrlString, bucket: "images") {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .empty:
                                // Placeholder for loading state - clear background lets gradient show
                                Color.clear.overlay(ProgressView().scaleEffect(1.5))
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill() // Ensures image fills its frame, maintaining aspect ratio
                            case .failure(_):
                                // Placeholder for failure state
                                VStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .resizable().scaledToFit().frame(width: 40, height: 40)
                                        .foregroundColor(.white.opacity(0.6))
                                    Text("Image unavailable")
                                        .font(.caption).foregroundColor(.white.opacity(0.6))
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity) // Center placeholder content
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        // Fallback if imageUrlString is nil or getPublicURL fails
                        VStack {
                            Image(systemName: "photo.on.rectangle.angled")
                                .resizable().scaledToFit().frame(width: 40, height: 40)
                                .foregroundColor(.white.opacity(0.6))
                            Text("Image not found")
                                .font(.caption).foregroundColor(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity) // Center placeholder content
                    }

                    // Gradient overlay part (covers the image/placeholder)
                    overlayGradient
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped() // Clip the entire background layer

                // --- Foreground Layer (Content Overlay) ---
                VStack(spacing: 0) {
                    // Top Section: Sapients & Date
                    VStack {
                        Text("Sapients")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(currentDate)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.top, topSafeArea + (screenHeight * titleTopPercentage))
                    .frame(maxWidth: .infinity, alignment: .center)

                    Spacer() // Flexible spacer to push bottom content down

                    // Bottom Group: Description & Play Button
                    VStack(spacing: 0) {
                        // Description
                        VStack {
                            Text(content.description ?? content.title ?? "No description available.")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                                .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
                        }
                        .padding(.bottom, paddingBelowDescription) // Uses the @State variable

                        // Play Button
                        VStack {
                            Button(action: onPlayTapped) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Play Episode")
                                        .fontWeight(.semibold)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 30)
                                .background(Color.white.opacity(0.25))
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

                } // Closes main Content Overlay VStack
                .padding(.horizontal, 20) // Overall horizontal padding for the content overlay

            } // Closes ZStack used for layering background and foreground
        } // Closes GeometryReader
    } // Closes new outermost ZStack
    .edgesIgnoringSafeArea(.all)
    .foregroundColor(.white)
    } // Closes body of InitialView
} // Closes struct InitialView

// MARK: - Playing View (More Compact Vertically)
struct PlayingView: View {
    let content: Content // Add the content property
    // The subsequent lines from your file (starting with @ObservedObject var repository: ContentRepository) will now correctly form the properties and body of this PlayingView struct.
    @ObservedObject var repository: ContentRepository
    @ObservedObject var audioPlayer: AudioPlayerService
    @Binding var isLoadingTranscription: Bool
    var onDismissTapped: () -> Void
    
    @State private var currentFontSizePreset: FontSizePreset = .medium // State for font size

    private let fadeOutHeight: CGFloat = 40 

    var body: some View {
        VStack(spacing: 0) { 
                HStack {
                Spacer() // Pushes font size button to the right
                // Font size adjustment button
                Button(action: { currentFontSizePreset = currentFontSizePreset.next() }) {
                    Image(systemName: "textformat.size")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.top ?? 15)
            .padding(.bottom, 8) // Apply horizontal padding to the HStack for both buttons

            Group {
                if isLoadingTranscription && repository.transcriptions.isEmpty { // Show loading only if empty
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
                                // Ensure ScrollView takes full available width
                            LazyVStack(alignment: .leading, spacing: 8) { 
                                ForEach(repository.transcriptions.indices, id: \.self) { index in
                                    let transcription = repository.transcriptions[index]
                                    let isHighlighted = audioPlayer.currentTranscriptionIndex == index
                                    let baseFontSize = currentFontSizePreset.size
                                    let currentTextSize = isHighlighted ? (baseFontSize * 1.4) : baseFontSize // Highlighted text 1.4x larger

                                    Text(transcription.text)
                                        .fontWeight(isHighlighted ? .bold : .regular)  // Highlighted text bold
                                        .font(.system(size: currentTextSize)) 
                                        .foregroundColor(isHighlighted ? .white.opacity(0.95) : .white.opacity(0.7)) // Slightly increased opacity for non-highlighted
                                        .lineSpacing(isHighlighted ? 8 : 6) // Increased line spacing, more for highlighted 
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .id(index)
                                        .onTapGesture { // Correctly placed onTapGesture
                                            audioPlayer.seek(to: TimeInterval(transcription.startTime))
                                            if !audioPlayer.isPlaying { audioPlayer.play() }
                                        }

                                    // Add a blank line equivalent after each transcription text block
                                    if index < repository.transcriptions.count - 1 {
                                        Text(" ")
                                            .font(.system(size: baseFontSize * 0.6)) // Adjust size for desired spacing
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
                            let effectiveIndex = newValue // Use newValue from the updated onChange signature
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
            .padding(.horizontal, 20) // This padding creates the margins for the transcription block
            .frame(height: UIScreen.main.bounds.height * 0.6) // Limit scroll area to avoid overflow
            .layoutPriority(1)

            // Title has been removed as per request

            DetailedAudioControls(audioPlayer: audioPlayer)
                .padding(.horizontal, 20) 
                .padding(.bottom, (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.bottom ?? 8) 
        }
        .frame(maxWidth: .infinity) // PlayingView's main VStack takes full width
        // Padding is now handled by children like the Group below
        // This main VStack for PlayingView should be full width.
        .foregroundColor(.white) 
    }
}

// MARK: - Detailed Audio Controls
struct DetailedAudioControls: View {
    @ObservedObject var audioPlayer: AudioPlayerService
    @State private var sliderValue: Double = 0
    @State private var isEditingSlider: Bool = false // To track slider drag state
    @State private var justSeeked: Bool = false // Flag to manage post-seek currentTime updates

    var body: some View {
        VStack(spacing: 10) {
            Slider(
                value: $sliderValue, // Bind to local state
                in: 0...max(audioPlayer.duration, 1),
                onEditingChanged: { editing in
                    if editing {
                        isEditingSlider = true
                        justSeeked = false // If user starts dragging again, clear the flag
                    } else {
                        // Editing ended.
                        isEditingSlider = false // User is no longer in direct control of sliderValue
                        audioPlayer.seek(to: sliderValue) // Tell player to seek
                        justSeeked = true // Set flag: we just told the player to seek

                        // Reset justSeeked after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            justSeeked = false
                        }
                    }
                }
            )
            .accentColor(.white.opacity(0.8))
            .padding(.vertical, 5)
            .onChange(of: audioPlayer.currentTime) { _, newTime in
                // Update slider position when audioPlayer.currentTime changes externally
                // Only if user is not dragging AND we haven't just initiated a seek
                if !isEditingSlider && !justSeeked {
                    sliderValue = newTime
                }
            }
            .onAppear {
                // Initialize sliderValue when the view appears
                sliderValue = audioPlayer.currentTime
            }
            
            HStack {
                Text(formatTime(sliderValue)) // Display based on sliderValue for consistent feedback
                Spacer()
                Text(formatTime(audioPlayer.duration))
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.7))
            
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
            .foregroundColor(.white.opacity(0.9))
        }
        .padding(.top, 20) // Apply desired top padding to the VStack
        .padding(.bottom, 5) // Apply desired bottom padding to the VStack
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
} // <<< Closing brace for DetailedAudioControls struct


#if DEBUG
struct ContentDetailView_Previews_FinalLayout: PreviewProvider {
    static var previews: some View {
        // Mock Content for preview
        let mockContent = Content(
            id: UUID(),
            title: "The Subtle Art of Not Giving a F*ck",
            description: "A Counterintuitive Approach to Living a Good Life",
            audioUrl: "sample.mp3", // These won't load in preview unless handled
            imageUrl: "sample.jpg", // These won't load in preview unless handled
            createdAt: Date()
        )
        
        // Mock Repository for preview
        let mockRepo = ContentRepository()
        // Example of populating mock transcriptions for previewing PlayingView
        // mockRepo.transcriptions = [
        //     Transcription(id: UUID(), contentId: mockContent.id, text: "This is a sample transcription line, make it long enough to test wrapping and visual appeal.", startTime: 0, endTime: 5, createdAt: Date()),
        //     Transcription(id: UUID(), contentId: mockContent.id, text: "Another line follows, perhaps a bit shorter this time.", startTime: 5, endTime: 10, createdAt: Date()),
        //     Transcription(id: UUID(), contentId: mockContent.id, text: "The quick brown fox jumps over the lazy dog.", startTime: 10, endTime: 15, createdAt: Date())
        // ]

        // You would pass the mockRepo to ContentDetailView if it's designed to take it as an @ObservedObject
        // For this setup, ContentDetailView initializes its own @StateObject for repository.
        // To make previews work with mock data for repository, you might need to adjust ContentDetailView
        // to accept repository as a parameter or use .environmentObject for previews.
        
        ContentDetailView(content: mockContent)
            // Example of how you might inject for preview if sub-views need it:
            // .environmentObject(AudioPlayerService.shared)
            // .environmentObject(mockRepo) // if repository was an EnvironmentObject
    }
}
#endif 
