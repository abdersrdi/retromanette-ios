import SwiftUI

/// The Premium page: one plan, one price, what it unlocks, and the subscription terms Apple requires on this screen.
struct PremiumView: View {
    @EnvironmentObject private var store: PremiumStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            RadialGradient(colors: [Theme.accent.opacity(0.28), .clear], center: .top, startRadius: 10, endRadius: 520)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 26) {
                    header
                    VStack(spacing: 14) {
                        feature("icloud.fill", "premium.feature.cloud", "premium.feature.cloud.detail")
                        feature("person.2.fill", "premium.feature.online", "premium.feature.online.detail")
                        feature("nosign", "premium.feature.noads", "premium.feature.noads.detail")
                    }
                    .padding(.horizontal, 20)

                    planCard
                    purchaseButtons
                    legal
                }
                .padding(.top, 36)
                .padding(.bottom, 40)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .padding(16)
            .accessibilityLabel(Text("common.done"))
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.accentSoft, Theme.accent], startPoint: .top, endPoint: .bottom))
                    .frame(width: 88, height: 88)
                    .shadow(color: Theme.accent.opacity(0.5), radius: 24, y: 8)
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Theme.accentInk)
            }
            Text("premium.title")
                .font(.display(34))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
            Text("premium.subtitle")
                .font(.system(size: 16))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
        }
    }

    private func feature(_ symbol: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.accent.opacity(0.14)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.text)
                Text(detail).font(.system(size: 14)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassCard()
    }

    /// The single plan: monthly, no yearly option.
    private var planCard: some View {
        VStack(spacing: 6) {
            Text("premium.plan.name")
                .font(.system(size: 13, weight: .bold))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(Theme.accent)
            if let price = store.displayPrice {
                Text(String(format: String(localized: "premium.price.month"), price))
                    .font(.display(30))
                    .foregroundStyle(Theme.text)
            } else {
                Text("premium.unavailable")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
            Text("premium.cancel")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
                .fill(Theme.accent.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous).stroke(Theme.accent.opacity(0.6), lineWidth: 1.5))
        )
        .padding(.horizontal, 20)
    }

    private var purchaseButtons: some View {
        VStack(spacing: 12) {
            if store.isPremium {
                Label("premium.active", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.success)
                    .padding(.vertical, 10)
            } else {
                Button {
                    Task { await store.purchase() }
                } label: {
                    HStack(spacing: 10) {
                        if store.isBusy { ProgressView().tint(Theme.accentInk) }
                        Text("premium.subscribe")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!store.canPurchase)
                .opacity(store.canPurchase ? 1 : 0.5)
            }
            Button { Task { await store.restore() } } label: {
                Text("premium.restore").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.accent)
            }
            .disabled(store.isBusy)
            if let failure = store.failure {
                Text(failure).font(.system(size: 13)).foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 24)
    }

    /// Apple requires the renewal terms, a way to manage the subscription, and the terms and privacy links on the page.
    private var legal: some View {
        VStack(spacing: 10) {
            Text("premium.legal")
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            HStack(spacing: 18) {
                Link(destination: Site.url("/legal/terms")) { Text("settings.terms") }
                Link(destination: Site.url("/legal/privacy")) { Text("settings.privacy") }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, 28)
    }
}
