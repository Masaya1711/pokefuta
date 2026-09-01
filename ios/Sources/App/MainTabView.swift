import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var manholeRepository: ManholeRepository
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var checkinHistoryService: CheckinHistoryService
    @EnvironmentObject private var photoHistoryService: PhotoHistoryService

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
            if let ownerRecordName = authService.userRecordName {
                await checkinHistoryService.refresh(ownerRecordName: ownerRecordName)
                await photoHistoryService.refresh(ownerRecordName: ownerRecordName)
            }
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
