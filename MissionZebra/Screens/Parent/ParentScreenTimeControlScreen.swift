import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif

struct ParentScreenTimeControlScreen: View {
    @EnvironmentObject var router: NavigationRouter
    @StateObject private var viewModel = ParentScreenTimeControlViewModel()

    @State private var showEditDialog = false
    @State private var editingChild: Child?
    @State private var editMinutes: String = ""
    @State private var screenTimePickerError: String?

    #if canImport(FamilyControls)
    @State private var showFamilyActivityPicker = false
    @State private var familySelection = DeviceActivityCoordinator.shared.loadSelection() ?? FamilyActivitySelection()
    #endif

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: { router.goBack() }) {
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
                    viewModel.onChildLimitChange(childId: child.id, value: editMinutes)
                    viewModel.saveChildLimit(childId: child.id)
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
                do {
                    try DeviceActivityCoordinator.shared.saveSelection(familySelection)
                    try DeviceActivityCoordinator.shared.startDailyMonitoring()
                    screenTimePickerError = nil
                } catch {
                    screenTimePickerError = error.localizedDescription
                }
            }
        }
        #endif
    }

    private func requestScreenTimeAuthorization() async {
        #if canImport(FamilyControls)
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            try DeviceActivityCoordinator.shared.startDailyMonitoring()
            await MainActor.run { screenTimePickerError = nil }
        } catch {
            await MainActor.run { screenTimePickerError = error.localizedDescription }
        }
        #else
        await MainActor.run {
            screenTimePickerError = "FamilyControls is niet beschikbaar op dit platform."
        }
        #endif
    }
}

private struct ScreenTimeSetupCard: View {
    let error: String?
    let onAuthorize: () -> Void
    let onPickApps: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Echte iOS Screen Time", systemImage: "shield.lefthalf.filled")
                    .font(.headline)
                Spacer()
                Text("Apple Screen Time")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("Kies apps of categorieën die MissionZebra mag meten en blokkeren. Zonder Apple-toestemming toont iOS alleen een veilige fallback, geen volledige toestel-schermtijd.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack {
                Button(action: onAuthorize) {
                    Label("Geef toestemming", systemImage: "checkmark.shield")
                }
                .buttonStyle(.bordered)

                Button(action: onPickApps) {
                    Label("Kies apps", systemImage: "square.grid.2x2")
                }
                .buttonStyle(.borderedProminent)
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
            .buttonStyle(.borderedProminent)
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
