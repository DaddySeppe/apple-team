import SwiftUI

struct TutorialStep {
    let icon: String      // SF Symbol name
    let iconBg: Color
    let iconColor: Color
    let title: String
    let description: String
    let hint: String?
}

struct InteractiveStep {
    let icon: String
    let iconBg: Color
    let iconColor: Color
    let title: String
    let description: String
    let tabIndex: Int
}

struct TutorialScreen: View {
    @EnvironmentObject var router: NavigationRouter
    var fromOnboarding: Bool = false

    @State private var currentStep = 0

    private let steps: [TutorialStep] = [
        TutorialStep(icon: "person.fill", iconBg: Color(red: 0.86, green: 0.99, blue: 0.91), iconColor: Color(red: 0.09, green: 0.64, blue: 0.26),
                     title: "Kinderen toevoegen",
                     description: "Ga naar het tabblad Kinderen en voeg je kind toe. Stel een dagelijkse schermtijdlimiet in en geef de geboortedatum op.",
                     hint: "👆 Tik onderaan het scherm op het tabblad 'Kinderen'"),
        TutorialStep(icon: "list.bullet", iconBg: Color(red: 0.88, green: 0.91, blue: 1.0), iconColor: Color(red: 0.31, green: 0.28, blue: 0.9),
                     title: "Taken aanmaken",
                     description: "Maak in het tabblad Taken opdrachten aan voor je kind. Geef punten mee en eventueel een vervaldatum. Je kind markeert taken als klaar — jij keurt ze goed of af.",
                     hint: "👆 Tik op het tabblad 'Taken' om taken aan te maken voor je kind"),
        TutorialStep(icon: "star.fill", iconBg: Color(red: 1.0, green: 0.95, blue: 0.78), iconColor: Color(red: 0.85, green: 0.47, blue: 0.04),
                     title: "Beloningen instellen",
                     description: "Voeg in het tabblad Beloningen beloningen toe die je kind kan inwisselen met zijn punten. Denk aan extra schermtijd, een snoepje of een leuke activiteit.",
                     hint: "👆 Tik op het tabblad 'Beloningen' om beloningen toe te voegen"),
        TutorialStep(icon: "phone.fill", iconBg: Color(red: 1.0, green: 0.89, blue: 0.9), iconColor: Color(red: 0.88, green: 0.11, blue: 0.28),
                     title: "Kindapparaat instellen",
                     description: "Op het toestel dat je kind gebruikt, kies je in Instellingen → Toestelmodus voor \"Dit toestel is voor een kind\". Je kind ziet dan zijn eigen dashboard met taken, beloningen en zijn zebra.",
                     hint: "👆 Ga op het kindapparaat naar Instellingen → Toestelmodus"),
        TutorialStep(icon: "trophy.fill", iconBg: Color(red: 0.99, green: 0.91, blue: 0.95), iconColor: Color(red: 0.86, green: 0.15, blue: 0.47),
                     title: "Punten & badges verdienen",
                     description: "Je kind verdient punten door taken te voltooien en de telefoon neer te leggen. Ze kunnen ook badges ontgrendelen — een leuke extra beloning voor consequent gedrag!",
                     hint: nil),
        TutorialStep(icon: "person.3.fill", iconBg: Color(red: 0.86, green: 0.99, blue: 0.91), iconColor: Color(red: 0.09, green: 0.64, blue: 0.26),
                     title: "Gezinsmoment",
                     description: "Activeer Gezinsmoment in de Instellingen om het kindapparaat tijdelijk te blokkeren. Handig aan tafel, bij gezinsmomenten of voor het slapengaan.",
                     hint: nil),
        TutorialStep(icon: "lock.fill", iconBg: Color(red: 0.93, green: 0.91, blue: 0.99), iconColor: Color(red: 0.49, green: 0.24, blue: 0.94),
                     title: "Ouder‑PIN",
                     description: "Stel een 4‑cijferige PIN in via Instellingen → Beveiliging. Je kind kan zonder deze code niet van profiel wisselen of afmelden.",
                     hint: nil),
        TutorialStep(icon: "star.circle.fill", iconBg: Color(red: 0.88, green: 0.95, blue: 1.0), iconColor: Color(red: 0.0, green: 0.5, blue: 0.78),
                     title: "Zebra aanpassen",
                     description: "Je kind kan zijn punten uitgeven in de Zebra Winkel om zijn zebra accessoires en een uniek uiterlijk te geven. Een extra motivatie!",
                     hint: nil)
    ]

    private let interactiveSteps: [InteractiveStep] = [
        InteractiveStep(icon: "person.fill", iconBg: Color(red: 0.86, green: 0.99, blue: 0.91), iconColor: Color(red: 0.09, green: 0.64, blue: 0.26),
                        title: "Kinderen",
                        description: "Bekijk je kinderen en voeg er nieuwe toe.",
                        tabIndex: 0),
        InteractiveStep(icon: "list.bullet", iconBg: Color(red: 0.88, green: 0.91, blue: 1.0), iconColor: Color(red: 0.31, green: 0.28, blue: 0.9),
                        title: "Taken",
                        description: "Hier maak je taken aan en keur je ze goed.",
                        tabIndex: 1),
        InteractiveStep(icon: "star.fill", iconBg: Color(red: 1.0, green: 0.95, blue: 0.78), iconColor: Color(red: 0.85, green: 0.47, blue: 0.04),
                        title: "Beloningen",
                        description: "Voeg beloningen toe of wissel punten in.",
                        tabIndex: 2),
        InteractiveStep(icon: "lock.fill", iconBg: Color(red: 0.93, green: 0.91, blue: 0.99), iconColor: Color(red: 0.49, green: 0.24, blue: 0.94),
                        title: "Beveiliging",
                        description: "Manage PIN, privacy en tutorial.",
                        tabIndex: 3)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if !fromOnboarding {
                    Button(action: { router.goBack() }) {
                        Image(systemName: "arrow.left")
                            .font(.title3)
                    }
                }
                Text("Hoe werkt MissionZebra?")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding()

            HStack(spacing: 6) {
                ForEach(0..<steps.count, id: \.self) { idx in
                    Circle()
                        .fill(idx == currentStep ? Color.accentColor : Color.primary.opacity(0.2))
                        .frame(width: idx == currentStep ? 10 : 6, height: idx == currentStep ? 10 : 6)
                }
            }
            .padding(.top, 8)

            Spacer().frame(height: 4)

            Text("Stap \(currentStep + 1) van \(steps.count)")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer().frame(height: 16)

            ZStack {
                ForEach(0..<steps.count, id: \.self) { idx in
                    if idx == currentStep {
                        stepView(for: steps[idx])
                            .transition(.asymmetric(insertion: .move(edge: currentStep > idx ? .trailing : .leading).combined(with: .opacity),
                                                    removal: .move(edge: currentStep > idx ? .leading : .trailing).combined(with: .opacity)))
                    }
                }
            }
            .animation(.easeInOut, value: currentStep)
            .frame(maxHeight: .infinity)

            HStack {
                if currentStep > 0 {
                    Button(action: { currentStep -= 1 }) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("Vorige")
                        }
                        .padding()
                    }
                } else {
                    Spacer().frame(width: 1)
                }

                Spacer()

                if currentStep < steps.count - 1 {
                    Button(action: { currentStep += 1 }) {
                        HStack {
                            Text("Volgende")
                            Image(systemName: "arrow.right")
                        }
                        .padding()
                    }
                } else {
                    Button(action: finishTutorial) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text(fromOnboarding ? "Aan de slag" : "Klaar")
                        }
                        .padding()
                    }
                }
            }
            .padding()
        }
    }

    private func stepView(for step: TutorialStep) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(step.iconBg)
                        .frame(width: 100, height: 100)
                    Image(systemName: step.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .foregroundColor(step.iconColor)
                }

                Text(step.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(step.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                if let hint = step.hint {
                    CardView(bg: step.iconBg) {
                        HStack {
                            Image(systemName: "hand.point.up.left")
                                .foregroundColor(step.iconColor)
                            Text(hint)
                                .foregroundColor(step.iconColor)
                                .fontWeight(.semibold)
                        }
                        .padding()
                    }
                }

                Spacer()
            }
            .padding()
        }
    }

    private func finishTutorial() {
        if fromOnboarding {
            Task {
                _ = await TaskFirebaseRepository().deleteTutorialData()
                _ = await ParentChildrenFirebaseRepository().deleteTutorialChildren()
                SessionManager.shared.clearTutorial()
                router.navigate(to: .deviceMode)
            }
        } else {
            router.goBack()
        }
    }
}

struct CardView<Content: View>: View {
    let bg: Color
    let content: Content
    init(bg: Color, @ViewBuilder content: () -> Content) {
        self.bg = bg
        self.content = content()
    }
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(bg)
            .overlay(content)
    }
}

struct InteractiveTutorialOverlay: View {
    var onDismiss: () -> Void
    var onSwitchToTab: (Int) -> Void

    @State private var currentStep = 0
    private let steps: [InteractiveStep] = [
        InteractiveStep(icon: "person.fill", iconBg: Color(red: 0.86, green: 0.99, blue: 0.91), iconColor: Color(red: 0.09, green: 0.64, blue: 0.26),
                        title: "Kinderen",
                        description: "Bekijk je kinderen en voeg er nieuwe toe.",
                        tabIndex: 0),
        InteractiveStep(icon: "list.bullet", iconBg: Color(red: 0.88, green: 0.91, blue: 1.0), iconColor: Color(red: 0.31, green: 0.28, blue: 0.9),
                        title: "Taken",
                        description: "Hier maak je taken aan en keur je ze goed.",
                        tabIndex: 1),
        InteractiveStep(icon: "star.fill", iconBg: Color(red: 1.0, green: 0.95, blue: 0.78), iconColor: Color(red: 0.85, green: 0.47, blue: 0.04),
                        title: "Beloningen",
                        description: "Voeg beloningen toe of wissel punten in.",
                        tabIndex: 2),
        InteractiveStep(icon: "lock.fill", iconBg: Color(red: 0.93, green: 0.91, blue: 0.99), iconColor: Color(red: 0.49, green: 0.24, blue: 0.94),
                        title: "Beveiliging",
                        description: "Manage PIN, privacy en tutorial.",
                        tabIndex: 3)
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { }

            VStack {
                Spacer()
                currentCard
                    .animation(.easeInOut, value: currentStep)
                    .transition(.move(edge: .bottom))
                    .padding()
            }
        }
        .onChange(of: currentStep) { new in
            onSwitchToTab(steps[new].tabIndex)
        }
    }

    private var currentCard: some View {
        let step = steps[currentStep]
        return VStack(spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    ForEach(0..<steps.count, id: \.self) { idx in
                        Circle()
                            .fill(idx == currentStep ? Color.accentColor : Color.primary.opacity(0.2))
                            .frame(width: idx == currentStep ? 10 : 6, height: idx == currentStep ? 10 : 6)
                    }
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                        .padding(8)
                }
            }

            HStack(alignment: .center) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(step.iconBg)
                        .frame(width: 52, height: 52)
                    Image(systemName: step.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .foregroundColor(step.iconColor)
                }
                Spacer().frame(width: 12)
                VStack(alignment: .leading) {
                    Text(step.title)
                        .font(.headline)
                        .fontWeight(.bold)
                    Text(step.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                if currentStep > 0 {
                    Button(action: { currentStep -= 1 }) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("Vorige")
                        }
                        .padding(8)
                    }
                } else {
                    Spacer().frame(width: 1)
                }

                Spacer()

                if currentStep < steps.count - 1 {
                    Button(action: { currentStep += 1 }) {
                        HStack {
                            Text("Volgende")
                            Image(systemName: "arrow.right")
                        }
                        .padding(8)
                    }
                } else {
                    Button(action: onDismiss) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("Klaar")
                        }
                        .padding(8)
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
        .shadow(radius: 4)
    }
}