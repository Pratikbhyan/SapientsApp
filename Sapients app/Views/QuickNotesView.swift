import SwiftUI

struct QuickNotesView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var noteText: String = "" // Will be loaded in onAppear after checking for new day
    @State private var noteSections: [NoteSection] = []
    @State private var isEditing: Bool = false
    @FocusState private var isTextEditorFocused: Bool
    
    private let skyBlue = Color(red: 135/255.0, green: 206/255.0, blue: 235/255.0)
    private let noteSectionsFileName = "noteSections.json"
    private let lastActiveNoteDateKey = "lastActiveNoteDateKey"
    
    var body: some View {
            VStack(spacing: 0) {
                // Centered header with colored title
                VStack(spacing: 8) {
                    Text("Quick Notes")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(skyBlue)
                    
                    if !noteText.isEmpty {
                        Text("\(wordCount) words")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 0) // Reduced top padding
                .padding(.bottom, 15)
                
                // Main content area
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            // Previous notes sections
                            ForEach($noteSections) { $section in // Use binding to allow editing
                                Section {
                                    VStack(alignment: .leading, spacing: 12) {
                                        TextEditor(text: $section.content)
                                            .frame(minHeight: 50) // Adjust height as needed
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 10)
                                            .onChange(of: section.content) {
                                                saveNoteSections() // Save when content changes
                                            }
                                    }
                                    .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
                                } header: {
                                    HStack {
                                        Text(formatDate(section.date))
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.gray)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(Color(UIColor.systemBackground))
                                }
                            }
                            
                            // Today's section
                            Section {
                                TextEditor(text: $noteText)
                                    .frame(minHeight: 200, maxHeight: .infinity)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 20)
                                    .focused($isTextEditorFocused)
                                    .onChange(of: noteText) {
                                        isEditing = true
                                        UserDefaults.standard.set(noteText, forKey: "todayNoteText")
                                        // Check if we need to create a new section for a new day
                                        checkForNewDay()
                                    }
                                    .onTapGesture {
                                        isEditing = true
                                    }
                                
                            } header: {
                                HStack {
                                    Text("Today - \(formatDate(Date()))")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Spacer()
                                    
                                    // Clear button for today's notes
                                    if !noteText.isEmpty {
                                        Button(action: clearTodaysNotes) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                                .font(.caption)
                                        }
                                        .buttonStyle(BorderlessButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color(UIColor.systemBackground))
                                .id("today")
                            }
                        }
                    }
                    .onAppear {
                        // Scroll to today's section
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut) {
                                proxy.scrollTo("today", anchor: .top)
                            }
                            isTextEditorFocused = true
                        }
                    }
                    .onAppear {
                        loadNoteSections()       // Load archived notes first
                        checkForNewDay()         // Archive previous day's note if needed, then load today's note
                        // Scroll to today's section
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut) {
                                proxy.scrollTo("today", anchor: .top)
                            }
                            isTextEditorFocused = true
                        }
                    }
                }
            }
            .onDisappear {
                saveNoteSections() // Save archived notes when view disappears
            }
            // Custom toolbar removed
        // NavigationView wrapper removed
        .onTapGesture {
            if !isTextEditorFocused {
                isTextEditorFocused = true
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var wordCount: Int {
        let words = noteText.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }
    
    // MARK: - Actions
    
    private func clearTodaysNotes() {
        withAnimation(.easeInOut(duration: 0.3)) {
            noteText = ""
            isEditing = false
            UserDefaults.standard.removeObject(forKey: "todayNoteText")
        }
    }
    
    private func checkForNewDay() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let lastActiveDateTimestamp = UserDefaults.standard.double(forKey: lastActiveNoteDateKey)
        let lastActiveDate = lastActiveDateTimestamp == 0 ? today : calendar.startOfDay(for: Date(timeIntervalSince1970: lastActiveDateTimestamp))
        
        let previousDayNote = UserDefaults.standard.string(forKey: "todayNoteText") ?? ""
        
        if !calendar.isDate(today, inSameDayAs: lastActiveDate) && !previousDayNote.isEmpty {
            // It's a new day and there was a note from the previous active day
            let newSection = NoteSection(date: lastActiveDate, content: previousDayNote)
            noteSections.append(newSection) // Append to the end for chronological display (oldest first)
            saveNoteSections() // Save the updated sections
            
            // Clear the old "today's note" as it's now archived
            noteText = "" 
            UserDefaults.standard.removeObject(forKey: "todayNoteText")
            print("Archived note from \(formatDate(lastActiveDate)) to sections.")
        } else {
            // Same day or no previous note to archive, just load current noteText
            noteText = previousDayNote
        }
        
        // Update the last active date to today
        UserDefaults.standard.set(today.timeIntervalSince1970, forKey: lastActiveNoteDateKey)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
    
    // MARK: - Data Persistence for NoteSections
    
    private var noteSectionsFileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(noteSectionsFileName)
    }
    
    private func saveNoteSections() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601 // Good for dates
        do {
            let data = try encoder.encode(noteSections)
            try data.write(to: noteSectionsFileURL, options: [.atomicWrite])
            print("Note sections saved successfully.")
        } catch {
            print("Error saving note sections: \(error.localizedDescription)")
        }
    }
    
    private func loadNoteSections() {
        guard FileManager.default.fileExists(atPath: noteSectionsFileURL.path) else {
            print("Note sections file does not exist yet.")
            return
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let data = try Data(contentsOf: noteSectionsFileURL)
            noteSections = try decoder.decode([NoteSection].self, from: data)
            print("Note sections loaded successfully.")
        } catch {
            print("Error loading note sections: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

struct NoteSection: Codable, Identifiable {
    var id = UUID() // Added for Identifiable conformance, useful for ForEach
    let date: Date
    var content: String // Changed from NSAttributedString to String
}

// MARK: - Attributed Text Display

struct AttributedText: View {
    let text: String // Changed from NSAttributedString to String
    
    var body: some View {
        Text(text)
            .frame(maxWidth: .infinity, alignment: .leading) // Ensure it takes width and aligns left
    }
}

// MARK: - Preview

struct NotesView_Previews: PreviewProvider {
    static var previews: some View {
        QuickNotesView()
    }
}
