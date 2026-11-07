import SwiftUI

/// A small game card for the horizontal rows.
struct GameCard: View {
    let game: Game
    var width: CGFloat = 148

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CoverImage(url: game.coverURL)
                .frame(width: width, height: width)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).stroke(Theme.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.45), radius: 10, y: 6)
            Text(game.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            Text(LocalizedStringKey(game.genreKey))
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
        }
        .frame(width: width, alignment: .leading)
    }
}

/// The big featured card at the top of the home screen.
struct HeroCard: View {
    let game: Game

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // the clear base takes the width it is offered; the cover only fills it, so it can never push the card wider
            Color.clear
                .overlay { CoverImage(url: game.coverURL).scaledToFill() }
                .clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.35), .black.opacity(0.88)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 6) {
                Text("discover.featured")
                    .font(.system(size: 12, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Theme.accent)
                Text(game.title)
                    .font(.display(32))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                Text(game.developer)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 340)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous).stroke(Theme.borderStrong, lineWidth: 1))
        .shadow(color: Theme.accent.opacity(0.12), radius: 24, y: 10)
        .padding(.horizontal, 20)
    }
}

/// A horizontal row with a title.
struct GameRail: View {
    let title: LocalizedStringKey
    let games: [Game]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: title)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(games) { game in
                        NavigationLink(value: game) { GameCard(game: game) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}
