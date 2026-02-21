import Foundation

struct Accessory: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let price: Int
    let emoji: String
    var description: String = ""
}
