import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("TechHouse")
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.primary)
            VStack(spacing: 16) {
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .padding()
                    .background(AppTheme.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                SecureField("Password", text: $password)
                    .padding()
                    .background(AppTheme.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .foregroundStyle(.white)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await signIn() }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                    }
                    Text(isLoading ? "Signing in" : "Sign in")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white)
            }
            .disabled(isLoading || username.isEmpty || password.isEmpty)
            Spacer()
        }
        .padding()
        .background(AppTheme.background.ignoresSafeArea())
    }

    private func signIn() async {
        guard !username.isEmpty, !password.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        await appState.authenticate(username: username, password: password)
        if let lastError = appState.session.lastError {
            errorMessage = lastError.localizedDescription
        }
        isLoading = false
    }
}
