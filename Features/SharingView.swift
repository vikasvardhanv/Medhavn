import SwiftUI

/// People I am connected to, and what I share with them or they share with me.
/// Nothing is shared until the data owner accepts. Declined requests can be undone or re-sent.
struct SharingView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var model = SharingModel()
    @State private var showAdd = false
    @State private var scopeSheet: ScopeSheetMode?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let message = model.message {
                    Text(message).font(.footnote).foregroundStyle(.white).padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading).glassCard(cornerRadius: 12)
                }
                requestsSection
                peopleSection
                ownedSection
                viewingSection
            }
            .padding(16)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background { MeshBackgroundView() }
        .navigationTitle("Connections & Sharing")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "person.badge.plus") }
                    .accessibilityLabel("Add person")
            }
        }
        .task { await model.load(token: appState.authToken) }
        .refreshable { await model.load(token: appState.authToken) }
        .sheet(isPresented: $showAdd) {
            AddPersonSheet(model: model).environmentObject(appState)
        }
        .sheet(item: $scopeSheet) { mode in
            ScopeSheet(mode: mode, model: model).environmentObject(appState)
        }
    }

    // MARK: Requests for me

    private var incomingConnections: [ConnectionItem] {
        model.connections.filter { $0.direction == "incoming" && ($0.status == "pending" || $0.status == "declined") }
    }
    private var incomingShares: [(ShareItem, Bool)] {
        // (share, iAmOwner)
        model.owned.filter { !$0.initiatedByMe && ($0.status == "pending" || $0.status == "declined") }.map { ($0, true) }
        + model.viewing.filter { !$0.initiatedByMe && ($0.status == "pending" || $0.status == "declined") }.map { ($0, false) }
    }

    @ViewBuilder private var requestsSection: some View {
        if !incomingConnections.isEmpty || !incomingShares.isEmpty {
            section("Requests for you") {
                ForEach(incomingConnections) { c in
                    requestRow(
                        title: "\(c.other.name) wants to connect",
                        subtitle: c.status == "declined" ? "You declined. Changed your mind?" : "They say they are your \(c.relationship).",
                        acceptTitle: "Accept",
                        declineTitle: c.status == "declined" ? nil : "Decline",
                        onAccept: { await model.respond(connection: c, accept: true, token: appState.authToken) },
                        onDecline: { await model.respond(connection: c, accept: false, token: appState.authToken) }
                    )
                }
                ForEach(incomingShares, id: \.0.id) { share, iAmOwner in
                    let what = iAmOwner ? "wants to see your health info" : "wants to share their health info with you"
                    requestRow(
                        title: "\(share.other.name) \(what)",
                        subtitle: (share.status == "declined" ? "You declined. " : "") + "Includes: " + scopeText(share.scopes),
                        acceptTitle: "Accept",
                        declineTitle: share.status == "declined" ? nil : "Decline",
                        onAccept: {
                            if iAmOwner { scopeSheet = .acceptRequest(share) }
                            else { await model.respond(share: share, accept: true, scopes: nil, token: appState.authToken) }
                        },
                        onDecline: { await model.respond(share: share, accept: false, scopes: nil, token: appState.authToken) }
                    )
                }
            }
        }
    }

    // MARK: My people

    @ViewBuilder private var peopleSection: some View {
        let mine = model.connections.filter { $0.direction == "outgoing" || $0.status == "accepted" }
        section("My people") {
            if mine.isEmpty {
                Text("Add a parent, child, partner or friend. You choose what to share after they accept.")
                    .font(.footnote).foregroundStyle(.white.opacity(0.7))
            }
            ForEach(mine) { c in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.other.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        Text(statusLine(c)).font(.caption).foregroundStyle(.white.opacity(0.65))
                    }
                    Spacer()
                    Menu {
                        if c.status == "accepted" {
                            Button("Share my info…") { scopeSheet = .propose(c, direction: "offer") }
                            Button("Ask to see theirs…") { scopeSheet = .propose(c, direction: "request") }
                        }
                        if c.status == "declined" {
                            Button("Send request again") {
                                Task { await model.resend(connection: c, token: appState.authToken) }
                            }
                        }
                        Button("Remove", role: .destructive) {
                            Task { await model.remove(connection: c, token: appState.authToken) }
                        }
                    } label: { Image(systemName: "ellipsis.circle").foregroundStyle(AppTheme.primary) }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func statusLine(_ c: ConnectionItem) -> String {
        switch c.status {
        case "accepted": return c.relationship.capitalized
        case "declined": return "\(c.relationship.capitalized) · declined your request"
        default: return "\(c.relationship.capitalized) · waiting for them to accept"
        }
    }

    // MARK: Who can see my data

    private var ownedSection: some View {
        section("Who can see my data") {
            let shown = model.owned.filter { $0.status == "active" || ($0.status == "pending" && $0.initiatedByMe) || ($0.status == "declined" && $0.initiatedByMe) }
            if shown.isEmpty {
                Text("Nobody. Sharing only starts when you agree.").font(.footnote).foregroundStyle(.white.opacity(0.7))
            }
            ForEach(shown) { s in
                shareRow(s, trailing: AnyView(
                    Menu {
                        if s.status == "active" { Button("Change what is shared") { scopeSheet = .edit(s) } }
                        Button(s.status == "active" ? "Stop sharing" : "Cancel", role: .destructive) {
                            Task { await model.revoke(share: s, token: appState.authToken) }
                        }
                    } label: { Image(systemName: "ellipsis.circle").foregroundStyle(AppTheme.primary) }
                ), note: s.status == "pending" ? "Waiting for them to accept" : (s.status == "declined" ? "They declined" : nil))
            }
        }
    }

    // MARK: Shared with me

    private var viewingSection: some View {
        section("Shared with me") {
            let active = model.viewing.filter { $0.status == "active" }
            let waiting = model.viewing.filter { $0.status != "active" && $0.initiatedByMe }
            if active.isEmpty && waiting.isEmpty {
                Text("Nobody shares with you yet.").font(.footnote).foregroundStyle(.white.opacity(0.7))
            }
            ForEach(active) { s in
                NavigationLink { SharedDataView(share: s).environmentObject(appState) } label: {
                    shareRow(s, trailing: AnyView(Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.5))), note: nil)
                }
            }
            ForEach(waiting) { s in
                shareRow(s, trailing: AnyView(
                    Button("Cancel") { Task { await model.revoke(share: s, token: appState.authToken) } }
                        .font(.caption.weight(.semibold)).foregroundStyle(AppTheme.primary)
                ), note: s.status == "declined" ? "They declined" : "Waiting for them to accept")
            }
        }
    }

    // MARK: Pieces

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline.weight(.bold)).foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 10) { content() }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).glassCard(cornerRadius: 16)
        }
    }

    private func shareRow(_ s: ShareItem, trailing: AnyView, note: String?) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(s.other.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text(note ?? scopeText(s.scopes)).font(.caption).foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            trailing
        }
    }

    private func requestRow(title: String, subtitle: String, acceptTitle: String, declineTitle: String?,
                            onAccept: @escaping () async -> Void, onDecline: @escaping () async -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.7))
            HStack(spacing: 10) {
                Button(acceptTitle) { Task { await onAccept() } }
                    .font(.caption.weight(.bold)).padding(.horizontal, 16).padding(.vertical, 8)
                    .background(AppTheme.primary).foregroundStyle(.black).clipShape(Capsule())
                if let declineTitle {
                    Button(declineTitle) { Task { await onDecline() } }
                        .font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.8))
                }
            }
        }
    }

    private func scopeText(_ scopes: [String]) -> String {
        scopes.compactMap { ShareScope(rawValue: $0)?.title }.joined(separator: ", ")
    }
}

// MARK: - Model

@MainActor
final class SharingModel: ObservableObject {
    @Published var connections: [ConnectionItem] = []
    @Published var owned: [ShareItem] = []
    @Published var viewing: [ShareItem] = []
    @Published var message: String?

    func load(token: String?) async {
        guard let api = BackendAPI(), let token, !token.isEmpty, token != "local-dev-token" else {
            message = "Sign in to connect with family and friends."
            return
        }
        do {
            connections = try await api.connections(token: token)
            let s = try await api.shares(token: token)
            owned = s.owned
            viewing = s.viewing
        } catch {
            message = "Could not load. Pull down to retry."
            appLog("Sharing load failed: \(error.localizedDescription)", level: .warning, category: "Sharing")
        }
    }

    private func run(_ token: String?, _ done: String? = nil, _ work: (BackendAPI, String) async throws -> Void) async {
        guard let api = BackendAPI(), let token, !token.isEmpty else { return }
        do {
            try await work(api, token)
            message = done
            await load(token: token)
        } catch {
            message = "That did not work. Please try again."
            appLog("Sharing action failed: \(error.localizedDescription)", level: .warning, category: "Sharing")
        }
    }

    func respond(connection c: ConnectionItem, accept: Bool, token: String?) async {
        await run(token, accept ? "Connected with \(c.other.name)." : "Declined. \(c.other.name) was told, and you can still change your mind.") {
            try await $0.respondToConnection(id: c.id, accept: accept, token: $1)
        }
    }

    func resend(connection c: ConnectionItem, token: String?) async {
        await run(token, "Request sent again.") { _ = try await $0.connect(email: c.other.email, relationship: c.relationship, token: $1) }
    }

    func remove(connection c: ConnectionItem, token: String?) async {
        await run(token, "Removed. Any sharing with \(c.other.name) has stopped.") { try await $0.removeConnection(id: c.id, token: $1) }
    }

    func respond(share s: ShareItem, accept: Bool, scopes: [String]?, token: String?) async {
        await run(token, accept ? "Sharing is on." : "Declined. \(s.other.name) was told, and you can still change your mind.") {
            try await $0.respondToShare(id: s.id, accept: accept, scopes: scopes, token: $1)
        }
    }

    func revoke(share s: ShareItem, token: String?) async {
        await run(token, "Sharing stopped.") { try await $0.revokeShare(id: s.id, token: $1) }
    }

    func propose(connection c: ConnectionItem, direction: String, scopes: [String], token: String?) async {
        await run(token, "Sent. Nothing is shared until \(c.other.name) accepts.") {
            try await $0.proposeShare(connectionId: c.id, direction: direction, scopes: scopes, token: $1)
        }
    }

    func update(share s: ShareItem, scopes: [String], token: String?) async {
        await run(token, "Updated.") { try await $0.updateShare(id: s.id, scopes: scopes, token: $1) }
    }
}

// MARK: - Sheets

enum ScopeSheetMode: Identifiable {
    case propose(ConnectionItem, direction: String)
    case edit(ShareItem)
    case acceptRequest(ShareItem)

    var id: String {
        switch self {
        case .propose(let c, let d): return "p-\(c.id)-\(d)"
        case .edit(let s): return "e-\(s.id)"
        case .acceptRequest(let s): return "a-\(s.id)"
        }
    }
}

private struct ScopeSheet: View {
    let mode: ScopeSheetMode
    @ObservedObject var model: SharingModel
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []

    private var available: [ShareScope] {
        if case .acceptRequest(let s) = mode { return ShareScope.allCases.filter { s.scopes.contains($0.rawValue) } }
        return ShareScope.allCases
    }

    private var heading: String {
        switch mode {
        case .propose(let c, let d): return d == "offer" ? "Share my info with \(c.other.name)" : "Ask to see \(c.other.name)'s info"
        case .edit(let s): return "What \(s.other.name) can see"
        case .acceptRequest(let s): return "Let \(s.other.name) see"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(heading) {
                    ForEach(available) { scope in
                        Toggle(isOn: Binding(
                            get: { selected.contains(scope.rawValue) },
                            set: { on in if on { selected.insert(scope.rawValue) } else { selected.remove(scope.rawValue) } }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(scope.title)
                                Text(scope.detail).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section { Text("You can stop sharing at any time.").font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle("Sharing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmTitle) {
                        let scopes = ShareScope.allCases.map(\.rawValue).filter(selected.contains)
                        Task {
                            switch mode {
                            case .propose(let c, let d): await model.propose(connection: c, direction: d, scopes: scopes, token: appState.authToken)
                            case .edit(let s): await model.update(share: s, scopes: scopes, token: appState.authToken)
                            case .acceptRequest(let s): await model.respond(share: s, accept: true, scopes: scopes, token: appState.authToken)
                            }
                            dismiss()
                        }
                    }
                    .disabled(selected.isEmpty)
                }
            }
            .onAppear {
                switch mode {
                case .edit(let s), .acceptRequest(let s): selected = Set(s.scopes)
                case .propose: selected = [ShareScope.alerts.rawValue, ShareScope.adherence.rawValue]
                }
            }
        }
    }

    private var confirmTitle: String {
        switch mode {
        case .propose: return "Send"
        case .edit: return "Save"
        case .acceptRequest: return "Accept"
        }
    }
}

private struct AddPersonSheet: View {
    @ObservedObject var model: SharingModel
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var relationship = "friend"
    @State private var notice: String?
    @State private var offerInvite = false
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Who") {
                    TextField("Their email", text: $email)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Picker("They are my", selection: $relationship) {
                        Text("Friend").tag("friend"); Text("Parent").tag("parent"); Text("Child").tag("child")
                        Text("Spouse").tag("spouse"); Text("Sibling").tag("sibling"); Text("Other").tag("other")
                    }
                }
                if let notice { Section { Text(notice).font(.footnote) } }
                if offerInvite {
                    Section {
                        Button("Invite them to Medhavn") {
                            Task {
                                let ok = await appState.sendReferralEmail(email: cleaned, relationship: relationship)
                                notice = ok ? "Invitation sent. You will be connected when they sign up." : "Could not send the invitation."
                                offerInvite = false
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send request") { Task { await send() } }.disabled(busy || !cleaned.contains("@"))
                }
            }
        }
    }

    private var cleaned: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func send() async {
        guard let api = BackendAPI(), let token = appState.authToken else { return }
        busy = true
        defer { busy = false }
        do {
            switch try await api.connect(email: cleaned, relationship: relationship, token: token) {
            case .sent:
                await model.load(token: token)
                dismiss()
            case .notAUser:
                notice = "That person is not on Medhavn yet."
                offerInvite = true
            case .alreadyConnected:
                notice = "You are already connected, or a request is waiting."
            }
        } catch {
            notice = "Could not send the request. Please try again."
        }
    }
}

// MARK: - What someone shared with me

struct SharedDataView: View {
    let share: ShareItem
    @EnvironmentObject private var appState: AppState
    @State private var report: AdherenceReport?
    @State private var meds: [SharedMedication] = []
    @State private var failed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if share.scopes.contains("adherence") || share.scopes.contains("medications") {
                    card("Last 7 days") {
                        if let report {
                            HStack {
                                stat("\(report.rate.map { "\($0)%" } ?? "–")", "taken")
                                stat("\(report.taken)", "doses taken")
                                stat("\(report.missed)", "missed")
                            }
                            ForEach(report.byDay.reversed()) { d in
                                HStack {
                                    Text(d.date).font(.caption).foregroundStyle(.white.opacity(0.7))
                                    Spacer()
                                    Text("\(d.taken) taken · \(d.missed) missed").font(.caption).foregroundStyle(.white)
                                }
                            }
                        } else { ProgressView() }
                    }
                }
                if share.scopes.contains("medications") {
                    card("Medications") {
                        if meds.isEmpty { Text("None listed.").font(.footnote).foregroundStyle(.white.opacity(0.7)) }
                        ForEach(meds) { m in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                Text("\(m.dosage_text) · \(m.remaining_pills) left").font(.caption).foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }
                }
                if share.scopes.contains("alerts") {
                    Text("You also get an email when \(share.other.name) misses a dose.")
                        .font(.footnote).foregroundStyle(.white.opacity(0.7))
                }
                if failed {
                    Text("Could not load. They may have stopped sharing.").font(.footnote).foregroundStyle(.white)
                }
                Text("\(share.other.name) controls this and can stop sharing at any time.")
                    .font(.caption).foregroundStyle(.white.opacity(0.55))
            }
            .padding(16)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background { MeshBackgroundView() }
        .navigationTitle(share.other.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        guard let api = BackendAPI(), let token = appState.authToken else { return }
        do {
            if share.scopes.contains("adherence") || share.scopes.contains("medications") {
                report = try await api.adherence(shareId: share.id, token: token)
            }
            if share.scopes.contains("medications") {
                meds = try await api.sharedMedications(shareId: share.id, token: token)
            }
        } catch {
            failed = true
        }
    }

    private func card<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline.weight(.bold)).foregroundStyle(.white)
            content()
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).glassCard(cornerRadius: 16)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack {
            Text(value).font(.title3.weight(.bold)).foregroundStyle(AppTheme.primary)
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}
