import SwiftUI
import MapKit

struct ManholeMapView: View {
    @EnvironmentObject private var manholeRepository: ManholeRepository
    @EnvironmentObject private var locationManager: LocationManager

    @State private var path = NavigationPath()
    @State private var previewManhole: Manhole?

    var body: some View {
        NavigationStack(path: $path) {
            ManholeMapRepresentable(
                manholes: manholeRepository.manholes,
                nearbyManholeId: locationManager.nearbyManholeId,
                onSelectManhole: { previewManhole = $0 }
            )
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("ポケふたマップ")
            .navigationDestination(for: Manhole.self) { manhole in
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
            .overlay(alignment: .bottom) {
                if let previewManhole {
                    ManholePreviewCard(
                        manhole: previewManhole,
                        onOpenDetail: {
                            path.append(previewManhole)
                            self.previewManhole = nil
                        },
                        onClose: { self.previewManhole = nil }
                    )
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.25), value: previewManhole?.id)
        }
    }
}

/// 個別ピンは透明背景のSF Symbol画像(`pinImage`)、クラスタ(まとまり)は`MKMarkerAnnotationView`の
/// 件数バッジ表示を使う。`clusteringIdentifier`を設定することでMapKit標準の自動クラスタリング
/// (近接ピンをまとめて件数表示し、拡大すると自動的に分離する)を利用する。SwiftUI標準の`Map`には
/// クラスタリングAPIがないため、`MKMapView`をUIViewRepresentableでラップしている。
private struct ManholeMapRepresentable: UIViewRepresentable {
    var manholes: [Manhole]
    var nearbyManholeId: String?
    var onSelectManhole: (Manhole) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.setRegion(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
                span: MKCoordinateSpan(latitudeDelta: 12, longitudeDelta: 12)
            ),
            animated: false
        )
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self

        let currentIds = Set(mapView.annotations.compactMap { ($0 as? ManholeAnnotation)?.manhole.id })
        let newIds = Set(manholes.map(\.id))

        if currentIds != newIds {
            let toRemove = mapView.annotations.filter {
                guard let annotation = $0 as? ManholeAnnotation else { return false }
                return !newIds.contains(annotation.manhole.id)
            }
            mapView.removeAnnotations(toRemove)

            let existingIds = Set(mapView.annotations.compactMap { ($0 as? ManholeAnnotation)?.manhole.id })
            let toAdd = manholes
                .filter { !existingIds.contains($0.id) }
                .map { ManholeAnnotation(manhole: $0) }
            mapView.addAnnotations(toAdd)
        }

        // チェックイン圏内(近接)の色分けは、ピンを作り直さずに既存ビューの画像だけ更新する(頻繁に変わるため)。
        for annotation in mapView.annotations {
            guard let manholeAnnotation = annotation as? ManholeAnnotation,
                  let view = mapView.view(for: manholeAnnotation) else { continue }
            view.image = Self.pinImage(isNearby: manholeAnnotation.manhole.id == nearbyManholeId)
        }
    }

    /// 位置を示す個別ピン。`MKMarkerAnnotationView`の吹き出し(不透明背景+白抜きグリフ)は使わず、
    /// 透明背景のSF Symbol画像をそのままピンとして使う。
    fileprivate static func pinImage(isNearby: Bool) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold)
        let tint: UIColor = isNearby ? .systemGreen : .systemBlue
        return UIImage(systemName: "mappin", withConfiguration: configuration)?
            .withTintColor(tint, renderingMode: .alwaysOriginal)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: ManholeMapRepresentable

        init(parent: ManholeMapRepresentable) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            if let cluster = annotation as? MKClusterAnnotation {
                let identifier = "manholeCluster"
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                    ?? MKMarkerAnnotationView(annotation: cluster, reuseIdentifier: identifier)
                view.annotation = cluster
                view.markerTintColor = .systemBlue
                view.canShowCallout = false
                return view
            }

            guard let manholeAnnotation = annotation as? ManholeAnnotation else { return nil }
            let identifier = "manhole"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKAnnotationView)
                ?? MKAnnotationView(annotation: manholeAnnotation, reuseIdentifier: identifier)
            view.annotation = manholeAnnotation
            view.clusteringIdentifier = "manhole"
            view.displayPriority = .defaultLow
            view.canShowCallout = false
            let image = ManholeMapRepresentable.pinImage(isNearby: manholeAnnotation.manhole.id == parent.nearbyManholeId)
            view.image = image
            view.centerOffset = CGPoint(x: 0, y: -(image?.size.height ?? 0) / 2)
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            mapView.deselectAnnotation(annotation, animated: false)

            if let cluster = annotation as? MKClusterAnnotation {
                if let region = Self.regionThatFits(coordinates: cluster.memberAnnotations.map(\.coordinate)) {
                    mapView.setRegion(region, animated: true)
                }
                return
            }

            guard let manholeAnnotation = annotation as? ManholeAnnotation else { return }
            parent.onSelectManhole(manholeAnnotation.manhole)
        }

        /// クラスタタップ時、内包する全ピンがバラけて見える範囲まで一気にズームする。
        private static func regionThatFits(coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
            guard !coordinates.isEmpty else { return nil }

            var rect = MKMapRect.null
            for coordinate in coordinates {
                let point = MKMapPoint(coordinate)
                rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 0, height: 0))
            }

            let paddedWidth = max(rect.width * 1.6, 800)
            let paddedHeight = max(rect.height * 1.6, 800)
            let padded = rect.insetBy(dx: (rect.width - paddedWidth) / 2, dy: (rect.height - paddedHeight) / 2)
            return MKCoordinateRegion(padded)
        }
    }
}

private final class ManholeAnnotation: NSObject, MKAnnotation {
    let manhole: Manhole

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: manhole.lat, longitude: manhole.lng)
    }
    var title: String? { manhole.displayTitle }

    init(manhole: Manhole) {
        self.manhole = manhole
    }
}
