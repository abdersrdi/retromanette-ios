import SwiftUI

struct RootView: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var catalog: CatalogStore
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
        .task { await debugLaunch() }
    }

    /// Debug builds only: `-tab 1` opens a tab and `-autoplay <slug>` starts a catalog game. The screenshot workflow uses
    /// these; release builds ignore them.
    private func debugLaunch() async {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count, let n = Int(args[i + 1]) { tab = n }
        if let i = args.firstIndex(of: "-autoplay"), i + 1 < args.count {
            let slug = args[i + 1]
            await catalog.load()
            if let game = catalog.game(slug: slug), let url = try? await ROMStore.ensure(game) {
                router.play(PlayRequest(key: game.key, title: game.title, romPath: url.path, system: game.system))
            }
        }
        #endif
    }
}
