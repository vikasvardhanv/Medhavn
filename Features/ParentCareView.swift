import SwiftUI

struct ParentCareView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showAddParent = false

    var body: some View {
        ZStack {
            MeshBackgroundView()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    overviewCard

                    if appState.linkedParentProfiles.isEmpty {
                        emptyState
                    } else {
                        ForEach(appState.linkedParentProfiles) { parent in
                            parentCard(parent)
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Parent Care")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddParent = true
                } label: {
                    Image(systemName: "person.badge.plus")
                        .foregroundStyle(AppTheme.primary)
                }
            }
        }
        .sheet(isPresented: $showAddParent) {
            AddLinkedParentView()
                .environmentObject(appState)
        }
        .onAppear {
            appState.checkForMissedDoses()
        }
    }

    private var overviewCard: some View {
        let unresolved = appState.unresolvedParentMissedDoseAlerts()
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.info.opacity(0.16))
                    .frame(width: 52, height: 52)
                Image(systemName: "figure.2.and.child.holdinghands")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.info)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Linked parent tablet care")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text("\(appState.linkedParentProfiles.count) parent profiles · \(unresolved.count) needs buzz")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()
        }
        .padding(18)
        .glassCard(cornerRadius: 18)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.2.badge.gearshape")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.primary)

            Text("Add a parent profile")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Text("Create a linked profile for a parent, then add their tablets from DoseMap. Their schedule appears here and missed doses can be buzzed.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            Button {
                showAddParent = true
            } label: {
                Text("Add Parent")
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 11)
                    .background(AppTheme.primary)
                    .foregroundStyle(.black)
                    .clipShape(Capsule())
            }
        }
        .padding(24)
        .glassCard(cornerRadius: 18)
    }

    private func parentCard(_ parent: LinkedParentProfile) -> some View {
        let items = appState.items(forProfileID: parent.profileID)
        let alerts = appState.parentAlerts(for: parent)
        let unresolved = appState.unresolvedParentMissedDoseAlerts(for: parent)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.primary.opacity(0.16))
                        .frame(width: 44, height: 44)
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .foregroundStyle(AppTheme.primary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(parent.displayName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text("\(parent.relationship) · \(parent.status.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }

                Spacer()

                Text(parent.linkCode)
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.primary)
                    .clipShape(Capsule())
            }

            Divider().opacity(0.1)

            if unresolved.isEmpty {
                Label("No missed tablets waiting for a buzz", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.success)
            } else {
                ForEach(unresolved.prefix(3)) { alert in
                    missedAlertRow(alert, parent: parent)
                }
            }

            if items.isEmpty {
                Text("No tablets are scheduled for this parent yet. Switch to \(parent.displayName)'s profile in DoseMap to add medication.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 6)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's Schedule")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.primary)

                    ForEach(DayTimeBlock.allCases.sorted(by: { $0.sortIndex < $1.sortIndex })) { block in
                        let blockItems = appState.items(forProfileID: parent.profileID, block: block, on: Date())
                        if !blockItems.isEmpty {
                            scheduleRow(block: block, items: blockItems)
                        }
                    }
                }
            }

            if let last = alerts.first {
                Text("Latest alert: \(last.medicationName) · \(last.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
    }

    private func missedAlertRow(_ alert: ParentMedicationAlert, parent: LinkedParentProfile) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .foregroundStyle(AppTheme.warning)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.medicationName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Missed \(alert.scheduledBlock.title.lowercased()) dose on \(alert.scheduledDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }

            Spacer()

            Button {
                appState.sendBuzz(for: alert.id)
            } label: {
                Label("Buzz", systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(AppTheme.warning)
                    .foregroundStyle(.black)
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func scheduleRow(block: DayTimeBlock, items: [MedCabinetItem]) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(block.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 74, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                ForEach(items) { item in
                    Text("\(item.name) · \(item.dosageText)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct AddLinkedParentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var relationship = "Parent"
    @State private var birthYear = 1965
    @State private var parentAppUserID = ""

    private let relationships = ["Parent", "Mother", "Father", "In-law", "Guardian"]
    private let years = Array((1924...Calendar.current.component(.year, from: Date())).reversed())

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackgroundView()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Parent Profile")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.primary)

                            TextField("First Name", text: $firstName)
                                .padding(12)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            TextField("Last Name", text: $lastName)
                                .padding(12)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            Picker("Relationship", selection: $relationship) {
                                ForEach(relationships, id: \.self) { value in
                                    Text(value).tag(value)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(AppTheme.primary)

                            Picker("Birth Year", selection: $birthYear) {
                                ForEach(years, id: \.self) { year in
                                    Text(String(year)).tag(year)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(AppTheme.primary)
                        }
                        .padding(16)
                        .glassCard(cornerRadius: 16)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Parent App Link")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.primary)

                            TextField("Parent app user ID or phone", text: $parentAppUserID)
                                .textInputAutocapitalization(.never)
                                .padding(12)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            Text("Leave blank to create a pending link code.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(16)
                        .glassCard(cornerRadius: 16)

                        Button {
                            appState.addLinkedParent(
                                firstName: firstName,
                                lastName: lastName,
                                relationship: relationship,
                                birthYear: birthYear,
                                parentAppUserID: parentAppUserID
                            )
                            dismiss()
                        } label: {
                            Text("Save Parent")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.primary)
                                .foregroundStyle(.black)
                                .clipShape(Capsule())
                        }
                        .disabled(firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Add Parent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
}
