import Foundation
import CloudKit

enum AccountState: Equatable {
    case checking
    case iCloudUnavailable(String)
    case needsOnboarding
    case ready
}

/// CloudKitはiCloudアカウントに認証を委ねるため、メール/パスワードのサインアップ画面は不要。
/// 初回起動時にiCloudのサインイン状態を確認し、表示名を1つ登録するだけで利用開始できる。
@MainActor
final class AuthService: ObservableObject {
    @Published var state: AccountState = .checking
    @Published var displayName: String = ""
    @Published var backgroundCheckInEnabled: Bool = false
    @Published private(set) var userRecordName: String?

    private let container = CKContainer(identifier: AppConfig.cloudKitContainerIdentifier)

    var isSignedIn: Bool { state == .ready }

    func refreshAccountState() async {
        state = .checking
        do {
            let status = try await container.accountStatus()
            guard status == .available else {
                state = .iCloudUnavailable("iCloudにサインインしてください(設定アプリ > 自分の名前 > iCloud)。")
                return
            }
            let recordID = try await container.userRecordID()
            userRecordName = recordID.recordName

            do {
                let record = try await container.publicCloudDatabase.record(for: recordID)
                if let profile = UserProfile(record: record) {
                    displayName = profile.displayName
                    backgroundCheckInEnabled = profile.backgroundCheckInEnabled
                    state = .ready
                    return
                }
            } catch {
                // レコード未作成(初回起動)の場合はここに来る想定
            }
            state = .needsOnboarding
        } catch {
            state = .iCloudUnavailable(error.localizedDescription)
        }
    }

    func completeOnboarding(displayName: String) async throws {
        guard let userRecordName else { return }
        let recordID = CKRecord.ID(recordName: userRecordName)
        let record = CKRecord(recordType: "UserProfile", recordID: recordID)
        record["displayName"] = displayName
        record["backgroundCheckInEnabled"] = Int64(0)
        _ = try await container.publicCloudDatabase.save(record)
        self.displayName = displayName
        self.backgroundCheckInEnabled = false
        state = .ready
    }

    func updateBackgroundCheckInEnabled(_ enabled: Bool) async throws {
        guard let userRecordName else { return }
        let recordID = CKRecord.ID(recordName: userRecordName)
        let record = try await container.publicCloudDatabase.record(for: recordID)
        record["backgroundCheckInEnabled"] = Int64(enabled ? 1 : 0)
        _ = try await container.publicCloudDatabase.save(record)
        backgroundCheckInEnabled = enabled
    }
}
