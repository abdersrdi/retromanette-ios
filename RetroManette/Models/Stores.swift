import Foundation
import SwiftUI

/// Where the app keeps its files.
enum Paths {
    static let support: URL = {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
    static func folder(_ name: String) -> URL {
        let url = support.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    static var roms: URL { folder("ROMs") }
    static var library: URL { folder("Library") }
    static var saves: URL { folder("Saves") }
    static var system: URL { folder("System") }
    static func saveFolder(for key: String) -> URL {
        let safe = key.replacingOccurrences(of: "/", with: "_")
        return folder("Saves/\(safe)")
    }
}

// MARK: - Catalog

/// The catalog from retromanette.com. A copy ships inside the app, so the first launch works offline; a newer list is
/// fetched when there is a connection and kept on the device.
@MainActor
final class CatalogStore: ObservableObject {
    @Published private(set) var games: [Game] = []
    @Published private(set) var isLoading = false
    @Published private(set) var failed = false

    private let cacheURL = Paths.support.appendingPathComponent("games.json")

    var playable: [Game] { games.filter { $0.system.isPlayable } }
    var comingSoonCount: Int { games.filter { !$0.system.isPlayable }.count }

    func games(for system: GameSystem) -> [Game] { playable.filter { $0.system == system } }
    func game(slug: String) -> Game? { games.first { $0.slug == slug } }

    func load() async {
        if games.isEmpty {
            if let cached = try? Data(contentsOf: cacheURL), let list = try? JSONDecoder().decode([Game].self, from: cached) {
                games = list
            } else if let bundled = Bundle.main.url(forResource: "games", withExtension: "json"),
                      let data = try? Data(contentsOf: bundled), let list = try? JSONDecoder().decode([Game].self, from: data) {
                games = list
            }
        }
        isLoading = true
        failed = false
        defer { isLoading = false }
        do {
            var request = URLRequest(url: Site.url("/games.json"))
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let list = try JSONDecoder().decode([Game].self, from: data)
            if !list.isEmpty {
                games = list
                try? data.write(to: cacheURL, options: .atomic)
            }
        } catch {
            failed = games.isEmpty
        }
    }
}

// MARK: - Game files

enum ROMError: LocalizedError {
    case downloadFailed
    var errorDescription: String? { String(localized: "detail.downloadFailed") }
}

/// Downloads catalog games when they are first played and keeps them on the device.
enum ROMStore {
    static func localURL(for game: Game) -> URL {
        Paths.roms.appendingPathComponent("\(game.slug).\(game.system.fileExtension)")
    }

    static func ensure(_ game: Game) async throws -> URL {
        let local = localURL(for: game)
        if FileManager.default.fileExists(atPath: local.path) { return local }
        let (tmp, response) = try await URLSession.shared.download(from: game.romURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ROMError.downloadFailed }
        try? FileManager.default.removeItem(at: local)
        try FileManager.default.moveItem(at: tmp, to: local)
        return local
    }
}

// MARK: - Library (games the user adds)

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var games: [LibraryGame] = []
    private let indexURL = Paths.support.appendingPathComponent("library.json")

    init() {
        if let data = try? Data(contentsOf: indexURL), let list = try? JSONDecoder().decode([LibraryGame].self, from: data) {
            games = list.sorted { $0.addedAt > $1.addedAt }
        }
    }

    enum ImportError: Error { case unsupported, copyFailed }

    /// Copies a file picked in Files into the app. The file stays on this device and is never uploaded.
    func add(from url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension.lowercased()
        guard let system = GameSystem(rawValue: ext), system.isPlayable else { throw ImportError.unsupported }
        let id = UUID()
        let fileName = "\(id.uuidString).\(ext)"
        do {
            try FileManager.default.copyItem(at: url, to: Paths.library.appendingPathComponent(fileName))
        } catch {
            throw ImportError.copyFailed
        }
        let name = url.deletingPathExtension().lastPathComponent
        games.insert(LibraryGame(id: id, name: name, fileName: fileName, system: system, addedAt: Date()), at: 0)
        save()
    }

    #if DEBUG
    /// Screenshot builds: puts a catalog game into the library under a friendly name.
    func seed(from url: URL, name: String, system: GameSystem) {
        guard !games.contains(where: { $0.name == name }) else { return }
        let id = UUID()
        let fileName = "\(id.uuidString).\(system.fileExtension)"
        guard (try? FileManager.default.copyItem(at: url, to: Paths.library.appendingPathComponent(fileName))) != nil else { return }
        games.append(LibraryGame(id: id, name: name, fileName: fileName, system: system, addedAt: Date()))
        save()
    }
    #endif

    func remove(_ game: LibraryGame) {
        try? FileManager.default.removeItem(at: url(for: game))
        try? FileManager.default.removeItem(at: Paths.saveFolder(for: game.key))
        games.removeAll { $0.id == game.id }
        save()
    }

    func url(for game: LibraryGame) -> URL { Paths.library.appendingPathComponent(game.fileName) }

    private func save() {
        if let data = try? JSONEncoder().encode(games) { try? data.write(to: indexURL, options: .atomic) }
    }
}

// MARK: - Recently played

@MainActor
final class RecentStore: ObservableObject {
    @Published private(set) var entries: [RecentEntry] = []
    private let defaultsKey = "recent.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey), let list = try? JSONDecoder().decode([RecentEntry].self, from: data) {
            entries = list
        }
    }

    func played(_ entry: RecentEntry) {
        entries.removeAll { $0.key == entry.key }
        entries.insert(entry, at: 0)
        if entries.count > 12 { entries = Array(entries.prefix(12)) }
        if let data = try? JSONEncoder().encode(entries) { UserDefaults.standard.set(data, forKey: defaultsKey) }
    }
}
