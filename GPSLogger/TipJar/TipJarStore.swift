//
//  TipJarStore.swift
//  Overland
//
//  StoreKit 2 for the tip jar. StoreKit 2 is Swift-only, so TipJarViewController calls this
//  from Objective-C. Completion handlers are called on the main queue.
//

import Foundation
import StoreKit
import UIKit

@objc enum TipJarPurchaseResult: Int {
    case purchased
    // Waiting for approval, e.g. Ask to Buy
    case pending
    case cancelled
    case failed
}

@objc final class TipJarProduct: NSObject {
    @objc let productID: String
    @objc let displayPrice: String
    // "one time", "monthly", "yearly", etc.
    @objc let frequency: String
    @objc let isSubscription: Bool
    @objc let isYearly: Bool

    fileprivate let product: Product

    fileprivate init(product: Product) {
        self.product = product
        productID = product.id
        displayPrice = product.displayPrice
        if let period = product.subscription?.subscriptionPeriod {
            isSubscription = true
            isYearly = (period.unit == .year)
            switch period.unit {
            case .day: frequency = "daily"
            case .week: frequency = "weekly"
            case .month: frequency = "monthly"
            case .year: frequency = "yearly"
            @unknown default: frequency = ""
            }
        } else {
            isSubscription = false
            isYearly = false
            frequency = "one time"
        }
    }
}

@objc final class TipJarStore: NSObject {
    @objc static let shared = TipJarStore()

    private var transactionUpdates: Task<Void, Never>?

    @objc var canMakePayments: Bool {
        AppStore.canMakePayments
    }

    // Called at launch. Finishes transactions that complete outside a purchase in the app,
    // such as subscription renewals and Ask to Buy approvals.
    @objc func startObservingTransactions() {
        guard transactionUpdates == nil else { return }
        transactionUpdates = Task.detached {
            for await result in Transaction.updates {
                await Self.finish(result)
            }
        }
    }

    @objc(loadProductsWithIdentifiers:completion:)
    func loadProducts(identifiers: [String], completion: @escaping ([TipJarProduct]) -> Void) {
        Task { @MainActor in
            do {
                let products = try await Product.products(for: identifiers)
                completion(products.map { TipJarProduct(product: $0) })
            } catch {
                NSLog("Couldn't load tip jar products: %@", error.localizedDescription)
                completion([])
            }
        }
    }

    // The error message is nil unless the result is .failed
    @objc(purchase:fromViewController:completion:)
    func purchase(_ tip: TipJarProduct, from viewController: UIViewController, completion: @escaping (TipJarPurchaseResult, String?) -> Void) {
        Task { @MainActor in
            do {
                let result: Product.PurchaseResult
                if #available(iOS 18.2, *) {
                    result = try await tip.product.purchase(confirmIn: viewController)
                } else {
                    result = try await tip.product.purchase()
                }

                switch result {
                case .success(let verification):
                    await Self.finish(verification)
                    completion(.purchased, nil)
                case .pending:
                    completion(.pending, nil)
                case .userCancelled:
                    completion(.cancelled, nil)
                @unknown default:
                    completion(.failed, nil)
                }
            } catch {
                NSLog("Tip purchase failed: %@", error.localizedDescription)
                completion(.failed, error.localizedDescription)
            }
        }
    }

    // The error message is nil if the restore succeeded
    @objc(restorePurchasesWithCompletion:)
    func restorePurchases(completion: @escaping (String?) -> Void) {
        Task { @MainActor in
            do {
                try await AppStore.sync()
                completion(nil)
            } catch {
                NSLog("Restoring purchases failed: %@", error.localizedDescription)
                completion(error.localizedDescription)
            }
        }
    }

    private static func finish(_ result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            NSLog("Finishing tip transaction for %@", transaction.productID)
            await transaction.finish()
        case .unverified(let transaction, let error):
            // Tips don't unlock anything, so there's nothing to withhold. Leave it unfinished.
            NSLog("Unverified tip transaction for %@: %@", transaction.productID, error.localizedDescription)
        }
    }
}
