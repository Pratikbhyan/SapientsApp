import SwiftUI

struct QuickNotesView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var noteText: String = ""
    @State private var noteSections: [NoteSection] = []
    @State private var isEditing: Bool = false
    @FocusState private var isTextEditorFocused: Bool
    @State private var selectedSectionForDeletion: NoteSection?
    @State private var showingDeleteConfirmation: Bool = false
    @State private var hasInitialized: Bool = false // Prevent duplicate initialization
    
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
            .padding(.top, 0)
            .padding(.bottom, 15)
            
            // Main content area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        // Previous notes sections (sorted chronologically - newest first)
                        ForEach($noteSections.sorted(by: { $0.date.wrappedValue > $1.date.wrappedValue })) { $section in
                            Section {
                                VStack(alignment: .leading, spacing: 12) {
                                    TextEditor(text: $section.content)
                                        .frame(minHeight: 50)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .onChange(of: section.content) {
                                            saveNoteSections()
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
                                .contentShape(Rectangle())
                                .onLongPressGesture {
                                    selectedSectionForDeletion = section
                                    showingDeleteConfirmation = true
                                }
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
                                    saveTodaysNote()
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
                    initializeNotesIfNeeded()
                    // Scroll to today's section after a brief delay
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
            saveNoteSections()
        }
        .alert(isPresented: $showingDeleteConfirmation) {
            Alert(
                title: Text("Delete Notes"),
                message: Text("Are you sure you want to delete all notes for \(selectedSectionForDeletion != nil ? formatDate(selectedSectionForDeletion!.date) : "this day")?"),
                primaryButton: .destructive(Text("Delete")) {
                    if let sectionToDelete = selectedSectionForDeletion {
                        deleteNotes(for: sectionToDelete)
                    }
                },
                secondaryButton: .cancel() {
                    selectedSectionForDeletion = nil
                }
            )
        }
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
    
    // MARK: - Initialization
    
    private func initializeNotesIfNeeded() {
        guard !hasInitialized else { return }
        hasInitialized = true
        
        // Load archived notes first
        loadNoteSections()
        
        // Then check for new day and load today's note
        checkForNewDay()
    }
    
    // MARK: - Actions

    private func deleteNotes(for section: NoteSection) {
        if let index = noteSections.firstIndex(where: { $0.id == section.id }) {
            noteSections.remove(at: index)
            saveNoteSections()
        }
        selectedSectionForDeletion = nil
    }
    
    private func clearTodaysNotes() {
        withAnimation(.easeInOut(duration: 0.3)) {
            noteText = ""
            isEditing = false
            UserDefaults.standard.removeObject(forKey: "todayNoteText")
        }
    }
    
    private func saveTodaysNote() {
        UserDefaults.standard.set(noteText, forKey: "todayNoteText")
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
            
            // Check if this section already exists to prevent duplicates
            if !noteSections.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: lastActiveDate) }) {
                noteSections.append(newSection)
                saveNoteSections()
                print("Archived note from \(formatDate(lastActiveDate)) to sections.")
            }
            
            // Clear the old "today's note" as it's now archived
            noteText = ""
            UserDefaults.standard.removeObject(forKey: "todayNoteText")
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
        encoder.dateEncodingStrategy = .iso8601
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
            let loadedSections = try decoder.decode([NoteSection].self, from: data)
            noteSections = loadedSections
            print("Note sections loaded successfully.")
        } catch {
            print("Error loading note sections: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

struct NoteSection: Codable, Identifiable {
    var id = UUID()
    let date: Date
    var content: String
}

// MARK: - Attributed Text Display

struct AttributedText: View {
    let text: String
    
    var body: some View {
        Text(text)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

struct NotesView_Previews: PreviewProvider {
    static var previews: some View {
        QuickNotesView()
    }
}