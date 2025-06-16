import Foundation
import UIKit // For UIImage
import CryptoKit // For SHA256

class ImageService {
    static let shared = ImageService()
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    
    private var cacheDirectory: URL {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("ImageCache_v2") // Changed name to avoid conflicts with old cache
    }

    private init() {
        cache.countLimit = 100 // Example: Store up to 100 images in memory
        cache.totalCostLimit = 1024 * 1024 * 50 // Example: Memory cache limit 50MB
        createCacheDirectoryIfNeeded()
        print("ImageService initialized. Cache directory: \(cacheDirectory.path)")
    }

    private func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            do {
                try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
                print("Successfully created cache directory at: \(cacheDirectory.path)")
            } catch {
                print("Error creating cache directory: \(error.localizedDescription) at path: \(cacheDirectory.path)")
            }
        }
    }

    // Helper function to generate a hashed filename
    private func hashedFileName(for url: URL) -> String {
        let urlString = url.absoluteString
        if #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *) {
            let inputData = Data(urlString.utf8)
            let hashed = SHA256.hash(data: inputData)
            return hashed.compactMap { String(format: "%02x", $0) }.joined()
        } else {
            // Fallback for older OS versions: simple base64 encoding of the URL string
            // This is not as robust as SHA256 for uniqueness or filename safety but better than raw URL.
            return Data(urlString.utf8).base64EncodedString().filter { $0.isLetter || $0.isNumber }
        }
    }

    func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = url.absoluteString as NSString // Memory cache key is still the full URL string
        
        // Check memory cache first
        if let cachedImage = cache.object(forKey: cacheKey) {
            print("Image loaded from memory cache: \(url.lastPathComponent)")
            DispatchQueue.main.async {
                completion(cachedImage)
            }
            return
        }
        
        // Check disk cache
        let diskFileName = hashedFileName(for: url)
        let fileURL = cacheDirectory.appendingPathComponent(diskFileName)
        
        // Perform disk operations on a background thread
        DispatchQueue.global(qos: .userInitiated).async {
            if self.fileManager.fileExists(atPath: fileURL.path), let diskImage = UIImage(contentsOfFile: fileURL.path) {
                print("Image loaded from disk cache: \(url.lastPathComponent)")
                // Cost for NSCache can be bytes of the image
                let cost = diskImage.jpegData(compressionQuality: 1.0)?.count ?? 0
                self.cache.setObject(diskImage, forKey: cacheKey, cost: cost) // Add to memory cache with cost
                DispatchQueue.main.async {
                    completion(diskImage)
                }
                return
            }
            
            // Download if not in memory or disk cache
            print("Image not in cache, downloading: \(url.absoluteString)")
            self.downloadAndCacheImage(from: url, cacheKey: cacheKey, fileURL: fileURL, completion: completion)
        }
    }

    private func downloadAndCacheImage(from url: URL, cacheKey: NSString, fileURL: URL, completion: @escaping (UIImage?) -> Void) {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        
        print("Downloading public image from Supabase Storage: \(url.absoluteString)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            if let error = error {
                print("Error downloading image: \(error.localizedDescription) for URL: \(url.absoluteString)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("Error: Non-successful HTTP response: \(statusCode) for URL: \(url.absoluteString)")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            guard let data = data, let image = UIImage(data: data) else {
                print("Error: Image data could not be loaded or is not valid for URL: \(url.absoluteString)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            print("Image downloaded successfully: \(url.lastPathComponent)")
            // Cache in memory with cost
            let cost = data.count
            self.cache.setObject(image, forKey: cacheKey, cost: cost)
            
            // Cache to disk
            do {
                try data.write(to: fileURL, options: .atomic)
                print("Image saved to disk cache: \(fileURL.path)")
            } catch {
                print("Error writing image to disk cache: \(error.localizedDescription) for URL: \(fileURL.path)")
            }
            
            DispatchQueue.main.async { completion(image) }
        }.resume()
    }

    func clearMemoryCache() {
        print("Clearing memory cache.")
        cache.removeAllObjects()
    }

    func clearDiskCache() {
        print("Clearing disk cache at: \(cacheDirectory.path)")
        DispatchQueue.global(qos: .background).async {
            do {
                if self.fileManager.fileExists(atPath: self.cacheDirectory.path) {
                    try self.fileManager.removeItem(at: self.cacheDirectory)
                    // Recreate directory after clearing
                    // Ensure this is thread-safe if called concurrently with other operations
                    DispatchQueue.main.async { // Or ensure createCacheDirectoryIfNeeded is thread-safe
                         self.createCacheDirectoryIfNeeded()
                    }
                } else {
                    print("Disk cache directory does not exist, no need to clear.")
                }
            } catch {
                print("Error clearing disk cache: \(error.localizedDescription)")
            }
        }
    }
    
    func clearAllCaches() {
        clearMemoryCache()
        clearDiskCache()
    }

    func clearExpiredDiskCache(olderThanDays days: Int = 7) {
        print("Clearing expired disk cache items older than \(days) days.")
        DispatchQueue.global(qos: .background).async {
            let cutoffDate = Date().addingTimeInterval(-TimeInterval(days * 24 * 60 * 60))
            
            guard self.fileManager.fileExists(atPath: self.cacheDirectory.path) else {
                print("Cache directory does not exist. No expired items to clear.")
                return
            }
            
            do {
                let files = try self.fileManager.contentsOfDirectory(at: self.cacheDirectory, 
                                                                    includingPropertiesForKeys: [.contentModificationDateKey], 
                                                                    options: .skipsHiddenFiles)
                var itemsRemoved = 0
                for fileURL in files {
                    let attributes = try self.fileManager.attributesOfItem(atPath: fileURL.path)
                    if let modDate = attributes[.modificationDate] as? Date, modDate < cutoffDate {
                        try self.fileManager.removeItem(at: fileURL)
                        itemsRemoved += 1
                        print("Removed expired cache file: \(fileURL.lastPathComponent)")
                    }
                }
                print("Expired cache clearing complete. Items removed: \(itemsRemoved).")
            } catch {
                print("Error during expired cache clearing: \(error.localizedDescription)")
            }
        }
    }
}
