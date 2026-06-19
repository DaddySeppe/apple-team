import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
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
    private let functions = Functions.functions(region: "europe-west1")

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

    func verifyApplePremiumPurchase(
        transactionId: String,
        originalTransactionId: String,
        productId: String,
        signedTransactionInfo: String,
        source: String
    ) async -> Result<PremiumStatus, Error> {
        do {
            guard auth.currentUser != nil else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            let request = ApplePremiumVerificationRequest(
                transactionId: transactionId,
                originalTransactionId: originalTransactionId,
                productId: productId,
                signedTransactionInfo: signedTransactionInfo,
                source: source
            )
            let response = try await functions.httpsCallable("verifyApplePremiumPurchase").call(request.callableData)
            let data = response.data as? [String: Any] ?? [:]
            let status = PremiumStatus(
                isPremium: FirestoreDecoding.bool(data["isPremium"]),
                premiumUntil: Self.millis(data["premiumUntil"])
            )
            return .success(status)
        } catch {
            return .failure(error)
        }
    }
}
