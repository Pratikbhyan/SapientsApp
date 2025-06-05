import SwiftUI
import AVFoundation
import Foundation // For URL, UUID

/// ViewModel that wraps AVPlayer and publishes playback state.
final class PlayerViewModel: ObservableObject {
    @Published private(set) var isPlaying: Bool = false
    private var player: AVPlayer?
    private var rateObservation: NSKeyValueObservation?

    deinit {
        removeRateObserver()
    }

    func loadItem(from url: URL) {
        removeRateObserver()
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer
        rateObservation = newPlayer.observe(\.rate, options: [.new, .initial]) { [weak self] player, _ in
            DispatchQueue.main.async {
                self?.isPlaying = (player.rate > 0 && player.error == nil)
            }
        }
    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    private func removeRateObserver() {
        rateObservation?.invalidate()
        rateObservation = nil
    }
}

// Ensure AudioItem struct is defined (e.g., in AudioItem.swift and added to target)
// Ensure AudioCacheManager class is defined (in AudioCacheManager.swift and added to target)

struct AudioPlayerView: View {
    @StateObject private var audioCacheManager = AudioCacheManager.shared
    @StateObject private var playerVM = PlayerViewModel()
    @State private var currentlyPlayingURL: URL? // To track which item is playing
    @State private var playRequestError: String?
    @State private var isLoadingTracks: Bool = false

    @State private var audioItems: [AudioItem] = [] // Will be populated from Supabase
    private let supabaseProjectId = "ryvgngwdmjmacefljhll"
    private let supabaseProjectBaseUrl = "https://ryvgngwdmjmacefljhll.supabase.co"
    private let supabaseBucketName = "audio"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ5dmduZ3dkbWptYWNlZmxqaGxsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgwNDMxOTIsImV4cCI6MjA2MzYxOTE5Mn0.AbhN-Pp4e-wNS9ofL4OtlGnPU9h8UHYYn5nNqCJ_cvM" // Your Supabase Anon Key

    var body: some View {
        NavigationView {
            List {
                if audioItems.isEmpty && playRequestError == nil && isLoadingTracks {
                    ProgressView("Loading audio tracks...")
                } else if audioItems.isEmpty && playRequestError == nil && !isLoadingTracks {
                    Text("No audio tracks found. Check Supabase 'content' table.")
                        .foregroundColor(.gray)
                } else if audioItems.isEmpty && playRequestError != nil { // This will now mostly catch errors from fetching
                     Text(playRequestError ?? "Failed to load audio tracks.")
                        .foregroundColor(.red)
                }
                
                ForEach(audioItems) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.name)
                                .font(.headline)
                            if audioCacheManager.isDownloading[item.remoteURL] == true {
                                ProgressView().scaleEffect(0.8)
                                Text("Downloading...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            } else if playerVM.isPlaying && currentlyPlayingURL == item.remoteURL {
                                Text("Playing...")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else if audioCacheManager.isAudioCached(for: item.remoteURL) {
                                Text("Cached")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        Spacer()
                        Button(action: {
                            playOrDownloadAudio(for: item)
                        }) {
                            Image(systemName: playerVM.isPlaying && currentlyPlayingURL == item.remoteURL ? "stop.circle.fill" : "play.circle.fill")
                                .font(.title)
                        }
                        .disabled(audioCacheManager.isDownloading[item.remoteURL] == true)
                    }
                }
                
                if let errorText = playRequestError, !audioItems.isEmpty { // Show general errors only if items are loaded but an error occurs
                    Section(header: Text("Info")) {
                        Text(errorText)
                            .foregroundColor(.orange)
                    }
                }
                
                Section(header: Text("Cache Management")) {
                    Button("Clear Audio Cache") {
                        audioCacheManager.clearCache()
                        playerVM.pause()
                        self.currentlyPlayingURL = nil
                        self.playRequestError = "Cache Cleared"
                    }
                    Button("Show Cache Size") {
                        audioCacheManager.cacheSize { size in
                            let formattedSize = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
                            print("Current audio cache size: \(formattedSize)")
                            self.playRequestError = "Cache Size: \(formattedSize)"
                        }
                    }
                }
            }
            .navigationTitle("Audio Player")
            .onAppear {
                fetchAudioTracks()
            }
            .onDisappear {
                playerVM.pause()
            }
        }
    }

    private func playOrDownloadAudio(for item: AudioItem) {
        self.playRequestError = nil

        // If the same URL is playing, pause it.
        if playerVM.isPlaying && currentlyPlayingURL == item.remoteURL {
            playerVM.pause()
            currentlyPlayingURL = nil
            return
        }

        // Otherwise, stop any existing playback and load the new URL
        playerVM.pause()
        currentlyPlayingURL = nil

        audioCacheManager.getAudioURL(for: item.remoteURL) { result in
            switch result {
            case .success(let localURL):
                print("Attempting to load: \(localURL.path)")
                DispatchQueue.main.async {
                    playerVM.loadItem(from: localURL)
                    playerVM.play()
                    currentlyPlayingURL = item.remoteURL
                    print("Playback started for \(item.name)")
                }
            case .failure(let error):
                print("Error getting audio URL for \(item.name): \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.playRequestError = "Failed to get audio for \(item.name): \(error.localizedDescription)"
                    currentlyPlayingURL = nil
                }
            }
        }
    }

    // Method to fetch audio tracks from Supabase using URLSession
    private func fetchAudioTracks() {
        guard !isLoadingTracks else { return } // Prevent multiple simultaneous fetches
        
        DispatchQueue.main.async {
            self.isLoadingTracks = true
            self.playRequestError = nil // Clear previous errors
        }

        // Construct the URL for Supabase PostgREST endpoint
        // Selecting 'audio_url' and aliasing it as 'name', and also selecting 'audio_url' itself.
        // Filtering for 'audio_url' not null and not an empty string.
        let urlString = "\(supabaseProjectBaseUrl)/rest/v1/content?select=name:audio_url,audio_url&audio_url=not.is.null&audio_url=not.eq."
        guard let url = URL(string: urlString) else {
            print("Error: Invalid URL for Supabase query")
            DispatchQueue.main.async {
                self.playRequestError = "Internal Error: Invalid Supabase URL."
                self.isLoadingTracks = false
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        print("Fetching audio tracks from: \(urlString)")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoadingTracks = false
            }

            if let error = error {
                print("Network error fetching audio tracks: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.playRequestError = "Network Error: \(error.localizedDescription)"
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("HTTP error fetching audio tracks: Status Code \(statusCode)")
                DispatchQueue.main.async {
                    self.playRequestError = "Server Error: Status Code \(statusCode)"
                }
                return
            }

            guard let jsonData = data else {
                print("No data received from Supabase")
                DispatchQueue.main.async {
                    self.playRequestError = "Error: No data received from server."
                }
                return
            }

            do {
                if let jsonArray = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [[String: Any]] {
                    self.parseAndSetAudioTracks(from: jsonArray)
                } else {
                    print("Failed to deserialize JSON into expected array of dictionaries")
                    DispatchQueue.main.async {
                        self.playRequestError = "Error: Could not parse server response."
                    }
                }
            } catch let jsonError {
                print("JSON decoding error: \(jsonError.localizedDescription)")
                DispatchQueue.main.async {
                    self.playRequestError = "Error decoding data: \(jsonError.localizedDescription)"
                }
            }
        }.resume()
    }

    // This function will be called by Cascade (or the callback from the MCP tool)
    // with the result of the mcp5_execute_sql call.
    func parseAndSetAudioTracks(from supabaseResult: Any) {
        guard let resultsArray = supabaseResult as? [[String: Any]] else {
            print("Failed to parse Supabase result: Expected an array of dictionaries, got \(type(of: supabaseResult))")
            self.playRequestError = "Error: Could not parse audio tracks from database."
            return
        }

        var loadedItems: [AudioItem] = []
        for dict in resultsArray {
            guard let name = dict["name"] as? String,
                  let audioPath = dict["audio_url"] as? String,
                  !audioPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                print("Skipping item, missing name or audio_url, or audio_url is empty: \(dict)")
                continue
            }

            let fullURLString = "\(supabaseProjectBaseUrl)/storage/v1/object/public/\(supabaseBucketName)/\(audioPath)"
            
            if let remoteURL = URL(string: fullURLString) {
                loadedItems.append(AudioItem(name: name, remoteURL: remoteURL))
            } else {
                print("Skipping item, could not create valid URL from string: \(fullURLString)")
            }
        }
        
        DispatchQueue.main.async {
            self.audioItems = loadedItems
            if loadedItems.isEmpty {
                self.playRequestError = "No audio tracks found or all paths were invalid. Check 'content' table and 'audio_url' paths."
            } else {
                self.playRequestError = nil // Clear error if items loaded successfully
            }
            print("Loaded \(loadedItems.count) audio items.")
        }
    }
}

struct AudioPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        AudioPlayerView()
    }
}
