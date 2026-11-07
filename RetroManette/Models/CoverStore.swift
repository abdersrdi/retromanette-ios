import Foundation
import UIKit

/// Covers are kept on the device after the first download, so the home screen is instant the next time and works offline.
final class CoverStore {
    static let shared = CoverStore()
    private let memory = NSCache<NSString, UIImage>()
    private let folder: URL = {
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("covers", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private func file(for url: URL) -> URL {
        let name = url.path.replacingOccurrences(of: "/", with: "_")
        return folder.appendingPathComponent(name)
    }

    func image(for url: URL) async -> UIImage? {
        let key = url.absoluteString as NSString
        if let cached = memory.object(forKey: key) { return cached }
        let local = file(for: url)
        if let data = try? Data(contentsOf: local), let image = UIImage(data: data) {
            memory.setObject(image, forKey: key)
            return image
        }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200, let image = UIImage(data: data) else { return nil }
        try? data.write(to: local, options: .atomic)
        memory.setObject(image, forKey: key)
        return image
    }
}
