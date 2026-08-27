import Foundation
import FirebaseFirestore

@MainActor
final class CheckinHistoryService: ObservableObject {
    @Published var checkins: [Checkin] = []

    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()

    func startListening(userId: String) {
        listener = db.collection("checkins")
            .whereField("userId", isEqualTo: userId)
            .order(by: "checkedInAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                self?.checkins = snapshot?.documents.compactMap { try? $0.data(as: Checkin.self) } ?? []
            }
    }

    var checkedInManholeIds: Set<String> {
        Set(checkins.map { $0.manholeId })
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    deinit {
        listener?.remove()
    }
}
