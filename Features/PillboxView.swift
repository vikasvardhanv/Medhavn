import SwiftUI
import MedicationLogicEngine

struct PillboxView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var showWizard = false
    @State private var showDateNavigator = false

    init() {}

    private var dailyScore: (taken: Int, total: Int) {
        let selectedDate = appState.selectedPillboxDate
        var totalTablets = 0
        var takenTablets = 0
        for block in DayTimeBlock.allCases {
            let blockItems = appState.items(for: block, on: selectedDate)
            for item in blockItems {
                totalTablets += 1
                let status = appState.statusForDose(itemID: item.id, block: block, date: selectedDate)
                if status == .taken {
                    takenTablets += 1
                }
            }
        }
        return (takenTablets, totalTablets)
    }

    var body: some View {
        let isRegular = hSizeClass == .regular
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: 16, alignment: .top),
            count: isRegular ? 2 : 1
        )
        
        let score = dailyScore

        ScrollView {
            VStack(spacing: 24) {
                // Top bar: profile picker + compact score
                headerBar(score: score)
                    .staggeredEntrance(delay: 0.0)

                if let profile = appState.selectedProfile {
                    Text("Welcome, \(profile.name)")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("Welcome, \(profile.name)")
                        .staggeredEntrance(delay: 0.03)
                }

                dateNavigator
                    .staggeredEntrance(delay: 0.06)

                LazyVGrid(columns: columns, spacing: 24) {
                    let blocks = DayTimeBlock.allCases.sorted(by: { $0.sortIndex < $1.sortIndex })
                    ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                        timeBlockSection(block)
                            .staggeredEntrance(delay: 0.24 + Double(index) * 0.08)
                    }
                }
                
                Button {
                    showWizard = true
                } label: {
                    HStack {
                        Text("New supplement")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(Color.black)
                        
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 28, height: 28)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppTheme.primary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(AppTheme.primary)
                    .clipShape(Capsule())
                    .shadow(color: AppTheme.primary.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .padding(.top, 12)
                .staggeredEntrance(delay: 0.5)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, isRegular ? 24 : 16)
            .padding(.top, isRegular ? 20 : 12)
            .padding(.bottom, 32)
        }
        .background { MeshBackgroundView() }
        .navigationBarHidden(true)
        .sheet(isPresented: $showWizard) {
            NavigationStack {
                AddMedicationWizardView()
                    .environmentObject(appState)
            }
        }
        .onAppear {
            appState.checkForMissedDoses()
        }
    }

    @ViewBuilder
    private func timeBlockSection(_ block: DayTimeBlock) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Spacer()
                Image(systemName: timeBlockIcon(for: block))
                    .foregroundStyle(AppTheme.primary)
                    .font(.system(size: 14, weight: .bold))
                
                Text(block.title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.vertical, 8)

            let items = appState.items(for: block, on: appState.selectedPillboxDate)
            if items.isEmpty {
                HStack {
                    Spacer()
                    Text("No medications scheduled")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(AppTheme.cardBackground.opacity(0.5))
                )
            } else {
                ForEach(items) { item in
                    MedicationCardView(item: item, block: block)
                        .environmentObject(appState)
                }
            }
        }
    }

    private func timeBlockIcon(for block: DayTimeBlock) -> String {
        switch block {
        case .morning: return "sun.and.horizon.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }

    private func headerBar(score: (taken: Int, total: Int)) -> some View {
        HStack {
            // "You" button — tap to switch profiles
            Menu {
                ForEach(appState.profiles) { profile in
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            appState.selectProfile(profile.id)
                        }
                    } label: {
                        HStack {
                            Image(systemName: profile.avatarSymbol)
                            Text(profile.name)
                            if appState.selectedProfileID == profile.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: appState.selectedProfile?.avatarSymbol ?? "person.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(appState.selectedProfile?.name ?? "You")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.cardBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            }
            .accessibilityLabel("Switch profile")

            Spacer()

            // Compact supplement score badge
            CompactScoreBadge(taken: score.taken, total: score.total)
        }
    }

    private func complianceDotColor(for date: Date) -> Color {
        let blocks = DayTimeBlock.allCases
        var total = 0
        var taken = 0
        var skipped = 0
        for block in blocks {
            let items = appState.items(for: block, on: date)
            for item in items {
                total += 1
                let status = appState.statusForDose(itemID: item.id, block: block, date: date)
                if status == .taken {
                    taken += 1
                } else if status == .skipped {
                    skipped += 1
                }
            }
        }
        if total == 0 {
            return Color.clear
        } else if taken == total {
            return AppTheme.success
        } else if taken + skipped == total {
            return AppTheme.warning
        } else {
            return Color.secondary.opacity(0.5)
        }
    }

    private var dateNavigator: some View {
        VStack(spacing: 16) {
            HStack {
                Menu {
                    Button {
                        withAnimation {
                            appState.selectedPillboxDate = Date()
                            appState.checkForMissedDoses()
                        }
                    } label: {
                        Label("Go to Today", systemImage: "arrow.uturn.backward")
                    }
                    
                    Divider()
                    
                    Button {
                        withAnimation { appState.shiftPillboxDate(by: -30) }
                    } label: {
                        Label("Go Back 1 Month", systemImage: "chevron.left.2")
                    }
                    
                    Button {
                        withAnimation { appState.shiftPillboxDate(by: 30) }
                    } label: {
                        Label("Go Forward 1 Month", systemImage: "chevron.right.2")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(appState.selectedPillboxDate.formatted(date: .complete, time: .omitted))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                        
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.primary)
                    }
                }
                
                Spacer()
                
                DatePicker(
                    "Jump",
                    selection: $appState.selectedPillboxDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(AppTheme.primary)
            }
            
            let stripItems = makeDateStripItems(anchor: appState.selectedPillboxDate, range: -15...15)
            
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .center, spacing: 10) {
                        ForEach(stripItems) { item in
                            switch item.kind {
                            case .separator(let label):
                                Text(label)
                                    .font(.system(.caption2, design: .rounded).weight(.bold))
                                    .foregroundStyle(AppTheme.primary)
                                    .lineLimit(1)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 10)
                                    .background(AppTheme.primary.opacity(0.12))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(AppTheme.primary.opacity(0.2), lineWidth: 1)
                                    )
                                
                            case .day(let dayOffset, let date):
                                let isSelected = Calendar.current.isDate(date, inSameDayAs: appState.selectedPillboxDate)
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                                        appState.selectedPillboxDate = date
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        Text(date.formatted(.dateTime.weekday(.abbreviated)))
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(isSelected ? Color.black.opacity(0.8) : Color.secondary)
                                            .textCase(.uppercase)
                                        
                                        Text(date.formatted(.dateTime.day()))
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundStyle(isSelected ? Color.black : Color.white)
                                        
                                        let dotColor = complianceDotColor(for: date)
                                        Circle()
                                            .fill(dotColor)
                                            .frame(width: 5, height: 5)
                                            .shadow(color: dotColor.opacity(0.5), radius: 2)
                                    }
                                    .frame(width: 48, height: 68)
                                    .background(
                                        ZStack {
                                            if isSelected {
                                                AppTheme.primary
                                                    .transition(.scale.combined(with: .opacity))
                                            } else {
                                                Color.white.opacity(0.04)
                                            }
                                        }
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(isSelected ? Color.clear : Color.white.opacity(0.08), lineWidth: 1)
                                    )
                                    .shadow(color: isSelected ? AppTheme.primary.opacity(0.3) : Color.clear, radius: 6, x: 0, y: 3)
                                }
                                .id(dayOffset)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .onAppear {
                        proxy.scrollTo(0, anchor: .center)
                    }
                    .onChange(of: appState.selectedPillboxDate) { _, _ in
                        withAnimation {
                            proxy.scrollTo(0, anchor: .center)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Compact Score Badge (top-right corner)

struct CompactScoreBadge: View {
    let taken: Int
    let total: Int

    var progress: Double {
        total > 0 ? Double(taken) / Double(total) : 0.0
    }

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 3)
                    .frame(width: 28, height: 28)

                Circle()
                    .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                    .stroke(
                        LinearGradient(
                            colors: [AppTheme.primary, AppTheme.primary.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 28, height: 28)
                    .rotationEffect(Angle(degrees: -90))

                Text("\(taken)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text("of \(total)")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AppTheme.cardBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}



// MARK: - Medication Card Component
struct MedicationCardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showDeleteConfirm = false

    let item: MedCabinetItem
    let block: DayTimeBlock

    init(item: MedCabinetItem, block: DayTimeBlock) {
        self.item = item
        self.block = block
    }

    private func scheduledTimeString(for item: MedCabinetItem, block: DayTimeBlock) -> String {
        let timesForBlock = item.scheduledTimes.filter { t in
            switch t.hour {
            case 5..<12: return block == .morning
            case 12..<17: return block == .afternoon
            case 17..<21: return block == .evening
            default: return block == .night
            }
        }
        if let first = timesForBlock.first {
            return first.displayString
        }
        switch block {
        case .morning: return "9:00 AM"
        case .afternoon: return "1:00 PM"
        case .evening: return "7:00 PM"
        case .night: return "10:00 PM"
        }
    }

    var body: some View {
        let status = appState.statusForDose(itemID: item.id, block: block, date: appState.selectedPillboxDate)

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                PillVisual(shape: item.pillShape, colorHex: item.pillColorHex)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                    
                    Text("Dose: \(item.dosageText)")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondary)
                    
                    if !item.contraindicationTags.isEmpty {
                        Text("Features: \(item.contraindicationTags.joined(separator: ", "))")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.secondary)
                    }
                }
                Spacer()
                
                Menu {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            appState.markDose(itemID: item.id, block: block, date: appState.selectedPillboxDate, status: .taken)
                        }
                    } label: {
                        Label("Mark as Taken", systemImage: "checkmark.circle")
                    }
                    
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            appState.markDose(itemID: item.id, block: block, date: appState.selectedPillboxDate, status: .skipped)
                        }
                    } label: {
                        Label("Mark as Skipped", systemImage: "xmark.circle")
                    }
                    
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            appState.markDose(itemID: item.id, block: block, date: appState.selectedPillboxDate, status: .pending)
                        }
                    } label: {
                        Label("Mark as Pending", systemImage: "questionmark.circle")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Medication", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.secondary)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Options for \(item.name)")
            }

            Divider()
                .background(Color.white.opacity(0.08))

            HStack {
                let timeStr = scheduledTimeString(for: item, block: block)
                let isMissed = appState.selectedPillboxDate < Calendar.current.startOfDay(for: Date()) && status != .taken
                
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text("To take: at \(timeStr)")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(isMissed ? AppTheme.danger : AppTheme.secondary)
                
                Spacer()
                
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        if status == .taken {
                            appState.markDose(itemID: item.id, block: block, date: appState.selectedPillboxDate, status: .pending)
                        } else {
                            appState.markDose(itemID: item.id, block: block, date: appState.selectedPillboxDate, status: .taken)
                        }
                    }
                } label: {
                    ZStack {
                        if status == .taken {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 26, height: 26)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.black)
                        } else {
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                .frame(width: 26, height: 26)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .glassCard()
        .alert("Remove this medication?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                appState.removeMedCabinetItem(id: item.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes \(item.name) from DoseMap and Vault.")
        }
    }
}

// MARK: - Pill Visual
struct PillVisual: View {
    let shape: PillShapeStyle
    let colorHex: String

    init(shape: PillShapeStyle, colorHex: String) {
        self.shape = shape
        self.colorHex = colorHex
    }

    var body: some View {
        let baseColor = Color(hex: colorHex) ?? AppTheme.primary
        let highlightGradient = LinearGradient(
            colors: [.white.opacity(0.45), .white.opacity(0.0)],
            startPoint: .top,
            endPoint: .bottom
        )
        let pillGradient = LinearGradient(
            colors: [
                baseColor.opacity(1.0),
                baseColor.opacity(0.85),
                baseColor.opacity(0.7)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        ZStack {
            Group {
                switch shape {
                case .capsule:
                    Capsule()
                        .fill(pillGradient)
                case .round:
                    Circle()
                        .fill(pillGradient)
                case .oval:
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(pillGradient)
                case .tablet:
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(pillGradient)
                }
            }
            
            Group {
                switch shape {
                case .capsule:
                    Rectangle()
                        .fill(Color.black.opacity(0.12))
                        .frame(width: 1.5)
                        .padding(.vertical, 1)
                        .overlay(
                            Rectangle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 0.8)
                                .offset(x: -0.5)
                        )
                case .round:
                    Rectangle()
                        .fill(Color.black.opacity(0.15))
                        .frame(width: 1)
                        .padding(.vertical, 2)
                case .oval:
                    Rectangle()
                        .fill(Color.black.opacity(0.12))
                        .frame(width: 1)
                        .padding(.vertical, 3)
                case .tablet:
                    Rectangle()
                        .fill(Color.black.opacity(0.15))
                        .frame(width: 1)
                        .padding(.vertical, 2)
                }
            }
            
            Group {
                switch shape {
                case .capsule:
                    Capsule()
                        .fill(highlightGradient)
                        .frame(height: 10)
                        .padding(.horizontal, 2)
                        .offset(y: -5)
                case .round:
                    Circle()
                        .fill(highlightGradient)
                        .frame(height: 10)
                        .padding(.horizontal, 2)
                        .offset(y: -5)
                case .oval:
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(highlightGradient)
                        .frame(height: 10)
                        .padding(.horizontal, 2)
                        .offset(y: -5)
                case .tablet:
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(highlightGradient)
                        .frame(height: 10)
                        .padding(.horizontal, 2)
                        .offset(y: -5)
                }
            }
        }
        .frame(width: 38, height: 26)
        .overlay(
            Group {
                switch shape {
                case .capsule:
                    Capsule().stroke(.white.opacity(0.28), lineWidth: 1)
                case .round:
                    Circle().stroke(.white.opacity(0.28), lineWidth: 1)
                case .oval:
                    RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.28), lineWidth: 1)
                case .tablet:
                    RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.white.opacity(0.28), lineWidth: 1)
                }
            }
        )
        .shadow(color: baseColor.opacity(0.35), radius: 5, x: 0, y: 3)
        .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Date strip helpers
private enum DateStripKind {
    case day(Int, Date)
    case separator(String)
}

private struct DateStripItem: Identifiable {
    let id: String
    let kind: DateStripKind
}

private func makeDateStripItems(anchor: Date, range: ClosedRange<Int>) -> [DateStripItem] {
    let cal = Calendar.current
    var items: [DateStripItem] = []
    var prevMonth: Int? = nil
    var prevYear: Int? = nil

    for offset in range {
        guard let date = cal.date(byAdding: .day, value: offset, to: anchor) else { continue }
        let month = cal.component(.month, from: date)
        let year = cal.component(.year, from: date)

        if month != prevMonth || year != prevYear {
            let label = date.formatted(.dateTime.month(.abbreviated).year(.twoDigits))
            items.append(DateStripItem(id: "sep-\(year)-\(month)", kind: .separator(label)))
            prevMonth = month
            prevYear = year
        }

        items.append(DateStripItem(id: "day-\(offset)", kind: .day(offset, date)))
    }
    return items
}
