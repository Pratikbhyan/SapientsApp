import Foundation
import UIKit // For UIImage

class ImageService {
    static let shared = ImageService()
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    
    private var cacheDirectory: URL {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("ImageCache")
    }

    private init() {
        cache.countLimit = 100 // Adjust based on your needs
        createCacheDirectoryIfNeeded()
    }

    private func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
        }
    }

    func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = url.absoluteString as NSString
        
        // Check memory cache first
        if let cachedImage = cache.object(forKey: cacheKey) {
            DispatchQueue.main.async {
                completion(cachedImage)
            }
            return
        }
        
        // Check disk cache
        let filename = url.lastPathComponent // Consider sanitizing or hashing for more robust filenames
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        // Perform disk operations on a background thread
        DispatchQueue.global(qos: .userInitiated).async {
            if let diskImage = UIImage(contentsOfFile: fileURL.path) {
                self.cache.setObject(diskImage, forKey: cacheKey) // Add to memory cache
                DispatchQueue.main.async {
                    completion(diskImage)
                }
                return
            }
            
            // Download if not in memory or disk cache
            self.downloadAndCacheImage(from: url, cacheKey: cacheKey, fileURL: fileURL, completion: completion)
        }
    }

    private func downloadAndCacheImage(from url: URL, cacheKey: NSString, fileURL: URL, completion: @escaping (UIImage?) -> Void) {
        var request = URLRequest(url: url)
        
        // Add Supabase auth headers if needed
        if let token = getSupabaseToken() { // Placeholder - implement this function
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data, let image = UIImage(data: data), error == nil else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            // Cache in memory
            self.cache.setObject(image, forKey: cacheKey)
            
            // Cache to disk (on a background thread, though dataTask is already on one)
            // Ensure cache directory exists (createCacheDirectoryIfNeeded is called in init)
            try? data.write(to: fileURL)
            
            DispatchQueue.main.async { completion(image) }
        }.resume()
    }

    // Retrieves the Supabase access token from the current session.
    private func getSupabaseToken() -> String? {
        // Access the Supabase client through the SupabaseManager singleton
        // and attempt to get the accessToken from the current session.
        return SupabaseManager.shared.client.auth.currentSession?.accessToken
    }

    func clearCache() {
        cache.removeAllObjects()
        DispatchQueue.global(qos: .background).async {
            try? self.fileManager.removeItem(at: self.cacheDirectory)
            self.createCacheDirectoryIfNeeded() // Recreate directory after clearing
        }
    }

    func clearExpiredCache(olderThan days: Int = 7) {
        DispatchQueue.global(qos: .background).async {
            let cutoffDate = Date().addingTimeInterval(-TimeInterval(days * 24 * 60 * 60))
            
            guard self.fileManager.fileExists(atPath: self.cacheDirectory.path),
                  let files = try? self.fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) else { return }
            
            for file in files {
                if let attributes = try? self.fileManager.attributesOfItem(atPath: file.path),
                   let modDate = attributes[.modificationDate] as? Date,
                   modDate < cutoffDate {
                    try? self.fileManager.removeItem(at: file)
                }
            }
        }
    }
}
