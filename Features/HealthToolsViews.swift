import SwiftUI

// MARK: - Measurements List View
struct MeasurementsListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showLog = false
    @State private var logType: HealthMetricType = .bloodPressure

    private var sections: [(String, [HealthMetricType])] { allSections.filter { appState.showsFertility || $0.0 != "REPRODUCTIVE HEALTH" } }

    private let allSections: [(String, [HealthMetricType])] = [
        ("GENERAL", [.painLevel, .peakFlow, .spO2]),
        ("REPRODUCTIVE HEALTH", [.basalBodyTemp, .cervicalMucus, .ovulationTest, .sexualActivity, .spotting]),
        ("VITALS", [.bloodPressure, .pulse, .temperature]),
        ("METABOLIC", [.glucose, .weight])
    ]

    var body: some View {
        ZStack {
            MeshBackgroundView()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(sections, id: \.0) { title, types in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(title)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.primary)
                                .padding(.horizontal, 4)
                            
                            VStack(spacing: 0) {
                                ForEach(Array(types.enumerated()), id: \.offset) { idx, metric in
                                    Button {
                                        logType = metric
                                        showLog = true
                                    } label: {
                                        HStack(spacing: 14) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(AppTheme.primary.opacity(0.12))
                                                    .frame(width: 36, height: 36)
                                                Image(systemName: metric.sfSymbol)
                                                    .foregroundStyle(.black)
                                                    .font(.system(size: 16))
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(metric.rawValue)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(.white)
                                                
                                                if let last = appState.healthMetrics.first(where: { $0.type == metric }) {
                                                    Text("\(last.value) \(last.unit) · \(last.timestamp.formatted(date: .abbreviated, time: .omitted))")
                                                        .font(.caption)
                                                        .foregroundStyle(.white.opacity(0.7))
                                                } else {
                                                    Text("No data logged")
                                                        .font(.caption)
                                                        .foregroundStyle(.white.opacity(0.5))
                                                }
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.white.opacity(0.5))
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 14)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    if idx < types.count - 1 {
                                        Divider()
                                            .padding(.leading, 64)
                                            .opacity(0.1)
                                    }
                                }
                            }
                            .glassCard(cornerRadius: 16)
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Health Measurements")
        .sheet(isPresented: $showLog) {
            LogMeasurementView(metricType: logType)
                .environmentObject(appState)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    MeasurementsCitationsView()
                } label: {
                    Label("Sources", systemImage: "info.circle")
                        .foregroundStyle(AppTheme.primary)
                }
            }
        }
    }
}

// MARK: - Measurements Citations View
struct MeasurementsCitationsView: View {
    var body: some View {
        ZStack {
            MeshBackgroundView()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Clinical Reference Guidelines")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.primary)
                        
                        Text("All clinical normal ranges and unit specifications mapped inside Medhavn conform to verified global database standards:")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineSpacing(4)
                    }
                    .padding(20)
                    .glassCard(cornerRadius: 16)
                    
                    citationCard(
                        title: "WHO BMI Classification",
                        description: "World Health Organization reference classifications for Body Mass Index (BMI) and metabolic status.",
                        url: URL(string: "https://www.who.int/news-room/fact-sheets/detail/obesity-and-overweight")!,
                        domain: "who.int"
                    )
                    
                    citationCard(
                        title: "NIH Blood Pressure Guidelines",
                        description: "National Institutes of Health reference standards for high blood pressure and hypertension categories.",
                        url: URL(string: "https://www.nhlbi.nih.gov/health/high-blood-pressure")!,
                        domain: "nhlbi.nih.gov"
                    )
                    
                    citationCard(
                        title: "ADA Blood Glucose Standards",
                        description: "American Diabetes Association reference levels for blood sugar ranges and diabetic screening.",
                        url: URL(string: "https://www.diabetes.org/diabetes/diagnosis")!,
                        domain: "diabetes.org"
                    )
                    
                    citationCard(
                        title: "CDC Vital Signs Reference Ranges",
                        description: "Centers for Disease Control and Prevention guidelines for normal pulse, temp, and oxygen saturation.",
                        url: URL(string: "https://www.cdc.gov/nchs/fastats/body-measurements.htm")!,
                        domain: "cdc.gov"
                    )
                    
                    citationCard(
                        title: "NIH MedlinePlus Lab Manual",
                        description: "Official National Library of Medicine definitions for baseline laboratory test ranges.",
                        url: URL(string: "https://medlineplus.gov/lab-tests/")!,
                        domain: "medlineplus.gov"
                    )
                    
                    VStack(spacing: 10) {
                        Text("Disclaimer")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.danger)
                        Text("Medhavn stores metric records for informational tracking only. Consult a licensed clinician to interpret measurements in the context of your medical history.")
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
                .foregroundStyle(AppTheme.primary)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 14)
    }
}

// MARK: - Log Measurement View
struct LogMeasurementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let metricType: HealthMetricType
    @State private var value = ""

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackgroundView()
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label(metricType.rawValue, systemImage: metricType.sfSymbol)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(AppTheme.primary)
                            Spacer()
                        }
                        
                        HStack(spacing: 12) {
                            TextField("0.0", text: $value)
                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                                .keyboardType(.decimalPad)
                                .padding(14)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                            
                            Text(metricType.defaultUnit)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 80)
                        }
                    }
                    .padding(20)
                    .glassCard(cornerRadius: 16)
                    
                    Button {
                        appState.addHealthMetric(type: metricType, value: value, unit: metricType.defaultUnit)
                        dismiss()
                    } label: {
                        Text("Log Measurement")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.primary, AppTheme.secondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                    
                    Spacer()
                }
                .padding(16)
                .padding(.top, 16)
            }
            .navigationTitle("Log Metric")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
}

// MARK: - Diary View
struct DiaryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            MeshBackgroundView()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // New Entry Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("New Entry")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.primary)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 12) {
                            TextEditor(text: $draft)
                                .focused($focused)
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(focused ? AppTheme.primary : Color.white.opacity(0.15), lineWidth: 1)
                                )
                            
                            Button {
                                appState.addDiaryEntry(draft)
                                draft = ""
                                focused = false
                            } label: {
                                Label("Save Entry", systemImage: "square.and.pencil")
                                    .font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(AppTheme.primary)
                                    .foregroundStyle(.black)
                                    .clipShape(Capsule())
                            }
                            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                        }
                        .padding(14)
                        .glassCard(cornerRadius: 16)
                    }
                    
                    // History
                    VStack(alignment: .leading, spacing: 10) {
                        Text("History")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.primary)
                            .padding(.horizontal, 4)
                        
                        if appState.diaryEntries.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "pencil.and.scribble")
                                    .font(.title)
                                    .foregroundStyle(.white.opacity(0.5))
                                Text("No diary entries recorded")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(30)
                            .glassCard(cornerRadius: 16)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(appState.diaryEntries) { entry in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(entry.text)
                                                .font(.subheadline)
                                                .foregroundStyle(.white)
                                                .lineSpacing(3)
                                            
                                            Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption2)
                                                .foregroundStyle(.white.opacity(0.7))
                                        }
                                        Spacer()
                                        
                                        Button {
                                            if let index = appState.diaryEntries.firstIndex(where: { $0.id == entry.id }) {
                                                appState.diaryEntries.remove(at: index)
                                            }
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(AppTheme.danger.opacity(0.8))
                                                .font(.footnote)
                                        }
                                    }
                                    .padding(14)
                                    .glassCard(cornerRadius: 14)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Symptoms Diary")
    }
}

// MARK: - Appointments View
struct AppointmentsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showAdd = false

    var body: some View {
        ZStack {
            MeshBackgroundView()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    if appState.appointments.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 48))
                                .foregroundStyle(.white.opacity(0.5))
                            Text("No Scheduled Appointments")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                            Text("Tap the button below to log your next clinic visit or check-up.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            
                            Button {
                                showAdd = true
                            } label: {
                                Label("Add Appointment", systemImage: "plus")
                                    .font(.subheadline.weight(.bold))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(AppTheme.primary)
                                    .foregroundStyle(.black)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(24)
                        .glassCard(cornerRadius: 16)
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(appState.appointments.sorted { $0.date < $1.date }) { appt in
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(appt.title)
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(.white)
                                            
                                            Spacer()
                                            
                                            Text(appt.type)
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(.black)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(AppTheme.primary)
                                                .clipShape(Capsule())
                                        }
                                        
                                        HStack(spacing: 8) {
                                            Image(systemName: "calendar")
                                                .font(.caption)
                                            Text(appt.date.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption)
                                        }
                                        .foregroundStyle(.white.opacity(0.7))
                                        
                                        if !appt.doctorName.isEmpty {
                                            Label(appt.doctorName, systemImage: "stethoscope")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.7))
                                        }
                                        
                                        if !appt.notes.isEmpty {
                                            Text(appt.notes)
                                                .font(.caption2)
                                                .foregroundStyle(.white.opacity(0.5))
                                                .padding(.top, 2)
                                        }
                                    }
                                    Spacer()
                                    
                                    Button {
                                        appState.removeAppointment(id: appt.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(AppTheme.danger.opacity(0.8))
                                            .font(.footnote)
                                    }
                                }
                                .padding(14)
                                .glassCard(cornerRadius: 14)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Appointments")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(.black)
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddAppointmentView()
                .environmentObject(appState)
        }
    }
}

// MARK: - Add Appointment View
struct AddAppointmentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var title = ""
    @State private var doctorName = ""
    @State private var date = Date()
    @State private var notes = ""
    @State private var type = "Routine Checkup"

    private let appointmentTypes = ["Routine Checkup", "Fasting Lab", "Blood Test", "Follow-up", "Vaccination", "Dental"]

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackgroundView()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Appointment Details")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.primary)
                                .padding(.horizontal, 4)
                            
                            VStack(spacing: 12) {
                                TextField("Title (e.g. Annual Check-up)", text: $title)
                                    .padding(12)
                                    .background(Color.primary.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                
                                TextField("Doctor or Provider Name", text: $doctorName)
                                    .padding(12)
                                    .background(Color.primary.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                Picker("Appointment Type", selection: $type) {
                                    ForEach(appointmentTypes, id: \.self) { t in
                                        Text(t).tag(t)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(AppTheme.primary)
                                
                                DatePicker("Date & Time", selection: $date)
                                    .font(.subheadline)
                                    .tint(AppTheme.primary)
                                    .padding(.vertical, 4)
                            }
                            .padding(16)
                            .glassCard(cornerRadius: 16)
                        }
                        
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Notes & Location")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 4)
                            
                            TextEditor(text: $notes)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.primary.opacity(0.08), style: StrokeStyle(lineWidth: 1))
                                )
                                .padding(12)
                                .glassCard(cornerRadius: 16)
                        }
                        
                        Button {
                            appState.addAppointment(AppointmentRecord(
                                id: UUID(),
                                title: title,
                                doctorName: doctorName,
                                date: date,
                                notes: notes,
                                type: type
                            ))
                            dismiss()
                        } label: {
                            Text("Save Appointment")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.primary)
                                .foregroundStyle(.black)
                                .clipShape(Capsule())
                                .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                        .padding(.top, 10)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Add Appointment")
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

// MARK: - Doctors View
struct DoctorsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showAdd = false

    var body: some View {
        ZStack {
            MeshBackgroundView()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    if appState.doctors.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "stethoscope")
                                .font(.system(size: 48))
                                .foregroundStyle(.white.opacity(0.5))
                            Text("No Care Team Members")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                            Text("Keep vital contact details for specialists and primary doctors in one secure catalog.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            
                            Button {
                                showAdd = true
                            } label: {
                                Label("Add Doctor", systemImage: "plus")
                                    .font(.subheadline.weight(.bold))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(AppTheme.primary)
                                    .foregroundStyle(.black)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(24)
                        .glassCard(cornerRadius: 16)
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(appState.doctors) { doc in
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Image(systemName: "stethoscope")
                                                .foregroundStyle(AppTheme.primary)
                                            Text(doc.name)
                                                .font(.subheadline.weight(.bold))
                                        }
                                        Text(doc.specialty)
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.7))
                                        
                                        if !doc.phone.isEmpty {
                                            Link(destination: URL(string: "tel:\(doc.phone.filter { $0.isNumber })")!) {
                                                Label(doc.phone, systemImage: "phone.fill")
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.7))
                                            }
                                        }
                                        
                                        if !doc.notes.isEmpty {
                                            Text(doc.notes)
                                                .font(.caption2)
                                                .foregroundStyle(.white.opacity(0.5))
                                                .padding(.top, 2)
                                        }
                                    }
                                    Spacer()
                                    
                                    Button {
                                        appState.removeDoctor(id: doc.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(AppTheme.danger.opacity(0.8))
                                            .font(.footnote)
                                    }
                                }
                                .padding(14)
                                .glassCard(cornerRadius: 14)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Doctors")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(.black)
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddDoctorView()
                .environmentObject(appState)
        }
    }
}

// MARK: - Add Doctor View
struct AddDoctorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var name = ""
    @State private var specialty = ""
    @State private var phone = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackgroundView()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Doctor Information")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.primary)
                                .padding(.horizontal, 4)
                            
                            VStack(spacing: 12) {
                                TextField("Full Name (e.g. Dr. Jane Smith)", text: $name)
                                    .padding(12)
                                    .background(Color.primary.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                
                                TextField("Specialty (e.g. Cardiologist)", text: $specialty)
                                    .padding(12)
                                    .background(Color.primary.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                
                                TextField("Office Phone", text: $phone)
                                    .keyboardType(.phonePad)
                                    .padding(12)
                                    .background(Color.primary.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .padding(16)
                            .glassCard(cornerRadius: 16)
                        }
                        
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Notes & Details")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 4)
                            
                            TextEditor(text: $notes)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                                .padding(12)
                                .glassCard(cornerRadius: 16)
                        }
                        
                        Button {
                            appState.addDoctor(DoctorRecord(
                                id: UUID(),
                                name: name,
                                specialty: specialty,
                                phone: phone,
                                notes: notes
                            ))
                            dismiss()
                        } label: {
                            Text("Save Doctor")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.primary)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                                .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                        .padding(.top, 10)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Add Doctor")
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

// MARK: - Safe Circle View
struct SafeCircleView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showAdd = false

    var body: some View {
        ZStack {
            MeshBackgroundView()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Care Network Intro Card
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Trusted Care Network", systemImage: "shield.lefthalf.filled.badge.checkmark")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                        
                        Text("SafeCircle contacts can be designated as emergency checkers. When enabled, they are automatically alerted if you miss critical scheduled doses.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineSpacing(4)
                    }
                    .padding(20)
                    .glassCard(cornerRadius: 16)
                    
                    // Circle Members
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Circle Members")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.primary)
                            .padding(.horizontal, 4)
                        
                        if appState.safeCircleContacts.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "person.3.sequence.fill")
                                    .font(.title)
                                    .foregroundStyle(.white.opacity(0.5))
                                Text("Your circle is currently empty")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                                
                                Button {
                                    showAdd = true
                                } label: {
                                    Text("Invite a Contact")
                                        .font(.caption.weight(.bold))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(AppTheme.primary)
                                        .foregroundStyle(.black)
                                        .clipShape(Capsule())
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)
                            .glassCard(cornerRadius: 16)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(appState.safeCircleContacts) { c in
                                    HStack(spacing: 14) {
                                        ZStack {
                                            Circle()
                                                .fill(AppTheme.primary.opacity(0.12))
                                                .frame(width: 44, height: 44)
                                            Text(String(c.name.prefix(1)).uppercased())
                                                .font(.headline.weight(.bold))
                                                .foregroundStyle(.black)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(c.name)
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(.white)
                                            Text(c.relationship.isEmpty ? c.contactInfo : "\(c.relationship) · \(c.contactInfo)")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.7))
                                        }
                                        
                                        Spacer()
                                        
                                        Button {
                                            appState.removeSafeCircleContact(id: c.id)
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(AppTheme.danger.opacity(0.8))
                                                .font(.footnote)
                                        }
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .padding(14)
                            .glassCard(cornerRadius: 16)
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("SafeCircle")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(.black)
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddSafeCircleContactView()
                .environmentObject(appState)
        }
    }
}

// MARK: - Add Safe Circle Contact View
struct AddSafeCircleContactView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var name = ""
    @State private var contact = ""
    @State private var relationship = ""
    private let relationships = ["Spouse","Parent","Child","Friend","Doctor","Pharmacist","Caregiver","Other"]

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackgroundView()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Contact Details")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.primary)
                                .padding(.horizontal, 4)
                            
                            VStack(spacing: 12) {
                                TextField("Full Name", text: $name)
                                    .padding(12)
                                    .background(Color.primary.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                
                                TextField("Email or Phone Number", text: $contact)
                                    .keyboardType(.emailAddress)
                                    .padding(12)
                                    .background(Color.primary.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                
                                Picker("Relationship", selection: $relationship) {
                                    Text("Select relationship...").tag("")
                                    ForEach(relationships, id: \.self) {
                                        Text($0).tag($0)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(AppTheme.primary)
                                .padding(.vertical, 4)
                            }
                            .padding(16)
                            .glassCard(cornerRadius: 16)
                        }
                        
                        VStack(spacing: 10) {
                            Label("Missed Dose Alerts", systemImage: "bell.badge.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppTheme.info)
                            Text("When saved, this contact can be configured to receive instant updates if you miss a scheduled medication check-in.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }
                        .padding(16)
                        .glassCard(cornerRadius: 16)
                        
                        Button {
                            appState.addSafeCircleContact(name: name, contactInfo: contact, relationship: relationship)
                            dismiss()
                        } label: {
                            Text("Save Member")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.primary)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                                .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                        .padding(.top, 10)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Add to Circle")
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

// MARK: - Add Dependent View
struct AddDependentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var gender = "Female"
    @State private var birthYear = 2010
    private let genders = ["Female","Male","Other"]
    private let years = Array((1924...Calendar.current.component(.year, from: Date())).reversed())

    var body: some View {
        ZStack {
            MeshBackgroundView()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Personal Information")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.primary)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 12) {
                            TextField("First Name", text: $firstName)
                                .padding(12)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            
                            TextField("Last Name", text: $lastName)
                                .padding(12)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            
                            HStack {
                                Text("Gender")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.7))
                                Spacer()
                                Picker("Gender", selection: $gender) {
                                    ForEach(genders, id: \.self) {
                                        Text($0).tag($0)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(AppTheme.primary)
                            }
                            .padding(.vertical, 4)
                            
                            HStack {
                                Text("Birth Year")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.7))
                                Spacer()
                                Picker("Birth Year", selection: $birthYear) {
                                    ForEach(years, id: \.self) {
                                        Text(String($0)).tag($0)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(AppTheme.primary)
                            }
                            .padding(.vertical, 4)
                        }
                        .padding(16)
                        .glassCard(cornerRadius: 16)
                    }
                    
                    Button {
                        appState.addDependent(DependentProfile(
                            id: UUID(),
                            firstName: firstName,
                            lastName: lastName,
                            gender: gender,
                            birthYear: birthYear,
                            avatarColor: "#2F80ED"
                        ))
                        dismiss()
                    } label: {
                        Text("Save Profile")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.primary)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                    .padding(.top, 10)
                }
                .padding(16)
            }
        }
        .navigationTitle("Add Dependent")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

// MARK: - Allergies View
struct AllergiesView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showAdd = false

    var body: some View {
        ZStack {
            MeshBackgroundView()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    if appState.allergies.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "allergens")
                                .font(.system(size: 48))
                                .foregroundStyle(AppTheme.warning)
                            Text("No Recorded Allergies")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                            Text("Document substance, food, or drug allergies to run automatic cross-checking scans on your cabinet.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            
                            Button {
                                showAdd = true
                            } label: {
                                Label("Add Allergy", systemImage: "plus")
                                    .font(.subheadline.weight(.bold))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(AppTheme.primary)
                                    .foregroundStyle(.black)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(24)
                        .glassCard(cornerRadius: 16)
                        .padding(.top, 40)
                    } else {
                        // Allergy warning banners
                        let warnings = appState.medCabinetItems.flatMap {
                            appState.allergyWarnings(for: $0.name)
                        }
                        
                        if !warnings.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("ACTIVE ALLERGY WARNINGS", systemImage: "exclamationmark.shield.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.danger)
                                
                                ForEach(warnings, id: \.self) { w in
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(AppTheme.danger)
                                        Text(w)
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(AppTheme.danger)
                                    }
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.danger.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(AppTheme.danger.opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Recorded Allergies")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.primary)
                                .padding(.horizontal, 4)
                            
                            LazyVStack(spacing: 12) {
                                ForEach(appState.allergies) { allergy in
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(reactionColor(allergy.reaction))
                                            .frame(width: 10, height: 10)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(allergy.substance)
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(.white)
                                            Text("Reaction: \(allergy.reaction.rawValue)")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.7))
                                            if !allergy.notes.isEmpty {
                                                Text(allergy.notes)
                                                    .font(.caption2)
                                                    .foregroundStyle(.white.opacity(0.5))
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(allergy.dateAdded.formatted(date: .abbreviated, time: .omitted))
                                                .font(.caption2)
                                                .foregroundStyle(.white.opacity(0.5))
                                            
                                            Button {
                                                appState.removeAllergy(id: allergy.id)
                                            } label: {
                                                Image(systemName: "trash")
                                                    .foregroundStyle(AppTheme.danger.opacity(0.8))
                                                    .font(.caption)
                                            }
                                        }
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .padding(14)
                            .glassCard(cornerRadius: 16)
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Allergies")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(.black)
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                AddAllergyView()
                    .environmentObject(appState)
            }
        }
    }

    private func reactionColor(_ reaction: AllergyReaction) -> Color {
        switch reaction {
        case .mild: return AppTheme.success
        case .moderate: return AppTheme.warning
        case .severe: return AppTheme.danger
        }
    }
}

// MARK: - Add Allergy View
struct AddAllergyView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var substance = ""
    @State private var reaction: AllergyReaction = .mild
    @State private var notes = ""

    var body: some View {
        ZStack {
            MeshBackgroundView()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Substance Details")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.primary)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 12) {
                            TextField("Substance (e.g. Penicillin, Peanuts)", text: $substance)
                                .autocorrectionDisabled()
                                .padding(12)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Reaction Severity")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white.opacity(0.7))
                                
                                Picker("Reaction", selection: $reaction) {
                                    ForEach(AllergyReaction.allCases) { r in
                                        Text(r.rawValue).tag(r)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(.top, 6)
                        }
                        .padding(16)
                        .glassCard(cornerRadius: 16)
                    }
                    
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Symptoms (Optional)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 4)
                        
                        TextField("e.g. skin rash, hives, breathing trouble", text: $notes)
                            .padding(12)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(12)
                            .glassCard(cornerRadius: 16)
                    }
                    
                    Button {
                        let record = AllergyRecord(
                            substance: substance.trimmingCharacters(in: .whitespacesAndNewlines),
                            reaction: reaction,
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        appState.addAllergy(record)
                        dismiss()
                    } label: {
                        Text("Save Allergy")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.primary)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(substance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(substance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                    .padding(.top, 10)
                }
                .padding(16)
            }
        }
        .navigationTitle("Add Allergy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}
