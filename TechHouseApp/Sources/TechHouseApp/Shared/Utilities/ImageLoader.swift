import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#else
typealias PlatformImage = AnyObject
#endif

final class ImageLoader: ObservableObject {
    @Published var image: Image?

    private var cancellable: AnyCancellable?
    private static let cache = NSCache<NSURL, PlatformImage>()

    func load(from url: URL?) {
        guard let url else { return }
        if let cached = Self.cache.object(forKey: url as NSURL) {
            image = makeImage(from: cached)
            return
        }

        cancellable = URLSession.shared
            .dataTaskPublisher(for: url)
            .map { Self.makePlatformImage(from: $0.data) }
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] platformImage in
                guard let platformImage else { return }
                Self.cache.setObject(platformImage, forKey: url as NSURL)
                self?.image = self?.makeImage(from: platformImage)
            }
    }

    func cancel() {
        cancellable?.cancel()
    }
}

private extension ImageLoader {
    static func makePlatformImage(from data: Data) -> PlatformImage? {
        #if canImport(UIKit)
        return UIImage(data: data)
        #elseif canImport(AppKit)
        return NSImage(data: data)
        #else
        return nil
        #endif
    }

    func makeImage(from platformImage: PlatformImage) -> Image {
        #if canImport(UIKit)
        return Image(uiImage: platformImage)
        #elseif canImport(AppKit)
        return Image(nsImage: platformImage)
        #else
        return Image(systemName: "photo")
        #endif
    }
}
