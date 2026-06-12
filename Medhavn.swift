import SwiftUI

@main
struct MedhavnApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Use a transparent navigation bar with frosted ultra-thin material blur
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(red: 0.95, green: 0.79, blue: 0.30, alpha: 1.0) // Gold primary

        // Solid dark tab bar — matches meshStart so color never shifts between tabs
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(red: 0.07, green: 0.08, blue: 0.11, alpha: 1.0)
        tabAppearance.shadowColor = .clear

        let goldColor = UIColor(red: 0.95, green: 0.79, blue: 0.30, alpha: 1.0)
        let inactiveColor = UIColor.white.withAlphaComponent(0.4)
        
        tabAppearance.stackedLayoutAppearance.selected.iconColor = goldColor
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: goldColor]
        tabAppearance.stackedLayoutAppearance.normal.iconColor = inactiveColor
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: inactiveColor]
        
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = goldColor
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .task {
                    appState.bootstrap()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { appState.lockApp() }
                }
        }
        .windowResizability(.automatic)
    }
}

struct RootView: View, AppStateProvider {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: AppTab = .doseMap

    var currentAppState: AppState { appState }

    private var appBackgroundLayer: some View {
        MeshBackgroundView()
    }

    var body: some View {
        ZStack {
            Group {
            // ── First-launch gate ─────────────────────────────────────────
            // Show the model-download setup screen the very first time the
            // app runs (isFirstLaunchSetupDone = false, stored in UserDefaults).
            // Once the download completes – or the user taps "Continue without
            // AI" – isFirstLaunchSetupDone flips to true and is never false again.
            if !appState.isFirstLaunchSetupDone {
                FirstLaunchSetupView()
            } else if !appState.isLoggedIn {
                LoginView()
            } else if !appState.consentChecklistCompleted {
                ConsentChecklistView()
            } else {
                tabShell
                .sheet(isPresented: $appState.showUpgradeSheet) {
                    UpgradeSheetView()
                        .environmentObject(appState)
                }
            }
            }
        // PIN lock overlay
        if appState.isAppLocked {
            LockScreenView()
                .environmentObject(appState)
                .transition(.opacity)
        }
        }  // end ZStack
        .background(appBackgroundLayer.ignoresSafeArea())
        
    }

    private var tabShell: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { PillboxView().scrollContentBackground(.hidden) }
                .tag(AppTab.doseMap)
                .tabItem { Label("DoseMap", systemImage: "calendar.badge.clock") }

            NavigationStack { UpdatesFeedView().scrollContentBackground(.hidden) }
                .tag(AppTab.timeline)
                .tabItem { Label("Timeline", systemImage: "clock.arrow.circlepath") }

            NavigationStack { ReportsDashboardView().scrollContentBackground(.hidden) }
                .tag(AppTab.insights)
                .tabItem { Label("Insights", systemImage: "waveform.path.ecg") }

            NavigationStack { MedCabinetView().scrollContentBackground(.hidden) }
                .tag(AppTab.vault)
                .tabItem { Label("Vault", systemImage: "lock.doc.fill") }

            NavigationStack { MoreHubView().scrollContentBackground(.hidden) }
                .tag(AppTab.hub)
                .tabItem { Label("Hub", systemImage: "square.grid.2x2.fill") }
        }
        .tabViewStyle(.automatic)
        .toolbar(.visible, for: .tabBar)
        .ignoresSafeArea()
        .overlay(alignment: .bottomTrailing) {
            FloatingPillChatHost()
                .padding(.bottom, 16) // ensure above home indicator
        }
    }
}

private enum AppTab: CaseIterable {
    case doseMap
    case timeline
    case insights
    case vault
    case hub

    var title: String {
        switch self {
        case .doseMap: return "DoseMap"
        case .timeline: return "Timeline"
        case .insights: return "Insights"
        case .vault: return "Vault"
        case .hub: return "Hub"
        }
    }

    var icon: String {
        switch self {
        case .doseMap: return "calendar.badge.clock"
        case .timeline: return "clock.arrow.circlepath"
        case .insights: return "waveform.path.ecg"
        case .vault: return "lock.doc.fill"
        case .hub: return "square.grid.2x2.fill"
        }
    }
}
