import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var manholeRepository: ManholeRepository
    @EnvironmentObject private var locationManager: LocationManager

    var body: some View {
        TabView {
            ManholeMapView()
                .tabItem { Label("マップ", systemImage: "map") }

            CollectionView()
                .tabItem { Label("コレクション", systemImage: "star.fill") }

            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .task {
            await manholeRepository.load()
        }
        .onAppear {
            locationManager.requestForegroundAuthorization()
            locationManager.startForegroundUpdates()
        }
        .onChange(of: manholeRepository.manholes) { manholes in
            locationManager.updateManholes(manholes)
        }
    }
}
