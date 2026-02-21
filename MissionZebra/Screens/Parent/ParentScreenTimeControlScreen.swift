import SwiftUI

struct ParentScreenTimeControlScreen: View {
    @EnvironmentObject var router: NavigationRouter
    @StateObject private var viewModel = ParentScreenTimeControlViewModel()

    @State private var showEditDialog = false
    @State private var editingChild: Child?
    @State private var editMinutes: String = ""

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
                    AddChildSection(
                        name: $viewModel.uiState.newChildName,
                        minutes: $viewModel.uiState.newChildMinutes,
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

                    // BannerAdView placeholder
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
    }
}

// MARK: - Add Child Section

struct AddChildSection: View {
    @Binding var name: String
    @Binding var minutes: String
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nieuw kind toevoegen")
                .font(.headline)
                .fontWeight(.bold)

            TextField("Naam van het kind", text: $name)
                .textFieldStyle(.roundedBorder)

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
