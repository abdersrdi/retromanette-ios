import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var recents: RecentStore
    @State private var importing = false
    @State private var importError: LibraryStore.ImportError?

    private static let romTypes: [UTType] = ["gb", "gbc", "gba"].compactMap { UTType(filenameExtension: $0) } + [.data]

    var body: some View {
        NavigationStack {
            Group {
                if library.games.isEmpty { emptyState } else { list }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("library.title")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { importing = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel(Text("library.import"))
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .fileImporter(isPresented: $importing, allowedContentTypes: Self.romTypes, allowsMultipleSelection: true) { result in
                guard case .success(let urls) = result else { return }
                for url in urls {
                    do { try library.add(from: url) }
                    catch let error as LibraryStore.ImportError { importError = error }
                    catch { importError = .copyFailed }
                }
            }
            .alert(LocalizedStringKey(importError == .unsupported ? "library.unsupported" : "library.importFailed"),
                   isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("common.ok", role: .cancel) {}
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent)
            Text("library.empty.title").font(.display(24)).foregroundStyle(Theme.text)
            Text("library.empty.body")
                .font(.system(size: 15))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Button { importing = true } label: { Text("library.import") }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 60)
                .padding(.top, 6)
            Text("library.footer")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(library.games) { game in
                    Button { play(game) } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surface)
                                Image(systemName: "gamecontroller.fill").foregroundStyle(Theme.accent)
                            }
                            .frame(width: 54, height: 54)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(game.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                                Text(LocalizedStringKey(game.system.titleKey)).font(.system(size: 13)).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Image(systemName: "play.fill").foregroundStyle(Theme.accent)
                        }
                        .padding(12)
                        .glassCard()
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) { library.remove(game) } label: { Label("common.delete", systemImage: "trash") }
                    }
                }
                Text("library.footer")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .padding(20)
        }
    }

    private func play(_ game: LibraryGame) {
        recents.played(RecentEntry(key: game.key, title: game.name, slug: nil))
        router.play(PlayRequest(key: game.key, title: game.name, romPath: library.url(for: game).path, system: game.system))
    }
}
