import SwiftUI
import MapKit

struct ManholeMapView: View {
    @EnvironmentObject private var manholeRepository: ManholeRepository
    @EnvironmentObject private var locationManager: LocationManager

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
        span: MKCoordinateSpan(latitudeDelta: 12, longitudeDelta: 12)
    )
    @State private var selectedManhole: Manhole?

    var body: some View {
        NavigationStack {
            Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: manholeRepository.manholes) { manhole in
                MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: manhole.lat, longitude: manhole.lng)) {
                    Button {
                        selectedManhole = manhole
                    } label: {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title2)
                            .foregroundStyle(manhole.id == locationManager.nearbyManholeId ? .green : .red)
                    }
                }
            }
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
