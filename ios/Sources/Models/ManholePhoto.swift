import Foundation
import CloudKit

struct ManholePhoto: Identifiable, Hashable {
    var id: String
    var manholeId: String
    var ownerRecordName: String
    var imageData: Data?
    var createdAt: Date?

    static func == (lhs: ManholePhoto, rhs: ManholePhoto) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension ManholePhoto {
    init?(record: CKRecord) {
        guard let manholeId = record["manholeId"] as? String,
              let ownerRecordName = record["ownerRecordName"] as? String else { return nil }
        id = record.recordID.recordName
        self.manholeId = manholeId
        self.ownerRecordName = ownerRecordName
        createdAt = record.creationDate
        if let asset = record["asset"] as? CKAsset, let url = asset.fileURL {
            imageData = try? Data(contentsOf: url)
        } else {
            imageData = nil
        }
    }
}
