import SwiftUI

// MARK: - MZColorScheme Extensions – Semantische kleuren

extension MZColorScheme {

    // Surface varianten
    var mzSurfaceSoft: Color   { surfaceVariant }
    var mzSurfaceStripe: Color { outlineVariant }

    // Kind taak-kaarten
    var taskCompletedCard: Color { secondaryContainer }   // groen
    var taskPendingCard: Color   { tertiaryContainer }    // geel/oranje
    var taskDefaultCard: Color   { primaryContainer }     // blauw
    var blockedCard: Color       { errorContainer }       // rood

    // Kind beloning-kaarten
    var rewardRedeemedCard: Color { outlineVariant }      // grijs
    var rewardCanRedeemCard: Color { tertiaryContainer }  // geel
    var rewardDefaultCard: Color  { primaryContainer }    // blauw

    // Ouder dashboard insight cards
    var insightPositiveCard: Color { secondaryContainer }
    var insightNeutralCard: Color  { surfaceVariant }

    // Parent message card (oranje tint – mapped naar tertiaryContainer)
    var parentMessageCard: Color { tertiaryContainer }
}
