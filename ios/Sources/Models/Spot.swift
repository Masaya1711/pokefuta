import Foundation
import CloudKit

enum SpotCategory: String, CaseIterable, Identifiable {
    case restaurant
    case sightseeing
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .restaurant: return "飲食店"
        case .sightseeing: return "観光スポット"
        case .other: return "その他"
        }
    }
}

struct Spot: Identifiable, Hashable {
    var id: String
    var manholeId: String
    var ownerRecordName: String
    var name: String
    var category: SpotCategory
    var rating: Int
    var comment: String
    var createdAt: Date?
}

extension Spot {
    init?(record: CKRecord) {
        guard let manholeId = record["manholeId"] as? String,
              let ownerRecordName = record["ownerRecordName"] as? String,
              let name = record["name"] as? String,
              let categoryRaw = record["category"] as? String,
              let category = SpotCategory(rawValue: categoryRaw),
              let ratingNumber = record["rating"] as? Int64 else { return nil }
        id = record.recordID.recordName
        self.manholeId = manholeId
        self.ownerRecordName = ownerRecordName
        self.name = name
        self.category = category
        rating = Int(ratingNumber)
        comment = record["comment"] as? String ?? ""
        createdAt = record.creationDate
    }
}
