import SwiftUI

struct DailyContentViewLoader: View {
    @StateObject private var repository = ContentRepository()
    @State private var dailyContent: Content?
    @State private var isLoadingState = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoadingState {
                VStack {
                    Image("loadingScreen")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .padding(.bottom)
                    ProgressView("Loading Today's Pick...")
                }
            } else if let content = dailyContent {
                ContentDetailView(content: content)
            } else if let errorMessage = errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text("Error Loading Content")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Try Again") {
                        Task {
                            await loadDailyContent()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                }
                .padding()
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("No Daily Content Available")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Please check back later for today's featured audio.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
            }
        }
        .task {
            await loadDailyContent()
        }
    }

    private func loadDailyContent() async {
        isLoadingState = true
        errorMessage = nil
        do {
            dailyContent = try await repository.fetchDailyContent()
        } catch {
            self.errorMessage = error.localizedDescription
            print("Failed to load daily content from DailyContentViewLoader: \(error)")
        }
        isLoadingState = false
    }
}

#Preview {
    DailyContentViewLoader()
}
