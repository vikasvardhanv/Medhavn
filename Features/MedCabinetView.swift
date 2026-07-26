import SwiftUI
import MedicationLogicEngine

public struct MedCabinetView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showWizard = false
    @State private var showDeleteConfirm = false
    @State private var selectedItemToDelete: MedCabinetItem? = nil
    @State private var isRefilling = false
    @State private var showRefillAlert = false
    @State private var refillAlertMessage = ""

    public init() {}

    public var body: some View {
        let items = appState.itemsForSelectedProfile()
        let lowSupplyCount = items.filter { $0.remainingPills <= $0.refillThreshold }.count

        ScrollView {
            VStack(spacing: 24) {
                // Connected Pharmacy Integration Widget
                pharmacyIntegrationCard
                    .staggeredEntrance(delay: 0.0)

                // Summary Widgets at the Top
                if !items.isEmpty {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Active Meds")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(AppTheme.secondary)
                            Text("\(items.count)")
                                .font(.system(.title, design: .rounded).weight(.bold))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .glassCard()

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Refills Needed")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(AppTheme.secondary)
                            Text("\(lowSupplyCount)")
                                .font(.system(.title, design: .rounded).weight(.bold))
                                .foregroundStyle(lowSupplyCount > 0 ? AppTheme.danger : .white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .glassCard()
                    }
                    .padding(.horizontal, 4)
                    .staggeredEntrance(delay: 0.05)
                }

                if items.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "pills.fill")
                            .font(.system(size: 54))
                            .foregroundStyle(AppTheme.secondary)
                            .padding(.bottom, 8)
                        
                        Text("Your Pharmacy Cabinet is empty")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        
                        Text("Securely store and track inventory for all your medications in one place.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        
                        Button {
                            showWizard = true
                        } label: {
                            Text("Add Medication")
                                .font(.subheadline.weight(.bold))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.primary)
                        .shadow(color: AppTheme.primary.opacity(0.2), radius: 6, x: 0, y: 3)
                    }
                    .frame(maxWidth: .infinity, minHeight: 320)
                    .padding(24)
                    .glassCard()
                    .padding(.horizontal, 4)
                    .staggeredEntrance(delay: 0.1)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            medCabinetRow(item: item)
                                .staggeredEntrance(delay: 0.1 + Double(index) * 0.05)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background { MeshBackgroundView() }
        .navigationTitle("Pharmacy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showWizard = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(AppTheme.primary)
            }
        }
        .sheet(isPresented: $showWizard) {
            NavigationStack {
                AddMedicationWizardView()
                    .environmentObject(appState)
            }
        }
        .alert("Remove this medication?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let item = selectedItemToDelete {
                    withAnimation {
                        appState.removeMedCabinetItem(id: item.id)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let item = selectedItemToDelete {
                Text("This removes \(item.name) from Home and Pharmacy.")
            } else {
                Text("Are you sure you want to delete this medication?")
            }
        }
        .alert("Pharmacy Refill", isPresented: $showRefillAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(refillAlertMessage)
        }
    }

    private var pharmacyIntegrationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accentTeal.opacity(0.16))
                        .frame(width: 44, height: 44)
                    Image(systemName: "cross.case.fill")
                        .foregroundStyle(AppTheme.accentTeal)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("CVS Pharmacy Connected")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Prescriptions linked & auto-refills enabled")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }
                
                Spacer()

                Text("Active")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.success)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .glassCard()
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func medCabinetRow(item: MedCabinetItem) -> some View {
        let isLowSupply = item.remainingPills <= item.refillThreshold
        
        HStack(spacing: 16) {
            PillVisual(shape: item.pillShape, colorHex: item.pillColorHex)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                
                Text(item.dosageText)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.secondary)
                
                HStack(spacing: 8) {
                    Text("Remaining: \(item.remainingPills) pills")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isLowSupply ? AppTheme.danger : AppTheme.secondary)
                    
                    if isLowSupply {
                        Text("Low Stock")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.danger)
                            .clipShape(Capsule())
                    }
                }
            }
            Spacer()
            
            if isLowSupply {
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    isRefilling = true
                    // Simulate refill order sending to connected pharmacy
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        isRefilling = false
                        appState.refillMedCabinetItem(id: item.id, amount: 30)
                        refillAlertMessage = "Refill request for \(item.name) has been sent to CVS. Your new stock of 30 pills has been added."
                        showRefillAlert = true
                    }
                } label: {
                    if isRefilling {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 10)
                    } else {
                        Text("Refill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.primary)
                            .clipShape(Capsule())
                    }
                }
                .buttonStyle(.plain)
            }

            Menu {
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    withAnimation {
                        appState.refillMedCabinetItem(id: item.id, amount: 30)
                    }
                } label: {
                    Label("Manual Refill (+30)", systemImage: "plus.circle")
                }
                
                Button(role: .destructive) {
                    selectedItemToDelete = item
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
        }
        .padding(18)
        .glassCard()
    }
}
