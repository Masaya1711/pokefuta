import Foundation
import FirebaseFirestore

enum SpotCategory: String, Codable, CaseIterable, Identifiable {
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

struct Spot: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var userId: String
    var name: String
    var category: SpotCategory
    var rating: Int
    var comment: String
    var lat: Double?
    var lng: Double?
    @ServerTimestamp var createdAt: Date?
}
