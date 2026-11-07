import SwiftUI
import UIKit

enum Haptics {
    private static let generator = UIImpactFeedbackGenerator(style: .light)
    static func tap() {
        guard UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true else { return }
        generator.impactOccurred(intensity: 0.7)
    }
}

/// The glass look shared by every on-screen control.
private struct GlassFill: ViewModifier {
    let pressed: Bool
    func body(content: Content) -> some View {
        content
            .background(Circle().fill(pressed ? AnyShapeStyle(Theme.accent.opacity(0.9)) : AnyShapeStyle(.ultraThinMaterial)))
            .overlay(Circle().stroke(Color.white.opacity(pressed ? 0.5 : 0.18), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }
}

/// A round button (A, B, X, Y).
struct PadKey: View {
    let label: String
    let button: PadButton
    var size: CGFloat = 68
    let press: (PadButton, Bool) -> Void
    @State private var pressed = false

    var body: some View {
        Text(label)
            .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
            .foregroundStyle(pressed ? Theme.accentInk : Theme.text)
            .frame(width: size, height: size)
            .modifier(GlassFill(pressed: pressed))
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressed { pressed = true; press(button, true); Haptics.tap() }
                }
                .onEnded { _ in
                    pressed = false
                    press(button, false)
                })
    }
}

/// A pill-shaped button (Start, Select, L, R).
struct PadPill: View {
    let label: String
    let button: PadButton
    var width: CGFloat = 88
    var height: CGFloat = 34
    let press: (PadButton, Bool) -> Void
    @State private var pressed = false

    var body: some View {
        Text(label)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .textCase(.uppercase)
            .foregroundStyle(pressed ? Theme.accentInk : Theme.text)
            .frame(width: width, height: height)
            .background(Capsule().fill(pressed ? AnyShapeStyle(Theme.accent.opacity(0.9)) : AnyShapeStyle(.ultraThinMaterial)))
            .overlay(Capsule().stroke(Color.white.opacity(pressed ? 0.5 : 0.18), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
            .contentShape(Capsule())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressed { pressed = true; press(button, true); Haptics.tap() }
                }
                .onEnded { _ in
                    pressed = false
                    press(button, false)
                })
    }
}

/// The directional pad: one finger can slide between the eight directions.
struct DPadView: View {
    var size: CGFloat = 160
    let press: (PadButton, Bool) -> Void
    @State private var active: Set<PadButton> = []

    var body: some View {
        ZStack {
            Circle().fill(.ultraThinMaterial)
            Circle().stroke(Color.white.opacity(0.18), lineWidth: 1)
            arrow("chevron.up", .up, x: 0, y: -1)
            arrow("chevron.down", .down, x: 0, y: 1)
            arrow("chevron.left", .left, x: -1, y: 0)
            arrow("chevron.right", .right, x: 1, y: 0)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { value in update(value.location) }
            .onEnded { _ in set([]) })
    }

    private func arrow(_ symbol: String, _ button: PadButton, x: CGFloat, y: CGFloat) -> some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.16, weight: .bold))
            .foregroundStyle(active.contains(button) ? Theme.accent : Theme.text.opacity(0.75))
            .offset(x: x * size * 0.33, y: y * size * 0.33)
    }

    private func update(_ point: CGPoint) {
        let dx = point.x - size / 2
        let dy = point.y - size / 2
        if hypot(dx, dy) < size * 0.12 { set([]); return }
        var directions: Set<PadButton> = []
        let ax = abs(dx), ay = abs(dy)
        if ax > ay * 0.45 { directions.insert(dx > 0 ? .right : .left) }
        if ay > ax * 0.45 { directions.insert(dy > 0 ? .down : .up) }
        set(directions)
    }

    private func set(_ new: Set<PadButton>) {
        guard new != active else { return }
        if !new.subtracting(active).isEmpty { Haptics.tap() }
        for button in [PadButton.up, .down, .left, .right] { press(button, new.contains(button)) }
        active = new
    }
}

/// A and B in the diagonal layout of the handheld.
struct ActionCluster: View {
    var size: CGFloat = 68
    let press: (PadButton, Bool) -> Void

    var body: some View {
        ZStack {
            PadKey(label: "B", button: .b, size: size, press: press).offset(x: -size * 0.62, y: size * 0.42)
            PadKey(label: "A", button: .a, size: size, press: press).offset(x: size * 0.62, y: -size * 0.42)
        }
        .frame(width: size * 2.5, height: size * 2.1)
    }
}
