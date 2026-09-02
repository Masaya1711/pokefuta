import Foundation
import CloudKit

/// 自分が写真を投稿したポケふたのIDと投稿日時を保持する。地図のピンの色分けとコレクション一覧に使う。
///
/// CloudKitの検索は`ownerRecordName`にQueryableインデックスが設定されていないと失敗するため、
/// それだけに頼らず、投稿した時点で端末側にも記録する。端末側の記録と検索結果は合成して使う。
@MainActor
final class PhotoHistoryService: ObservableObject {
    @Published private(set) var photoDatesById: [String: Date] = [:]
    @Published var errorMessage: String?

    var photoManholeIds: Set<String> { Set(photoDatesById.keys) }

    private static let storageKey = "uploadedPhotoDatesByManholeId"

    private let db = CKContainer(identifier: AppConfig.cloudKitContainerIdentifier).publicCloudDatabase
    private var remoteDates: [String: Date] = [:]
    private var localDates: [String: Date]

    init() {
        let stored = UserDefaults.standard.dictionary(forKey: Self.storageKey) as? [String: Double] ?? [:]
        localDates = stored.mapValues { Date(timeIntervalSince1970: $0) }
        photoDatesById = localDates
    }

    /// 写真の投稿が成功した直後に呼ぶ。CloudKitの検索可否に関わらず反映される。
    func markUploaded(manholeId: String) {
        localDates[manholeId] = Date()
        persistLocal()
        merge()
    }

    /// そのポケふたの自分の写真がすべて削除されたときに呼ぶ。
    func markRemoved(manholeId: String) {
        localDates.removeValue(forKey: manholeId)
        remoteDates.removeValue(forKey: manholeId)
        persistLocal()
        merge()
    }

    /// `manholeIds`はカタログの全ポケふたID。`ownerRecordName`での検索が使えない場合の
    /// 代替経路で使う。
    func refresh(ownerRecordName: String, manholeIds: [String]) async {
        do {
            // 1段目: 自分のレコードだけを直接検索する(Queryableインデックスが必要)。
            let predicate = NSPredicate(format: "ownerRecordName == %@", ownerRecordName)
            let byOwner = try await fetchDates(predicate: predicate, ownerRecordName: ownerRecordName)
            // 検索自体は成功しても0件が返ることがあるため、その場合も2段目を試す。
            remoteDates = byOwner.isEmpty
                ? try await fetchDatesByManholeIds(manholeIds, ownerRecordName: ownerRecordName)
                : byOwner
            errorMessage = nil
        } catch {
            do {
                // 2段目: `manholeId`はインデックスがあるため、そちらで全件を取得して端末側で絞る。
                remoteDates = try await fetchDatesByManholeIds(manholeIds, ownerRecordName: ownerRecordName)
                errorMessage = nil
            } catch {
                // どちらも失敗しても端末側の記録は残すため、色分けと一覧は維持される。
                errorMessage = error.localizedDescription
            }
        }
        merge()
    }

    private func fetchDates(predicate: NSPredicate, ownerRecordName: String) async throws -> [String: Date] {
        let query = CKQuery(recordType: "ManholePhoto", predicate: predicate)
        let (results, _) = try await db.records(
            matching: query,
            desiredKeys: ["manholeId", "ownerRecordName"]
        )
        var dates: [String: Date] = [:]
        for (_, result) in results {
            guard case .success(let record) = result,
                  let manholeId = record["manholeId"] as? String,
                  record["ownerRecordName"] as? String == ownerRecordName else { continue }
            let date = record.creationDate ?? .distantPast
            if let existing = dates[manholeId], existing >= date { continue }
            dates[manholeId] = date
        }
        return dates
    }

    /// `manholeId IN [...]`で分割検索する。1回のクエリに渡すIDが多すぎると弾かれるため小分けにする。
    private func fetchDatesByManholeIds(_ manholeIds: [String], ownerRecordName: String) async throws -> [String: Date] {
        var dates: [String: Date] = [:]
        for batch in stride(from: 0, to: manholeIds.count, by: 100).map({ Array(manholeIds[$0..<min($0 + 100, manholeIds.count)]) }) {
            let predicate = NSPredicate(format: "manholeId IN %@", batch)
            let batchDates = try await fetchDates(predicate: predicate, ownerRecordName: ownerRecordName)
            for (manholeId, date) in batchDates {
                if let existing = dates[manholeId], existing >= date { continue }
                dates[manholeId] = date
            }
        }
        return dates
    }

    private func merge() {
        var merged = remoteDates
        for (manholeId, date) in localDates {
            if let existing = merged[manholeId], existing >= date { continue }
            merged[manholeId] = date
        }
        photoDatesById = merged
    }

    private func persistLocal() {
        UserDefaults.standard.set(
            localDates.mapValues { $0.timeIntervalSince1970 },
            forKey: Self.storageKey
        )
    }
}
