import Foundation
import FirebaseAuth
import FirebaseFirestore

class ZebraShopRepository: ObservableObject {
    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()

    let availableAccessories: [Accessory] = [
        Accessory(id: "kleur_roze", name: "Roze strepen", price: 80, emoji: "🌸", category: .KLEUR),
        Accessory(id: "kleur_blauw", name: "Blauwe strepen", price: 80, emoji: "💙", category: .KLEUR),
        Accessory(id: "kleur_goud", name: "Gouden strepen", price: 180, emoji: "✨", category: .KLEUR),
        Accessory(id: "kleur_regenboog", name: "Regenboog", price: 250, emoji: "🌈", category: .KLEUR),
        Accessory(id: "kleur_paars", name: "Paarse strepen", price: 90, emoji: "💜", category: .KLEUR),
        Accessory(id: "kleur_groen", name: "Groene strepen", price: 90, emoji: "💚", category: .KLEUR),
        Accessory(id: "kleur_rood", name: "Rode strepen", price: 90, emoji: "❤️", category: .KLEUR),

        Accessory(id: "tophat", name: "Hoge hoed", price: 100, emoji: "🎩", category: .HOOFD),
        Accessory(id: "crown", name: "Kroon", price: 500, emoji: "👑", category: .HOOFD),
        Accessory(id: "sunglasses", name: "Zonnebril", price: 50, emoji: "🕶️", category: .HOOFD),
        Accessory(id: "star", name: "Sterrenbril", price: 150, emoji: "🤩", category: .HOOFD),
        Accessory(id: "detective", name: "Detective", price: 80, emoji: "🕵️", category: .HOOFD),
        Accessory(id: "helm", name: "Helm", price: 120, emoji: "⛑️", category: .HOOFD),
        Accessory(id: "cap", name: "Pet", price: 70, emoji: "🧢", category: .HOOFD),
        Accessory(id: "kerstmuts", name: "Kerstmuts", price: 140, emoji: "🎅", category: .HOOFD),
        Accessory(id: "viking", name: "Vikinghelm", price: 220, emoji: "🪖", category: .HOOFD),
        Accessory(id: "bril", name: "Bril", price: 60, emoji: "👓", category: .HOOFD),
        Accessory(id: "party_hat", name: "Feesthoed", price: 110, emoji: "🥳", category: .HOOFD),

        Accessory(id: "shirt_rood", name: "Rood shirt", price: 90, emoji: "👕", category: .SHIRT),
        Accessory(id: "shirt_blauw", name: "Blauw shirt", price: 90, emoji: "🧢", category: .SHIRT),
        Accessory(id: "shirt_groen", name: "Groen shirt", price: 90, emoji: "🟢", category: .SHIRT),
        Accessory(id: "shirt_geel", name: "Geel shirt", price: 90, emoji: "🟡", category: .SHIRT),
        Accessory(id: "shirt_paars", name: "Paars shirt", price: 100, emoji: "🟣", category: .SHIRT),
        Accessory(id: "superheld", name: "Superheld", price: 260, emoji: "🦸", category: .SHIRT),
        Accessory(id: "jas", name: "Jas", price: 140, emoji: "🧥", category: .SHIRT),
        Accessory(id: "space", name: "Ruimtepak", price: 300, emoji: "🧑‍🚀", category: .SHIRT),
        Accessory(id: "regenjack", name: "Regenjas", price: 130, emoji: "🌧️", category: .SHIRT),
        Accessory(id: "voetbalshirt", name: "Voetbalshirt", price: 170, emoji: "⚽️", category: .SHIRT),

        Accessory(id: "sneakers", name: "Sneakers", price: 80, emoji: "👟", category: .SCHOENEN),
        Accessory(id: "laarzen", name: "Laarzen", price: 100, emoji: "🥾", category: .SCHOENEN),
        Accessory(id: "skates", name: "Skates", price: 180, emoji: "🛼", category: .SCHOENEN),
        Accessory(id: "voetbalschoenen", name: "Voetbalschoenen", price: 150, emoji: "⚽️", category: .SCHOENEN),
        Accessory(id: "nette_schoenen", name: "Nette schoenen", price: 140, emoji: "👞", category: .SCHOENEN),
        Accessory(id: "slippers", name: "Slippers", price: 50, emoji: "🩴", category: .SCHOENEN),
        Accessory(id: "hoge_hakken", name: "Hoge hakken", price: 160, emoji: "👠", category: .SCHOENEN),

        Accessory(id: "scarf", name: "Sjaal", price: 30, emoji: "🧣", category: .EXTRA),
        Accessory(id: "rugzak", name: "Rugzak", price: 120, emoji: "🎒", category: .EXTRA),
        Accessory(id: "muziek", name: "Muziek", price: 90, emoji: "🎵", category: .EXTRA),
        Accessory(id: "skateboard", name: "Skateboard", price: 180, emoji: "🛹", category: .EXTRA),
        Accessory(id: "boek", name: "Boek", price: 70, emoji: "📚", category: .EXTRA),
        Accessory(id: "zonnebloem", name: "Zonnebloem", price: 110, emoji: "🌻", category: .EXTRA),
        Accessory(id: "gitaar", name: "Gitaar", price: 210, emoji: "🎸", category: .EXTRA),
        Accessory(id: "schildpad", name: "Schildpad", price: 240, emoji: "🐢", category: .EXTRA)
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

                let data = snapshot.data() ?? [:]
                let currentPoints = data["points"] as? Int ?? 0
                var currentInventory = data["purchasedAccessoryIds"] as? [String] ?? []
                let currentEquipped = data["equippedItems"] as? [String: String] ?? [:]

                switch ZebraCustomizerPolicy.remainingPointsAfterPurchase(
                    accessory: accessory,
                    childPoints: currentPoints,
                    purchasedIds: currentInventory
                ) {
                case .failure(.alreadyPurchased):
                    let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Je hebt dit item al!"])
                    errorPointer?.pointee = error
                    return nil
                case .failure(.insufficientPoints):
                    let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet genoeg punten!"])
                    errorPointer?.pointee = error
                    return nil
                case .success(let remainingPoints):
                    currentInventory.append(accessory.id)
                    let equippedItems = ZebraCustomizerPolicy.updatedEquippedItems(
                        currentEquipped,
                        category: accessory.category,
                        accessoryId: accessory.id
                    )
                    transaction.updateData([
                        "points": remainingPoints,
                        "purchasedAccessoryIds": currentInventory,
                        "equippedItems": equippedItems,
                        "equippedAccessoryId": accessory.id
                    ], forDocument: childRef)
                }

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
            let value: Any
            if let accessoryId {
                value = accessoryId
            } else {
                value = FieldValue.delete()
            }
            try await childrenCollection(parentUid: user.uid)
                .document(childId)
                .updateData(["equippedAccessoryId": value])
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func equipCategoryItem(childId: String, category: ZebraCategory, accessoryId: String?) async -> Result<Void, Error> {
        do {
            guard let user = auth.currentUser else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
            }

            if let accessoryId {
                var update: [String: Any] = [
                    "equippedItems.\(category.rawValue)": accessoryId,
                    "equippedAccessoryId": accessoryId
                ]
                try await childrenCollection(parentUid: user.uid)
                    .document(childId)
                    .updateData(update)
            } else if category == .HOOFD {
                try await childrenCollection(parentUid: user.uid)
                    .document(childId)
                    .updateData([
                        "equippedItems.\(category.rawValue)": FieldValue.delete(),
                        "equippedAccessoryId": FieldValue.delete()
                    ])
            } else {
                try await childrenCollection(parentUid: user.uid)
                    .document(childId)
                    .updateData(["equippedItems.\(category.rawValue)": FieldValue.delete()])
            }
            return .success(())
        } catch {
            return .failure(error)
        }
    }
}
