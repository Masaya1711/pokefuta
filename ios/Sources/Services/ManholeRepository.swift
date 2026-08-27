import Foundation
import FirebaseFirestore

@MainActor
final class ManholeRepository: ObservableObject {
    @Published var manholes: [Manhole] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()

    func startListening() {
        guard listener == nil else { return }
        isLoading = true
        listener = db.collection("manholes").addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            self.isLoading = false
            if let error {
                self.errorMessage = error.localizedDescription
                return
            }
            self.manholes = snapshot?.documents.compactMap {
                try? $0.data(as: Manhole.self)
            } ?? []
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    deinit {
        listener?.remove()
    }
}
