import Foundation
import FirebaseFirestore

struct UserProfile: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var displayName: String
    var backgroundCheckInEnabled: Bool
    @ServerTimestamp var createdAt: Date?
}
