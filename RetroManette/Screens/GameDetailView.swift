import SwiftUI

struct GameDetailView: View {
    let game: Game
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var recents: RecentStore
    @State private var preparing = false
    @State private var failed = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            // the cover, blurred and dimmed, as a backdrop
            CoverImage(url: game.coverURL)
                .frame(height: 520)
                .frame(maxWidth: .infinity)
                .blur(radius: 60)
                .opacity(0.42)
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 22) {
                    CoverImage(url: game.coverURL)
                        .frame(width: 220, height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous).stroke(Theme.borderStrong, lineWidth: 1))
                        .shadow(color: .black.opacity(0.6), radius: 24, y: 14)
                        .padding(.top, 12)

                    VStack(spacing: 6) {
                        Text(game.title)
                            .font(.display(30))
                            .foregroundStyle(Theme.text)
                            .multilineTextAlignment(.center)
                        Text(game.developer)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.muted)
                    }

                    HStack(spacing: 8) {
                        Chip(text: String(localized: String.LocalizationValue(game.system.titleKey)), tint: Theme.accent)
                        Chip(text: String(localized: String.LocalizationValue(game.genreKey)))
                        Chip(text: (game.players ?? 1) > 1
                             ? String(format: String(localized: "detail.players.many"), game.players ?? 2)
                             : String(localized: "detail.players.one"))
                    }

                    Button(action: play) {
                        HStack(spacing: 10) {
                            if preparing { ProgressView().tint(Theme.accentInk) }
                            else { Image(systemName: "play.fill") }
                            Text(preparing ? "detail.downloading" : "detail.play")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(preparing)
                    .padding(.horizontal, 24)

                    VStack(alignment: .leading, spacing: 14) {
                        infoRow("detail.license", game.license)
                        if let url = game.licenseURL { linkRow("detail.licenseText", url) }
                        if let url = game.sourceURL { linkRow("detail.source", url) }
                    }
                    .padding(18)
                    .glassCard()
                    .padding(.horizontal, 20)

                    Text("detail.footer")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 30)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .alert("detail.downloadFailed", isPresented: $failed) {
            Button("common.ok", role: .cancel) {}
        }
    }

    private func infoRow(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(Theme.muted)
            Spacer(minLength: 16)
            Text(value).foregroundStyle(Theme.text).multilineTextAlignment(.trailing)
        }
        .font(.system(size: 15))
    }

    private func linkRow(_ label: LocalizedStringKey, _ url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Text(label).foregroundStyle(Theme.accent)
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.accent)
            }
            .font(.system(size: 15))
        }
    }

    private func play() {
        Task {
            preparing = true
            defer { preparing = false }
            do {
                let url = try await ROMStore.ensure(game)
                recents.played(RecentEntry(key: game.key, title: game.title, slug: game.slug))
                router.play(PlayRequest(key: game.key, title: game.title, romPath: url.path, system: game.system))
            } catch {
                failed = true
            }
        }
    }
}
