import Foundation
import FirebaseFirestore

enum CheckinMethod: String, Codable {
    case gpsAuto = "gps_auto"
    case manual
}

struct Checkin: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var userId: String
    var manholeId: String
    var method: CheckinMethod
    var distanceMeters: Double
    var photoId: String?
    @ServerTimestamp var checkedInAt: Date?
}
