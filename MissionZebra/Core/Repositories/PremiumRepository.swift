import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

struct PremiumStatus: Equatable {
    var isPremium: Bool = false
    var premiumUntil: Int64? = nil

    var expiresAt: Date? {
        premiumUntil.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
    }
}

final class PremiumRepository {
    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()

    func premiumStatusFlow() -> AnyPublisher<PremiumStatus, Never> {
        let subject = CurrentValueSubject<PremiumStatus, Never>(PremiumStatus())

        guard let user = auth.currentUser else {
            return Just(PremiumStatus()).eraseToAnyPublisher()
        }

        var lastKnownStatus = PremiumStatus()
        let listener = firestore.collection("parents").document(user.uid)
            .addSnapshotListener { snapshot, error in
                guard error == nil, let data = snapshot?.data() else {
                    subject.send(lastKnownStatus)
                    return
                }

                let rawIsPremium = FirestoreDecoding.bool(data["isPremium"])
                let premiumUntil = Self.millis(data["premiumUntil"])
                let isStillValid = rawIsPremium && (premiumUntil == nil || premiumUntil! > Self.nowMillis())

                lastKnownStatus = PremiumStatus(isPremium: isStillValid, premiumUntil: premiumUntil)
                subject.send(lastKnownStatus)
            }

        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    private static func millis(_ value: Any?) -> Int64? {
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        if let value = value as? Double { return Int64(value) }
        if let value = value as? NSNumber { return value.int64Value }
        if let timestamp = value as? Timestamp {
            return Int64(timestamp.dateValue().timeIntervalSince1970 * 1000)
        }
        return nil
    }

    private static func nowMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}
