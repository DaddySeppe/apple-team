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
                let equippedItems = FirestoreDecoding.stringMap(data["equippedItems"])
                let child = Child(
                    id: snapshot.documentID,
                    name: data["name"] as? String ?? "",
                    points: FirestoreDecoding.int(data["points"]),
                    dailyScreenTimeUsedMinutes: FirestoreDecoding.int(data["dailyScreenTimeUsedMinutes"]),
                    dailyScreenTimeLimitMinutes: FirestoreDecoding.int(data["dailyScreenTimeLimitMinutes"], default: 120),
                    isBlocked: FirestoreDecoding.bool(data["isBlocked"]),
                    purchasedAccessoryIds: data["purchasedAccessoryIds"] as? [String] ?? [],
                    equippedAccessoryId: data["equippedAccessoryId"] as? String,
                    equippedItems: equippedItems.isEmpty ? Self.legacyEquippedItems(data["equippedAccessoryId"] as? String) : equippedItems,
                    streak: FirestoreDecoding.int(data["streak"]),
                    lastStreakCheckDate: data["lastStreakCheckDate"] as? String,
                    motivationalMessage: data["motivationalMessage"] as? String,
                    screenTimeHistory: FirestoreDecoding.intMap(data["screenTimeHistory"]),
                    deviceScreenTimes: FirestoreDecoding.intMap(data["deviceScreenTimes"]),
                    deviceNames: FirestoreDecoding.stringMap(data["deviceNames"]),
                    deviceScreenTimeDates: FirestoreDecoding.stringMap(data["deviceScreenTimeDates"]),
                    screenTimePermissionGranted: data["screenTimePermissionGranted"] as? Bool
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
                        points: FirestoreDecoding.int(data["points"]),
                        childId: data["childId"] as? String,
                        childName: data["childName"] as? String,
                        parentId: data["parentId"] as? String,
                        pendingApproval: FirestoreDecoding.bool(data["pendingApproval"]),
                        completed: FirestoreDecoding.bool(data["completed"]),
                        dueDate: data["dueDate"] as? String,
                        recurrence: data["recurrence"] as? String,
                        purpose: data["purpose"] as? String ?? "",
                        contributionTarget: data["contributionTarget"] as? String ?? "",
                        childReflection: data["childReflection"] as? String ?? "",
                        effortLevel: data["effortLevel"] as? String ?? "",
                        parentFeedback: data["parentFeedback"] as? String ?? "",
                        createdAt: FirestoreDecoding.int64(data["createdAt"]),
                        updatedAt: FirestoreDecoding.int64(data["updatedAt"])
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

    private static func legacyEquippedItems(_ accessoryId: String?) -> [String: String] {
        guard let accessoryId else { return [:] }
        return [ZebraCategory.HOOFD.rawValue: accessoryId]
    }
}
