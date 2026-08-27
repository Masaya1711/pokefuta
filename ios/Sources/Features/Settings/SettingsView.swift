import SwiftUI
import FirebaseFirestore

struct SettingsView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var locationManager: LocationManager

    @State private var backgroundCheckInEnabled = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("バックグラウンドでの自動チェックイン検知", isOn: $backgroundCheckInEnabled)
                        .onChange(of: backgroundCheckInEnabled) { newValue in
                            updateBackgroundSetting(newValue)
                        }
                    Text("ONにすると、アプリを開いていなくても近くのポケふたを検知して通知します。「常に許可」の位置情報アクセスが必要です。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }

                Section {
                    Button("ログアウト", role: .destructive) {
                        try? authService.signOut()
                    }
                }
            }
            .navigationTitle("設定")
            .task { await loadSetting() }
        }
    }

    private func loadSetting() async {
        guard let userId = authService.currentUser?.uid else { return }
        do {
            let snapshot = try await Firestore.firestore().collection("users").document(userId).getDocument()
            let profile = try snapshot.data(as: UserProfile.self)
            backgroundCheckInEnabled = profile.backgroundCheckInEnabled
            locationManager.setBackgroundCheckInEnabled(profile.backgroundCheckInEnabled)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateBackgroundSetting(_ enabled: Bool) {
        guard let userId = authService.currentUser?.uid else { return }
        locationManager.setBackgroundCheckInEnabled(enabled)
        Firestore.firestore()
            .collection("users")
            .document(userId)
            .setData(["backgroundCheckInEnabled": enabled], merge: true) { error in
                if let error {
                    errorMessage = error.localizedDescription
                }
            }
    }
}
