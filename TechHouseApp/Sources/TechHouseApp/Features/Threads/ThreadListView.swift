import SwiftUI

struct ThreadListView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: ThreadListViewModel
    @State private var showingComposer = false

    init() {
        _viewModel = StateObject(wrappedValue: ThreadListViewModel(api: PreviewXenForoAPI())) 
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                SearchBar(text: $viewModel.searchText, placeholder: "Search threads")
                content
            }
            .padding(.horizontal)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Chats")
                        .font(.title.bold())
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingComposer = true }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .task { await refreshIfNeeded() }
            .sheet(isPresented: $showingComposer) {
                ComposerSheet(isPresented: $showingComposer)
                    .environmentObject(appState)
            }
        }
        .onAppear {
            viewModel.update(api: appState.environment.api)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage {
            VStack(spacing: 12) {
                Text(error).foregroundStyle(.red)
                Button("Retry") { Task { await viewModel.load() } }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(viewModel.filteredThreads) { thread in
                NavigationLink(value: thread) {
                    ThreadRow(thread: thread)
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .navigationDestination(for: ThreadSummary.self) { thread in
                ThreadDetailView(thread: thread)
                    .environmentObject(appState)
            }
        }
    }

    private func refreshIfNeeded() async {
        if viewModel.threads.isEmpty {
            await viewModel.load()
        }
    }
}

private struct ThreadRow: View {
    let thread: ThreadSummary

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: thread.avatarURL, initials: initials)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(thread.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(thread.lastPostDate, style: .time)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                Text(thread.messagePreview ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 8)
    }

    private var initials: String {
        let components = thread.username.split(separator: " ")
        return components.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}
