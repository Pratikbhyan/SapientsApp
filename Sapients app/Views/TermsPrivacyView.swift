import SwiftUI
import SafariServices

struct TermsPrivacyView: View {
    let title: String
    let url: URL
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        SafariWebView(url: url, dismiss: dismiss)
            .edgesIgnoringSafeArea(.all)
    }
}

struct SafariWebView: UIViewControllerRepresentable {
    let url: URL
    let dismiss: DismissAction
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true
        
        let safari = SFSafariViewController(url: url, configuration: config)
        safari.preferredBarTintColor = UIColor.systemBackground
        safari.preferredControlTintColor = UIColor.label
        
        safari.delegate = context.coordinator
        
        return safari
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }
    
    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let dismiss: DismissAction
        
        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }
        
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            dismiss()
        }
    }
}
