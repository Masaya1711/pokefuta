import SwiftUI
import FirebaseCore

@main
struct PokeHutaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}
