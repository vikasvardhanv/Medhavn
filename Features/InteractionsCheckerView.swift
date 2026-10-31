import SwiftUI

struct InteractionsCheckerView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query = ""
    @State private var results: [DrugInteractionRecord] = []
    @State private var selectedRecord: DrugInteractionRecord? = nil
    @State private var registrySuggestions: [String] = []
    @State private var isSearchingRegistry = false
    @State private var registryTask: Task<Void, Never>?
    private let drugLookupService = DrugLookupService()

    private func badgeColor(_ s: InteractionSeverity) -> Color {
        switch s {
        case .mild: return AppTheme.success
        case .moderate: return AppTheme.warning
        case .severe: return AppTheme.danger
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            MeshBackgroundView()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom styled Search Card
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: isSearchingRegistry ? "arrow.triangle.2.circlepath" : "magnifyingglass")
                            .foregroundStyle(isSearchingRegistry ? AppTheme.primary : .white.opacity(0.5))
                            .animation(.easeInOut(duration: 0.2), value: isSearchingRegistry)

                        TextField("Enter medication name...", text: $query)
                            .submitLabel(.search)
                            .foregroundStyle(.white)
                            .onSubmit {
                                results = appState.checkInteractions(for: query)
                                registrySuggestions = []
                            }
                            .onChange(of: query) { _, newValue in
                                fetchRegistrySuggestions(for: newValue)
                            }

                        if !query.isEmpty {
                            Button {
                                query = ""
                                results = []
                                registrySuggestions = []
                                registryTask?.cancel()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )

                    // Live registry suggestions
                    if !registrySuggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("From medical registry:")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.5))

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(registrySuggestions, id: \.self) { name in
                                        Button {
                                            query = name
                                            results = appState.checkInteractions(for: name)
                                            registrySuggestions = []
                                        } label: {
                                            Text(name)
                                                .font(.caption.weight(.bold))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(AppTheme.primary.opacity(0.15))
                                                .foregroundStyle(AppTheme.primary)
                                                .clipShape(Capsule())
                                                .overlay(Capsule().stroke(AppTheme.primary.opacity(0.25), lineWidth: 1))
                                        }
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(.top, 4)
                    }

                    // Quick check from cabinet
                    if !appState.itemsForSelectedProfile().isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Quick check:")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(appState.itemsForSelectedProfile().prefix(8)) { item in
                                        Button {
                                            query = item.name
                                            results = appState.checkInteractions(for: item.name)
                                            registrySuggestions = []
                                        } label: {
                                            Text(item.name)
                                                .font(.caption.weight(.bold))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(AppTheme.primary.opacity(0.12))
                                                .foregroundStyle(.white)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(16)
                .glassCard(cornerRadius: 16)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // Content area
                if results.isEmpty && !query.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(AppTheme.success)
                        Text("No interactions found")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                        Text("No known interactions detected for \"\(query)\".")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .glassCard(cornerRadius: 16)
                    .padding(.horizontal, 16)
                    .padding(.top, 40)
                    Spacer()
                } else if results.isEmpty && query.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 48))
                            .foregroundStyle(AppTheme.primary)
                        Text("Drug-Drug Safety Check")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                        Text("Type a drug name or select a quick check medication above to search for clinical contraindications.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .glassCard(cornerRadius: 16)
                    .padding(.horizontal, 16)
                    .padding(.top, 40)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(results) { r in
                                Button {
                                    selectedRecord = r
                                } label: {
                                    HStack(spacing: 16) {
                                        ZStack {
                                            Circle()
                                                .fill(badgeColor(r.severity).opacity(0.12))
                                                .frame(width: 44, height: 44)
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundStyle(badgeColor(r.severity))
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(r.severity.rawValue.uppercased())
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(badgeColor(r.severity))
                                            
                                            Text("\(r.drug1) + \(r.drug2)")
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(.white)
                                                .multilineTextAlignment(.leading)
                                            
                                            Text(r.detail)
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.7))
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                    .padding(14)
                                    .glassCard(cornerRadius: 14)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 80)
                    }
                }
                
                // Disclaimer footer
                VStack(spacing: 8) {
                    Text("Always consult your pharmacist or doctor.")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.danger)
                    Text("Information here does not replace professional medical advice.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .padding(.top, 12)
                .background(.ultraThinMaterial)
            }
        }
        .navigationTitle("Safety Checker")
        .sheet(item: $selectedRecord) { r in
            InteractionDetailView(record: r)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    InteractionsCitationsView()
                } label: {
                    Label("Sources", systemImage: "info.circle")
                        .foregroundStyle(AppTheme.primary)
                }
            }
        }
    }

    private func fetchRegistrySuggestions(for text: String) {
        registryTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            registrySuggestions = []
            isSearchingRegistry = false
            return
        }
        registryTask = Task {
            isSearchingRegistry = true
            try? await Task.sleep(nanoseconds: 280_000_000) // 280ms debounce
            guard !Task.isCancelled else { return }
            let names = (try? await drugLookupService.searchMedicationNames(query: trimmed, limit: 10, token: appState.authToken)) ?? []
            guard !Task.isCancelled else { return }
            await MainActor.run {
                registrySuggestions = names
                isSearchingRegistry = false
                if !trimmed.isEmpty {
                    results = appState.checkInteractions(for: trimmed)
                }
            }
        }
    }
}

struct InteractionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let record: DrugInteractionRecord

    private var severityColor: Color {
        switch record.severity {
        case .mild: return AppTheme.success
        case .moderate: return AppTheme.warning
        case .severe: return AppTheme.danger
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackgroundView()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header info
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(severityColor.opacity(0.12))
                                    .frame(width: 64, height: 64)
                                Image(systemName: "exclamationmark.shield.fill")
                                    .font(.title)
                                    .foregroundStyle(severityColor)
                            }
                            
                            Text(record.severity.rawValue.uppercased())
                                .font(.headline.weight(.bold))
                                .foregroundStyle(severityColor)
                            
                            Text("\(record.drug1) + \(record.drug2)")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .glassCard(cornerRadius: 16)
                        
                        // Detail text
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Clinical Contraindication Details")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                            Text(record.detail)
                                .font(.body)
                                .lineSpacing(6)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(20)
                        .glassCard(cornerRadius: 16)
                        
                        // Sources & actions
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Data Sources & Warnings")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                            
                            Text("Always consult your doctor for a complete review of possible interactions. Do not adjust doses on your own.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                            
                            Divider()
                                .opacity(0.1)
                            
                            Link(destination: URL(string: "https://go.drugbank.com/drugs")!) {
                                HStack {
                                    Label("DrugBank Open Data", systemImage: "link")
                                    Spacer()
                                    Text("drugbank.ca")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            
                            Link(destination: URL(string: "https://www.fda.gov/drugs/drug-interactions-labeling/drug-interactions-what-you-should-know")!) {
                                HStack {
                                    Label("FDA Drug Interactions Guide", systemImage: "link")
                                    Spacer()
                                    Text("fda.gov")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            
                            Link(destination: URL(string: "https://dailymed.nlm.nih.gov/dailymed/")!) {
                                HStack {
                                    Label("NIH DailyMed Drug Labels", systemImage: "link")
                                    Spacer()
                                    Text("dailymed.nlm.nih.gov")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        }
                        .padding(20)
                        .glassCard(cornerRadius: 16)
                        .padding(.bottom, 20)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Contraindication Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

struct InteractionsCitationsView: View {
    var body: some View {
        ZStack {
            MeshBackgroundView()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Verification Standards")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                        
                        Text("Medhavn parses safety and interaction data using standard FDA product label tags and clinical indexes. Reference materials are drawn from the following authoritative directories:")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineSpacing(4)
                    }
                    .padding(20)
                    .glassCard(cornerRadius: 16)
                    
                    citationCard(
                        title: "DrugBank Open Data",
                        description: "Comprehensive drug chemical, clinical, and interaction database used for severity classification.",
                        url: URL(string: "https://go.drugbank.com/drugs")!,
                        domain: "drugbank.ca"
                    )
                    
                    citationCard(
                        title: "FDA Drug Interactions",
                        description: "Official Food and Drug Administration guidance for clinical drug-drug interactions and labeling requirements.",
                        url: URL(string: "https://www.fda.gov/drugs/drug-interactions-labeling/drug-interactions-what-you-should-know")!,
                        domain: "fda.gov"
                    )
                    
                    citationCard(
                        title: "NIH DailyMed",
                        description: "Official FDA label information database published for providers and patients by the National Library of Medicine.",
                        url: URL(string: "https://dailymed.nlm.nih.gov/dailymed/")!,
                        domain: "dailymed.nlm.nih.gov"
                    )
                    
                    VStack(spacing: 10) {
                        Text("Disclaimer")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.danger)
                        Text("This safety checker provides information for reference purposes only and does not cover all possible clinical cases. Always consult your prescribing physician before altering your medication regimens.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(20)
                    .glassCard(cornerRadius: 16)
                    .padding(.bottom, 20)
                }
                .padding(16)
            }
        }
        .navigationTitle("Data Sources")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func citationCard(title: String, description: String, url: URL, domain: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
            Text(description)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .lineSpacing(3)
            
            Divider()
                .opacity(0.1)
            
            Link(destination: url) {
                HStack {
                    Label("Visit Official Database", systemImage: "arrow.up.right.square")
                    Spacer()
                    Text(domain)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 14)
    }
}
