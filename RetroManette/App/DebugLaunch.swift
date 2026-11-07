import Foundation

/// Sent by the scripted tour (debug builds only) to move the screens without a finger on the glass.
extension Notification.Name {
    static let tourOpenGame = Notification.Name("retromanette.tourOpenGame")      // object: Game
    static let tourToggleMenu = Notification.Name("retromanette.tourToggleMenu")
}

#if DEBUG
/// Launch arguments of debug builds. The screenshot workflow uses them; release builds do not contain this code.
///   -tab N            open a tab (0 discover, 1 library, 2 settings)
///   -autoplay SLUG    start a catalog game
///   -demo             while a game runs, press buttons like a player would
///   -openGame SLUG    open a game's page
///   -showPremium      open the Premium page
///   -store            show the Premium price without asking the App Store
///   -seedLibrary      fill the library with a few catalog games
///   -tour             run the whole scripted tour (used for the screen recordings)
enum DebugArgs {
    static let all = ProcessInfo.processInfo.arguments
    static func has(_ name: String) -> Bool { all.contains(name) }
    static func value(_ name: String) -> String? {
        guard let i = all.firstIndex(of: name), i + 1 < all.count else { return nil }
        return all[i + 1]
    }
}

/// Button presses for a game that is already running: START through the menus, then some playing.
enum DemoInput {
    static func run(_ session: EmulatorSession, skipIntro: Bool = false) async {
        func tap(_ button: PadButton, hold: Double = 0.18) async {
            session.press(button, down: true)
            try? await Task.sleep(nanoseconds: UInt64(hold * 1_000_000_000))
            session.press(button, down: false)
        }
        func wait(_ seconds: Double) async { try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }

        if skipIntro {
            await wait(0.6)
        } else {
            await wait(0.8)
            await tap(.start)
            await wait(1.0)
            await tap(.a)
            await wait(1.0)
            await tap(.start)
            await wait(1.2)
        }
        // some playing: the pad moves left and right, A on and off
        let pattern: [(PadButton, Double)] = [(.right, 0.5), (.a, 0.3), (.right, 0.6), (.a, 0.3), (.left, 0.5), (.a, 0.3), (.left, 0.6), (.a, 0.3)]
        for _ in 0..<6 {
            for (button, hold) in pattern {
                await tap(button, hold: hold)
                await wait(0.12)
            }
        }
    }
}
#endif
