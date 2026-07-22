import SwiftUI

private let privacyPolicyText = """
📄 MissionZebra Privacy Policy
Laatste update: [04/12/2025]
MissionZebra – Student Project ("wij", "ons", of "onze") ontwikkelt de MissionZebra-app, een tool waarmee gezinnen schermtijd op een positieve manier beheren. Deze Privacy Policy legt uit hoe wij persoonsgegevens verwerken wanneer je onze app gebruikt.
Door MissionZebra te gebruiken, ga je akkoord met deze privacyverklaring.

1. Welke gegevens verzamelen wij?
1.1. Gegevens die jij zelf invoert
• Naam van ouder-account
• Namen van kinderen
• Dagelijkse schermtijdlimieten
• Taken en beloningen
• Voortgang, punten, statistieken
➡️ Deze gegevens worden gebruikt om de functionaliteit van MissionZebra mogelijk te maken.

1.2. Inloggegevens
Wij gebruiken Firebase Authentication.
Mogelijke gegevens die Firebase verzamelt:
• E-mailadres
• Versleuteld wachtwoord
• Unieke User ID
Firebase slaat geen wachtwoorden in leesbare vorm op.

1.3. Automatisch verzamelde gegevens
MissionZebra kan gebruikmaken van Firebase-diensten die anonieme technische data verwerken:
• App-prestaties
• (Optioneel) foutmeldingen
• App-versie en apparaattype
Wij verzamelen geen locatiegegevens, geen contacten, geen foto's en geen trackinggegevens voor advertenties.

2. Waarvoor gebruiken wij deze gegevens?
Wij verwerken gegevens uitsluitend voor:
• Het laten functioneren van de app
• Het beheren van schermtijd
• Het opslaan van taken/beloningen
• Het veilig inloggen
• Verbeteringen van stabiliteit en gebruikerservaring
Wij gebruiken geen gegevens voor commerciële doeleinden.

3. Hoe verwerken en bewaren wij gegevens?
3.1. Firebase Firestore
Alle gegevens worden opgeslagen in Google Firebase (EU of US datacenters).
Firebase voldoet aan:
• GDPR
• ISO 27001
• SOC 1, SOC 2, SOC 3
Wij beperken toegang via Firestore Security Rules zodat gebruikers enkel hun eigen gegevens kunnen zien.

4. Kinderen & Ouderlijke toestemming
MissionZebra is ontworpen voor gebruik door ouders en kinderen.
• Accounts worden aangemaakt en beheerd door de ouder.
• Kinderen gebruiken de app onder toezicht van een ouder.
• Wij verzamelen géén persoonlijke gegevens van kinderen zonder toestemming van een ouder.
Dit is in lijn met GDPR-K en COPPA.

5. Delen wij gegevens met derden?
Wij delen geen persoonsgegevens met externe partijen, behalve:
✔ Firebase (Google Cloud)
Voor opslag, authenticatie en app-functionaliteit.
Google handelt als verwerker volgens GDPR.
❌ Geen verkoop van gegevens
❌ Geen advertenties of tracking
❌ Geen datadeling met social media

6. Hoe lang bewaren we gegevens?
Gegevens blijven bewaard zolang jouw account actief is.
Bij verwijdering van het account:
• Worden alle gekoppelde gegevens permanent verwijderd uit Firestore
• Verwijderen wij jouw Firebase Authentication-profiel

7. Jouw rechten (GDPR)
Als gebruiker heb je het recht om:
• Jouw gegevens in te zien
• Jouw gegevens te laten verwijderen
• Jouw gegevens te laten aanpassen
• Dataverwerking te beperken
• Een klacht in te dienen bij een gegevensautoriteit
Je kunt ons hiervoor altijd contacteren via:
📩 missionzebrahelp@gmail.com

8. Beveiliging
Wij implementeren beveiligingsmaatregelen zoals:
• Firestore Security Rules
• Versleutelde verbindingen (HTTPS)
• Beveiligde Firebase Authentication
Hoewel wij ons best doen om jouw gegevens te beschermen, is geen enkel systeem 100% veilig.

9. Contactinformatie
Voor vragen over deze Privacy Policy of dataverzoeken:
MissionZebra – Student Project
📩 missionzebrahelp@gmail.com

10. Wijzigingen aan deze Privacy Policy
Wij kunnen deze Privacy Policy van tijd tot tijd updaten. De nieuwste versie is altijd beschikbaar in de app en/of op onze website.
"""

struct PrivacyPolicyScreen: View {
    @EnvironmentObject var router: NavigationRouter

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy policy")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)

                Text(privacyPolicyText)
                    .font(.body)

                HStack {
                    Spacer()
                    Button("Terug") {
                        router.goBack()
                    }
                    .buttonStyle(MZPrimaryButtonStyle())
                }
            }
            .padding(20)
        }
        .background(Color(.systemBackground))
    }
}
