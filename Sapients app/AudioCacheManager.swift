import Foundation
import Combine
import BackgroundTasks

class AudioCacheManager: ObservableObject {
    static let shared = AudioCacheManager()
    
    private let subscriptionService = SubscriptionService.shared
    
    private init() {
        ensureCacheDirectoryExists()
        setupCachePolicy()
    }

    // MARK: - Properties
    private var downloadTasks: [URL: URLSessionDownloadTask] = [:]
    
    @Published var downloadProgress: [URL: Double] = [:]
    @Published var isDownloading: [URL: Bool] = [:]
    @Published var cacheStats: CacheStats = CacheStats()
    
    private let fileManager = FileManager.default
    private lazy var cachesDirectory: URL = {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let appCacheDirectory = urls[0]
        return appCacheDirectory.appendingPathComponent("AudioCache", isDirectory: true)
    }()
    
    // MARK: - Cache Policy Configuration (Subscription-aware)
    private var maxCacheSize: UInt64 = 500 * 1024 * 1024 // 500MB default
    private var maxCachedFiles: Int = 50 // Keep up to 50 episodes for premium users
    private var freeTierMaxFiles: Int = 3 // Keep only 3 episodes for free users
    
    struct CacheStats {
        var totalSize: UInt64 = 0
        var fileCount: Int = 0
        var hitRate: Double = 0.0
        var totalRequests: Int = 0
        var cacheHits: Int = 0
        var freeUserCacheHits: Int = 0
        var premiumUserCacheHits: Int = 0
    }

    // MARK: - Setup Methods
    private func setupCachePolicy() {
        // Configure cache size based on available disk space
        if let availableSpace = getAvailableDiskSpace() {
            // Use up to 5% of available space, but cap at 1GB
            let suggestedCacheSize = min(availableSpace / 20, 1024 * 1024 * 1024)
            maxCacheSize = max(suggestedCacheSize, 200 * 1024 * 1024) // Minimum 200MB
        }
        
        updateCacheStats()
    }
    
    // MARK: - Core Cache Methods
    private func ensureCacheDirectoryExists() {
        if !fileManager.fileExists(atPath: cachesDirectory.path) {
            do {
                try fileManager.createDirectory(at: cachesDirectory, withIntermediateDirectories: true, attributes: nil)
                print("📁 AudioCache directory created at: \(cachesDirectory.path)")
            } catch {
                print("❌ Error creating AudioCache directory: \(error)")
            }
        }
    }

    private func localFileURL(for remoteURL: URL) -> URL {
        // Create a more reliable filename using URL hash + original extension
        let urlHash = remoteURL.absoluteString.hash
        let fileExtension = remoteURL.pathExtension.isEmpty ? "mp3" : remoteURL.pathExtension
        let fileName = "\(abs(urlHash)).\(fileExtension)"
        return cachesDirectory.appendingPathComponent(fileName)
    }

    func isAudioCached(for remoteURL: URL) -> Bool {
        let localURL = localFileURL(for: remoteURL)
        let exists = fileManager.fileExists(atPath: localURL.path)
        
        // Update cache stats
        DispatchQueue.main.async {
            self.cacheStats.totalRequests += 1
            if exists {
                self.cacheStats.cacheHits += 1
                
                if self.subscriptionService.hasActiveSubscription {
                    self.cacheStats.premiumUserCacheHits += 1
                } else {
                    self.cacheStats.freeUserCacheHits += 1
                }
            }
            self.cacheStats.hitRate = Double(self.cacheStats.cacheHits) / Double(self.cacheStats.totalRequests)
        }
        
        return exists
    }

    // MARK: - Enhanced Audio Retrieval (Cache-on-Play-Only)
    func getAudioURL(for remoteURL: URL, content: Content? = nil, priority: CachePriority = .normal, completion: @escaping (Result<URL, Error>) -> Void) {
        let localURL = localFileURL(for: remoteURL)

        // Check if already cached
        if fileManager.fileExists(atPath: localURL.path) {
            // Update access time for LRU cache management
            updateFileAccessTime(localURL)
            print("🎵 Audio found in cache: \(localURL.lastPathComponent)")
            
            DispatchQueue.main.async {
                completion(.success(localURL))
            }
            return
        }

        // Check if download is already in progress
        if isDownloading[remoteURL] == true {
            print("⏳ Download already in progress for: \(remoteURL.lastPathComponent)")
            return
        }

        // Determine if we should cache this content
        Task { @MainActor in
            let shouldCache = self.shouldCacheContent(content)
            
            if shouldCache {
                print("⬇️ Caching audio on play: \(remoteURL.lastPathComponent)")
                self.startDownload(remoteURL: remoteURL, localURL: localURL, priority: priority, completion: completion)
            } else {
                print("🔄 Streaming without cache: \(remoteURL.lastPathComponent)")
                // Return the remote URL directly for streaming without caching
                DispatchQueue.main.async {
                    completion(.success(remoteURL))
                }
            }
        }
    }
    
    // MARK: - Subscription-aware Content Caching Policy
    @MainActor
    private func shouldCacheContent(_ content: Content?) -> Bool {
        guard let content = content else {
            // If no content info, don't cache to be safe
            return false
        }
        
        let hasSubscription = subscriptionService.hasActiveSubscription
        
        if hasSubscription {
            // Premium users: cache any content they play
            print("✅ Premium user - caching allowed for: \(content.title)")
            return true
        } else {
            // Free users: only cache free content (latest episode)
            let repository = ContentRepository()
            let isFree = subscriptionService.isContentFree(content, in: repository.contents)
            
            if isFree {
                print("✅ Free user - caching free content: \(content.title)")
                return true
            } else {
                print("🚫 Free user - premium content, streaming only: \(content.title)")
                return false
            }
        }
    }
    
    // MARK: - Download Management
    private func startDownload(remoteURL: URL, localURL: URL, priority: CachePriority, completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.main.async {
            self.isDownloading[remoteURL] = true
            self.downloadProgress[remoteURL] = 0.0
        }

        let task = URLSession.shared.downloadTask(with: remoteURL) { [weak self] tempLocalURL, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isDownloading[remoteURL] = false
                self.downloadProgress.removeValue(forKey: remoteURL)
            }

            if let error = error {
                print("❌ Download error for \(remoteURL.lastPathComponent): \(error.localizedDescription)")
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

            self.finalizeDownload(tempURL: tempLocalURL, finalURL: localURL, remoteURL: remoteURL, completion: completion)
        }
        
        // Set priority based on download priority
        switch priority {
        case .high:
            task.priority = URLSessionTask.highPriority
        case .normal:
            task.priority = URLSessionTask.defaultPriority
        case .low:
            task.priority = URLSessionTask.lowPriority
        }
        
        task.resume()
        downloadTasks[remoteURL] = task
    }
    
    private func finalizeDownload(tempURL: URL, finalURL: URL, remoteURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        do {
            ensureCacheDirectoryExists()
            
            // Check if we need to make space before moving the file
            if let fileSize = try? tempURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                Task { @MainActor in
                    self.ensureCacheSpace(neededSpace: UInt64(fileSize))
                }
            }
            
            // Move the downloaded file to cache
            if fileManager.fileExists(atPath: finalURL.path) {
                try fileManager.removeItem(at: finalURL)
            }
            
            try fileManager.moveItem(at: tempURL, to: finalURL)
            
            // Set file attributes for cache management
            try setFileAttributes(for: finalURL)
            
            updateCacheStats()
            print("✅ Audio cached successfully: \(finalURL.lastPathComponent)")
            
            DispatchQueue.main.async {
                completion(.success(finalURL))
            }
        } catch {
            print("❌ Error finalizing download: \(error)")
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Cache Management
    @MainActor
    private func ensureCacheSpace(neededSpace: UInt64) {
        let currentSize = getCurrentCacheSize()
        let hasSubscription = subscriptionService.hasActiveSubscription
        
        // Different cache limits based on subscription
        let effectiveMaxSize = hasSubscription ? maxCacheSize : (maxCacheSize / 4) // Free users get 1/4 cache space
        let effectiveMaxFiles = hasSubscription ? maxCachedFiles : freeTierMaxFiles
        
        let currentFileCount = getCurrentCacheFileCount()
        
        // Check if we need cleanup based on size or file count
        let needsSpaceCleanup = currentSize + neededSpace > effectiveMaxSize
        let needsFileCleanup = currentFileCount >= effectiveMaxFiles
        
        if needsSpaceCleanup || needsFileCleanup {
            let spaceToFree = needsSpaceCleanup ? 
                (currentSize + neededSpace) - effectiveMaxSize + (50 * 1024 * 1024) : 0
            
            cleanupOldestFiles(spaceToFree: spaceToFree, maxFiles: effectiveMaxFiles)
        }
    }
    
    private func getCurrentCacheFileCount() -> Int {
        do {
            let cachedFiles = try fileManager.contentsOfDirectory(at: cachesDirectory, includingPropertiesForKeys: nil)
            return cachedFiles.count
        } catch {
            print("❌ Error counting cached files: \(error)")
            return 0
        }
    }
    
    private func cleanupOldestFiles(spaceToFree: UInt64, maxFiles: Int) {
        do {
            let cachedFiles = try fileManager.contentsOfDirectory(at: cachesDirectory, includingPropertiesForKeys: [.contentAccessDateKey, .fileSizeKey])
            
            // Sort by access date (oldest first)
            let sortedFiles = cachedFiles.sorted { file1, file2 in
                let date1 = (try? file1.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? Date.distantPast
                let date2 = (try? file2.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? Date.distantPast
                return date1 < date2
            }
            
            var freedSpace: UInt64 = 0
            var deletedCount = 0
            let targetDeleteCount = max(sortedFiles.count - maxFiles + 1, 0)
            
            for file in sortedFiles {
                // Delete if we need space OR if we exceed file count limit
                let needsSpaceReduction = spaceToFree > 0 && freedSpace < spaceToFree
                let needsFileReduction = deletedCount < targetDeleteCount
                
                if !needsSpaceReduction && !needsFileReduction {
                    break
                }
                
                do {
                    let resourceValues = try file.resourceValues(forKeys: [.fileSizeKey])
                    let fileSize = UInt64(resourceValues.fileSize ?? 0)
                    
                    try fileManager.removeItem(at: file)
                    freedSpace += fileSize
                    deletedCount += 1
                    
                    print("🗑️ Removed cached file: \(file.lastPathComponent) (\(fileSize.formattedByteCount))")
                } catch {
                    print("❌ Error removing cached file: \(error)")
                }
            }
            
            let reason = spaceToFree > 0 ? "space management" : "file count management"
            print("🧹 Cache cleanup completed (\(reason)): \(deletedCount) files removed, \(freedSpace.formattedByteCount) freed")
            updateCacheStats()
            
        } catch {
            print("❌ Error during cache cleanup: \(error)")
        }
    }
    
    // MARK: - Utility Methods
    private func updateFileAccessTime(_ fileURL: URL) {
        do {
            try fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
        } catch {
            print("❌ Error updating file access time: \(error)")
        }
    }
    
    private func setFileAttributes(for fileURL: URL) throws {
        let attributes: [FileAttributeKey: Any] = [
            .creationDate: Date(),
            .modificationDate: Date()
        ]
        try fileManager.setAttributes(attributes, ofItemAtPath: fileURL.path)
    }
    
    private func getCurrentCacheSize() -> UInt64 {
        var totalSize: UInt64 = 0
        do {
            let cachedFiles = try fileManager.contentsOfDirectory(at: cachesDirectory, includingPropertiesForKeys: [.fileSizeKey])
            for fileURL in cachedFiles {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += UInt64(resourceValues.fileSize ?? 0)
            }
        } catch {
            print("❌ Error calculating cache size: \(error)")
        }
        return totalSize
    }
    
    private func updateCacheStats() {
        DispatchQueue.global(qos: .background).async {
            let totalSize = self.getCurrentCacheSize()
            var fileCount = 0
            
            do {
                let cachedFiles = try self.fileManager.contentsOfDirectory(at: self.cachesDirectory, includingPropertiesForKeys: nil)
                fileCount = cachedFiles.count
            } catch {
                print("❌ Error counting cached files: \(error)")
            }
            
            DispatchQueue.main.async {
                self.cacheStats.totalSize = totalSize
                self.cacheStats.fileCount = fileCount
            }
        }
    }
    
    private func getAvailableDiskSpace() -> UInt64? {
        do {
            let systemAttributes = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
            return systemAttributes[.systemFreeSize] as? UInt64
        } catch {
            print("❌ Error getting available disk space: \(error)")
            return nil
        }
    }
    
    // MARK: - Public Cache Management
    func cancelDownload(for remoteURL: URL) {
        downloadTasks[remoteURL]?.cancel()
        downloadTasks.removeValue(forKey: remoteURL)
        
        DispatchQueue.main.async {
            self.isDownloading.removeValue(forKey: remoteURL)
            self.downloadProgress.removeValue(forKey: remoteURL)
        }
        print("❌ Download cancelled for: \(remoteURL.lastPathComponent)")
    }
    
    func clearCache() {
        // Cancel all downloads
        downloadTasks.values.forEach { $0.cancel() }
        downloadTasks.removeAll()
        
        DispatchQueue.main.async {
            self.isDownloading.removeAll()
            self.downloadProgress.removeAll()
        }
        
        do {
            let cachedFiles = try fileManager.contentsOfDirectory(at: cachesDirectory, includingPropertiesForKeys: nil)
            for fileURL in cachedFiles {
                try fileManager.removeItem(at: fileURL)
            }
            print("🗑️ Audio cache cleared completely")
            updateCacheStats()
        } catch {
            print("❌ Error clearing audio cache: \(error)")
        }
    }
    
    func cacheSize(completion: @escaping (UInt64) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let totalSize = self.getCurrentCacheSize()
            DispatchQueue.main.async {
                completion(totalSize)
            }
        }
    }
    
    @MainActor
    func getCacheEfficiencyReport() -> String {
        let hitRatePercentage = (cacheStats.hitRate * 100).rounded(toPlaces: 1)
        let sizeFormatted = cacheStats.totalSize.formattedByteCount
        let userTier = subscriptionService.hasActiveSubscription ? "Premium" : "Free"
        let maxFilesAllowed = subscriptionService.hasActiveSubscription ? maxCachedFiles : freeTierMaxFiles
        
        return """
        📊 Cache Statistics (\(userTier) User):
        • Cache Hit Rate: \(hitRatePercentage)%
        • Total Size: \(sizeFormatted)
        • Files Cached: \(cacheStats.fileCount)/\(maxFilesAllowed)
        • Total Requests: \(cacheStats.totalRequests)
        • Cache Hits: \(cacheStats.cacheHits)
        • Free User Hits: \(cacheStats.freeUserCacheHits)
        • Premium User Hits: \(cacheStats.premiumUserCacheHits)
        """
    }
    
    @MainActor
    func handleSubscriptionStatusChange() {
        let hasSubscription = subscriptionService.hasActiveSubscription
        
        if !hasSubscription {
            // User downgraded - clean up cache to free tier limits
            print("👤 User downgraded to free tier - cleaning cache")
            ensureCacheSpace(neededSpace: 0) // This will trigger cleanup to free tier limits
        } else {
            // User upgraded - can now cache more content
            print("⭐ User upgraded to premium - cache limits increased")
        }
    }
    
    @MainActor
    func getCachePolicyDescription() -> String {
        let hasSubscription = subscriptionService.hasActiveSubscription
        
        if hasSubscription {
            return """
            📋 Premium Cache Policy:
            • Cache episodes ONLY when user plays them
            • Never cache unreleased content
            • No preemptive caching to minimize egress costs
            • Maximum: \(maxCachedFiles) episodes, \(maxCacheSize.formattedByteCount)
            """
        } else {
            return """
            📋 Free Tier Cache Policy:
            • Cache ONLY today's free episode when played
            • Premium content streams without caching
            • Never cache unreleased content
            • Maximum: \(freeTierMaxFiles) episodes, \((maxCacheSize/4).formattedByteCount)
            """
        }
    }
    
    func preloadUpcomingContent(_ contents: [Content]) {
        print("ℹ️ Preemptive caching disabled - episodes cached only when user plays them")
    }

}

// MARK: - Supporting Types
enum CachePriority {
    case high    // Currently playing/about to play
    case normal  // User initiated
    case low     // Background caching (not used in this implementation)
}

// MARK: - Extensions
extension UInt64 {
    var formattedByteCount: String {
        return ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .file)
    }
}

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
