import SwiftUI

struct AsyncImageView: View {
    @StateObject private var loader = ImageLoader()
    let url: URL?
    let placeholder: Image

    init(url: URL?, placeholder: Image = Image(systemName: "person.crop.circle.fill")) {
        self.url = url
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = loader.image {
                image.resizable()
            } else {
                placeholder.resizable()
                    .foregroundStyle(AppTheme.primary)
                    .opacity(0.6)
            }
        }
        .onAppear { loader.load(from: url) }
        .onDisappear { loader.cancel() }
    }
}
