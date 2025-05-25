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
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    // MARK: - Audio Loading
    func loadAudio(from url: URL) {
        if let timeObserver = timeObserver, let player = player {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil // Clear the old observer
        }
        cancellables.forEach { $0.cancel() } // Cancel previous subscriptions
        cancellables.removeAll()

        // Reset state for new audio
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentTime = 0
            self.duration = 0
            self.currentTranscriptionIndex = 0
        }
        
        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        // Get duration asynchronously
        if let currentItem = playerItem {
            Task {
                do {
                    let loadedDuration = try await currentItem.asset.load(.duration)
                    DispatchQueue.main.async {
                        self.duration = CMTimeGetSeconds(loadedDuration)
                    }
                } catch {
                    print("Failed to load duration: \(error)")
                    DispatchQueue.main.async {
                        self.duration = 0
                    }
                }
            }
        } else {
             DispatchQueue.main.async {
                self.duration = 0
            }
        }
        
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = CMTimeGetSeconds(time)
        }
        
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.isPlaying = false
                self.currentTime = 0 // Or self.duration if you want it to stay at the end
                self.player?.seek(to: CMTime.zero)
                // self.currentTranscriptionIndex = 0 // Optionally reset transcription index
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Playback Controls
    func play() {
        player?.play()
        isPlaying = true
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func seek(to time: TimeInterval) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
    }
    
    // MARK: - Transcription Sync
    func updateCurrentTranscription(transcriptions: [Transcription]) {
        for (index, transcription) in transcriptions.enumerated() {
            if currentTime >= TimeInterval(transcription.startTime) && 
               currentTime <= TimeInterval(transcription.endTime) {
                if currentTranscriptionIndex != index { // Update only if changed
                    currentTranscriptionIndex = index
                }
                break // Found the current one
            }
        }
    }
    
    // MARK: - Cleanup
    deinit {
        if let timeObserver = timeObserver, let player = player {
            player.removeTimeObserver(timeObserver)
        }
        cancellables.forEach { $0.cancel() }
    }
} 