import SwiftUI
import CoreLocation

struct ManholeMapView: View {
    @EnvironmentObject private var manholeRepository: ManholeRepository
    @EnvironmentObject private var locationManager: LocationManager

    @State private var selectedManhole: Manhole?

    var body: some View {
        NavigationStack {
            GoogleMapView(
                manholes: manholeRepository.manholes,
                nearbyManholeId: locationManager.nearbyManholeId,
                onSelect: { manhole in selectedManhole = manhole }
            )
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("ポケふたマップ")
            .navigationDestination(item: $selectedManhole) { manhole in
                ManholeDetailView(manhole: manhole)
            }
            .overlay(alignment: .top) {
                if manholeRepository.isLoading {
                    ProgressView()
                        .padding(8)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.top, 8)
                }
            }
        }
    }
}
