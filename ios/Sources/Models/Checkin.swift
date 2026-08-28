import Foundation
import CloudKit

enum CheckinMethod: String {
    case gpsAuto = "gps_auto"
    case manual
}

struct Checkin: Identifiable, Hashable {
    var id: String
    var manholeId: String
    var ownerRecordName: String
    var method: CheckinMethod
    var distanceMeters: Double
    var checkedInAt: Date?
}

extension Checkin {
    init?(record: CKRecord) {
        guard let manholeId = record["manholeId"] as? String,
              let ownerRecordName = record["ownerRecordName"] as? String,
              let methodRaw = record["method"] as? String,
              let method = CheckinMethod(rawValue: methodRaw),
              let distance = record["distanceMeters"] as? Double else { return nil }
        id = record.recordID.recordName
        self.manholeId = manholeId
        self.ownerRecordName = ownerRecordName
        self.method = method
        distanceMeters = distance
        checkedInAt = record.creationDate
    }
}
