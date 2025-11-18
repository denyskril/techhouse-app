import SwiftUI

struct AvatarView: View {
    let url: URL?
    let initials: String
    let size: CGFloat

    init(url: URL?, initials: String, size: CGFloat = 48) {
        self.url = url
        self.initials = initials
        self.size = size
    }

    var body: some View {
        ZStack {
            AsyncImageView(url: url)
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(AppTheme.primary.opacity(0.3), lineWidth: 1)
                )
                .contentShape(Circle())
            if url == nil {
                Text(initials)
                    .font(.system(size: size / 2, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }
}
