import XCTest
@testable import MissionZebra

final class ZebraCustomizerPolicyTests: XCTestCase {
    func testPurchasePolicyRejectsDuplicateAndInsufficientPoints() {
        let accessory = Accessory(id: "crown", name: "Kroon", price: 500, emoji: "👑", category: .HOOFD)

        XCTAssertEqual(
            ZebraCustomizerPolicy.remainingPointsAfterPurchase(accessory: accessory, childPoints: 600, purchasedIds: ["crown"]),
            .failure(.alreadyPurchased)
        )
        XCTAssertEqual(
            ZebraCustomizerPolicy.remainingPointsAfterPurchase(accessory: accessory, childPoints: 100, purchasedIds: []),
            .failure(.insufficientPoints)
        )
    }

    func testEquipCategoryUpdatesOnlyThatCategory() throws {
        let equipped = [
            ZebraCategory.HOOFD.rawValue: "tophat",
            ZebraCategory.SHIRT.rawValue: "shirt_rood"
        ]

        let updated = ZebraCustomizerPolicy.updatedEquippedItems(
            equipped,
            category: .HOOFD,
            accessoryId: "crown"
        )

        XCTAssertEqual(updated[ZebraCategory.HOOFD.rawValue], "crown")
        XCTAssertEqual(updated[ZebraCategory.SHIRT.rawValue], "shirt_rood")

        let removed = ZebraCustomizerPolicy.updatedEquippedItems(updated, category: .HOOFD, accessoryId: nil)
        XCTAssertNil(removed[ZebraCategory.HOOFD.rawValue])
        XCTAssertEqual(removed[ZebraCategory.SHIRT.rawValue], "shirt_rood")
    }
}
