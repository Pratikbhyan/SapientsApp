import SwiftUI
import SafariServices

struct TermsPrivacyView: View {
    let title: String
    let url: URL
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            SafariWebView(url: url)
                .edgesIgnoringSafeArea(.all)
            
            // Custom overlay with done button
            VStack {
                HStack {
                    Button("Done") {
                        dismiss()
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(20)
                    .padding(.leading)
                    
                    Spacer()
                }
                .padding(.top, 50) // Account for safe area
                
                Spacer()
            }
        }
    }
}

struct SafariWebView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true
        
        let safari = SFSafariViewController(url: url, configuration: config)
        safari.preferredBarTintColor = UIColor.systemBackground
        safari.preferredControlTintColor = UIColor.label
        
        return safari
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No updates needed
    }
}
