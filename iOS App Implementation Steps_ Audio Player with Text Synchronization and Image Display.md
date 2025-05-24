# iOS App Implementation Steps: Audio Player with Text Synchronization and Image Display

## Overview
This document outlines the steps to create an iOS app with the following features:
- Audio player that plays MP3 files uploaded to a backend
- Text synchronization with audio playback (sentence by sentence)
- Image display for thumbnails/backgrounds associated with audio content
- Supabase backend integration for storage and data management
- Google Gemini API integration for transcription and timestamp generation

## 1. Project Setup

### 1.1 Create a New iOS Project
```
1. Open Xcode
2. Select File > New > Project
3. Choose iOS App template
4. Name your project (e.g., "AudioTextSync")
5. Select SwiftUI for interface
6. Choose the latest iOS version as deployment target
7. Save the project to your preferred location
```

### 1.2 Set Up Supabase Project
```
1. Go to https://supabase.com and create a new project
2. Note your Supabase URL and anon key for later use
3. Create the necessary database tables:
   - content: To store metadata about audio files
   - transcriptions: To store text and timestamps
```

### 1.3 Install Dependencies
```
1. Add the Supabase Swift package:
   - In Xcode, go to File > Add Packages
   - Enter: https://github.com/supabase/supabase-swift.git
   - Select the Supabase product

2. Add any additional packages needed:
   - For image caching/loading: Kingfisher or AsyncImage (built into SwiftUI)
   - For JSON parsing: No additional packages needed (Swift's Codable)
```

## 2. Backend Setup

### 2.1 Create Database Schema in Supabase
```sql
-- Create content table
CREATE TABLE content (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  description TEXT,
  audio_url TEXT NOT NULL,
  image_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create transcriptions table
CREATE TABLE transcriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  content_id UUID REFERENCES content(id) ON DELETE CASCADE,
  text TEXT NOT NULL,
  start_time FLOAT NOT NULL,
  end_time FLOAT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Set up Row Level Security
ALTER TABLE content ENABLE ROW LEVEL SECURITY;
ALTER TABLE transcriptions ENABLE ROW LEVEL SECURITY;

-- Create policies for public read access
CREATE POLICY "Public read access for content" ON content
  FOR SELECT USING (true);
  
CREATE POLICY "Public read access for transcriptions" ON transcriptions
  FOR SELECT USING (true);
```

### 2.2 Set Up Supabase Storage Buckets
```
1. In Supabase dashboard, go to Storage
2. Create two buckets:
   - audio: For storing audio files
   - images: For storing thumbnail/background images
3. Set bucket permissions to public for read access
```

## 3. Swift App Implementation

### 3.1 Configure Supabase Client
Create a file named `SupabaseClient.swift`:

```swift
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        guard let supabaseURL = URL(string: "YOUR_SUPABASE_URL") else {
            fatalError("Invalid Supabase URL")
        }
        
        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: "YOUR_SUPABASE_ANON_KEY"
        )
    }
}
```

### 3.2 Create Data Models
Create a file named `Models.swift`:

```swift
import Foundation

struct Content: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String?
    let audioUrl: String
    let imageUrl: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case audioUrl = "audio_url"
        case imageUrl = "image_url"
        case createdAt = "created_at"
    }
}

struct Transcription: Identifiable, Codable {
    let id: UUID
    let contentId: UUID
    let text: String
    let startTime: Float
    let endTime: Float
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case contentId = "content_id"
        case text
        case startTime = "start_time"
        case endTime = "end_time"
        case createdAt = "created_at"
    }
}
```

### 3.3 Implement Audio Player Service
Create a file named `AudioPlayerService.swift`:

```swift
import Foundation
import AVFoundation
import Combine

class AudioPlayerService: ObservableObject {
    static let shared = AudioPlayerService()
    
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentTranscriptionIndex: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    func loadAudio(from url: URL) {
        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        // Get duration
        if let duration = playerItem?.asset.duration {
            self.duration = CMTimeGetSeconds(duration)
        }
        
        // Add time observer
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = CMTimeGetSeconds(time)
        }
        
        // Listen for playback end
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.isPlaying = false
                self.currentTime = 0
                self.player?.seek(to: CMTime.zero)
            }
            .store(in: &cancellables)
    }
    
    func play() {
        player?.play()
        isPlaying = true
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func seek(to time: TimeInterval) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
    }
    
    func updateCurrentTranscription(transcriptions: [Transcription]) {
        // Find the transcription that matches the current time
        for (index, transcription) in transcriptions.enumerated() {
            if currentTime >= TimeInterval(transcription.startTime) && 
               currentTime <= TimeInterval(transcription.endTime) {
                currentTranscriptionIndex = index
                break
            }
        }
    }
    
    deinit {
        if let timeObserver = timeObserver, let player = player {
            player.removeTimeObserver(timeObserver)
        }
    }
}
```

### 3.4 Implement Content Repository
Create a file named `ContentRepository.swift`:

```swift
import Foundation
import Supabase
import Combine

class ContentRepository: ObservableObject {
    private let supabase = SupabaseManager.shared.client
    
    @Published var contents: [Content] = []
    @Published var transcriptions: [Transcription] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    func fetchAllContent() async {
        isLoading = true
        
        do {
            let response: [Content] = try await supabase
                .from("content")
                .select()
                .execute()
                .value
            
            DispatchQueue.main.async {
                self.contents = response
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    func fetchTranscriptions(for contentId: UUID) async {
        isLoading = true
        
        do {
            let response: [Transcription] = try await supabase
                .from("transcriptions")
                .select()
                .eq("content_id", value: contentId)
                .order("start_time")
                .execute()
                .value
            
            DispatchQueue.main.async {
                self.transcriptions = response
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    func getPublicURL(for path: String, bucket: String) -> URL? {
        return supabase.storage.from(bucket).getPublicURL(path: path)
    }
}
```

### 3.5 Create UI Components

#### 3.5.1 Content List View
Create a file named `ContentListView.swift`:

```swift
import SwiftUI

struct ContentListView: View {
    @StateObject private var repository = ContentRepository()
    
    var body: some View {
        NavigationView {
            Group {
                if repository.isLoading {
                    ProgressView("Loading content...")
                } else if let error = repository.error {
                    Text("Error: \(error.localizedDescription)")
                        .foregroundColor(.red)
                } else if repository.contents.isEmpty {
                    Text("No content available")
                } else {
                    List(repository.contents) { content in
                        NavigationLink(destination: ContentDetailView(content: content)) {
                            HStack {
                                if let imageUrl = content.imageUrl,
                                   let url = repository.getPublicURL(for: imageUrl, bucket: "images") {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Color.gray
                                    }
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(8)
                                } else {
                                    Image(systemName: "music.note")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 40, height: 40)
                                        .padding(10)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(8)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(content.title)
                                        .font(.headline)
                                    if let description = content.description {
                                        Text(description)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Audio Content")
        }
        .task {
            await repository.fetchAllContent()
        }
    }
}
```

#### 3.5.2 Content Detail View
Create a file named `ContentDetailView.swift`:

```swift
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
                // Image
                if let imageUrl = content.imageUrl,
                   let url = repository.getPublicURL(for: imageUrl, bucket: "images") {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .foregroundColor(.gray.opacity(0.2))
                    }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(12)
                }
                
                // Title and description
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
                
                // Audio player controls
                VStack(spacing: 16) {
                    // Progress bar
                    Slider(value: Binding(
                        get: { audioPlayer.currentTime },
                        set: { audioPlayer.seek(to: $0) }
                    ), in: 0...max(audioPlayer.duration, 1))
                    .disabled(isLoading)
                    
                    // Time labels
                    HStack {
                        Text(formatTime(audioPlayer.currentTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(formatTime(audioPlayer.duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Play/Pause button
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            if audioPlayer.isPlaying {
                                audioPlayer.pause()
                            } else {
                                audioPlayer.play()
                            }
                        }) {
                            Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
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
                
                // Transcription text
                VStack(alignment: .leading, spacing: 16) {
                    Text("Transcription")
                        .font(.headline)
                    
                    if repository.isLoading {
                        ProgressView("Loading transcription...")
                    } else if repository.transcriptions.isEmpty {
                        Text("No transcription available")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(repository.transcriptions.indices, id: \.self) { index in
                            let transcription = repository.transcriptions[index]
                            Text(transcription.text)
                                .padding(8)
                                .background(
                                    audioPlayer.currentTranscriptionIndex == index ?
                                    Color.blue.opacity(0.2) : Color.clear
                                )
                                .cornerRadius(8)
                                .animation(.easeInOut, value: audioPlayer.currentTranscriptionIndex)
                                .onTapGesture {
                                    audioPlayer.seek(to: TimeInterval(transcription.startTime))
                                    audioPlayer.play()
                                }
                        }
                    }
                }
                .padding(.horizontal)
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
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
```

### 3.6 Set Up App Entry Point
Update `App.swift`:

```swift
import SwiftUI

@main
struct AudioTextSyncApp: App {
    var body: some Scene {
        WindowGroup {
            ContentListView()
        }
    }
}
```

## 4. Backend Admin Panel for Content Management

### 4.1 Create Admin Interface in Supabase
```
1. Use Supabase Studio to manage content:
   - Upload audio files to the 'audio' bucket
   - Upload image files to the 'images' bucket
   - Add entries to the 'content' table with references to the uploaded files
```

### 4.2 Implement Google Gemini API Integration for Transcription
Create a server-side function or use a separate tool to:

1. Process audio files with Google Gemini API
2. Extract transcription with sentence-level timestamps
3. Store the transcription data in the 'transcriptions' table

Example Python script for backend processing:

```python
import os
import json
import uuid
from supabase import create_client, Client
import google.generativeai as genai

# Configure Supabase client
supabase_url = os.environ.get("SUPABASE_URL")
supabase_key = os.environ.get("SUPABASE_KEY")
supabase: Client = create_client(supabase_url, supabase_key)

# Configure Google Gemini API
genai.configure(api_key=os.environ.get("GEMINI_API_KEY"))

def process_audio(content_id, audio_path):
    """
    Process audio file with Google Gemini API and store transcription in Supabase
    """
    try:
        # Download audio file from Supabase
        audio_data = supabase.storage.from_("audio").download(audio_path)
        
        # Process with Gemini API to get transcription with timestamps
        # Note: This is a placeholder for the actual Gemini API call
        # You'll need to use the appropriate Gemini API method for audio transcription
        model = genai.GenerativeModel('gemini-pro-vision')
        response = model.generate_content([audio_data])
        
        # Parse response to extract sentences with timestamps
        # This is a simplified example - actual implementation will depend on Gemini API response format
        transcription_data = parse_gemini_response(response)
        
        # Store transcription data in Supabase
        for sentence in transcription_data:
            supabase.table("transcriptions").insert({
                "id": str(uuid.uuid4()),
                "content_id": content_id,
                "text": sentence["text"],
                "start_time": sentence["start_time"],
                "end_time": sentence["end_time"]
            }).execute()
            
        return {"success": True, "message": "Transcription processed successfully"}
        
    except Exception as e:
        return {"success": False, "error": str(e)}

def parse_gemini_response(response):
    """
    Parse Gemini API response to extract sentences with timestamps
    """
    # This is a placeholder - actual implementation will depend on Gemini API response format
    # Example expected format:
    # [
    #   {"text": "This is the first sentence.", "start_time": 0.0, "end_time": 2.5},
    #   {"text": "This is the second sentence.", "start_time": 2.5, "end_time": 5.0},
    #   ...
    # ]
    
    # For now, we'll return a dummy response
    return [
        {"text": "This is a placeholder sentence.", "start_time": 0.0, "end_time": 2.5},
        {"text": "Replace with actual Gemini API integration.", "start_time": 2.5, "end_time": 5.0}
    ]
```

## 5. Testing and Deployment

### 5.1 Test the Application
```
1. Test audio playback functionality
2. Test text synchronization with audio
3. Test image display
4. Test backend integration and data retrieval
```

### 5.2 Deploy to TestFlight
```
1. Configure app signing and certificates in Xcode
2. Create an App Store Connect record for your app
3. Archive and upload the build to TestFlight
4. Invite testers to try the app
```

### 5.3 Prepare for App Store Submission
```
1. Create app screenshots
2. Write app description and metadata
3. Configure app privacy information
4. Submit for App Store review
```

## 6. Future Enhancements

1. User authentication for personalized content
2. Offline mode with content caching
3. Playback speed controls
4. Dark mode support
5. Accessibility features
6. Analytics integration
7. Content search functionality
8. User bookmarks and favorites

## References

1. Apple AVFoundation Documentation: https://developer.apple.com/av-foundation/
2. Supabase Swift Documentation: https://supabase.com/docs/reference/swift/introduction
3. Google Gemini API Documentation: https://ai.google.dev/docs
4. SwiftUI Documentation: https://developer.apple.com/documentation/swiftui/
