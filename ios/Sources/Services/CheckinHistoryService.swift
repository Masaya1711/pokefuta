import Foundation
import CloudKit

@MainActor
final class CheckinHistoryService: ObservableObject {
    @Published var checkins: [Checkin] = []
    @Published var errorMessage: String?

    private let db = CKContainer(identifier: AppConfig.cloudKitContainerIdentifier).publicCloudDatabase

    func refresh(ownerRecordName: String) async {
        let predicate = NSPredicate(format: "ownerRecordName == %@", ownerRecordName)
        // CloudKitはスキーマ側でSortable指定がない項目で並び替えるとクエリ全体が失敗するため、
        // 並び替えはサーバーに要求せずアプリ側で行う。
        let query = CKQuery(recordType: "Checkin", predicate: predicate)
        do {
            let (results, _) = try await db.records(matching: query)
            checkins = results
                .compactMap { _, result -> Checkin? in
                    guard case .success(let record) = result else { return nil }
                    return Checkin(record: record)
                }
                .sorted { ($0.checkedInAt ?? .distantPast) > ($1.checkedInAt ?? .distantPast) }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var checkedInManholeIds: Set<String> {
        Set(checkins.map { $0.manholeId })
    }
}
