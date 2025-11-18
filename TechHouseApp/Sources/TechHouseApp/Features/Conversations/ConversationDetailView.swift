import SwiftUI

struct ConversationDetailView: View {
    let conversation: ConversationSummary

    var body: some View {
        VStack {
            Text("Conversation detail work in progress")
                .foregroundStyle(.gray)
                .padding()
            Spacer()
        }
        .navigationTitle(conversation.title)
        .background(AppTheme.background.ignoresSafeArea())
    }
}
