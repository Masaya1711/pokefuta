import SwiftUI

@main
struct PokeHutaApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var manholeRepository = ManholeRepository()
    @StateObject private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .environmentObject(manholeRepository)
                .environmentObject(locationManager)
        }
    }
}
