import SwiftUI

struct ComposerSheet: View {
    @EnvironmentObject private var appState: AppState
    @Binding var isPresented: Bool
    @State private var title: String = ""
    @State private var message: String = ""
    @State private var isPosting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Thread title") {
                    TextField("What is this about?", text: $title)
                }
                Section("Message") {
                    TextEditor(text: $message)
                        .frame(height: 150)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Thread")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { Task { await createThread() } }) {
                        if isPosting { ProgressView() }
                        Text("Post")
                    }
                    .disabled(isPosting || title.isEmpty || message.isEmpty)
                }
            }
        }
    }

    private func createThread() async {
        // Placeholder: XenForo API requires custom endpoint for thread creation
        isPosting = true
        errorMessage = "Thread creation endpoint not implemented yet."
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isPosting = false
    }
}
