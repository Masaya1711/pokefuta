import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var locationManager: LocationManager

    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("アカウント") {
                    LabeledContent("表示名", value: authService.displayName)
                }

                Section {
                    Toggle(
                        "バックグラウンドでの自動チェックイン検知",
                        isOn: Binding(
                            get: { authService.backgroundCheckInEnabled },
                            set: { updateBackgroundSetting($0) }
                        )
                    )
                    Text("ONにすると、アプリを開いていなくても近くのポケふたを検知して通知します。「常に許可」の位置情報アクセスが必要です。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("設定")
            .task {
                locationManager.setBackgroundCheckInEnabled(authService.backgroundCheckInEnabled)
            }
        }
    }

    private func updateBackgroundSetting(_ enabled: Bool) {
        locationManager.setBackgroundCheckInEnabled(enabled)
        Task {
            do {
                try await authService.updateBackgroundCheckInEnabled(enabled)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
