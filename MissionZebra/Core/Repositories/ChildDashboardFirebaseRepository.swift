import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class ChildDashboardFirebaseRepository: ObservableObject {
    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()

    private func parentId() -> String {
        guard let user = auth.currentUser else {
            fatalError("Not logged in")
        }
        return user.uid
    }

    private func childDoc(childId: String) -> DocumentReference {
        return firestore
            .collection("parents")
            .document(parentId())
            .collection("children")
            .document(childId)
    }

    func childFlow(childId: String) -> AnyPublisher<Child?, Never> {
        let subject = CurrentValueSubject<Child?, Never>(nil)

        let listener = childDoc(childId: childId)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot, error == nil, snapshot.exists else {
                    subject.send(nil)
                    return
                }

                let data = snapshot.data() ?? [:]
                let child = Child(
                    id: snapshot.documentID,
                    name: data["name"] as? String ?? "",
                    points: data["points"] as? Int ?? 0,
                    dailyScreenTimeUsedMinutes: data["dailyScreenTimeUsedMinutes"] as? Int ?? 0,
                    dailyScreenTimeLimitMinutes: data["dailyScreenTimeLimitMinutes"] as? Int ?? 120,
                    isBlocked: data["isBlocked"] as? Bool ?? false,
                    purchasedAccessoryIds: data["purchasedAccessoryIds"] as? [String] ?? [],
                    equippedAccessoryId: data["equippedAccessoryId"] as? String,
                    streak: data["streak"] as? Int ?? 0,
                    lastStreakCheckDate: data["lastStreakCheckDate"] as? String,
                    motivationalMessage: data["motivationalMessage"] as? String,
                    screenTimeHistory: data["screenTimeHistory"] as? [String: Int] ?? [:]
                )
                subject.send(child)
            }

        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    func tasksFlow(childId: String) -> AnyPublisher<[MZTask], Never> {
        let subject = CurrentValueSubject<[MZTask], Never>([])

        let listener = firestore
            .collection("parents")
            .document(parentId())
            .collection("tasks")
            .whereField("childId", isEqualTo: childId)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot, error == nil else {
                    subject.send([])
                    return
                }

                let tasks: [MZTask] = snapshot.documents.map { doc in
                    let data = doc.data()
                    return MZTask(
                        id: doc.documentID,
                        title: data["title"] as? String ?? "",
                        points: data["points"] as? Int ?? 0,
                        childId: data["childId"] as? String,
                        pendingApproval: data["pendingApproval"] as? Bool ?? false,
                        completed: data["completed"] as? Bool ?? false
                    )
                }
                subject.send(tasks)
            }

        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    func rewardsFlow(childId: String) -> AnyPublisher<[Reward], Never> {
        let subject = CurrentValueSubject<[Reward], Never>([])

        let listener = firestore
            .collection("parents")
            .document(parentId())
            .collection("rewards")
            .whereField("childId", isEqualTo: childId)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot, error == nil else {
                    subject.send([])
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

    func updateDailyScreenTime(childId: String, usedMinutes: Int) async {
        try? await childDoc(childId: childId)
            .updateData(["dailyScreenTimeUsedMinutes": usedMinutes])
    }

    func markTaskDone(childId: String, taskId: String) async {
        try? await firestore
            .collection("parents")
            .document(parentId())
            .collection("tasks")
            .document(taskId)
            .updateData(["pendingApproval": true])
    }

    func redeemReward(childId: String, rewardId: String) async {
        try? await firestore
            .collection("parents")
            .document(parentId())
            .collection("rewards")
            .document(rewardId)
            .updateData(["redeemed": true])
    }

    func endSession(childId: String) async {
        try? await childDoc(childId: childId).setData([
            "lastSessionEndedAt": Timestamp(date: Date())
        ], merge: true)
    }
}
