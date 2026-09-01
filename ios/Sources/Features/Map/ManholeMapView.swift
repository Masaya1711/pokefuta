import SwiftUI
import MapKit

struct ManholeMapView: View {
    @EnvironmentObject private var manholeRepository: ManholeRepository
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var checkinHistoryService: CheckinHistoryService
    @EnvironmentObject private var photoHistoryService: PhotoHistoryService

    @State private var path = NavigationPath()
    @State private var previewManhole: Manhole?

    var body: some View {
        NavigationStack(path: $path) {
            ManholeMapRepresentable(
                manholes: manholeRepository.manholes,
                nearbyManholeId: locationManager.nearbyManholeId,
                checkedInManholeIds: checkinHistoryService.checkedInManholeIds,
                photoManholeIds: photoHistoryService.photoManholeIds,
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

/// 個別ピンは`Assets.xcassets/MapPin`(透明背景)、クラスタ(まとまり)は自前描画の丸バッジ画像を使う。
/// `clusteringIdentifier`を設定することでMapKit標準の自動クラスタリング(近接ピンをまとめて件数表示し、
/// 拡大すると自動的に分離する)を利用する。SwiftUI標準の`Map`にはクラスタリングAPIがないため、
/// `MKMapView`をUIViewRepresentableでラップしている。
private struct ManholeMapRepresentable: UIViewRepresentable {
    var manholes: [Manhole]
    var nearbyManholeId: String?
    var checkedInManholeIds: Set<String>
    var photoManholeIds: Set<String>
    var onSelectManhole: (Manhole) -> Void

    /// 現在地からチェックイン可能な圏内のピンに使う明るい水色。
    private static let nearbyPinColor = UIColor(red: 0.35, green: 0.84, blue: 1.0, alpha: 1.0)
    /// チェックインはしていないが写真だけ投稿済みのピンに使う明るい緑色。
    private static let photoOnlyPinColor = UIColor(red: 0.40, green: 0.90, blue: 0.50, alpha: 1.0)

    /// チェックイン済みは赤、現在地からチェックイン可能圏内は明るい水色、
    /// チェックインせず写真だけ投稿済みは明るい緑、それ以外は濃い青。
    func pinTint(for manholeId: String) -> UIColor {
        if checkedInManholeIds.contains(manholeId) { return .systemRed }
        if manholeId == nearbyManholeId { return Self.nearbyPinColor }
        if photoManholeIds.contains(manholeId) { return Self.photoOnlyPinColor }
        return .systemBlue
    }

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

        // 近接/チェックイン済みの色分けは、ピンを作り直さずに既存ビューの画像だけ更新する(頻繁に変わるため)。
        for annotation in mapView.annotations {
            guard let manholeAnnotation = annotation as? ManholeAnnotation,
                  let view = mapView.view(for: manholeAnnotation) else { continue }
            view.image = Self.pinImage(tint: pinTint(for: manholeAnnotation.manhole.id))
        }
    }

    /// 位置を示す個別ピン画像(`Assets.xcassets/MapPin`、透明背景)を指定の高さにリサイズして返す。
    private static let basePinImage: UIImage? = {
        guard let original = UIImage(named: "MapPin") else { return nil }
        let targetHeight: CGFloat = 32
        let scale = targetHeight / original.size.height
        let targetSize = CGSize(width: original.size.width * scale, height: targetHeight)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            original.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }()

    /// ピン画像を指定色で塗り替える。
    /// `withTintColor`はテンプレート画像でないと着色されないことがあるため、
    /// 画像を描画したうえで`.sourceIn`で塗りつぶし、不透明部分だけを確実に単色化する。
    fileprivate static func pinImage(tint: UIColor) -> UIImage? {
        guard let base = basePinImage else { return nil }
        let renderer = UIGraphicsImageRenderer(size: base.size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: base.size)
            base.draw(in: rect)
            context.cgContext.setBlendMode(.sourceIn)
            tint.setFill()
            context.cgContext.fill(rect)
        }
    }

    /// クラスタ(近接ピンのまとめ)バッジ画像。細い黒枠付きの円+件数。
    fileprivate static func clusterImage(count: Int) -> UIImage {
        let diameter: CGFloat = 32
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        return renderer.image { _ in
            let strokeWidth: CGFloat = 1.5
            let circleRect = CGRect(x: strokeWidth / 2, y: strokeWidth / 2, width: diameter - strokeWidth, height: diameter - strokeWidth)
            let path = UIBezierPath(ovalIn: circleRect)
            UIColor.systemBlue.setFill()
            path.fill()
            UIColor.black.setStroke()
            path.lineWidth = strokeWidth
            path.stroke()

            let text = "\(count)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 13),
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            text.draw(
                in: CGRect(
                    x: (diameter - textSize.width) / 2,
                    y: (diameter - textSize.height) / 2,
                    width: textSize.width,
                    height: textSize.height
                ),
                withAttributes: attributes
            )
        }
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
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKAnnotationView)
                    ?? MKAnnotationView(annotation: cluster, reuseIdentifier: identifier)
                view.annotation = cluster
                view.canShowCallout = false
                view.image = ManholeMapRepresentable.clusterImage(count: cluster.memberAnnotations.count)
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
            let image = ManholeMapRepresentable.pinImage(tint: parent.pinTint(for: manholeAnnotation.manhole.id))
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
