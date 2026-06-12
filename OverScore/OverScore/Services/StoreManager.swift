import Foundation
import StoreKit

@MainActor
@Observable
final class StoreManager {
    static let removeAdsProductID = "com.sujang.ScoreFrame.removeAds"

    private(set) var isAdRemoved = false
    private(set) var removeAdsProduct: Product?
    private(set) var purchaseError: String?
    private(set) var isLoading = false

    private nonisolated(unsafe) var updateTask: Task<Void, Never>?

    init() {
        updateTask = Task { [weak self] in
            await self?.listenForTransactions()
        }
        Task {
            await loadProducts()
            await checkPurchaseStatus()
        }
    }

    deinit {
        updateTask?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        do {
            let products = try await Product.products(for: [Self.removeAdsProductID])
            removeAdsProduct = products.first
        } catch {
            purchaseError = error.localizedDescription
        }
        isLoading = false
    }

    func purchase() async {
        guard let product = removeAdsProduct else { return }
        purchaseError = nil
        isLoading = true

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                isAdRemoved = true
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
        isLoading = false
    }

    func restore() async {
        isLoading = true
        try? await AppStore.sync()
        await checkPurchaseStatus()
        isLoading = false
    }

    private func checkPurchaseStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.removeAdsProductID {
                isAdRemoved = true
                return
            }
        }
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                if transaction.productID == Self.removeAdsProductID {
                    isAdRemoved = true
                }
                await transaction.finish()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let value):
            return value
        }
    }

    enum StoreError: LocalizedError {
        case verificationFailed

        var errorDescription: String? {
            switch self {
            case .verificationFailed:
                return String(localized: "購入の検証に失敗しました")
            }
        }
    }
}
