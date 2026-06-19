import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class TaskFirebaseRepository: ObservableObject {
    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()

    private var tasksCollection: CollectionReference? {
        guard let uid = auth.currentUser?.uid else { return nil }
        return firestore.collection("parents").document(uid).collection("tasks")
    }

    func tasksFlow() -> AnyPublisher<[MZTask], Never> {
        let subject = CurrentValueSubject<[MZTask], Never>([])

        guard let collection = tasksCollection else {
            return Just([]).eraseToAnyPublisher()
        }

        let listener = collection.addSnapshotListener { snapshot, error in
            guard let snapshot = snapshot, error == nil else {
                subject.send([])
                return
            }

            let tasks: [MZTask] = snapshot.documents.map { doc in
                let data = doc.data()
                return MZTask(
                    id: doc.documentID,
                    title: data["title"] as? String ?? "",
                    points: Self.intValue(data["points"]),
                    childId: data["childId"] as? String,
                    childName: data["childName"] as? String,
                    parentId: data["parentId"] as? String,
                    pendingApproval: data["pendingApproval"] as? Bool ?? false,
                    completed: data["completed"] as? Bool ?? false,
                    dueDate: data["dueDate"] as? String,
                    recurrence: data["recurrence"] as? String,
                    purpose: data["purpose"] as? String ?? "",
                    contributionTarget: data["contributionTarget"] as? String ?? "",
                    childReflection: data["childReflection"] as? String ?? "",
                    effortLevel: data["effortLevel"] as? String ?? "",
                    parentFeedback: data["parentFeedback"] as? String ?? "",
                    createdAt: Self.int64Value(data["createdAt"]),
                    updatedAt: Self.int64Value(data["updatedAt"])
                )
            }

            subject.send(tasks)
        }

        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    func deleteTask(taskId: String) async -> Result<Void, Error> {
        do {
            guard let user = auth.currentUser else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            try await firestore.collection("parents").document(user.uid)
                .collection("tasks").document(taskId).delete()
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func deleteTutorialData() async -> Result<Void, Error> {
        do {
            guard let collection = tasksCollection else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            let snapshot = try await collection.whereField("isTutorial", isEqualTo: true).getDocuments()
            guard !snapshot.documents.isEmpty else { return .success(()) }

            let batch = firestore.batch()
            snapshot.documents.forEach { batch.deleteDocument($0.reference) }
            try await batch.commit()
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func addTask(
        title: String,
        points: Int,
        childId: String,
        dueDate: String? = nil,
        recurrence: String? = nil,
        purpose: String = "",
        contributionTarget: String = "",
        isTutorial: Bool = false
    ) async -> Result<Void, Error> {
        do {
            guard let collection = tasksCollection else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            let now = Self.nowMillis()
            var data: [String: Any] = [
                "title": title,
                "points": points,
                "childId": childId,
                "pendingApproval": false,
                "completed": false,
                "dueDate": dueDate ?? Self.todayKey(),
                "purpose": purpose,
                "contributionTarget": contributionTarget,
                "childReflection": "",
                "effortLevel": "",
                "parentFeedback": "",
                "createdAt": now,
                "updatedAt": now,
                "isTutorial": isTutorial
            ]
            if let recurrence {
                data["recurrence"] = recurrence
            }
            _ = try await collection.addDocument(data: data)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func requestTaskCompletion(
        taskId: String,
        childReflection: String = "",
        effortLevel: String = ""
    ) async -> Result<Void, Error> {
        do {
            guard let collection = tasksCollection else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            try await collection.document(taskId).updateData([
                "pendingApproval": true,
                "childReflection": childReflection,
                "effortLevel": effortLevel,
                "updatedAt": Self.nowMillis()
            ])
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func approveTask(taskId: String, parentFeedback: String = "") async -> Result<Void, Error> {
        do {
            guard let user = auth.currentUser else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            guard let collection = tasksCollection else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }

            let parentDoc = firestore.collection("parents").document(user.uid)
            let taskRef = collection.document(taskId)
            let snapshot = try await taskRef.getDocument()
            let data = snapshot.data() ?? [:]
            let points = Self.intValue(data["points"])
            let childId = data["childId"] as? String
            let recurrence = data["recurrence"] as? String
            let dueDate = data["dueDate"] as? String

            if let childId = childId {
                let childRef = parentDoc.collection("children").document(childId)
                try await childRef.updateData(["points": FieldValue.increment(Int64(points))])
            }

            if recurrence == MZTask.recurrenceWeekly {
                try await taskRef.updateData([
                    "completed": false,
                    "pendingApproval": false,
                    "dueDate": TaskOrdering.nextWeeklyDueDate(from: dueDate),
                    "childReflection": "",
                    "effortLevel": "",
                    "parentFeedback": parentFeedback,
                    "updatedAt": Self.nowMillis()
                ])
            } else {
                try await taskRef.updateData([
                    "completed": true,
                    "pendingApproval": false,
                    "parentFeedback": parentFeedback,
                    "updatedAt": Self.nowMillis()
                ])
            }
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func rejectTask(taskId: String) async -> Result<Void, Error> {
        do {
            guard let collection = tasksCollection else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            try await collection.document(taskId).updateData([
                "pendingApproval": false,
                "completed": false,
                "updatedAt": Self.nowMillis()
            ])
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func updateTask(task: MZTask) async -> Result<Void, Error> {
        do {
            guard !task.id.isEmpty else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Task ID cannot be empty"])
            }
            guard let collection = tasksCollection else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            let now = Self.nowMillis()
            var data: [String: Any] = [
                "title": task.title,
                "points": task.points,
                "childId": task.childId as Any,
                "childName": task.childName as Any,
                "parentId": task.parentId as Any,
                "pendingApproval": task.pendingApproval,
                "completed": task.completed,
                "purpose": task.purpose,
                "contributionTarget": task.contributionTarget,
                "childReflection": task.childReflection,
                "effortLevel": task.effortLevel,
                "parentFeedback": task.parentFeedback,
                "createdAt": task.createdAt > 0 ? task.createdAt : now,
                "updatedAt": now
            ]
            data["dueDate"] = task.dueDate ?? FieldValue.delete()
            data["recurrence"] = task.recurrence ?? FieldValue.delete()
            try await collection.document(task.id).setData(data, merge: true)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    private static func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private static func nowMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    private static func intValue(_ value: Any?) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? Int64 { return Int(value) }
        if let value = value as? NSNumber { return value.intValue }
        return 0
    }

    private static func int64Value(_ value: Any?) -> Int64 {
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        if let value = value as? NSNumber { return value.int64Value }
        return 0
    }
}
