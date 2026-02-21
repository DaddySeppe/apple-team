import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class RewardFirebaseRepository: ObservableObject {
    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()

    private var rewardsCollection: CollectionReference? {
        guard let uid = auth.currentUser?.uid else { return nil }
        return firestore.collection("parents").document(uid).collection("rewards")
    }

    func rewardsFlow() -> AnyPublisher<[Reward], Never> {
        let subject = CurrentValueSubject<[Reward], Never>([])

        guard let user = auth.currentUser else {
            return Just([]).eraseToAnyPublisher()
        }

        let collection = firestore.collection("parents").document(user.uid).collection("rewards")

        let listener = collection.addSnapshotListener { snapshot, error in
            guard let snapshot = snapshot, error == nil else {
                return
            }

            let rewards: [Reward] = snapshot.documents.map { doc in
                let data = doc.data()
                return Reward(
                    id: doc.documentID,
                    title: data["title"] as? String ?? "",
                    costPoints: data["costPoints"] as? Int ?? 0,
                    childId: data["childId"] as? String,
                    redeemed: data["redeemed"] as? Bool ?? false,
                    requested: data["requested"] as? Bool ?? false
                )
            }

            subject.send(rewards)
        }

        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    func addReward(title: String, costPoints: Int, childId: String) async -> Result<Void, Error> {
        do {
            guard let collection = rewardsCollection else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            _ = try await collection.addDocument(data: [
                "title": title,
                "costPoints": costPoints,
                "childId": childId,
                "redeemed": false,
                "requested": false
            ])
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func updateReward(reward: Reward) async -> Result<Void, Error> {
        do {
            guard let collection = rewardsCollection else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            try await collection.document(reward.id).setData([
                "title": reward.title,
                "costPoints": reward.costPoints,
                "childId": reward.childId as Any,
                "redeemed": reward.redeemed,
                "requested": reward.requested
            ], merge: true)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    private func setRewardRequestedInternal(rewardId: String, requested: Bool) async -> Result<Void, Error> {
        do {
            guard let collection = rewardsCollection else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            try await collection.document(rewardId).updateData(["requested": requested])
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func requestReward(rewardId: String) async -> Result<Void, Error> {
        return await setRewardRequestedInternal(rewardId: rewardId, requested: true)
    }

    func cancelRewardRequest(rewardId: String) async -> Result<Void, Error> {
        return await setRewardRequestedInternal(rewardId: rewardId, requested: false)
    }

    func deleteReward(rewardId: String) async -> Result<Void, Error> {
        do {
            guard let collection = rewardsCollection else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            try await collection.document(rewardId).delete()
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func redeemReward(rewardId: String) async -> Result<Void, Error> {
        do {
            guard let user = auth.currentUser else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }

            let parentDoc = firestore.collection("parents").document(user.uid)
            let rewardRef = parentDoc.collection("rewards").document(rewardId)

            try await firestore.runTransaction { transaction, errorPointer in
                let rewardSnap: DocumentSnapshot
                do {
                    rewardSnap = try transaction.getDocument(rewardRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }

                let cost = rewardSnap.data()?["costPoints"] as? Int ?? 0
                let childId = rewardSnap.data()?["childId"] as? String
                let redeemed = rewardSnap.data()?["redeemed"] as? Bool ?? false

                guard let childId = childId else {
                    let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Geen kind gekoppeld aan beloning"])
                    errorPointer?.pointee = error
                    return nil
                }

                if redeemed {
                    let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Beloning is al ingewisseld"])
                    errorPointer?.pointee = error
                    return nil
                }

                let childRef = parentDoc.collection("children").document(childId)

                let childSnap: DocumentSnapshot
                do {
                    childSnap = try transaction.getDocument(childRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }

                let currentPoints = childSnap.data()?["points"] as? Int ?? 0

                if currentPoints < cost {
                    let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet genoeg punten"])
                    errorPointer?.pointee = error
                    return nil
                }

                transaction.updateData(["points": currentPoints - cost], forDocument: childRef)
                transaction.updateData([
                    "redeemed": true,
                    "requested": false
                ], forDocument: rewardRef)

                return nil
            }

            return .success(())
        } catch {
            return .failure(error)
        }
    }
}
