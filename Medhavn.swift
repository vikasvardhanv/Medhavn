import SwiftUI
import UserNotifications

@main
struct MedhavnApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Must be set before launch finishes so a tap on a reminder is not missed.
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared

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
                    NotificationRouter.shared.appState = appState
                    appState.bootstrap()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { appState.lockApp() }
                    // Back in the foreground (for example opened from AuraPath):
                    // sync medicines and dose ticks so both apps agree.
                    if phase == .active {
                        Task {
                            await appState.pullCloudMeds()
                            await appState.scheduleCabinetReminders()
                        }
                        appState.applyPendingDoseActions()
                        if appState.appleWatchLinked { Task { await appState.syncAppleWatch() } }
                    }
                }
                .onOpenURL { url in
                    if InviteLinkHandler.shared.handle(url: url) {
                        appState.pendingInvitationID = InviteLinkHandler.shared.pendingInvitationID
                    }
                }
        }
        .windowResizability(.automatic)
    }
}

struct RootView: View, AppStateProvider {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: AppTab = .home

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
            } else if !appState.trackerSelectionCompleted && appState.showsFertility {
                TrackerSelectionView()
            } else {
                tabShell
                .sheet(isPresented: $appState.showUpgradeSheet) {
                    UpgradeSheetView()
                        .environmentObject(appState)
                }
                .sheet(isPresented: Binding(
                    get: { appState.pendingInvitationID != nil },
                    set: { val in if !val { appState.pendingInvitationID = nil } }
                )) {
                    if let inviteID = appState.pendingInvitationID {
                        LinkConsentView(invitationID: inviteID, inviterContact: "proposed-inviter@medhavn.com")
                            .environmentObject(appState)
                    }
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
                .tag(AppTab.home)
                .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack { MedCabinetView().scrollContentBackground(.hidden) }
                .tag(AppTab.pharmacy)
                .tabItem { Label("Pharmacy", systemImage: "pills.fill") }

            NavigationStack { DashboardTabView().scrollContentBackground(.hidden) }
                .tag(AppTab.dashboard)
                .tabItem { Label("Dashboard", systemImage: "heart.text.square.fill") }

            NavigationStack { MoreHubView().scrollContentBackground(.hidden) }
                .tag(AppTab.hub)
                .tabItem { Label("Hub", systemImage: "square.grid.2x2.fill") }
        }
        .tabViewStyle(.automatic)
        .toolbar(.visible, for: .tabBar)
        .onChange(of: appState.openHomeTick) { _, _ in selectedTab = .home }
        .sheet(isPresented: Binding(
            get: { appState.isLoggedIn && appState.consentChecklistCompleted && appState.sex == nil },
            set: { _ in }
        )) {
            SexPromptView().environmentObject(appState).interactiveDismissDisabled()
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottomTrailing) {
            FloatingPillChatHost()
                .padding(.bottom, 16) // ensure above home indicator
        }
    }
}

private enum AppTab: Hashable {
    case home
    case pharmacy
    case dashboard
    case hub
}

