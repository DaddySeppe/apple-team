import Foundation

enum ZebraCustomizerError: Error, Equatable {
    case alreadyPurchased
    case insufficientPoints
}

enum ZebraCustomizerPolicy {
    static func remainingPointsAfterPurchase(accessory: Accessory, childPoints: Int, purchasedIds: [String]) -> Result<Int, ZebraCustomizerError> {
        if purchasedIds.contains(accessory.id) {
            return .failure(.alreadyPurchased)
        }
        if childPoints < accessory.price {
            return .failure(.insufficientPoints)
        }
        return .success(childPoints - accessory.price)
    }

    static func updatedEquippedItems(_ equippedItems: [String: String], category: ZebraCategory, accessoryId: String?) -> [String: String] {
        var updated = equippedItems
        if let accessoryId {
            updated[category.rawValue] = accessoryId
        } else {
            updated.removeValue(forKey: category.rawValue)
        }
        return updated
    }
}
