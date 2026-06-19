import Foundation
import StoreKit

@MainActor
final class PremiumPurchaseManager: ObservableObject {
    static let premiumMonthlyProductId = "premium_monthly"

    @Published private(set) var product: Product?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastPurchaseSucceeded = false

    private let premiumRepository: PremiumRepository
    private var updatesTask: Task<Void, Never>?

    init(premiumRepository: PremiumRepository = PremiumRepository()) {
        self.premiumRepository = premiumRepository
        updatesTask = listenForTransactions()
        Task { await loadProducts() }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        do {
            product = try await Product.products(for: [Self.premiumMonthlyProductId]).first
            if product == nil {
                errorMessage = "Premium product niet gevonden in StoreKit."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func purchase() async {
        guard let product else {
            errorMessage = "Premium product is nog niet geladen."
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
            errorMessage = error.localizedDescription
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
                guard transaction.productID == Self.premiumMonthlyProductId else { continue }
                await verifyPremium(from: transaction, signedTransactionInfo: signedTransactionInfo, source: "iosStoreKitRestore")
                restored = true
            }
            if !restored {
                errorMessage = "Geen actieve premium aankoop gevonden."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await verification in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try self.checkVerified(verification)
                    guard transaction.productID == Self.premiumMonthlyProductId else { continue }
                    await self.verifyPremium(from: transaction, signedTransactionInfo: verification.jwsRepresentation, source: "iosStoreKitUpdate")
                    await transaction.finish()
                } catch {
                    self.errorMessage = error.localizedDescription
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
        let result = await premiumRepository.verifyApplePremiumPurchase(
            transactionId: String(transaction.id),
            originalTransactionId: String(transaction.originalID),
            productId: transaction.productID,
            signedTransactionInfo: signedTransactionInfo,
            source: source
        )
        switch result {
        case .success:
            lastPurchaseSucceeded = true
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}
