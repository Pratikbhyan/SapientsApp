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
        // Clean up previous player
        if let timeObserver = timeObserver, let player = player {
            player.removeTimeObserver(timeObserver)
        }
        
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
        // Find the transcription that matches the current time
        for (index, transcription) in transcriptions.enumerated() {
            if currentTime >= TimeInterval(transcription.startTime) && 
               currentTime <= TimeInterval(transcription.endTime) {
                currentTranscriptionIndex = index
                break
            }
        }
    }
    
    // MARK: - Cleanup
    deinit {
        if let timeObserver = timeObserver, let player = player {
            player.removeTimeObserver(timeObserver)
        }
    }
} 