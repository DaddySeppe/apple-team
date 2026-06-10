import Foundation
import FirebaseAuth
import FirebaseFirestore

struct NotificationPreferences: Equatable {
    var notifyOnTaskDone: Bool = true
    var notifyOnRewardRedeemed: Bool = true
    var rewardsEnabled: Bool = false
}

final class NotificationPreferencesRepository {
    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()

    func loadPreferences() async -> NotificationPreferences {
        guard let user = auth.currentUser else { return NotificationPreferences() }

        do {
            let snapshot = try await firestore.collection("parents").document(user.uid).getDocument()
            let data = snapshot.data() ?? [:]
            return NotificationPreferences(
                notifyOnTaskDone: data["notifyOnTaskDone"] as? Bool ?? true,
                notifyOnRewardRedeemed: data["notifyOnRewardRedeemed"] as? Bool ?? true,
                rewardsEnabled: data["rewardsEnabled"] as? Bool ?? false
            )
        } catch {
            return NotificationPreferences()
        }
    }

    func savePreferences(_ preferences: NotificationPreferences) async -> Result<Void, Error> {
        do {
            guard let user = auth.currentUser else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            try await firestore.collection("parents").document(user.uid).setData([
                "notifyOnTaskDone": preferences.notifyOnTaskDone,
                "notifyOnRewardRedeemed": preferences.notifyOnRewardRedeemed,
                "rewardsEnabled": preferences.rewardsEnabled
            ], merge: true)
            return .success(())
        } catch {
            return .failure(error)
        }
    }
}
