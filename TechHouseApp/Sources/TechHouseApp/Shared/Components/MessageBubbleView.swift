import SwiftUI

struct MessageBubbleView: View {
    enum Alignment {
        case leading
        case trailing
    }

    let text: String
    let alignment: Alignment
    let timestamp: Date

    var body: some View {
        HStack {
            if alignment == .trailing { Spacer(minLength: 32) }
            VStack(alignment: alignment == .leading ? .leading : .trailing, spacing: 6) {
                Text(text)
                    .padding(12)
                    .background(alignment == .leading ? AppTheme.secondary : AppTheme.primary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text(timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
            if alignment == .leading { Spacer(minLength: 32) }
        }
    }
}
