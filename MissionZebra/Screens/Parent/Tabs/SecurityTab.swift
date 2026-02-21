import SwiftUI
import FirebaseAuth

// MARK: - TAB 4: SECURITY (INSTELLINGEN)

struct SecurityPage: View {
    let familyTimeActive: Bool
    let onToggleFamilyTime: () -> Void
    let onGoToPremiumDashboard: () -> Void
    let onLogout: () -> Void
    let isDeviceForChild: Bool
    let onSetDeviceForChild: () -> Void
    let onSetDeviceForParent: () -> Void
    let onOpenPrivacyPolicy: () -> Void
    let onOpenOnlineSafety: () -> Void

    @AppStorage("notifyOnTaskDone") private var notifyOnTaskDone = true
    @AppStorage("notifyOnRewardRedeemed") private var notifyOnRewardRedeemed = true
    @AppStorage("isDarkTheme") private var isDarkTheme = false

    private var userEmail: String {
        Auth.auth().currentUser?.email ?? "Onbekend"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Account
                SettingsCardView(title: "Account") {
                    Text("Ingelogd als")
                        .font(.caption)
                    Text(userEmail)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer().frame(height: 8)
                    Text("Later kan je hier ook je wachtwoord of account beheren.")
                        .font(.caption)
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
                    Button(action: onOpenOnlineSafety) {
                        HStack {
                            Image(systemName: "shield")
                            Text("Online Veiligheid Instellingen")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                // Toestelmodus
                SettingsCardView(title: "Toestelmodus") {
                    Text(isDeviceForChild
                         ? "Dit toestel is momenteel ingesteld als kindapparaat."
                         : "Dit toestel is momenteel een ouderapparaat.")
                        .font(.caption)
                    Spacer().frame(height: 8)
                    if isDeviceForChild {
                        Button("Maak dit een ouderapparaat", action: onSetDeviceForParent)
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                    } else {
                        Button("Dit toestel gebruiken als kindapparaat", action: onSetDeviceForChild)
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Gezinsmoment
                SettingsCardView(title: "Gezinsmoment") {
                    if !familyTimeActive {
                        Text("Start een tijdelijke schermpauze voor het hele gezin.")
                            .font(.caption)
                        Spacer().frame(height: 8)
                        Button("Gezinsmoment starten", action: onToggleFamilyTime)
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Gezinsmoment is nu actief. Schermen even aan de kant.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer().frame(height: 8)
                        Button("Gezinsmoment stoppen", action: onToggleFamilyTime)
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                    }
                }

                // App-instellingen
                SettingsCardView(title: "App-instellingen") {
                    SettingsSwitchRow(label: "Melding bij voltooide taak", isOn: $notifyOnTaskDone)
                    Spacer().frame(height: 8)
                    SettingsSwitchRow(label: "Melding bij ingewisselde beloning", isOn: $notifyOnRewardRedeemed)
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
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                }

                // Over MissionZebra
                SettingsCardView(title: "Over MissionZebra") {
                    Text("MissionZebra helpt je kinderen op een speelse manier met schermtijd omgaan door taken, beloningen en duidelijke afspraken te combineren.")
                        .font(.caption)
                    Spacer().frame(height: 12)

                    Link("Bekijk privacy policy", destination: URL(string: "https://missionzebra.be/privacy-policy-nl.html")!)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)

                    Link("Bekijk terms of service", destination: URL(string: "https://missionzebra.be/terms-nl.html")!)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                }

                // Actions
                Button("Premium Dashboard", action: onGoToPremiumDashboard)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)

                Button(action: onLogout) {
                    Text("Afmelden")
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Spacer().frame(height: 16)
            }
            .padding(.horizontal, 16)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let hasPin = ParentPinManager.shared.hasParentPin()
            let label = hasPin ? "Nieuwe ouder-PIN (4 cijfers)" : "Stel ouder-PIN in (4 cijfers)"

            TextField(label, text: $pin)
                .keyboardType(.numberPad)
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
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
    }
}
