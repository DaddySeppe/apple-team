import SwiftUI
import FirebaseAuth

// MARK: - TAB 4: SECURITY (INSTELLINGEN)

struct SecurityPage: View {
    let familyTimeActive: Bool
    let onToggleFamilyTime: () -> Void
    let appBlockingEnabled: Bool
    let isUpdatingAppBlocking: Bool
    let onSetAppBlockingEnabled: (Bool) -> Void
    let onShowInterstitialAd: () -> Void
    let onLogout: () -> Void
    let onDeleteAccount: (_ password: String?) async throws -> Void
    let isDeviceForChild: Bool
    let isSharedChildDevice: Bool
    let onSetDeviceForChild: () -> Void
    let onSetSharedChildDevice: () -> Void
    let onSetDeviceForParent: () -> Void
    let onOpenPrivacyPolicy: () -> Void
    let onOpenOnlineSafety: () -> Void
    let headerContent: AnyView

    @AppStorage("notifyOnTaskDone") private var notifyOnTaskDone = true
    @AppStorage("notifyOnRewardRedeemed") private var notifyOnRewardRedeemed = true
    @AppStorage("notifyOnScreenTimeLimit") private var notifyOnScreenTimeLimit = true
    @AppStorage("dark_theme") private var isDarkTheme = false
    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var accountDeleteError: String?

    private var userEmail: String {
        Auth.auth().currentUser?.email ?? "Onbekend"
    }

    private var deviceModeDescription: String {
        if isSharedChildDevice {
            return "Dit toestel is momenteel ingesteld als gedeeld kindapparaat."
        }
        if isDeviceForChild {
            return "Dit toestel is momenteel ingesteld als kindapparaat."
        }
        return "Dit toestel is momenteel een ouderapparaat."
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerContent

                VStack(spacing: 16) {
                    // Account
                    SettingsCardView(title: "Account") {
                        Text("Ingelogd als")
                            .font(.caption)
                        Text(userEmail)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer().frame(height: 8)

                        if let accountDeleteError {
                            Text(accountDeleteError)
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        Button(role: .destructive) {
                            accountDeleteError = nil
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                if isDeletingAccount {
                                    ProgressView()
                                } else {
                                    Image(systemName: "trash")
                                }
                                Text(isDeletingAccount ? "Account verwijderen..." : "Account verwijderen")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(MZSecondaryButtonStyle())
                        .tint(.red)
                        .disabled(isDeletingAccount)
                    }

                    // PIN & Beveiliging
                    SettingsCardView(title: "Ouder-PIN & beveiliging") {
                        ParentPinSectionView()
                    }

                    // Online Veiligheid
                    SettingsCardView(title: "Online Veiligheid") {
                        Text("Beheer online risico's, bekijk gedrags-signalen en pas veiligheidsinstellingen aan.")
                            .font(.caption)
                        Spacer().frame(height: 8)
                        Button(action: {
                            onShowInterstitialAd()
                            onOpenOnlineSafety()
                        }) {
                            HStack {
                                Image(systemName: "shield")
                                Text("Online Veiligheid Instellingen")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(MZSecondaryButtonStyle())
                    }

                    // Toestelmodus
                    SettingsCardView(title: "Toestelmodus") {
                        Text(deviceModeDescription)
                            .font(.caption)
                        Spacer().frame(height: 8)
                        if isDeviceForChild {
                            Button("Maak dit een ouderapparaat", action: onSetDeviceForParent)
                                .buttonStyle(MZPrimaryButtonStyle())
                                .frame(maxWidth: .infinity)
                        } else {
                            Button("Dit toestel gebruiken als kindapparaat", action: onSetDeviceForChild)
                                .buttonStyle(MZPrimaryButtonStyle())
                                .frame(maxWidth: .infinity)
                        }

                        Spacer().frame(height: 8)

                        Button(action: onSetSharedChildDevice) {
                            HStack {
                                Image(systemName: "person.2.fill")
                                Text("Gebruik als gedeeld kindapparaat")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(MZSecondaryButtonStyle())
                    }

                    // Gezinsmoment
                    SettingsCardView(title: "Gezinsmoment") {
                        if !familyTimeActive {
                            Text("Start een tijdelijke schermpauze voor het hele gezin.")
                                .font(.caption)
                            Spacer().frame(height: 8)
                            Button("Gezinsmoment starten") {
                                onShowInterstitialAd()
                                onToggleFamilyTime()
                            }
                                .buttonStyle(MZPrimaryButtonStyle())
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Gezinsmoment is nu actief. Schermen even aan de kant.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer().frame(height: 8)
                            Button("Gezinsmoment stoppen") {
                                onShowInterstitialAd()
                                onToggleFamilyTime()
                            }
                                .buttonStyle(MZPrimaryButtonStyle())
                                .frame(maxWidth: .infinity)
                        }
                    }

                    // Schermtijd blokkades
                    SettingsCardView(title: "Schermtijd blokkades") {
                        Text("Schermtijd blijft meten. Met deze knop kies je of MissionZebra de gekozen apps ook echt blokkeert wanneer een limiet, bedtijd of focustijd actief is.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer().frame(height: 8)
                        SettingsSwitchRow(
                            label: isUpdatingAppBlocking ? "Apps blokkeren wordt aangepast..." : "Apps blokkeren bij schermtijd",
                            isOn: Binding(
                                get: { appBlockingEnabled },
                                set: {
                                    onShowInterstitialAd()
                                    onSetAppBlockingEnabled($0)
                                }
                            )
                        )
                        .disabled(isUpdatingAppBlocking)
                    }

                    // App-instellingen
                    SettingsCardView(title: "App-instellingen") {
                        SettingsSwitchRow(label: "Melding bij voltooide taak", isOn: $notifyOnTaskDone)
                        Spacer().frame(height: 8)
                        SettingsSwitchRow(label: "Melding bij ingewisselde beloning", isOn: $notifyOnRewardRedeemed)
                        Spacer().frame(height: 8)
                        SettingsSwitchRow(label: "Melding bij bijna schermtijd op", isOn: $notifyOnScreenTimeLimit)
                    }

                    // Thema
                    SettingsCardView(title: "Thema") {
                        Text("Kies tussen licht en donker thema voor de app.")
                            .font(.caption)
                        Spacer().frame(height: 8)
                        SettingsSwitchRow(label: "Donker thema", isOn: $isDarkTheme)
                    }

                    // Steun ons
                    SettingsCardView(title: "Steun ons") {
                        Text("Je kunt ons project steunen door de app te delen met andere ouders of door feedback te geven. Zo helpen jullie ons MissionZebra te verbeteren.")
                            .font(.caption)
                        Spacer().frame(height: 8)
                        Link("Bezoek missionzebra.be", destination: URL(string: "https://missionzebra.be")!)
                            .buttonStyle(MZPrimaryButtonStyle())
                            .frame(maxWidth: .infinity)
                    }

                    // Over MissionZebra
                    SettingsCardView(title: "Over MissionZebra") {
                        Text("MissionZebra helpt je kinderen op een speelse manier met schermtijd omgaan door taken, beloningen en duidelijke afspraken te combineren.")
                            .font(.caption)
                        Spacer().frame(height: 12)

                        Link("Bekijk privacy policy", destination: URL(string: "https://missionzebra.be/privacy-policy-nl.html")!)
                            .frame(maxWidth: .infinity)
                            .buttonStyle(MZPrimaryButtonStyle())

                        Link("Bekijk terms of service", destination: URL(string: "https://missionzebra.be/terms-nl.html")!)
                            .frame(maxWidth: .infinity)
                            .buttonStyle(MZPrimaryButtonStyle())
                    }

                    Button(action: onLogout) {
                        Text("Afmelden")
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MZSecondaryButtonStyle())
                    .tint(.red)

                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 16)
            }
        }
        .confirmationDialog(
            "Account permanent verwijderen?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Verwijder account", role: .destructive) {
                deleteAccount(password: nil)
            }
            Button("Annuleren", role: .cancel) {}
        } message: {
            Text("Hiermee verwijder je je ouderaccount, kinderen, taken, beloningen en schermtijdgegevens permanent.")
        }
        .onChange(of: notifyOnTaskDone) { enabled in
            if enabled {
                NotificationManager.shared.requestPermissionIfNeeded()
            }
        }
        .onChange(of: notifyOnRewardRedeemed) { enabled in
            if enabled {
                NotificationManager.shared.requestPermissionIfNeeded()
            }
        }
        .onChange(of: notifyOnScreenTimeLimit) { enabled in
            if enabled {
                NotificationManager.shared.requestPermissionIfNeeded()
            }
        }
    }

    private func deleteAccount(password: String?) {
        isDeletingAccount = true
        accountDeleteError = nil

        Task {
            do {
                try await onDeleteAccount(password)
            } catch {
                await MainActor.run {
                    accountDeleteError = error.userFriendlyMessage("Account verwijderen is niet gelukt. Log opnieuw in en probeer het nog eens.")
                    isDeletingAccount = false
                }
            }
        }
    }
}

// MARK: - Settings Card

struct SettingsCardView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.body)
                .fontWeight(.bold)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)).shadow(radius: 2))
    }
}

// MARK: - Settings Switch Row

struct SettingsSwitchRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(label, isOn: $isOn)
            .font(.subheadline)
    }
}

// MARK: - Parent PIN Section

struct ParentPinSectionView: View {
    @State private var pin = ""
    @State private var message: String?
    @FocusState private var isPinFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let hasPin = ParentPinManager.shared.hasParentPin()
            let label = hasPin ? "Nieuwe ouder-PIN (4 cijfers)" : "Stel ouder-PIN in (4 cijfers)"

            TextField(label, text: $pin)
                .keyboardType(.numberPad)
                .focused($isPinFocused)
                .textFieldStyle(.roundedBorder)
                .onChange(of: pin, perform: { newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    pin = String(filtered.prefix(4))
                })

            if let message = message {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button("PIN opslaan") {
                guard pin.count == 4 else {
                    message = "PIN moet 4 cijfers zijn"
                    return
                }
                ParentPinManager.shared.setParentPin(pin)
                message = "PIN opgeslagen"
                pin = ""
                isPinFocused = false
            }
            .buttonStyle(MZPrimaryButtonStyle())
            .frame(maxWidth: .infinity)
        }
    }
}
