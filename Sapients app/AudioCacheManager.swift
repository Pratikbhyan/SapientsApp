import Foundation
import Combine

class AudioCacheManager: ObservableObject {
    static let shared = AudioCacheManager()
    private init() {
        ensureCacheDirectoryExists() // Ensure directory is ready when manager is initialized
    }

    private var downloadTasks: [URL: URLSessionDownloadTask] = [:]
    // No need for activeDownloads with URLSessionDownloadTask's completion handler approach for this basic version

    @Published var downloadProgress: [URL: Double] = [:] // URL -> Progress (0.0 to 1.0) - Placeholder for future enhancement
    @Published var isDownloading: [URL: Bool] = [:]     // URL -> Bool

    private let fileManager = FileManager.default
    private lazy var cachesDirectory: URL = {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        // It's good practice for the cache directory to be unique to the app bundle identifier
        // or a specific purpose to avoid conflicts if multiple apps use similar naming.
        // For this app, "AudioCache" under the app's cache is fine.
        let appCacheDirectory = urls[0]
        return appCacheDirectory.appendingPathComponent("AudioCache", isDirectory: true)
    }()

    // Ensures the cache directory exists
    private func ensureCacheDirectoryExists() {
        if !fileManager.fileExists(atPath: cachesDirectory.path) {
            do {
                try fileManager.createDirectory(at: cachesDirectory, withIntermediateDirectories: true, attributes: nil)
                print("AudioCache directory created at: \(cachesDirectory.path)")
            } catch {
                print("Error creating AudioCache directory: \(error)")
            }
        }
    }

    // Generates a local file URL for a given remote URL
    // Using a simple hash of the URL can be more robust against special characters in filenames
    private func localFileURL(for remoteURL: URL) -> URL {
        let fileNameWithExtension = remoteURL.lastPathComponent
        // A more robust way to generate a unique filename from a URL:
        // let uniqueFileName = SHA256.hash(data: Data(remoteURL.absoluteString.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        // let fileName = uniqueFileName + "." + remoteURL.pathExtension // if you need to preserve extension
        // For simplicity, we'll use lastPathComponent, but be mindful of very long names or special chars.
        return cachesDirectory.appendingPathComponent(fileNameWithExtension)
    }

    // Check if audio is cached
    func isAudioCached(for remoteURL: URL) -> Bool {
        let localURL = localFileURL(for: remoteURL)
        return fileManager.fileExists(atPath: localURL.path)
    }

    // Get local URL if cached, otherwise start download
    func getAudioURL(for remoteURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let localURL = localFileURL(for: remoteURL)

        if fileManager.fileExists(atPath: localURL.path) {
            print("Audio found in cache: \(localURL.path)")
            DispatchQueue.main.async {
                completion(.success(localURL))
            }
            return
        }

        if isDownloading[remoteURL] == true {
            print("Download already in progress for: \(remoteURL)")
            // For now, we don't queue completion handlers. The UI should reflect this state.
            // Consider implementing a way to attach multiple completion handlers if needed.
            return
        }

        print("Audio not in cache. Starting download for: \(remoteURL)")
        DispatchQueue.main.async {
            self.isDownloading[remoteURL] = true
            self.downloadProgress[remoteURL] = 0.0 // Placeholder
        }

        let task = URLSession.shared.downloadTask(with: remoteURL) { [weak self] tempLocalURL, response, error in
            guard let self = self else { return }
            
            // Ensure UI updates are on the main thread
            DispatchQueue.main.async {
                self.isDownloading[remoteURL] = false
                self.downloadProgress.removeValue(forKey: remoteURL) // Clean up progress
            }

            if let error = error {
                print("Download error for \(remoteURL.absoluteString): \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let tempLocalURL = tempLocalURL else {
                let tempFileError = NSError(domain: "AudioCacheManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Temporary file URL is nil after download."])
                DispatchQueue.main.async {
                    completion(.failure(tempFileError))
                }
                return
            }

            do {
                // Ensure directory exists (it should, but belt-and-suspenders)
                self.ensureCacheDirectoryExists()
                try self.fileManager.moveItem(at: tempLocalURL, to: localURL)
                print("Audio downloaded and cached at: \(localURL.path)")
                DispatchQueue.main.async {
                    completion(.success(localURL))
                }
            } catch let moveError {
                // If move fails because file already exists (e.g., race condition or previous incomplete cleanup)
                if self.fileManager.fileExists(atPath: localURL.path) {
                    print("File already existed at destination after download (race condition?): \(localURL.path)")
                    DispatchQueue.main.async {
                        completion(.success(localURL))
                    }
                } else {
                    print("Error moving downloaded file \(tempLocalURL.path) to \(localURL.path): \(moveError)")
                    DispatchQueue.main.async {
                        completion(.failure(moveError))
                    }
                }
            }
        }
        
        task.resume()
        downloadTasks[remoteURL] = task // Store task to allow cancellation
    }

    func cancelDownload(for remoteURL: URL) {
        downloadTasks[remoteURL]?.cancel()
        downloadTasks.removeValue(forKey: remoteURL)
        DispatchQueue.main.async {
            self.isDownloading.removeValue(forKey: remoteURL)
            self.downloadProgress.removeValue(forKey: remoteURL)
        }
        print("Download cancelled for: \(remoteURL)")
    }
    
    func clearCache() {
        do {
            let cachedFiles = try fileManager.contentsOfDirectory(at: cachesDirectory, includingPropertiesForKeys: nil)
            for fileURL in cachedFiles {
                try fileManager.removeItem(at: fileURL)
            }
            print("Audio cache cleared from \(cachesDirectory.path)")
        } catch {
            print("Error clearing audio cache: \(error)")
        }
    }

    func cacheSize(completion: @escaping (UInt64) -> Void) {
        DispatchQueue.global(qos: .background).async { // Perform file operations off the main thread
            var totalSize: UInt64 = 0
            do {
                let cachedFiles = try self.fileManager.contentsOfDirectory(at: self.cachesDirectory, includingPropertiesForKeys: [.fileSizeKey])
                for fileURL in cachedFiles {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                    totalSize += UInt64(resourceValues.fileSize ?? 0)
                }
            } catch {
                print("Error calculating cache size: \(error)")
            }
            DispatchQueue.main.async {
                completion(totalSize)
            }
        }
    }
}
