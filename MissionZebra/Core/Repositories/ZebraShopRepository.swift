import Foundation
import FirebaseAuth
import FirebaseFirestore

class ZebraShopRepository: ObservableObject {
    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()

    // Hardcoded inventory for now (later potentially from Firestore)
    let availableAccessories: [Accessory] = [
        Accessory(id: "tophat", name: "Hoge Hoed", price: 100, emoji: "🎩"),
        Accessory(id: "sunglasses", name: "Zonnebril", price: 50, emoji: "🕶️"),
        Accessory(id: "crown", name: "Toverkroon", price: 500, emoji: "👑"),
        Accessory(id: "scarf", name: "Sjaal", price: 30, emoji: "🧣"),
        Accessory(id: "star", name: "Sterrenbril", price: 150, emoji: "🤩"),
        Accessory(id: "detective", name: "Detective", price: 80, emoji: "🕵️")
    ]

    private func childrenCollection(parentUid: String) -> CollectionReference {
        return firestore.collection("parents").document(parentUid).collection("children")
    }

    func buyAccessory(childId: String, accessory: Accessory) async -> Result<Void, Error> {
        do {
            guard let user = auth.currentUser else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }

            let childRef = childrenCollection(parentUid: user.uid).document(childId)

            try await firestore.runTransaction { transaction, errorPointer in
                let snapshot: DocumentSnapshot
                do {
                    snapshot = try transaction.getDocument(childRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }

                let currentPoints = snapshot.data()?["points"] as? Int ?? 0
                var currentInventory = snapshot.data()?["purchasedAccessoryIds"] as? [String] ?? []

                if currentInventory.contains(accessory.id) {
                    let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Je hebt dit item al!"])
                    errorPointer?.pointee = error
                    return nil
                }

                if currentPoints < accessory.price {
                    let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet genoeg punten!"])
                    errorPointer?.pointee = error
                    return nil
                }

                // Deduct points
                transaction.updateData(["points": currentPoints - accessory.price], forDocument: childRef)

                // Add to inventory
                currentInventory.append(accessory.id)
                transaction.updateData(["purchasedAccessoryIds": currentInventory], forDocument: childRef)

                return nil
            }

            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func equipAccessory(childId: String, accessoryId: String?) async -> Result<Void, Error> {
        do {
            guard let user = auth.currentUser else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }
            try await childrenCollection(parentUid: user.uid)
                .document(childId)
                .updateData(["equippedAccessoryId": accessoryId as Any])
            return .success(())
        } catch {
            return .failure(error)
        }
    }
}
