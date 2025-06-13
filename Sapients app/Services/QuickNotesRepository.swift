import Foundation
import Combine

@MainActor
class QuickNotesRepository: ObservableObject {
    static let shared = QuickNotesRepository()

    @Published var noteSections: [NoteSection] = []
    @Published var isLoading = false

    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let noteSectionsFileName = "noteSections.json"

    private var noteSectionsFileURL: URL {
        documentsDirectory.appendingPathComponent(noteSectionsFileName)
    }

    private init() {
        loadNoteSections()
        // If noteSections is empty after loading, consider adding a default placeholder note.
        // if noteSections.isEmpty {
        //     noteSections.append(NoteSection(date: Date(), content: "Welcome to your first Quick Note!"))
        //     saveNoteSections()
        // }
    }

    func addSection(content: String, date: Date = Date()) {
        // MIGRATION: Use new Highlights system instead
        // Default to "Quick Notes" as the group title for backwards compatibility
        HighlightRepository.shared.add(content, to: "Quick Notes")
        
        // Legacy note system - keep for any existing references
        let newSection = NoteSection(date: date, content: content)
        noteSections.insert(newSection, at: 0) // Add new notes to the top
        saveNoteSections()
    }

    func deleteSection(at offsets: IndexSet) {
        noteSections.remove(atOffsets: offsets)
        saveNoteSections()
    }
    
    func updateSection(id: UUID, newContent: String) {
        if let index = noteSections.firstIndex(where: { $0.id == id }) {
            noteSections[index].content = newContent
            saveNoteSections()
        }
    }

    private func saveNoteSections() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(noteSections)
            try data.write(to: noteSectionsFileURL, options: [.atomicWrite])
            print("QuickNotesRepository: Note sections saved successfully. Count: \(noteSections.count)")
        } catch {
            print("QuickNotesRepository: Error saving note sections: \(error.localizedDescription)")
        }
    }

    private func loadNoteSections() {
        guard FileManager.default.fileExists(atPath: noteSectionsFileURL.path) else {
            print("QuickNotesRepository: Note sections file does not exist yet.")
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let data = try Data(contentsOf: noteSectionsFileURL)
            // Ensure that we decode into [NoteSection]
            let loadedSections = try decoder.decode([NoteSection].self, from: data)
            noteSections = loadedSections.sorted(by: { $0.date > $1.date }) // Keep them sorted, newest first
            print("QuickNotesRepository: Note sections loaded successfully. Count: \(noteSections.count)")
        } catch {
            print("QuickNotesRepository: Error loading note sections: \(error.localizedDescription)")
            noteSections = [] // Initialize to empty array on error to prevent crash
        }
    }
}
