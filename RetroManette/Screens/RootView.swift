import SwiftUI

struct RootView: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var catalog: CatalogStore
    @EnvironmentObject private var library: LibraryStore
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            DiscoverView()
                .tabItem { Label("tab.discover", systemImage: "sparkles.tv.fill") }
                .tag(0)
            LibraryView()
                .tabItem { Label("tab.library", systemImage: "square.stack.fill") }
                .tag(1)
            SettingsView()
                .tabItem { Label("tab.settings", systemImage: "gearshape.fill") }
                .tag(2)
        }
        .fullScreenCover(item: $router.playing) { request in
            PlayerView(request: request)
        }
        .sheet(isPresented: $router.showPremium) { PremiumView() }
        .task { await debugLaunch() }
    }

    /// Debug builds only (see DebugArgs): the screenshot workflow opens screens and runs a scripted tour with these.
    private func debugLaunch() async {
        #if DEBUG
        func pause(_ seconds: Double) async { try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
        func request(_ game: Game, _ url: URL) -> PlayRequest {
            PlayRequest(key: game.key, title: game.title, romPath: url.path, system: game.system)
        }

        if let n = DebugArgs.value("-tab").flatMap({ Int($0) }) { tab = n }

        if DebugArgs.has("-seedLibrary") {
            await catalog.load()
            let picks: [(String, String)] = [("tobutobugirl", "Tobu Tobu Girl"), ("dustline", "Dustline"), ("zoomer", "Zoomer GBA"), ("gbarcade", "GBArcade")]
            for (slug, name) in picks {
                if let game = catalog.playable.first(where: { $0.slug.contains(slug) }), let url = try? await ROMStore.ensure(game) {
                    library.seed(from: url, name: name, system: game.system)
                }
            }
        }
        if let slug = DebugArgs.value("-openGame") {
            await catalog.load()
            await pause(1.5)
            if let game = catalog.game(slug: slug) { NotificationCenter.default.post(name: .tourOpenGame, object: game) }
        }
        if DebugArgs.has("-showPremium") {
            await pause(1.0)
            router.showPremium = true
        }
        if let slug = DebugArgs.value("-autoplay") {
            await catalog.load()
            if let game = catalog.game(slug: slug), let url = try? await ROMStore.ensure(game) { router.play(request(game, url)) }
        }

        // the scripted tour: discover, a game's page, playing with the menu, the Premium page, settings
        if DebugArgs.has("-tour") {
            await catalog.load()
            guard let game = catalog.game(slug: DebugArgs.value("-tourGame") ?? "tobutobugirl"), let url = try? await ROMStore.ensure(game) else { return }
            tab = 0
            await pause(3.0)
            NotificationCenter.default.post(name: .tourOpenGame, object: game)
            await pause(3.0)
            router.play(request(game, url))
            await pause(9.5)
            NotificationCenter.default.post(name: .tourToggleMenu, object: nil)
            await pause(2.5)
            NotificationCenter.default.post(name: .tourToggleMenu, object: nil)
            await pause(0.8)
            router.playing = nil
            await pause(1.0)
            router.showPremium = true
            await pause(4.0)
            router.showPremium = false
            await pause(0.6)
            tab = 2
        }
        #endif
    }
}
