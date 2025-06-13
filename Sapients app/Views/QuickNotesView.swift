import SwiftUI
import Combine

// MARK: - View

struct QuickHighlightsView: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject private var repo = HighlightRepository.shared
    
    @State private var showActionSheet = false
    @State private var selectedHighlightText = ""
    
    private let skyBlue = Color(red: 135/255.0, green: 206/255.0, blue: 235/255.0)

    var body: some View {
        NavigationView {
            Group {
                if repo.isLoading && repo.groups.isEmpty {
                    // Loading state
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading highlights...")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if repo.groups.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "highlighter")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        Text("Highlight your favourite segments and they will appear here")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Highlights list
                    List {
                        ForEach(repo.groups) { group in
                            Section(header: GroupHeader(group: group)) {
                                ForEach(group.segments) { seg in
                                    Text(seg.text)
                                        .padding(.vertical, 4)
                                        .swipeActions {
                                            Button(role: .destructive) {
                                                repo.deleteSegment(group: group,
                                                                   segment: seg)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .onLongPressGesture {
                                            selectedHighlightText = seg.text
                                            showActionSheet = true
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await repo.refreshHighlights()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Highlight Options", isPresented: $showActionSheet, titleVisibility: .visible) {
                Button("Copy") {
                    copyHighlight(text: selectedHighlightText)
                }
                Button("Share") {
                    shareHighlight(text: selectedHighlightText)
                }
                Button("Cancel", role: .cancel) { }
            }
            .alert("Error", isPresented: .constant(repo.error != nil)) {
                Button("OK") {
                    repo.error = nil
                }
            } message: {
                Text(repo.error ?? "")
            }
        }
        .onAppear {
            Task {
                await repo.refreshHighlights()
            }
        }
    }
    
    private func copyHighlight(text: String) {
        UIPasteboard.general.string = text
        
        // Optional: Show a brief feedback (you could add a toast notification here)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func shareHighlight(text: String) {
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        // Configure for specific apps
        activityVC.excludedActivityTypes = [
            .assignToContact,
            .saveToCameraRoll,
            .addToReadingList,
            .postToFlickr,
            .postToVimeo,
            .postToTencentWeibo,
            .postToWeibo
        ]
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            if let topController = window.rootViewController {
                var presentedController = topController
                while let presented = presentedController.presentedViewController {
                    presentedController = presented
                }
                
                // Configure for iPad
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = window
                    popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                
                presentedController.present(activityVC, animated: true)
            }
        }
    }
}

// MARK: - Subviews

private struct GroupHeader: View {
    let group: HighlightGroup
    
    var body: some View {
        HStack {
            Spacer()
            Text(group.title)
                .font(.headline)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Backwards Compatibility Typealias
// This allows existing code that references QuickNotesView to continue working
typealias QuickNotesView = QuickHighlightsView

// MARK: - Preview

struct QuickHighlightsView_Previews: PreviewProvider {
    static var previews: some View {
        QuickHighlightsView()
    }
}
