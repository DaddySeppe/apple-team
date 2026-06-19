import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging

final class FirebaseMessagingManager: NSObject, MessagingDelegate {
    static let shared = FirebaseMessagingManager()

    private let firestore = Firestore.firestore()
    private let auth = Auth.auth()

    private override init() {}

    func refreshAndStoreToken() {
        Messaging.messaging().token { [weak self] token, error in
            guard error == nil, let token else { return }
            self?.saveTokenToFirestore(token)
        }
    }

    func saveTokenToFirestore(_ token: String) {
        guard let user = auth.currentUser else { return }
        firestore.collection("parents").document(user.uid).setData([
            "fcmTokens": FieldValue.arrayUnion([token])
        ], merge: true)
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        saveTokenToFirestore(fcmToken)
    }
}
