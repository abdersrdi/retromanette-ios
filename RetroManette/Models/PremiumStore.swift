import Foundation
import StoreKit

/// Premium is one auto-renewing monthly subscription. There is no yearly plan. The product is created in App Store Connect
/// (subscription group "Retro Manette Premium", product ID below, price 9.99 USD a month); until it exists the page shows
/// the plan but the button stays disabled, so nothing can be bought before the product is live.
@MainActor
final class PremiumStore: ObservableObject {
    static let productID = "com.retromanette.app.premium.monthly"

    @Published private(set) var product: Product?
    @Published private(set) var isPremium = false
    @Published private(set) var isBusy = false
    @Published private(set) var failure: String?

    private var updatesTask: Task<Void, Never>?

    /// Debug screenshot builds show the plan price without talking to the App Store.
    var screenshotMode: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-store")
        #else
        return false
        #endif
    }

    /// The price as the App Store formats it for the user's country; the sample only appears in screenshot builds.
    var displayPrice: String? { product?.displayPrice ?? (screenshotMode ? "$9.99" : nil) }
    var canPurchase: Bool { (product != nil || screenshotMode) && !isPremium && !isBusy }

    func start() async {
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                for await update in Transaction.updates {
                    if case .verified(let transaction) = update { await transaction.finish() }
                    await self?.refresh()
                }
            }
        }
        if screenshotMode { return }
        product = try? await Product.products(for: [Self.productID]).first
        await refresh()
    }

    func purchase() async {
        guard let product else { return }
        isBusy = true
        failure = nil
        defer { isBusy = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refresh()
                } else {
                    failure = String(localized: "premium.error")
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            failure = String(localized: "premium.error")
        }
    }

    func restore() async {
        isBusy = true
        failure = nil
        defer { isBusy = false }
        do { try await AppStore.sync() } catch { failure = String(localized: "premium.error") }
        await refresh()
    }

    private func refresh() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.productID, transaction.revocationDate == nil {
                active = true
            }
        }
        isPremium = active
        AdsManager.shared.setPremium(active)
    }
}
