import SwiftUI
import AVFoundation

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
                BlurredBackgroundView(content: content, repository: repository)
            }

            // Main content area
            VStack(alignment: .leading, spacing: 0) {
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
    }
}

// MARK: - Blurred Background
struct BlurredBackgroundView: View {
    let content: Content
    @ObservedObject var repository: ContentRepository // Ensure this is correctly passed or use @EnvironmentObject

    var body: some View {
        Group {
            if let imageUrl = content.imageUrl,
               let url = repository.getPublicURL(for: imageUrl, bucket: "images") {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .failure(_):
                        Color.gray.opacity(0.2) // Fallback for failed image load
                    case .empty:
                        Color.gray.opacity(0.1).overlay(ProgressView()) // Placeholder while loading
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Color.gray.opacity(0.2) // Fallback if no image URL
            }
        }
        .overlay(Color.black.opacity(0.55)) // Increased dimming slightly
        .blur(radius: 20) 
        .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - Initial View (Home Screen Card)
struct InitialView: View {
    let content: Content
    let currentDate: String
    @ObservedObject var repository: ContentRepository
    @ObservedObject var audioPlayer: AudioPlayerService
    var onPlayTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sapients")
                .font(.system(size: 34, weight: .bold)) 
                .padding(.horizontal)
                .padding(.top, (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.top ?? 15)

            Text(currentDate)
                .font(.system(size: 22, weight: .medium)) 
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 15) 

            ZStack { 
                if let imageUrl = content.imageUrl,
                   let url = repository.getPublicURL(for: imageUrl, bucket: "images") {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        case .failure(_):
                            Rectangle().foregroundColor(Color(UIColor.secondarySystemBackground)).overlay(Image(systemName: "photo.fill").foregroundColor(.secondary))
                        case .empty:
                            Rectangle().foregroundColor(Color(UIColor.secondarySystemBackground)).overlay(ProgressView())
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(height: UIScreen.main.bounds.height * 0.50) 
                    .clipped()
                    .cornerRadius(20)
                } else {
                    Rectangle().fill(Color(UIColor.secondarySystemBackground))
                        .frame(height: UIScreen.main.bounds.height * 0.50)
                        .cornerRadius(20)
                        .overlay(Image(systemName: "photo.fill").font(.largeTitle).foregroundColor(.secondary))
                }

                VStack { 
                    Text(content.title)
                        .font(.system(size: 24, weight: .bold)) 
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .padding(.top, 20) 
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)

                    Spacer() 
                    
                    Button(action: onPlayTapped) {
                        Image(systemName: "play.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 65, height: 65) 
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.4), radius: 5, x: 0, y: 3)
                    }
                    .padding(.bottom, 25) 
                }
                .frame(height: UIScreen.main.bounds.height * 0.50) 
            }
            .padding(.horizontal)
            
            Spacer() 
        }
    }
}

// MARK: - Playing View (More Compact Vertically)
struct PlayingView: View {
    let content: Content
    @ObservedObject var repository: ContentRepository
    @ObservedObject var audioPlayer: AudioPlayerService
    @Binding var isLoadingTranscription: Bool
    var onDismissTapped: () -> Void
    
    private let fadeOutHeight: CGFloat = 40 

    var body: some View {
        VStack(spacing: 0) { 
            HStack {
                Spacer()
                Button(action: onDismissTapped) {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.title2) 
                        .foregroundColor(.white.opacity(0.75))
                }
            }
            .padding(.top, (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.top ?? 10)
            .padding(.trailing)
            .padding(.bottom, 8) 

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
                            LazyVStack(alignment: .leading, spacing: 8) { 
                                ForEach(repository.transcriptions.indices, id: \.self) { index in
                                    let transcription = repository.transcriptions[index]
                                    Text(transcription.text)
                                        .fontWeight(audioPlayer.currentTranscriptionIndex == index ? .medium : .regular) 
                                        .font(.system(size: 16.5)) 
                                        .foregroundColor(audioPlayer.currentTranscriptionIndex == index ? .white.opacity(0.95) : .white.opacity(0.6)) 
                                        .lineSpacing(4) 
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .id(index)
                                        .onTapGesture {
                                            audioPlayer.seek(to: TimeInterval(transcription.startTime))
                                            if !audioPlayer.isPlaying { audioPlayer.play() }
                                        }
                                }
                            }
                            .padding(.horizontal, 20) 
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
                        .onChange(of: audioPlayer.currentTranscriptionIndex) { newIndex in // Corrected for iOS 17+
                            if newIndex >= 0 && newIndex < repository.transcriptions.count {
                                withAnimation(.easeInOut) {
                                    scrollViewProxy.scrollTo(newIndex, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity) 

            Text(content.title)
                .font(.system(size: 19, weight: .semibold)) 
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 20)
                .padding(.top, -fadeOutHeight + 8) 
                .padding(.bottom, 8) 
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            DetailedAudioControls(audioPlayer: audioPlayer)
                .padding(.horizontal, 20) 
                .padding(.bottom, (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.bottom ?? 8) 
        }
        .foregroundColor(.white) 
    }
}

// MARK: - Detailed Audio Controls
struct DetailedAudioControls: View {
    @ObservedObject var audioPlayer: AudioPlayerService
    
    var body: some View {
        VStack(spacing: 10) { 
                Slider(
                    value: Binding(
                    get: { audioPlayer.currentTime },
                    set: { audioPlayer.seek(to: $0) }
                    ),
                in: 0...max(audioPlayer.duration, 1)
                )
            .accentColor(.white.opacity(0.8)) 
            .padding(.vertical, 5) 
                
                HStack {
                Text(formatTime(audioPlayer.currentTime))
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
        .padding(.top, 5) 
        .padding(.bottom, 5) 
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}


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