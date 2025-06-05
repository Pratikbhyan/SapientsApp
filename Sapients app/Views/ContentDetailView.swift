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
        print("[DIAG] ContentDetailView init: Title - \(content.title), Repository instance: \(Unmanaged.passUnretained(repository).toOpaque())")
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
                                if audioPlayer.currentLoadedURL != newAudioURL || audioPlayer.currentContent?.id != content.id {
                                    print("ContentDetailView: Loading new audio for \(content.title) from URL: \(newAudioURL)")
                                    audioPlayer.loadAudio(from: newAudioURL, for: content) // Pass content here
                                } else {
                                    print("ContentDetailView: Audio for \(content.title) is already loaded or the same.")
                                }
                                
                                // Always attempt to play.
                                print("ContentDetailView: Attempting to play audio for \(content.title)")
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
            // Audio is no longer loaded automatically on appear.
            // It will be loaded on explicit play action.
            // Fetch transcriptions when the view appears
            Task {
                isLoadingTranscription = true
                await repository.fetchTranscriptions(for: content.id, from: content.transcriptionUrl)
                isLoadingTranscription = false
            }
        }
        .onDisappear {
            // audioPlayer.pause() // Removed to allow miniplayer to function
        }
        .onChange(of: audioPlayer.currentTime) { // Corrected onChange for iOS 17+
            if isPlayingViewActive {
                audioPlayer.updateCurrentTranscription(transcriptions: repository.transcriptions)
            }
        }
        .edgesIgnoringSafeArea(isPlayingViewActive ? .all : [])
        .preferredColorScheme(isPlayingViewActive ? .dark : nil)
        .onDisappear {
            // When the full player disappears, the mini-player's visibility should be updated.
            if audioPlayer.hasLoadedTrack {
                withAnimation { miniState.isVisible = true }
            } else {
                withAnimation { miniState.isVisible = false }
            }

            // Reset the full player presentation flag if this view is disappearing.
            // This is important if ContentDetailView was presented by tapping the mini-player.
            if miniState.isPresentingFullPlayer {
                miniState.isPresentingFullPlayer = false
            }
            print("[DIAG] ContentDetailView ON_DISAPPEAR: Title - \(content.title), miniState.isVisible: \(miniState.isVisible), miniState.isPresentingFullPlayer: \(miniState.isPresentingFullPlayer)")
        }
        .onAppear {
            // show big player => hide mini automatically
            withAnimation { miniState.isVisible = false }
            print("[DIAG] ContentDetailView ON_APPEAR: Title - \(content.title)")
            // Audio is no longer loaded automatically on appear.
            // It will be loaded on explicit play action.
            // Fetch transcriptions when the view appears
            Task {
                if repository.transcriptions.isEmpty || repository.currentContentIdForTranscriptions != content.id {
                    print("ContentDetailView: Fetching transcriptions on appear for \(content.title)")
                    isLoadingTranscription = true
                    await repository.fetchTranscriptions(for: content.id, from: content.transcriptionUrl)
                    isLoadingTranscription = false
                    repository.currentContentIdForTranscriptions = content.id // Remember which content's transcriptions are loaded
                }
            }
        }
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
    @State private var paddingBelowDescription: CGFloat = 5.0 // Adjust for space between description and play button
    
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
                        CachedAsyncImage(url: imageURL) {
                            // Placeholder for loading and error states (shows ProgressView for both)
                            Color.clear.overlay(ProgressView().scaleEffect(1.5))
                        }
                        .scaledToFill() // Ensures image fills its frame, maintaining aspect ratio
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

                    Spacer() // Flexible spacer to push bottom content down

                    // Bottom Group: Description & Play Button
                    VStack(spacing: 5) {
                        // Description
                        VStack {
                            Text(content.description ?? content.title)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                                .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 2)
                        }
                        .padding(.bottom, paddingBelowDescription) // Uses the @State variable
                        .padding(.bottom, paddingBelowDescription) // seUses the @State variable

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

                } // Closes main Content Overlay VStack
                .padding(.horizontal, 20) // Overall horizontal padding for the content overlay

            } // Closes ZStack used for layering background and foreground
        } // Closes GeometryReader
    } // Closes new outermost ZStack
    .edgesIgnoringSafeArea(.all)
    .foregroundColor(.white)
    } // Closes body of InitialView
} // Closes struct InitialView


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
            createdAt: Date(),
            publishOn: nil,
            transcriptionUrl: nil // Added for preview
        )
        
        // Mock Repository for preview (instance not directly used here as ContentDetailView creates its own)
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
        let mockRepo = ContentRepository() // Create a mock repository for the preview
        // Optionally populate mockRepo with data if needed for the preview
        // mockRepo.transcriptions = [ ... ]

        ContentDetailView(content: mockContent, repository: mockRepo)
            // Example of how you might inject for preview if sub-views need it:
            // .environmentObject(AudioPlayerService.shared)
            // .environmentObject(mockRepo) // if repository was an EnvironmentObject
    }
}
#endif
