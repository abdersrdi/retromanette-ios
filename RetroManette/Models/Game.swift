import Foundation

enum Site {
    static let base = URL(string: "https://retromanette.com")!
    static func url(_ path: String) -> URL { URL(string: path, relativeTo: base)!.absoluteURL }
}

/// Systems the app knows about. Only the ones with a permissive emulator core inside the app can be played.
enum GameSystem: String, Codable {
    case gb, gbc, gba, nes

    /// mGBA (MPL-2.0) plays the GB, GBC and GBA formats. NES needs another core and comes later.
    var isPlayable: Bool { self != .nes }
    var titleKey: String {
        switch self {
        case .gb: return "system.gb"
        case .gbc: return "system.gbc"
        case .gba: return "system.gba"
        case .nes: return "system.nes"
        }
    }
    var fileExtension: String { rawValue }
}

/// One game of the catalog (the list that retromanette.com publishes in games.json). Every game is released by its
/// authors under an open or permissive license.
struct Game: Identifiable, Codable, Hashable {
    let id: Int
    let slug: String
    let title: String
    let developer: String
    let genre: String
    let rom: String
    let cover: String
    let license: String
    let licenseFile: String?
    let source: String?
    let players: Int?

    var key: String { "catalog-\(slug)" }
    var system: GameSystem { GameSystem(rawValue: (rom as NSString).pathExtension.lowercased()) ?? .gb }
    var coverURL: URL { Site.url(cover) }
    var romURL: URL { Site.url(rom) }
    var licenseURL: URL? { licenseFile.map { Site.url($0) } }
    var sourceURL: URL? { source.flatMap { URL(string: $0) } }
    var genreKey: String { "genre.\(genre)" }
}

/// A game the user added from Files. It never leaves the device.
struct LibraryGame: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let fileName: String          // name inside the app's Library folder
    let system: GameSystem
    let addedAt: Date

    var key: String { "library-\(id.uuidString)" }
}

/// Everything the player needs to start a game.
struct PlayRequest: Identifiable, Hashable {
    let key: String
    let title: String
    let romPath: String
    let system: GameSystem
    var id: String { key }
}

/// One entry of the "Continue playing" row.
struct RecentEntry: Codable, Hashable, Identifiable {
    let key: String
    let title: String
    let slug: String?             // catalog games only (the library has no covers)
    var id: String { key }
}
