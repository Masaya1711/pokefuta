import Foundation
import CloudKit

@MainActor
final class CheckinHistoryService: ObservableObject {
    @Published var checkins: [Checkin] = []
    @Published var errorMessage: String?

    private let db = CKContainer.default().publicCloudDatabase

    func refresh(ownerRecordName: String) async {
        let predicate = NSPredicate(format: "ownerRecordName == %@", ownerRecordName)
        let query = CKQuery(recordType: "Checkin", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        do {
            let (results, _) = try await db.records(matching: query)
            checkins = results.compactMap { _, result -> Checkin? in
                guard case .success(let record) = result else { return nil }
                return Checkin(record: record)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var checkedInManholeIds: Set<String> {
        Set(checkins.map { $0.manholeId })
    }
}
