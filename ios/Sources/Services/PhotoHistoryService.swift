import Foundation
import CloudKit

/// 自分が写真を投稿したポケふたのIDを保持する。地図のピンの色分けに使う。
/// 画像本体は不要なので`desiredKeys`を`manholeId`だけに絞り、CKAssetのダウンロードを避ける。
@MainActor
final class PhotoHistoryService: ObservableObject {
    @Published private(set) var photoManholeIds: Set<String> = []
    @Published var errorMessage: String?

    private let db = CKContainer(identifier: AppConfig.cloudKitContainerIdentifier).publicCloudDatabase

    func refresh(ownerRecordName: String) async {
        let predicate = NSPredicate(format: "ownerRecordName == %@", ownerRecordName)
        let query = CKQuery(recordType: "ManholePhoto", predicate: predicate)
        do {
            let (results, _) = try await db.records(matching: query, desiredKeys: ["manholeId"])
            photoManholeIds = Set(
                results.compactMap { _, result -> String? in
                    guard case .success(let record) = result else { return nil }
                    return record["manholeId"] as? String
                }
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
