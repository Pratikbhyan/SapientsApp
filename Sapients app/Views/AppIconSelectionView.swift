import SwiftUI

struct AppIconSelectionView: View {
    let iconOptions: [AppIconOption]
    @Binding var selectedIconName: String? // Store the iconName (String or nil for default)
    @Environment(\.dismiss) var dismiss

    // Define grid layout: e.g., 3 columns, adaptive size
    let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 3)

    var body: some View {
        // Removed NavigationView from here, assuming SettingsView is already in one.
        // If not, you might need to wrap SettingsView's body in a NavigationView.
        ScrollView {
            VStack(spacing: 20) {
                Text("Select Your App Icon")
                    .font(.headline)
                    .padding(.top)

                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(iconOptions, id: \.self) { option in
                        Button(action: {
                            selectedIconName = option.iconName
                            changeAppIconWithName(option.iconName)
                            // dismiss() // Optional: dismiss immediately or let user use Done button
                        }) {
                            VStack {
                                Image(option.previewImageName) // Assumes p_sky, p_earth etc. exist
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80, height: 80) // Adjust size as needed
                                    .clipShape(RoundedRectangle(cornerRadius: 18)) // iOS icon shape
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(isSelected(option: option) ? Color.blue : Color.clear, lineWidth: 3)
                                    )
                                // Text(option.displayName) // Removed to show only images
                                //     .font(.caption)
                                //     .lineLimit(1)
                            }
                        }
                    }
                }
                .padding()

                Button(action: {
                    selectedIconName = nil // Reset to default
                    changeAppIconWithName(nil)
                    // dismiss() // Optional
                }) {
                    Text("Reset to Default")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Choose Icon")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            // This view now relies on selectedIconName being correctly passed in and updated.
            // If you need to fetch the *actual* current icon from UIApplication upon appearing:
            // self.selectedIconName = UIApplication.shared.alternateIconName
        }
    }

    private func isSelected(option: AppIconOption) -> Bool {
        return selectedIconName == option.iconName
    }
    
    private func changeAppIconWithName(_ iconNameToSet: String?) {
        UIApplication.shared.setAlternateIconName(iconNameToSet) { error in
            if let error = error {
                print("Error changing app icon: \(error.localizedDescription)")
            } else {
                print("App icon change requested to: \(iconNameToSet ?? "Default")")
                // Persist the selected icon name if needed (e.g., UserDefaults)
                // UserDefaults.standard.set(iconNameToSet, forKey: "selectedAppIconName")
            }
        }
    }
}

// Preview needs AppIconOption definition if you want to use it directly here
// For simplicity, ensure AppIconOption is accessible or provide mock data for preview.
/*
struct AppIconSelectionView_Previews: PreviewProvider {
    @State static var previewSelectedIconName: String? = nil
    static let previewIconOptions: [AppIconOption] = [
        .init(displayName: "Sapients Default", iconName: nil, previewImageName: "p_primary"),
        .init(displayName: "Sky", iconName: "sky", previewImageName: "p_sky"),
        .init(displayName: "Earth", iconName: "earth", previewImageName: "p_earth")
    ]

    static var previews: some View {
        NavigationView { // Wrap in NavigationView for preview context
            AppIconSelectionView(iconOptions: previewIconOptions, selectedIconName: $previewSelectedIconName)
        }
    }
}
*/
