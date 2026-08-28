import SwiftUI

/// iCloudアカウントに認証を委ねるため、ここでは状態確認とオンボーディング(表示名登録)のみを行う。
struct AuthView: View {
    @EnvironmentObject private var authService: AuthService

    @State private var displayNameInput = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("ポケふた収集")
        }
        .task {
            await authService.refreshAccountState()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch authService.state {
        case .checking:
            VStack(spacing: 12) {
                ProgressView()
                Text("iCloudの状態を確認しています…")
                    .foregroundStyle(.secondary)
            }

        case .iCloudUnavailable(let message):
            VStack(spacing: 16) {
                Image(systemName: "icloud.slash")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(message)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button("再確認する") {
                    Task { await authService.refreshAccountState() }
                }
            }

        case .needsOnboarding:
            Form {
                Section("表示名を登録してください") {
                    TextField("表示名", text: $displayNameInput)
                    Text("投稿した写真やスポットレビューに表示される名前です。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
                Section {
                    Button("はじめる") {
                        submitOnboarding()
                    }
                    .disabled(displayNameInput.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                }
            }

        case .ready:
            ProgressView()
        }
    }

    private func submitOnboarding() {
        errorMessage = nil
        isSubmitting = true
        Task {
            do {
                try await authService.completeOnboarding(displayName: displayNameInput.trimmingCharacters(in: .whitespaces))
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}
