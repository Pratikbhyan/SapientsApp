import SwiftUI

struct CacheDetailsView: View {
    @StateObject private var cacheManager = AudioCacheManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Cache Statistics Card
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Cache Performance")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            StatRow(
                                title: "Cache Hit Rate",
                                value: "\((cacheManager.cacheStats.hitRate * 100).rounded(toPlaces: 1))%",
                                icon: "target",
                                color: cacheManager.cacheStats.hitRate > 0.7 ? .green : .orange
                            )
                            
                            StatRow(
                                title: "Episodes Cached",
                                value: "\(cacheManager.cacheStats.fileCount)",
                                icon: "music.note.list",
                                color: .blue
                            )
                            
                            StatRow(
                                title: "Storage Used",
                                value: cacheManager.cacheStats.totalSize.formattedByteCount,
                                icon: "internaldrive",
                                color: .purple
                            )
                            
                            StatRow(
                                title: "Total Requests",
                                value: "\(cacheManager.cacheStats.totalRequests)",
                                icon: "arrow.down.circle",
                                color: .gray
                            )
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Cache Efficiency Report
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Efficiency Report")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(cacheManager.getCacheEfficiencyReport())
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Actions
                    VStack(spacing: 12) {
                        Button(action: {
                            let repository = ContentRepository()
                            cacheManager.cacheUpcomingEpisodes(from: repository)
                        }) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Cache Upcoming Episodes")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        Button(action: {
                            cacheManager.clearCache()
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Clear All Cache")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    
                    // Info Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About Audio Caching")
                            .font(.headline)
                        
                        Text("Audio caching reduces data usage and improves playback performance by storing episodes locally on your device. Episodes are automatically cached when you play them and intelligently pre-cached based on your listening patterns.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("Cache Details")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StatRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

#Preview {
    CacheDetailsView()
}