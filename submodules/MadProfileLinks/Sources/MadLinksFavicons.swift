import Foundation
import UIKit
import MadProfileLinksCore

public final class MadLinksFavicons {
    public static let shared = MadLinksFavicons()

    private var images: [String: UIImage] = [:]
    private var waiting: [String: [(UIImage?) -> Void]] = [:]
    private var failed: Set<String> = []

    private func render(_ favicon: UIImage) -> UIImage {
        let size = CGSize(width: 60.0, height: 60.0)
        return UIGraphicsImageRenderer(size: size).image { _ in
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 14.0).addClip()
            favicon.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    public func cached(host: String) -> UIImage? {
        return self.images[host]
    }

    public func load(host: String, completion: @escaping (UIImage?) -> Void) {
        if let image = self.images[host] {
            completion(image)
            return
        }
        if self.failed.contains(host) {
            completion(nil)
            return
        }
        if self.waiting[host] != nil {
            self.waiting[host]?.append(completion)
            return
        }
        self.waiting[host] = [completion]
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        guard let encoded = host.addingPercentEncoding(withAllowedCharacters: allowed), let url = URL(string: "https://icons.duckduckgo.com/ip3/\(encoded).ico") else {
            self.finish(host: host, image: nil)
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15.0
        URLSession.shared.dataTask(with: request, completionHandler: { [weak self] data, response, _ in
            var image: UIImage?
            if let data, (response as? HTTPURLResponse)?.statusCode == 200, data.count < 512 * 1024, let favicon = UIImage(data: data) {
                image = self?.render(favicon)
            }
            DispatchQueue.main.async {
                self?.finish(host: host, image: image)
            }
        }).resume()
    }

    private func finish(host: String, image: UIImage?) {
        if let image {
            self.images[host] = image
        } else {
            self.failed.insert(host)
        }
        let callbacks = self.waiting.removeValue(forKey: host) ?? []
        for callback in callbacks {
            callback(image)
        }
    }
}

public extension MadLinksUI {
    static func setIcon(for account: MadLinksAccount, apply: @escaping (UIImage?) -> Void) {
        let fallback = MadLinksUI.icon(account.platform)
        guard account.usesFavicon, let host = account.faviconHost else {
            apply(fallback)
            return
        }
        if let cached = MadLinksFavicons.shared.cached(host: host) {
            apply(cached)
            return
        }
        apply(fallback)
        MadLinksFavicons.shared.load(host: host, completion: { image in
            if let image {
                apply(image)
            }
        })
    }
}
