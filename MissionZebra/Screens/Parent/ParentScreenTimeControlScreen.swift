import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif
import UIKit

struct ParentScreenTimeControlScreen: View {
    @EnvironmentObject var router: NavigationRouter
    @StateObject private var viewModel = ParentScreenTimeControlViewModel()

    @State private var showEditDialog = false
    @State private var editingChild: Child?
    @State private var editMinutes: String = ""
    @State private var screenTimePickerError: String?
    @State private var screenTimeAvailability = DeviceActivityCoordinator.shared.availability()

    #if canImport(FamilyControls)
    @State private var showFamilyActivityPicker = false
    @State private var familySelection = DeviceActivityCoordinator.shared.loadSelection() ?? FamilyActivitySelection()
    #endif

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: goBackToParentArea) {
                    Image(systemName: "arrow.left")
                        .font(.title3)
                }
                Text("⏱ Schermtijd instellen")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding()

            ScrollView {
                VStack(spacing: 16) {
                    ScreenTimeSetupCard(
                        availability: screenTimeAvailability,
                        error: screenTimePickerError,
                        onAuthorize: {
                            Task { await requestScreenTimeAuthorization() }
                        },
                        onPickApps: {
                            #if canImport(FamilyControls)
                            showFamilyActivityPicker = true
                            #else
                            screenTimePickerError = "FamilyControls is niet beschikbaar op dit platform."
                            #endif
                        },
                        onOpenSettings: {
                            openAppSettings()
                        }
                    )

                    AddChildSection(
                        name: $viewModel.uiState.newChildName,
                        minutes: $viewModel.uiState.newChildMinutes,
                        birthDate: Binding(
                            get: { viewModel.uiState.newChildBirthDate },
                            set: { viewModel.onNewChildBirthDateChange($0) }
                        ),
                        onAdd: { viewModel.addChild() }
                    )

                    if viewModel.uiState.children.isEmpty {
                        VStack(spacing: 8) {
                            Text("Nog geen kinderen toegevoegd.")
                                .foregroundColor(.secondary)
                            Text("Voeg een kind toe om de schermtijd te beheren.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(24)
                    } else {
                        ChildrenList(
                            children: viewModel.uiState.children,
                            onEdit: { child in
                                editingChild = child
                                editMinutes = "\(child.dailyScreenTimeLimitMinutes)"
                                showEditDialog = true
                            },
                            onDelete: { child in
                                viewModel.deleteChild(childId: child.id)
                            }
                        )
                    }

                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 50)
                }
                .padding(.horizontal, 16)
            }
        }
        .alert("Schermtijd aanpassen", isPresented: $showEditDialog) {
            TextField("Minuten", text: $editMinutes)
                .keyboardType(.numberPad)
            Button("Opslaan") {
                if let child = editingChild {
                    viewModel.saveChildLimit(childId: child.id, value: editMinutes)
                }
                showEditDialog = false
            }
            Button("Annuleren", role: .cancel) {
                showEditDialog = false
            }
        } message: {
            if let child = editingChild {
                Text("Pas de dagelijkse limiet aan voor \(child.name)")
            }
        }
        #if canImport(FamilyControls)
        .familyActivityPicker(isPresented: $showFamilyActivityPicker, selection: $familySelection)
        .onChange(of: showFamilyActivityPicker) { isPresented in
            if !isPresented {
                saveFamilyActivitySelection()
            }
        }
        #endif
        .onAppear {
            refreshScreenTimeAvailability()
        }
    }

    private func requestScreenTimeAuthorization() async {
        #if canImport(FamilyControls)
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            let availability = DeviceActivityCoordinator.shared.availability()
            if availability == .available {
                try DeviceActivityCoordinator.shared.startDailyMonitoring()
            }
            await MainActor.run {
                screenTimeAvailability = availability
                switch availability {
                case .available:
                    screenTimePickerError = nil
                case .missingSelection:
                    screenTimePickerError = "Toestemming staat aan. Kies nu apps of categorieën, anders kan iOS geen schermtijd doorgeven."
                    showFamilyActivityPicker = true
                case .missingAuthorization:
                    screenTimePickerError = "Apple Screen Time-toestemming staat nog uit. Open Instellingen en zet Screen Time/Family Controls voor MissionZebra aan."
                case .unavailable(let reason):
                    screenTimePickerError = reason
                }
            }
        } catch {
            await MainActor.run {
                refreshScreenTimeAvailability()
                screenTimePickerError = "Toestemming lukte niet: \(error.localizedDescription). Open Instellingen, zet Screen Time aan en probeer opnieuw."
            }
        }
        #else
        await MainActor.run {
            screenTimePickerError = "FamilyControls is niet beschikbaar op dit platform."
        }
        #endif
    }

    private func goBackToParentArea() {
        SessionManager.shared.setParentLoggedIn()
        MissionZebraAdPrivacy.applyForParentMode()
        router.reset(to: .parentDashboard)
    }

    private func refreshScreenTimeAvailability() {
        screenTimeAvailability = DeviceActivityCoordinator.shared.availability()
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    #if canImport(FamilyControls)
    private func saveFamilyActivitySelection() {
        do {
            try DeviceActivityCoordinator.shared.saveSelection(familySelection)
            let availability = DeviceActivityCoordinator.shared.availability()
            screenTimeAvailability = availability
            guard availability == .available else {
                screenTimePickerError = "Kies minstens 1 app of categorie. Zonder keuze kan Apple geen echte schermtijd-events sturen."
                return
            }
            try DeviceActivityCoordinator.shared.startDailyMonitoring()
            screenTimePickerError = nil
        } catch {
            refreshScreenTimeAvailability()
            screenTimePickerError = error.localizedDescription
        }
    }
    #endif
}

private struct ScreenTimeSetupCard: View {
    let availability: DeviceActivityAvailability
    let error: String?
    let onAuthorize: () -> Void
    let onPickApps: () -> Void
    let onOpenSettings: () -> Void

    private var statusTitle: String {
        switch availability {
        case .available:
            return "Actief: echte Screen Time kan gemeten worden"
        case .missingAuthorization:
            return "Niet actief: Apple Screen Time-toestemming ontbreekt"
        case .missingSelection:
            return "Bijna klaar: kies apps of categorieën"
        case .unavailable:
            return "Niet beschikbaar op dit toestel"
        }
    }

    private var statusColor: Color {
        switch availability {
        case .available:
            return .green
        case .missingSelection:
            return .orange
        case .missingAuthorization, .unavailable:
            return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Echte iOS Screen Time", systemImage: "shield.lefthalf.filled")
                    .font(.headline)
                Spacer()
                Text("Apple Screen Time")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text(availability.userMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if availability != .available {
                Text("Belangrijk: zonder Apple Family Controls meet MissionZebra niet de echte totale toestel-schermtijd. Ouders moeten dit aanzetten en kinderen moeten weten dat dit nodig is om eerlijk te meten.")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                VStack(alignment: .leading, spacing: 6) {
                    Label("Stap 1: zet Screen Time/Family Controls aan voor MissionZebra.", systemImage: "1.circle.fill")
                    Label("Stap 2: kies minstens 1 app of categorie om te meten.", systemImage: "2.circle.fill")
                    Label("Stap 3: laat MissionZebra op het kindertoestel staan zodat iOS events kan doorgeven.", systemImage: "3.circle.fill")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            if let error {
                Text(error)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
            }

            VStack(spacing: 10) {
                if availability != .available {
                    Button(action: onAuthorize) {
                        Label("Toestemming aanvragen", systemImage: "checkmark.shield")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MZPrimaryButtonStyle())
                }

                if availability == .available {
                    Button(action: onPickApps) {
                        Label("Apps of categorieën aanpassen", systemImage: "square.grid.2x2")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MZPrimaryButtonStyle())
                } else {
                    Button(action: onPickApps) {
                        Label("Apps of categorieën kiezen", systemImage: "square.grid.2x2")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MZSecondaryButtonStyle())
                }

                Button(action: onOpenSettings) {
                    Label("Open iOS-instellingen", systemImage: "gearshape.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MZSecondaryButtonStyle())
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}

// MARK: - Add Child Section

struct AddChildSection: View {
    @Binding var name: String
    @Binding var minutes: String
    @Binding var birthDate: Date
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nieuw kind toevoegen")
                .font(.headline)
                .fontWeight(.bold)

            TextField("Naam van het kind", text: $name)
                .textFieldStyle(.roundedBorder)

            DatePicker("Geboortedatum", selection: $birthDate, displayedComponents: .date)
                .datePickerStyle(.compact)

            TextField("Dagelijkse schermtijd (minuten)", text: $minutes)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)

            Button(action: onAdd) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Kind toevoegen")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(MZPrimaryButtonStyle())
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || minutes.isEmpty)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}

// MARK: - Children List

struct ChildrenList: View {
    let children: [Child]
    let onEdit: (Child) -> Void
    let onDelete: (Child) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kinderen")
                .font(.headline)
                .fontWeight(.bold)

            ForEach(children) { child in
                ChildRow(child: child, onEdit: { onEdit(child) }, onDelete: { onDelete(child) })
            }
        }
    }
}

// MARK: - Child Row

struct ChildRow: View {
    let child: Child
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(child.name)
                    .font(.body)
                    .fontWeight(.medium)
                Text("Limiet: \(child.dailyScreenTimeLimitMinutes) min/dag · Gebruikt: \(child.dailyScreenTimeUsedMinutes) min")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let birthDate = child.birthDate {
                    Text("Geboren: \(birthDate) · \(child.age) jaar")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "trash.circle.fill")
                    .font(.title3)
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
    }
}
