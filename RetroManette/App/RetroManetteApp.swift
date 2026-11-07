import SwiftUI

/// Tells the root view which game is on screen.
@MainActor
final class Router: ObservableObject {
    @Published var playing: PlayRequest?
    @Published var showPremium = false
    func play(_ request: PlayRequest) { playing = request }
}

@main
struct RetroManetteApp: App {
    @StateObject private var catalog = CatalogStore()
    @StateObject private var library = LibraryStore()
    @StateObject private var recents = RecentStore()
    @StateObject private var router = Router()
    @StateObject private var premium = PremiumStore()

    init() {
        // covers are cached on disk so the home screen is instant the second time
        URLCache.shared = URLCache(memoryCapacity: 40 * 1024 * 1024, diskCapacity: 300 * 1024 * 1024)
        let bar = UITabBarAppearance()
        bar.configureWithDefaultBackground()
        bar.backgroundEffect = UIBlurEffect(style: .systemChromeMaterialDark)
        bar.backgroundColor = UIColor(Theme.background).withAlphaComponent(0.72)
        UITabBar.appearance().standardAppearance = bar
        UITabBar.appearance().scrollEdgeAppearance = bar
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(catalog)
                .environmentObject(library)
                .environmentObject(recents)
                .environmentObject(router)
                .environmentObject(premium)
                .task { await premium.start() }
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}
