import SwiftUI
import UIKit

struct SettingsView: View {
    @AppStorage("haptics") private var haptics = true
    @AppStorage("controlsOpacity") private var controlsOpacity = 0.95
    @AppStorage("smoothScaling") private var smoothScaling = false
    @AppStorage("autoResume") private var autoResume = true

    private var languageName: String {
        let code = Locale.preferredLanguages.first ?? "en"
        return Locale.current.localizedString(forIdentifier: code)?.capitalized ?? code
    }

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            List {
                premiumSection
                Section {
                    HStack {
                        Label("settings.language", systemImage: "globe")
                        Spacer()
                        Text(languageName).foregroundStyle(Theme.muted)
                    }
                    Button { openSystemSettings() } label: { Label("settings.openSettings", systemImage: "arrow.up.forward.app") }
                } header: {
                    Text("settings.language")
                } footer: {
                    Text("settings.language.note")
                }
                .listRowBackground(Theme.surfaceHigh)

                Section {
                    Toggle(isOn: $haptics) { Label("settings.haptics", systemImage: "iphone.radiowaves.left.and.right") }
                    VStack(alignment: .leading, spacing: 8) {
                        Label("settings.opacity", systemImage: "circle.lefthalf.filled")
                        Slider(value: $controlsOpacity, in: 0.35...1)
                    }
                    Toggle(isOn: $smoothScaling) { Label("settings.smooth", systemImage: "sparkles") }
                    Toggle(isOn: $autoResume) { Label("settings.resume", systemImage: "arrow.uturn.forward.circle") }
                } header: {
                    Text("settings.controls")
                } footer: {
                    Text("settings.controllers.note")
                }
                .listRowBackground(Theme.surfaceHigh)

                Section {
                    Link(destination: Site.base) { Label("settings.website", systemImage: "safari") }
                    Link(destination: Site.url("/legal/privacy")) { Label("settings.privacy", systemImage: "hand.raised") }
                    Link(destination: Site.url("/legal/terms")) { Label("settings.terms", systemImage: "doc.text") }
                    Link(destination: Site.url("/legal/contact")) { Label("settings.contact", systemImage: "envelope") }
                    NavigationLink { LicensesView() } label: { Label("settings.licenses", systemImage: "checkmark.seal") }
                    HStack {
                        Label("settings.version", systemImage: "info.circle")
                        Spacer()
                        Text(version).foregroundStyle(Theme.muted)
                    }
                } header: {
                    Text("settings.about")
                }
                .listRowBackground(Theme.surfaceHigh)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("settings.title")
            .toolbarBackground(Theme.background, for: .navigationBar)
        }
    }

    /// Premium is not for sale yet: the purchase arrives with a later update. Until then this explains what it will include.
    private var premiumSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("settings.premium").font(.display(24)).foregroundStyle(Theme.text)
                    Spacer()
                    Chip(text: String(localized: "settings.premium.soon"), tint: Theme.accent)
                }
                premiumRow("nosign", "settings.premium.noAds")
                premiumRow("icloud.fill", "settings.premium.cloud")
                premiumRow("person.2.fill", "settings.premium.online")
                Text("settings.premium.body")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.vertical, 6)
        }
        .listRowBackground(
            LinearGradient(colors: [Theme.accent.opacity(0.16), Theme.surfaceHigh], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }

    private func premiumRow(_ symbol: String, _ key: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Theme.accent).frame(width: 24)
            Text(key).foregroundStyle(Theme.text)
        }
        .font(.system(size: 15))
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}

struct LicensesView: View {
    private struct Item: Identifiable {
        let id: String
        let name: String
        let license: String
        let url: URL
    }

    private let items: [Item] = [
        Item(id: "mgba", name: "mGBA", license: "MPL-2.0", url: URL(string: "https://github.com/libretro/mgba")!),
        Item(id: "libretro", name: "libretro API (libretro.h)", license: "MIT", url: URL(string: "https://github.com/libretro/libretro-common")!),
        Item(id: "games", name: "Catalog games", license: "See each game", url: Site.url("/legal/licenses")),
    ]

    var body: some View {
        List {
            Section {
                ForEach(items) { item in
                    Link(destination: item.url) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name).foregroundStyle(Theme.text)
                            Text(item.license).font(.system(size: 13)).foregroundStyle(Theme.muted)
                        }
                    }
                }
            } footer: {
                Text("licenses.note")
            }
            .listRowBackground(Theme.surfaceHigh)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("settings.licenses")
    }
}
