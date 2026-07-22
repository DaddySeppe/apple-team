import SwiftUI

// MARK: - Add Task Dialog

struct AddTaskDialog: View {
    let children: [Child]
    let selectedChildId: String?
    let title: String
    let points: String
    let dueDate: Date
    let repeatsWeekly: Bool
    let purpose: String
    let contributionTarget: String
    let isSaving: Bool
    let error: String?
    let onChildSelected: (String) -> Void
    let onTitleChange: (String) -> Void
    let onPointsChange: (String) -> Void
    let onDueDateChange: (Date) -> Void
    let onRepeatsWeeklyChange: (Bool) -> Void
    let onPurposeChange: (String) -> Void
    let onContributionTargetChange: (String) -> Void
    let onAddClick: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                if children.isEmpty {
                    Text("Voeg eerst kinderen toe voordat je taken koppelt.")
                        .foregroundColor(.red)
                } else {
                    Section("Selecteer een kind") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(children) { child in
                                    Button(action: { onChildSelected(child.id) }) {
                                        Text(child.name)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                Capsule().fill(child.id == selectedChildId ? Color.accentColor : Color(.tertiarySystemBackground))
                                            )
                                            .foregroundColor(child.id == selectedChildId ? .white : .primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    Section {
                        TextField("Bijv. Kamer opruimen", text: Binding(
                            get: { title },
                            set: { onTitleChange($0) }
                        ))

                        TextField("Bijv. 10", text: Binding(
                            get: { points },
                            set: { onPointsChange($0) }
                        ))
                        .keyboardType(.numberPad)
                    }

                    Section("Planning") {
                        DatePicker(
                            "Vervaldatum",
                            selection: Binding(
                                get: { dueDate },
                                set: { onDueDateChange($0) }
                            ),
                            displayedComponents: .date
                        )

                        Toggle("Wekelijks herhalen", isOn: Binding(
                            get: { repeatsWeekly },
                            set: { onRepeatsWeeklyChange($0) }
                        ))
                    }

                    Section("Waarom deze taak?") {
                        TextField("Bijv. Een rustige kamer helpt je slapen", text: Binding(
                            get: { purpose },
                            set: { onPurposeChange($0) }
                        ), axis: .vertical)

                        TextField("Bijv. Helpt het gezin / spaardoel", text: Binding(
                            get: { contributionTarget },
                            set: { onContributionTargetChange($0) }
                        ), axis: .vertical)
                    }

                    if let error = error {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Nieuwe taak toevoegen")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuleren", action: onDismiss)
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if children.isEmpty {
                        EmptyView()
                    } else {
                        Button(action: onAddClick) {
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Toevoegen")
                            }
                        }
                        .fontWeight(.bold)
                        .foregroundStyle(Color.accentColor)
                        .disabled(isSaving)
                    }
                }
            }
        }
    }
}
