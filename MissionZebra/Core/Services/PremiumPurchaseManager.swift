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
                let transaction = try checkVerified(verification)
                await activatePremium(from: transaction, source: "iosStoreKitPurchase")
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
                let transaction = try checkVerified(verification)
                guard transaction.productID == Self.premiumMonthlyProductId else { continue }
                await activatePremium(from: transaction, source: "iosStoreKitRestore")
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
                    await self.activatePremium(from: transaction, source: "iosStoreKitUpdate")
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

    private func activatePremium(from transaction: Transaction, source: String) async {
        let premiumUntil = transaction.expirationDate.map { Int64($0.timeIntervalSince1970 * 1000) }
        let result = await premiumRepository.activatePremiumFromStoreKit(
            originalTransactionId: String(transaction.originalID),
            premiumUntil: premiumUntil,
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
