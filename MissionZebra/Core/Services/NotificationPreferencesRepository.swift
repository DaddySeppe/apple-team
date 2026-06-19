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
                notifyOnTaskDone: FirestoreDecoding.bool(data["notifyOnTaskDone"], default: true),
                notifyOnRewardRedeemed: FirestoreDecoding.bool(data["notifyOnRewardRedeemed"], default: true),
                rewardsEnabled: FirestoreDecoding.bool(data["rewardsEnabled"])
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
