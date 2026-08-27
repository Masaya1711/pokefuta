import Foundation
import FirebaseFirestore

@MainActor
final class ManholeDetailService: ObservableObject {
    @Published var photos: [ManholePhoto] = []
    @Published var spots: [Spot] = []

    private var photosListener: ListenerRegistration?
    private var spotsListener: ListenerRegistration?
    private let db = Firestore.firestore()
    let manholeId: String

    init(manholeId: String) {
        self.manholeId = manholeId
    }

    func startListening() {
        let base = db.collection("manholes").document(manholeId)

        photosListener = base.collection("photos")
            .whereField("moderationStatus", isEqualTo: ModerationStatus.approved.rawValue)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                self?.photos = snapshot?.documents.compactMap { try? $0.data(as: ManholePhoto.self) } ?? []
            }

        spotsListener = base.collection("spots")
            .order(by: "rating", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                self?.spots = snapshot?.documents.compactMap { try? $0.data(as: Spot.self) } ?? []
            }
    }

    func stopListening() {
        photosListener?.remove()
        spotsListener?.remove()
    }

    func addSpot(userId: String, name: String, category: SpotCategory, rating: Int, comment: String, lat: Double?, lng: Double?) throws {
        let spot = Spot(
            userId: userId,
            name: name,
            category: category,
            rating: rating,
            comment: comment,
            lat: lat,
            lng: lng
        )
        try db
            .collection("manholes")
            .document(manholeId)
            .collection("spots")
            .addDocument(from: spot)
    }

    func addCheckin(userId: String, method: CheckinMethod, distanceMeters: Double, photoId: String?) throws {
        let checkin = Checkin(
            userId: userId,
            manholeId: manholeId,
            method: method,
            distanceMeters: distanceMeters,
            photoId: photoId
        )
        try db.collection("checkins").addDocument(from: checkin)
    }

    deinit {
        photosListener?.remove()
        spotsListener?.remove()
    }
}
