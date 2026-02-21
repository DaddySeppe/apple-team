import SwiftUI

// MARK: - MissionZebra kleuren

// Primaire kleuren
let mzPrimary       = Color(hex: 0xFF6366F1) // Paars
let mzPrimaryDark   = Color(hex: 0xFF4F46E5)
let mzPrimaryLight  = Color(hex: 0xFFE0E7FF)

// Secundaire (accent) kleuren
let mzGreen  = Color(hex: 0xFF22C55E)
let mzRed    = Color(hex: 0xFFEF4444)
let mzOrange = Color(hex: 0xFFF97316)

// Grijswaarden en achtergronden
let mzSurfaceVariant = Color(hex: 0xFFE5E7EB)


// MARK: - LIGHT – MissionZebra zebra + kids kleuren

// Basis zebra
let mzZebraBlack = Color(hex: 0xFF111827)
let mzZebraGrey  = Color(hex: 0xFF4B5563)

// Blauwe hoofdkleur + varianten
let mzSky      = Color(hex: 0xFF78D9FA) // hoofd
let mzSkyDark  = Color(hex: 0xFF37B1D6)
let mzSkyLight = Color(hex: 0xFFE5F8FF)

// Accentkleuren
let mzLime   = Color(hex: 0xFF4ADE80)
let mzPink   = Color(hex: 0xFFF973A5)
let mzYellow = Color(hex: 0xFFFACC15)

// Achtergrond / surfaces (LIGHT)
let mzBackground    = Color(hex: 0xFFF3F4F6)
let mzSurface       = Color(hex: 0xFFFFFFFF)
let mzSurfaceSoft   = Color(hex: 0xFFF9FAFB)
let mzSurfaceStripe = Color(hex: 0xFFE5E7EB)


// MARK: - DARK – MissionZebra donker thema

let mzDarkBackground    = Color(hex: 0xFF050816)
let mzDarkSurface       = Color(hex: 0xFF0B1120)
let mzDarkSurfaceSoft   = Color(hex: 0xFF111827)
let mzDarkSurfaceStripe = Color(hex: 0xFF1F2937)

// Tekst op donkere achtergronden
let mzDarkOnSurface    = Color(hex: 0xFFE5E7EB)
let mzDarkOnSurfaceVar = Color(hex: 0xFF9CA3AF)

// Status kaart kleuren (dark)
let mzDarkCardGreen  = Color(hex: 0xFF064E3B) // voltooid
let mzDarkCardYellow = Color(hex: 0xFF78350F) // wachtend
let mzDarkCardBlue   = Color(hex: 0xFF0C4A6E) // standaard
let mzDarkCardRed    = Color(hex: 0xFF7F1D1D) // geblokkeerd
let mzDarkCardGray   = Color(hex: 0xFF1F2937) // ingewisseld

// Status kaart kleuren (light)
let mzLightCardGreen     = Color(hex: 0xFFDCFCE7)
let mzLightCardYellow    = Color(hex: 0xFFFFF7CD)
let mzLightCardBlue      = Color(hex: 0xFFE0F2FE)
let mzLightCardRed       = Color(hex: 0xFFFFCDD2)
let mzLightCardGray      = Color(hex: 0xFFE5E7EB)
let mzLightCardYellowAlt = Color(hex: 0xFFFEF9C3)


// MARK: - Color Hex Extension

extension Color {
    /// Initialize Color from a 0xAARRGGBB hex value (alpha in high byte).
    init(hex: UInt) {
        let a = Double((hex >> 24) & 0xFF) / 255.0
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8)  & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
