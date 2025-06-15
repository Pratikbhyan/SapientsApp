import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var feedbackService = FeedbackService.shared
    @State private var feedbackText: String = ""
    @State private var isSubmitting = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    private let maxCharacters = 1000
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Send Feedback")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text("We want to hear from you! Let us know what we can do to improve your experience.")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack(alignment: .topLeading) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                                    .frame(minHeight: 200)
                                
                                TextEditor(text: $feedbackText)
                                    .padding(12)
                                    .background(Color.clear)
                                    .scrollContentBackground(.hidden)
                                    .font(.body)
                                    .onChange(of: feedbackText) { oldValue, newValue in
                                        if newValue.count > maxCharacters {
                                            feedbackText = String(newValue.prefix(maxCharacters))
                                        }
                                    }
                                
                                if feedbackText.isEmpty {
                                    Text("Write some feedback")
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 20)
                                        .allowsHitTesting(false)
                                }
                            }
                            
                            HStack {
                                Spacer()
                                Text("\(feedbackText.count)/\(maxCharacters)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 120)
                    }
                }
                
                Button(action: submitFeedback) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("SENDING...")
                        } else {
                            Text("SEND")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                    )
                }
                .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                .padding(.horizontal)
                .padding(.bottom, 20)
                .background(Color(.systemBackground))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .keyboardType(.default)
        }
        .alert("Feedback Sent!", isPresented: $showingSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Thank you for your feedback! We appreciate you taking the time to help us improve.")
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func submitFeedback() {
        Task {
            isSubmitting = true
            
            do {
                try await feedbackService.submitFeedback(feedbackText)
                await MainActor.run {
                    showingSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                }
            }
            
            await MainActor.run {
                isSubmitting = false
            }
        }
    }
}

#Preview {
    FeedbackView()
}
