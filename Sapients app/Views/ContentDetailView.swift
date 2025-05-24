import SwiftUI
import AVFoundation

struct ContentDetailView: View {
    let content: Content
    
    @StateObject private var repository = ContentRepository()
    @StateObject private var audioPlayer = AudioPlayerService.shared
    
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Image
                if let imageUrl = content.imageUrl,
                   let url = repository.getPublicURL(for: imageUrl, bucket: "images") {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .foregroundColor(.gray.opacity(0.2))
                            .overlay(
                                ProgressView()
                                    .scaleEffect(1.2)
                            )
                    }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(12)
                    .clipped()
                }
                
                // Title and Description
                VStack(alignment: .leading, spacing: 8) {
                    Text(content.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let description = content.description {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                // Audio Player Controls
                AudioPlayerControlsView(
                    isPlaying: audioPlayer.isPlaying,
                    currentTime: audioPlayer.currentTime,
                    duration: audioPlayer.duration,
                    isLoading: isLoading,
                    onPlayPause: { audioPlayer.togglePlayPause() },
                    onSeek: { time in audioPlayer.seek(to: time) }
                )
                
                // Transcription Display
                TranscriptionView(
                    transcriptions: repository.transcriptions,
                    currentIndex: audioPlayer.currentTranscriptionIndex,
                    isLoading: repository.isLoading,
                    onTranscriptionTap: { transcription in
                        audioPlayer.seek(to: TimeInterval(transcription.startTime))
                        audioPlayer.play()
                    }
                )
            }
            .padding(.vertical)
        }
        .navigationTitle("Now Playing")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadContent()
        }
        .onDisappear {
            audioPlayer.pause()
        }
        .onChange(of: audioPlayer.currentTime) { _ in
            audioPlayer.updateCurrentTranscription(transcriptions: repository.transcriptions)
        }
    }
    
    private func loadContent() {
        Task {
            isLoading = true
            
            // Load transcriptions
            await repository.fetchTranscriptions(for: content.id)
            
            // Load audio
            if let audioUrl = repository.getPublicURL(for: content.audioUrl, bucket: "audio") {
                audioPlayer.loadAudio(from: audioUrl)
            }
            
            isLoading = false
        }
    }
}

struct AudioPlayerControlsView: View {
    let isPlaying: Bool
    let currentTime: TimeInterval
    let duration: TimeInterval
    let isLoading: Bool
    let onPlayPause: () -> Void
    let onSeek: (TimeInterval) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress Bar
            VStack(spacing: 8) {
                Slider(
                    value: Binding(
                        get: { currentTime },
                        set: onSeek
                    ),
                    in: 0...max(duration, 1)
                )
                .disabled(isLoading)
                
                // Time Labels
                HStack {
                    Text(formatTime(currentTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatTime(duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Play/Pause Button
            HStack {
                Spacer()
                
                Button(action: onPlayPause) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .foregroundColor(.blue)
                }
                .disabled(isLoading)
                
                Spacer()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct TranscriptionView: View {
    let transcriptions: [Transcription]
    let currentIndex: Int
    let isLoading: Bool
    let onTranscriptionTap: (Transcription) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transcription")
                .font(.headline)
                .padding(.horizontal)
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading transcription...")
                    Spacer()
                }
                .padding()
            } else if transcriptions.isEmpty {
                HStack {
                    Spacer()
                    VStack {
                        Image(systemName: "doc.text")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No transcription available")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
            } else {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(transcriptions.indices, id: \.self) { index in
                        let transcription = transcriptions[index]
                        Text(transcription.text)
                            .padding(12)
                            .background(
                                currentIndex == index ?
                                Color.blue.opacity(0.2) : Color.clear
                            )
                            .cornerRadius(8)
                            .animation(.easeInOut(duration: 0.3), value: currentIndex)
                            .onTapGesture {
                                onTranscriptionTap(transcription)
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

#Preview {
    ContentDetailView(content: Content(
        id: UUID(),
        title: "Sample Audio",
        description: "A sample audio file for testing",
        audioUrl: "sample-audio.mp3",
        imageUrl: "sample-image.jpg",
        createdAt: Date()
    ))
} 