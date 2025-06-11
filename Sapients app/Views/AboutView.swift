import SwiftUI

struct AboutView: View {
    @State private var showingTerms = false
    @State private var showingPrivacy = false
    @State private var showingSupport = false
    
    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "Version \(version) (\(build))"
        } else if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return "Version \(version)"
        } else {
            return "Version 1.0"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    // App Info Section
                    VStack(spacing: 12) {
                        Image("AppIcon") // Your app icon
                            .resizable()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        Text("Sapients")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(appVersion)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    
                    // Legal section
                    Text("Legal")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    // Terms of Use
                    HStack {
                        Text("Terms of Use")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Capsule())
                    .contentShape(Capsule())
                    .onTapGesture {
                        showingTerms = true
                    }
                    
                    // Privacy Policy
                    HStack {
                        Text("Privacy Policy")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Capsule())
                    .contentShape(Capsule())
                    .onTapGesture {
                        showingPrivacy = true
                    }
                    
                    // Support
                    HStack {
                        Text("Support")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Capsule())
                    .contentShape(Capsule())
                    .onTapGesture {
                        showingSupport = true
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingTerms) {
            TermsPrivacyView(
                title: "Terms of Use",
                url: URL(string: "https://v0-new-project-xup9pufctgc.vercel.app/terms")!
            )
        }
        .sheet(isPresented: $showingPrivacy) {
            TermsPrivacyView(
                title: "Privacy Policy",
                url: URL(string: "https://v0-new-project-xup9pufctgc.vercel.app/privacy")!
            )
        }
        .sheet(isPresented: $showingSupport) {
            TermsPrivacyView(
                title: "Support",
                url: URL(string: "https://v0-new-project-xup9pufctgc.vercel.app/support")!
            )
        }
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AboutView()
        }
    }
}