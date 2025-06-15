import Foundation

struct Content: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let description: String?
    let audioUrl: String
    let imageUrl: String?
    let createdAt: Date // This will now be a simple date (no time component)
    let transcriptionUrl: String?
    
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
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        audioUrl = try container.decode(String.self, forKey: .audioUrl)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        transcriptionUrl = try container.decodeIfPresent(String.self, forKey: .transcriptionUrl)
        
        // Custom date handling for simplified date format
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            // Parse date components directly to avoid timezone issues
            let components = dateString.split(separator: "-")
            if components.count == 3,
               let year = Int(components[0]),
               let month = Int(components[1]),
               let day = Int(components[2]) {
                
                // Create date using user's current calendar and timezone
                var calendar = Calendar.current
                let dateComponents = DateComponents(year: year, month: month, day: day, hour: 0, minute: 0, second: 0)
                
                if let date = calendar.date(from: dateComponents) {
                    createdAt = date
                } else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .createdAt,
                        in: container,
                        debugDescription: "Cannot create date from components: \(dateString)"
                    )
                }
            } else {
                // Fallback to ISO8601 format
                let iso8601Formatter = ISO8601DateFormatter()
                if let date = iso8601Formatter.date(from: dateString) {
                    createdAt = date
                } else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .createdAt,
                        in: container,
                        debugDescription: "Cannot decode date string: \(dateString)"
                    )
                }
            }
        } else {
            // Try decoding as Date directly (fallback)
            createdAt = try container.decode(Date.self, forKey: .createdAt)
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
        
        // Encode date as simple date string
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        let dateString = dateFormatter.string(from: createdAt)
        try container.encode(dateString, forKey: .createdAt)
    }
    
    init(id: UUID, title: String, description: String?, audioUrl: String, imageUrl: String?, createdAt: Date, transcriptionUrl: String?) {
        self.id = id
        self.title = title
        self.description = description
        self.audioUrl = audioUrl
        self.imageUrl = imageUrl
        self.createdAt = createdAt
        self.transcriptionUrl = transcriptionUrl
    }
}
