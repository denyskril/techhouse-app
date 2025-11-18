import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 96, height: 96)
                .foregroundStyle(AppTheme.primary)
            Button(role: .destructive) {
                appState.signOut()
            } label: {
                Text("Sign out")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.red.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            Spacer()
        }
        .padding()
        .background(AppTheme.background.ignoresSafeArea())
    }
}
