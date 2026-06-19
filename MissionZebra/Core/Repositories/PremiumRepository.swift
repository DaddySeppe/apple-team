import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

private let permanentPremiumTestEmail = "test@gmail.com"

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

        if user.email?.caseInsensitiveCompare(permanentPremiumTestEmail) == .orderedSame {
            grantPermanentPremiumForTestAccount(userId: user.uid)
            return Just(PremiumStatus(isPremium: true, premiumUntil: nil)).eraseToAnyPublisher()
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

    private func grantPermanentPremiumForTestAccount(userId: String) {
        firestore.collection("parents").document(userId).setData([
            "isPremium": true,
            "premiumUntil": FieldValue.delete(),
            "premiumSource": "testAccount"
        ], merge: true)
    }

    func activatePremiumFromStoreKit(
        originalTransactionId: String,
        premiumUntil: Int64?,
        source: String
    ) async -> Result<Void, Error> {
        do {
            guard let user = auth.currentUser else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            var data: [String: Any] = [
                "isPremium": true,
                "iosOriginalTransactionId": originalTransactionId,
                "premiumSource": source,
                "premiumUpdatedAt": Int64(Date().timeIntervalSince1970 * 1000)
            ]
            if let premiumUntil {
                data["premiumUntil"] = premiumUntil
            } else {
                data["premiumUntil"] = FieldValue.delete()
            }
            try await firestore.collection("parents").document(user.uid).setData(data, merge: true)
            return .success(())
        } catch {
            return .failure(error)
        }
    }
}
