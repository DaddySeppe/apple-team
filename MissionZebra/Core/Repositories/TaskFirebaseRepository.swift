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
                    points: data["points"] as? Int ?? 0,
                    childId: data["childId"] as? String,
                    pendingApproval: data["pendingApproval"] as? Bool ?? false,
                    completed: data["completed"] as? Bool ?? false,
                    dueDate: data["dueDate"] as? String,
                    recurrence: data["recurrence"] as? String
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

    func addTask(title: String, points: Int, childId: String) async -> Result<Void, Error> {
        do {
            guard let collection = tasksCollection else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            _ = try await collection.addDocument(data: [
                "title": title,
                "points": points,
                "childId": childId,
                "pendingApproval": false,
                "completed": false,
                "dueDate": Self.todayKey()
            ])
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func requestTaskCompletion(taskId: String) async -> Result<Void, Error> {
        do {
            guard let collection = tasksCollection else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            try await collection.document(taskId).updateData(["pendingApproval": true])
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func approveTask(taskId: String) async -> Result<Void, Error> {
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
            let points = snapshot.data()?["points"] as? Int ?? 0
            let childId = snapshot.data()?["childId"] as? String

            if let childId = childId {
                let childRef = parentDoc.collection("children").document(childId)
                try await childRef.updateData(["points": FieldValue.increment(Int64(points))])
            }

            try await taskRef.updateData([
                "completed": true,
                "pendingApproval": false
            ])
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
                "completed": false
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
            var data: [String: Any] = [
                "title": task.title,
                "points": task.points,
                "childId": task.childId as Any,
                "pendingApproval": task.pendingApproval,
                "completed": task.completed
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
}
