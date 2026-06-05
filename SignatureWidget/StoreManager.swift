//
//  StoreManager.swift
//  SignatureWidget
//

import Combine
import StoreKit
import WidgetKit

@MainActor
final class StoreManager: ObservableObject {

    // MARK: - Singleton

    static let shared = StoreManager()

    // MARK: - Product IDs

    enum ProductID {
        static let monthly  = "br.com.devbrains.signaturewidgets.monthly"
        static let yearly   = "br.com.devbrains.signaturewidgets.yearly"
        static let lifetime = "br.com.devbrains.signaturewidgets.lifetime"

        static let all = [monthly, yearly, lifetime]
    }

    // MARK: - Published State

    @Published var products: [Product] = []
    @Published var isPurchased = false
    @Published var isLoading   = false
    @Published var errorMessage: String?

    // MARK: - Private

    private var transactionListener: Task<Void, Error>?

    // MARK: - Init

    private init() {
        transactionListener = startTransactionListener()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await Product.products(for: ProductID.all)
            // Sort in display order: monthly → yearly → lifetime
            let order = ProductID.all
            products = fetched.sorted {
                (order.firstIndex(of: $0.id) ?? 99) < (order.firstIndex(of: $1.id) ?? 99)
            }
        } catch {
            let ns = error as NSError
            errorMessage = "Could not load plans. [\(ns.domain) \(ns.code)]"
            print("StoreManager.loadProducts error:", error)
            print("StoreManager.loadProducts domain:", ns.domain, "code:", ns.code)
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verified(verification)
            await grant(transaction)
            await transaction.finish()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            errorMessage = String(localized: "Error restoring purchases.")
            print("StoreManager.restorePurchases:", error)
        }
    }

    // MARK: - Entitlements

    func refreshEntitlements() async {
        var hasPurchase = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            if tx.revocationDate == nil { hasPurchase = true }
        }
        apply(purchased: hasPurchase)
    }

    // MARK: - Private Helpers

    private func grant(_ transaction: Transaction) async {
        apply(purchased: true)
    }

    private func apply(purchased: Bool) {
        isPurchased             = purchased
        TrialManager.isPurchased = purchased
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.failedVerification
        case .verified(let v): return v
        }
    }

    private func startTransactionListener() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let tx = try await self.verified(result)
                    await self.grant(tx)
                    await tx.finish()
                } catch {
                    print("StoreManager transaction update error:", error)
                }
            }
        }
    }

    enum StoreError: Error { case failedVerification }
}
