import Foundation

/// Represents the categories used when customizing a zebra appearance.
enum ZebraCategory: String, CaseIterable, Codable {
    case KLEUR
    case HOOFD
    case SHIRT
    case SCHOENEN
    case EXTRA

    var displayName: String {
        switch self {
        case .KLEUR: return "Kleur"
        case .HOOFD: return "Hoofd"
        case .SHIRT: return "Shirt"
        case .SCHOENEN: return "Schoenen"
        case .EXTRA: return "Extra"
        }
    }

    var emoji: String {
        switch self {
        case .KLEUR: return "🎨"
        case .HOOFD: return "🎩"
        case .SHIRT: return "👕"
        case .SCHOENEN: return "👟"
        case .EXTRA: return "⭐"
        }
    }
}
