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
    @State private var keyboardHeight: CGFloat = 0 // Track keyboard height
    @State private var scrollViewContentHeight: CGFloat = 0 // Track content height
    @State private var scrollViewFrameHeight: CGFloat = 0 // Track visible frame height
    
    @EnvironmentObject private var miniPlayerState: MiniPlayerState
    @State private var miniPlayerHeight: CGFloat = 70 // Approximate height of mini player
    @State private var quickNotesHidMiniPlayer: Bool = false // Track if this view hid the miniplayer
    
    private let skyBlue = Color(red: 135/255.0, green: 206/255.0, blue: 235/255.0)
    private let noteSectionsFileName = "noteSections.json"
    private let lastActiveNoteDateKey = "lastActiveNoteDateKey"

    // MARK: - Computed Properties
    
    private var wordCount: Int {
        let words = noteText.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Dismiss keyboard button
            HStack {
                Button(action: {
                    isTextEditorFocused = false // Dismiss the keyboard
                }) {
                    Image(systemName: "chevron.down") // Changed icon
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(skyBlue)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
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
                GeometryReader { geometry in
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
                                ZStack(alignment: .topLeading) {
                                    TextEditor(text: $noteText)
                                        .frame(minHeight: 200, maxHeight: .infinity)
                                        .padding(.horizontal, 20)
                                        .padding(.bottom, 20) // Fixed padding
                                        .focused($isTextEditorFocused)
                                        .onChange(of: noteText) {
                                            isEditing = true
                                            saveTodaysNote()
                                            
                                            // Only auto-scroll if content might be hidden behind keyboard
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                if shouldScrollToBottom(availableHeight: geometry.size.height) {
                                                    withAnimation(.easeOut(duration: 0.3)) {
                                                        proxy.scrollTo("today-bottom", anchor: .bottom)
                                                    }
                                                }
                                            }
                                        }
                                        .onTapGesture {
                                            isEditing = true
                                        }
                                    
                                    // Invisible anchor point at the bottom of the text editor
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Spacer()
                                        }
                                        .frame(height: 1)
                                        .id("today-bottom")
                                    }
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
                        .background(
                            GeometryReader { contentGeometry in
                                Color.clear.onAppear {
                                    scrollViewContentHeight = contentGeometry.size.height
                                }
                                .onChange(of: contentGeometry.size.height) { _, newHeight in
                                    scrollViewContentHeight = newHeight
                                }
                            }
                        )
                    }
                    .onAppear {
                        scrollViewFrameHeight = geometry.size.height
                        initializeNotesIfNeeded()
                        // Scroll to today's section after a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut) {
                                proxy.scrollTo("today", anchor: .top)
                            }
                            isTextEditorFocused = true // Directly set focus as in the 'good' version
                        }
                    }
                    .onChange(of: geometry.size.height) { _, newHeight in
                        scrollViewFrameHeight = newHeight
                    }
                    .onChange(of: isTextEditorFocused) { _, newFocusedState in
                        if newFocusedState {
                            // When text editor gains focus, only scroll if needed
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { // Ensure keyboard height is updated
                                if shouldScrollToBottom(availableHeight: geometry.size.height) {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        proxy.scrollTo("today-bottom", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: keyboardHeight) { _, newKeyboardHeight in
                        // When keyboard appears/disappears, only scroll if content would be hidden
                        if newKeyboardHeight > 0 && isTextEditorFocused {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                if shouldScrollToBottom(availableHeight: geometry.size.height) {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        proxy.scrollTo("today-bottom", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: miniPlayerState.isVisible) { _, isVisible in
                        // Only scroll when mini player appears and text would be hidden
                        if isVisible && isTextEditorFocused {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                if shouldScrollToBottom(availableHeight: geometry.size.height) {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        proxy.scrollTo("today-bottom", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.keyboardHeight = keyboardFrame.height // Local state for scrolling
                    miniPlayerState.keyboardHeight = keyboardFrame.height // For MiniPlayerState if it needs it
                    if miniPlayerState.isVisible {
                        miniPlayerState.isVisible = false
                        self.quickNotesHidMiniPlayer = true
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                self.keyboardHeight = 0 // Local state for scrolling
                miniPlayerState.keyboardHeight = 0 // For MiniPlayerState
                if self.quickNotesHidMiniPlayer {
                    miniPlayerState.isVisible = true
                    self.quickNotesHidMiniPlayer = false
                }
            }
        }
        .onDisappear {
            saveNoteSections()
            // If QuickNotesView hid the miniplayer and is now disappearing,
            // try to restore miniplayer visibility and reset keyboard height.
            if self.quickNotesHidMiniPlayer {
                miniPlayerState.isVisible = true
                self.quickNotesHidMiniPlayer = false
            }
            if miniPlayerState.keyboardHeight > 0 && keyboardHeight > 0 { // If this view's keyboard was up
                miniPlayerState.keyboardHeight = 0
            }
        }
        // Mini-player overlay moved to ContentView.swift
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
    }
    
    // MARK: - Smart Scrolling Function

    private func shouldScrollToBottom(availableHeight: CGFloat) -> Bool {
        // Only consider scrolling if the text editor for today's note is focused
        // and the keyboard is actually visible.
        guard isTextEditorFocused && keyboardHeight > 0 else {
            return false
        }

        // Calculate the height of the visible area within the ScrollView
        // after accounting for the keyboard.
        let visibleAreaHeight = availableHeight - keyboardHeight

        // If the total content height within the ScrollView is greater than
        // this calculated visible area height, it means some part of the content
        // (potentially the bottom of the "Today" TextEditor where the user is typing)
        // might be obscured or pushed off-screen. In such cases, scrolling is needed.
        return scrollViewContentHeight > visibleAreaHeight
    }
    
    // MARK: - Initialization
    
    private func initializeNotesIfNeeded() {
        guard !hasInitialized else { return }
        hasInitialized = true
        
        loadNoteSections()
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
        let currentNoteText = self.noteText // Capture value for the background task
        DispatchQueue.global(qos: .background).async {
            UserDefaults.standard.set(currentNoteText, forKey: "todayNoteText")
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

// MARK: - Preview

struct QuickNotesView_Previews: PreviewProvider {
    static var previews: some View {
        QuickNotesView()
    }
}
