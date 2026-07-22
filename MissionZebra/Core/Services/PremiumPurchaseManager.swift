import Foundation
import StoreKit
import UIKit

@MainActor
final class PremiumPurchaseManager: ObservableObject {
    static let premiumMonthlyProductId = PremiumProductConfiguration.primaryProductId

    @Published private(set) var product: Product?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastPurchaseSucceeded = false

    private let premiumRepository: PremiumRepository
    private var updatesTask: Task<Void, Never>?
    private var hasLoadedProducts = false

    init(premiumRepository: PremiumRepository = PremiumRepository()) {
        self.premiumRepository = premiumRepository
        updatesTask = listenForTransactions()
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let products = try await Product.products(for: PremiumProductConfiguration.productIds)
            print("MissionZebra StoreKit products loaded:", products.map(\.id))
            product = products.first { $0.id == Self.premiumMonthlyProductId } ?? products.first
            hasLoadedProducts = true
            if product == nil {
                errorMessage = Self.productUnavailableMessage()
            }
        } catch {
            print("MissionZebra StoreKit product load failed:", error)
            errorMessage = Self.userFacingStoreKitError(error)
        }
        isLoading = false
    }

    func loadProductsIfNeeded() async {
        guard !hasLoadedProducts || product == nil else { return }
        await loadProducts()
    }

    func purchase() async {
        if product == nil {
            await loadProducts()
        }

        guard let product else {
            if errorMessage == nil {
                errorMessage = Self.productUnavailableMessage()
            }
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let signedTransactionInfo = verification.jwsRepresentation
                let transaction = try checkVerified(verification)
                await verifyPremium(from: transaction, signedTransactionInfo: signedTransactionInfo, source: "iosStoreKitPurchase")
                await transaction.finish()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = Self.userFacingStoreKitError(error)
        }
        isLoading = false
    }

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        do {
            try await AppStore.sync()
            var restored = false
            for await verification in Transaction.currentEntitlements {
                let signedTransactionInfo = verification.jwsRepresentation
                let transaction = try checkVerified(verification)
                guard PremiumProductConfiguration.isKnownProductId(transaction.productID) else { continue }
                await verifyPremium(from: transaction, signedTransactionInfo: signedTransactionInfo, source: "iosStoreKitRestore")
                restored = true
            }
            if !restored {
                errorMessage = "Geen actieve premium aankoop gevonden."
            }
        } catch {
            errorMessage = Self.userFacingStoreKitError(error)
        }
        isLoading = false
    }

    func manageSubscriptions() async {
        errorMessage = nil
        do {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) ??
                UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
                throw NSError(
                    domain: "MissionZebraStoreKit",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Kan Apple abonnementen nu niet openen. Probeer opnieuw wanneer de app actief is."]
                )
            }
            try await AppStore.showManageSubscriptions(in: scene)
        } catch {
            errorMessage = Self.userFacingStoreKitError(error)
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await verification in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.checkVerified(verification)
                    guard PremiumProductConfiguration.isKnownProductId(transaction.productID) else { continue }
                    await self.verifyPremium(from: transaction, signedTransactionInfo: verification.jwsRepresentation, source: "iosStoreKitUpdate")
                    await transaction.finish()
                } catch {
                    self.errorMessage = Self.userFacingStoreKitError(error)
                }
            }
        }
    }

    private func checkVerified<T>(_ verification: VerificationResult<T>) throws -> T {
        switch verification {
        case .verified(let value):
            return value
        case .unverified:
            throw NSError(
                domain: "MissionZebraStoreKit",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Aankoop kon niet geverifieerd worden."]
            )
        }
    }

    private func verifyPremium(from transaction: Transaction, signedTransactionInfo: String, source: String) async {
        let entitlementResult = await premiumRepository.verifyApplePremiumPurchase(
            transactionId: String(transaction.id),
            originalTransactionId: String(transaction.originalID),
            productId: transaction.productID,
            signedTransactionInfo: signedTransactionInfo,
            source: source
        )
        switch entitlementResult {
        case .success:
            lastPurchaseSucceeded = true
        case .failure(let error):
            errorMessage = Self.userFacingPurchaseError(error)
        }
    }

    private static func userFacingPurchaseError(_ error: Error) -> String {
        let message = error.localizedDescription
        if message.uppercased().contains("NOT FOUND") {
            return "Premium-verificatie is tijdelijk niet beschikbaar. Er is nog niets geactiveerd of aangerekend zolang Apple en MissionZebra dit niet bevestigen."
        }
        return message.isEmpty ? "Aankoopverificatie is niet gelukt." : message
    }

    private static func productUnavailableMessage() -> String {
        let ids = PremiumProductConfiguration.productIds.joined(separator: ", ")
        #if DEBUG
        return "Geen Apple premium-product ontvangen voor \(ids). Je draait een Debug-build: kies in Xcode Product > Scheme > Edit Scheme > Run > Options > StoreKit Configuration: MissionZebra.storekit. TestFlight/App Store gebruikt App Store Connect, niet dit lokale bestand."
        #else
        return "Premium is nog niet beschikbaar via Apple. Controleer in App Store Connect of product \(ids) is aangemaakt, goedgekeurd en gekoppeld aan deze appversie."
        #endif
    }

    private static func userFacingStoreKitError(_ error: Error) -> String {
        let message = error.localizedDescription
        return message.isEmpty ? productUnavailableMessage() : message
    }
}
