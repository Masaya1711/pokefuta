import Foundation
import FirebaseFirestore

enum ModerationStatus: String, Codable {
    case pending
    case approved
    case rejected
}

struct ManholePhoto: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var userId: String
    var storagePath: String
    var downloadUrl: String
    @ServerTimestamp var createdAt: Date?
    var moderationStatus: ModerationStatus
}
