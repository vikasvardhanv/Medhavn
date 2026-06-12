import SwiftUI
import MedicationLogicEngine

struct UpdatesFeedView: View {
    @EnvironmentObject private var appState: AppState

    init() {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                let feedItems = appState.updatesFeed.sorted { $0.timestamp > $1.timestamp }
                
                if feedItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        
                        Text("No timeline entries yet")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Text("Your medication logs and adherence updates will appear here.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                    .padding()
                    .glassCard(cornerRadius: 24)
                    .staggeredEntrance(delay: 0.1)
                } else {
                    ZStack(alignment: .leading) {
                        // Timeline track line
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.primary.opacity(0.4), AppTheme.primary.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 3)
                            .padding(.leading, 24)
                            .padding(.vertical, 8)
                        
                        VStack(spacing: 16) {
                            ForEach(Array(feedItems.enumerated()), id: \.element.id) { index, item in
                                timelineRow(item: item)
                                    .staggeredEntrance(delay: Double(index) * 0.06)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background { MeshBackgroundView() }
        .navigationTitle("Timeline")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }

    @ViewBuilder
    private func timelineRow(item: UpdateFeedItem) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline dot indicator
            ZStack {
                Circle()
                    .fill(AppTheme.primary)
                    .frame(width: 14, height: 14)
                
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 14, height: 14)
            }
            .frame(width: 50)
            .padding(.top, 14)

            // Content card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(item.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.primary)
                        .clipShape(Capsule())
                }
                
                Text(item.detail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(item.timestamp.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))

                if item.category == .caregiver && item.title == "Parent dose missed" {
                    NavigationLink {
                        ParentCareView()
                            .environmentObject(appState)
                    } label: {
                        Label("Open Parent Care", systemImage: "bell.badge")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(AppTheme.primary)
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 2)
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 16)
        }
    }
}
