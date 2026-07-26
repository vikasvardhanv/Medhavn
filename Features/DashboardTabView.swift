import SwiftUI

struct DashboardTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedSegment = 0

    var body: some View {
        VStack(spacing: 0) {
            // Premium Segmented Picker
            Picker("Dashboard Type", selection: $selectedSegment) {
                Text("Medicine").tag(0)
                Text("Fertility").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .tint(AppTheme.primary)

            Divider().opacity(0.12)

            if selectedSegment == 0 {
                ReportsDashboardView()
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            } else {
                if appState.trackerPreference == .period {
                    PeriodTrackerView()
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else {
                    FertilityTrackerView()
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
        }
        .background { MeshBackgroundView().ignoresSafeArea() }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
    }
}
