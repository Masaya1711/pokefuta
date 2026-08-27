import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class AuthService: ObservableObject {
    @Published var currentUser: User?
    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
        }
    }

    deinit {
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
    }

    var isSignedIn: Bool { currentUser != nil }

    func signUp(email: String, password: String, displayName: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let profile = UserProfile(
            displayName: displayName,
            backgroundCheckInEnabled: false
        )
        try Firestore.firestore()
            .collection("users")
            .document(result.user.uid)
            .setData(from: profile)
    }

    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
}
