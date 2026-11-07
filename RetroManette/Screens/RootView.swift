import SwiftUI

struct RootView: View {
    @EnvironmentObject private var router: Router

    var body: some View {
        TabView {
            DiscoverView()
                .tabItem { Label("tab.discover", systemImage: "sparkles.tv.fill") }
            LibraryView()
                .tabItem { Label("tab.library", systemImage: "square.stack.fill") }
            SettingsView()
                .tabItem { Label("tab.settings", systemImage: "gearshape.fill") }
        }
        .fullScreenCover(item: $router.playing) { request in
            PlayerView(request: request)
        }
    }
}
