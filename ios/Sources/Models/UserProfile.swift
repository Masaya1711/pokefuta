import Foundation
import CloudKit

struct UserProfile: Identifiable, Hashable {
    var id: String
    var displayName: String
    var backgroundCheckInEnabled: Bool
}

extension UserProfile {
    init?(record: CKRecord) {
        guard let displayName = record["displayName"] as? String else { return nil }
        id = record.recordID.recordName
        self.displayName = displayName
        backgroundCheckInEnabled = (record["backgroundCheckInEnabled"] as? Int64 ?? 0) != 0
    }
}
