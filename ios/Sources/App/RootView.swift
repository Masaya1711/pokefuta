import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        Group {
            if authService.isSignedIn {
                MainTabView()
            } else {
                AuthView()
            }
        }
    }
}
