import SwiftUI

/// The look of Retro Manette: the same dark, warm palette as retromanette.com, in native components.
enum Theme {
    static let background = Color(red: 0.027, green: 0.027, blue: 0.039)      // #07070A
    static let surface = Color(red: 0.063, green: 0.063, blue: 0.078)         // #101014
    static let surfaceHigh = Color.white.opacity(0.07)
    static let border = Color.white.opacity(0.09)
    static let borderStrong = Color.white.opacity(0.16)
    static let text = Color(red: 0.957, green: 0.945, blue: 0.918)            // #F4F1EA
    static let muted = Color(red: 0.957, green: 0.945, blue: 0.918).opacity(0.58)
    static let accent = Color(red: 1.0, green: 0.690, blue: 0.125)            // #FFB020
    static let accentSoft = Color(red: 1.0, green: 0.765, blue: 0.322)        // #FFC352
    static let accentInk = Color(red: 0.106, green: 0.071, blue: 0.0)         // #1B1200
    static let success = Color(red: 0.373, green: 0.816, blue: 0.541)         // #5FD08A

    static let radiusLarge: CGFloat = 28
    static let radiusMedium: CGFloat = 20
    static let radiusSmall: CGFloat = 14
}

extension Font {
    /// Editorial serif for titles (New York on iOS); Arabic falls back to the system Arabic face.
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

extension View {
    /// A soft glass panel used for cards and rows.
    func glassCard(radius: CGFloat = Theme.radiusMedium) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Theme.surfaceHigh)
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.border, lineWidth: 1))
        )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var prominent = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(prominent ? Theme.accentInk : Theme.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .fill(prominent ? AnyShapeStyle(LinearGradient(colors: [Theme.accentSoft, Theme.accent], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Theme.surfaceHigh))
            )
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous).stroke(prominent ? Color.clear : Theme.border, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct Chip: View {
    let text: String
    var tint: Color = Theme.muted
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Theme.surfaceHigh))
            .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
    }
}

struct SectionHeader: View {
    let title: LocalizedStringKey
    var body: some View {
        Text(title)
            .font(.display(22))
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
    }
}

/// A cover image with a graceful placeholder. It is downloaded once and then read from the device (CoverStore).
struct CoverImage: View {
    let url: URL?
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().interpolation(.none).scaledToFill().transition(.opacity)
            } else {
                ZStack {
                    Theme.surface
                    Image(systemName: "gamecontroller.fill").font(.system(size: 26)).foregroundStyle(Theme.muted.opacity(0.5))
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: image != nil)
        .task(id: url) {
            guard let url else { return }
            image = await CoverStore.shared.image(for: url)
        }
    }
}

/// The wordmark used at the top of the home screen.
struct Wordmark: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.accentInk)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(LinearGradient(colors: [Theme.accentSoft, Theme.accent], startPoint: .top, endPoint: .bottom)))
            Text("app.name")
                .font(.display(24))
                .foregroundStyle(Theme.text)
        }
    }
}
