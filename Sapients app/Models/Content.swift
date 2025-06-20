import Foundation

struct Content: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let description: String?
    let audioUrl: String
    let imageUrl: String?
    let createdAt: Date // This will now be a simple date (no time component)
    let transcriptionUrl: String?
    let collectionId: UUID? // Optional – link to the parent collection
    
    var isAvailableToday: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let publishDate = Calendar.current.startOfDay(for: createdAt)
        return publishDate <= today
    }
    
    var publishDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: createdAt)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case audioUrl = "audio_url"
        case imageUrl = "image_url"
        case createdAt = "created_at"
        case transcriptionUrl = "transcription_url"
        case transcriptUrl = "transcript_url" // support legacy / alt column
        case collectionId = "collection_id"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        audioUrl = try container.decode(String.self, forKey: .audioUrl)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        
        // Support both `transcription_url` and legacy `transcript_url`
        if let url = try container.decodeIfPresent(String.self, forKey: .transcriptionUrl) {
            transcriptionUrl = url
        } else {
            transcriptionUrl = try container.decodeIfPresent(String.self, forKey: .transcriptUrl)
        }
        
        collectionId = try container.decodeIfPresent(UUID.self, forKey: .collectionId)
        
        // Custom date handling for simplified date format
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            // Attempt several date formats commonly returned by Postgres / Supabase
            func parse(_ string: String, format: String) -> Date? {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.dateFormat = format
                return formatter.date(from: string)
            }

            // 1️⃣ Simple YYYY-MM-DD
            if let d = parse(dateString, format: "yyyy-MM-dd") {
                createdAt = d
            }
            // 2️⃣ Postgres timestamp with timezone and microseconds: "yyyy-MM-dd HH:mm:ss.SSSSSSxxxxx"
            else if let d = parse(dateString, format: "yyyy-MM-dd HH:mm:ss.SSSSSSxxxxx") {
                createdAt = d
            }
            // 3️⃣ Postgres timestamp with timezone no microseconds
            else if let d = parse(dateString, format: "yyyy-MM-dd HH:mm:ssxxxxx") {
                createdAt = d
            }
            // 4️⃣ Try ISO8601 by replacing space with T
            else if let d = ISO8601DateFormatter().date(from: dateString.replacingOccurrences(of: " ", with: "T")) {
                createdAt = d
            }
            // 5️⃣ Handle timezone format ending with +00 (no minutes)
            else {
                var adjusted = dateString.replacingOccurrences(of: " ", with: "T")
                if adjusted.hasSuffix("+00") { adjusted = adjusted.replacingOccurrences(of: "+00", with: "Z") }
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let d = iso.date(from: adjusted) {
                    createdAt = d
                } else {
                    // Fallback: use current date to avoid crashing the decode
                    createdAt = Date()
                }
            }
        } else {
            // Try decoding as Date directly (fallback)
            createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(audioUrl, forKey: .audioUrl)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encodeIfPresent(transcriptionUrl, forKey: .transcriptionUrl)
        try container.encodeIfPresent(collectionId, forKey: .collectionId)
        
        // Encode date as simple date string
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        let dateString = dateFormatter.string(from: createdAt)
        try container.encode(dateString, forKey: .createdAt)
    }
    
    init(id: UUID, title: String, description: String?, audioUrl: String, imageUrl: String?, createdAt: Date, transcriptionUrl: String?, collectionId: UUID? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.audioUrl = audioUrl
        self.imageUrl = imageUrl
        self.createdAt = createdAt
        self.transcriptionUrl = transcriptionUrl
        self.collectionId = collectionId
    }
}
