import Foundation
import CloudKit

/// 自分が写真を投稿したポケふたのIDを保持する。地図のピンの色分けに使う。
///
/// CloudKitの検索は`ownerRecordName`にQueryableインデックスが設定されていないと失敗するため、
/// それだけに頼らず、投稿した時点で端末側にも記録して即座に色へ反映させる。
/// 端末側の記録とCloudKitの検索結果は合成して使う。
@MainActor
final class PhotoHistoryService: ObservableObject {
    @Published private(set) var photoManholeIds: Set<String> = []
    @Published var errorMessage: String?

    private static let storageKey = "uploadedPhotoManholeIds"

    private let db = CKContainer(identifier: AppConfig.cloudKitContainerIdentifier).publicCloudDatabase
    private var remoteIds: Set<String> = []
    private var localIds: Set<String>

    init() {
        localIds = Set(UserDefaults.standard.stringArray(forKey: Self.storageKey) ?? [])
        photoManholeIds = localIds
    }

    /// 写真の投稿が成功した直後に呼ぶ。CloudKitの検索可否に関わらず色分けへ反映される。
    func markUploaded(manholeId: String) {
        localIds.insert(manholeId)
        UserDefaults.standard.set(Array(localIds), forKey: Self.storageKey)
        photoManholeIds = remoteIds.union(localIds)
    }

    func refresh(ownerRecordName: String) async {
        let predicate = NSPredicate(format: "ownerRecordName == %@", ownerRecordName)
        let query = CKQuery(recordType: "ManholePhoto", predicate: predicate)
        do {
            let (results, _) = try await db.records(matching: query, desiredKeys: ["manholeId"])
            remoteIds = Set(
                results.compactMap { _, result -> String? in
                    guard case .success(let record) = result else { return nil }
                    return record["manholeId"] as? String
                }
            )
            errorMessage = nil
        } catch {
            // 検索が失敗しても端末側の記録は残すため、色分けは維持される。
            errorMessage = error.localizedDescription
        }
        photoManholeIds = remoteIds.union(localIds)
    }
}
