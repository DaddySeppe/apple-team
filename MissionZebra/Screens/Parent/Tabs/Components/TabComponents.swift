import SwiftUI

// MARK: - Manage Children Dialog

struct ManageChildrenDialog: View {
    let children: [Child]
    let onDismiss: () -> Void
    let onAddChild: (String, Int) -> Void
    let onDeleteChild: (String) -> Void
    let isAdding: Bool
    let addChildError: String?
    let onClearError: () -> Void

    @State private var newChildName = ""
    @State private var newChildLimit = "60"

    private let presets = ["30", "60", "90", "120"]

    var body: some View {
        NavigationStack {
            List {
                // Add Child Form
                Section("Nieuw kind toevoegen") {
                    TextField("Naam", text: $newChildName)
                        .onChange(of: newChildName, perform: { _ in onClearError() })

                    Text("Dagelijkse limiet:")
                        .font(.caption)
                        .fontWeight(.bold)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(presets, id: \.self) { preset in
                                Button(action: { newChildLimit = preset }) {
                                    Text("\(preset)m")
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(newChildLimit == preset ? Color.accentColor : Color(.tertiarySystemBackground)))
                                        .foregroundColor(newChildLimit == preset ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    TextField("Minuten", text: $newChildLimit)
                        .keyboardType(.numberPad)

                    if let error = addChildError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Button(action: {
                        let limit = Int(newChildLimit) ?? 60
                        if !newChildName.trimmingCharacters(in: .whitespaces).isEmpty {
                            onAddChild(newChildName, limit)
                        }
                    }) {
                        if isAdding {
                            ProgressView()
                        } else {
                            Text("Toevoegen")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isAdding || newChildName.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                // Existing Children
                Section("Huidige kinderen") {
                    ForEach(children) { child in
                        ManageChildItem(child: child) {
                            onDeleteChild(child.id)
                        }
                    }
                }
            }
            .navigationTitle("Kinderen beheren")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sluiten", action: onDismiss)
                }
            }
        }
    }
}

// MARK: - Manage Child Item

private struct ManageChildItem: View {
    let child: Child
    let onDelete: () -> Void

    @State private var showConfirm = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(child.name)
                    .fontWeight(.bold)
                Text("\(child.dailyScreenTimeLimitMinutes) min/dag")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { showConfirm = true }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .alert("Kind verwijderen", isPresented: $showConfirm) {
            Button("Verwijderen", role: .destructive, action: onDelete)
            Button("Annuleren", role: .cancel) {}
        } message: {
            Text("Weet je zeker dat je \(child.name) wilt verwijderen?")
        }
    }
}

// MARK: - Parent Message Dialog

struct ParentMessageDialog: View {
    let onDismiss: () -> Void
    let onSend: (String) -> Void

    private let presets = [
        "Goed bezig! 💪",
        "Trots op jou! ❤️",
        "Je doet het super! 🌟",
        "Vergeet niet even pauze te nemen! ☕",
        "Zet 'm op vandaag! 🚀"
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("Kies een berichtje dat direct op het scherm van je kind verschijnt:") {
                    ForEach(presets, id: \.self) { msg in
                        Button(action: { onSend(msg) }) {
                            Text(msg)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .navigationTitle("Stuur een berichtje")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Annuleren", action: onDismiss)
                }
            }
        }
    }
}
