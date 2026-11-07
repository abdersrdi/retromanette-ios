import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var catalog: CatalogStore
    @EnvironmentObject private var recents: RecentStore
    @State private var query = ""

    private var results: [Game] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return catalog.playable.filter { $0.title.lowercased().contains(q) || $0.developer.lowercased().contains(q) }
    }

    /// A different featured game every day.
    private var featured: Game? {
        let list = catalog.playable
        guard !list.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return list[day % list.count]
    }

    private var continuePlaying: [Game] {
        recents.entries.compactMap { entry in entry.slug.flatMap { catalog.game(slug: $0) } }
    }

    /// A plain String key (an interpolated literal would be looked up as "genre.%@" and show up untranslated).
    private func genreTitle(_ genre: String) -> LocalizedStringKey { LocalizedStringKey("genre." + genre) }

    private var genreRails: [(genre: String, games: [Game])] {
        let grouped = Dictionary(grouping: catalog.playable, by: { $0.genre })
        return grouped
            .filter { $0.key != "other" && $0.value.count >= 3 }
            .sorted { $0.value.count > $1.value.count }
            .map { (genre: $0.key, games: $0.value.sorted { $0.title < $1.title }) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 30) {
                    if !query.isEmpty {
                        searchResults
                    } else {
                        if let featured {
                            NavigationLink(value: featured) { HeroCard(game: featured) }.buttonStyle(.plain)
                        }
                        if !continuePlaying.isEmpty { GameRail(title: "discover.continue", games: continuePlaying) }
                        let gba = catalog.games(for: .gba)
                        if !gba.isEmpty { GameRail(title: "system.gba", games: gba) }
                        ForEach(genreRails, id: \.genre) { rail in
                            GameRail(title: genreTitle(rail.genre), games: rail.games)
                        }
                        if catalog.playable.isEmpty { emptyState }
                        if catalog.comingSoonCount > 0 {
                            Text("discover.nes")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.muted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { Wordmark() } }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .searchable(text: $query, prompt: Text("discover.search"))
            .navigationDestination(for: Game.self) { GameDetailView(game: $0) }
            .refreshable { await catalog.load() }
        }
        .task { await catalog.load() }
    }

    private var searchResults: some View {
        VStack(spacing: 14) {
            if results.isEmpty {
                Text("discover.noResults").foregroundStyle(Theme.muted).padding(.top, 40)
            }
            ForEach(results) { game in
                NavigationLink(value: game) {
                    HStack(spacing: 14) {
                        CoverImage(url: game.coverURL)
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(game.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.text)
                            Text(game.developer).font(.system(size: 13)).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Image(systemName: "chevron.forward").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
                    }
                    .padding(12)
                    .glassCard()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            if catalog.isLoading {
                ProgressView().tint(Theme.accent)
            } else {
                Image(systemName: "wifi.slash").font(.system(size: 34)).foregroundStyle(Theme.muted)
                Text("discover.loadError").foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                Button("common.retry") { Task { await catalog.load() } }
                    .buttonStyle(PrimaryButtonStyle(prominent: false))
                    .frame(maxWidth: 200)
            }
        }
        .padding(.top, 60)
    }
}
