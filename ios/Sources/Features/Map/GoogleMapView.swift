import SwiftUI
import GoogleMaps

/// GoogleMapsのGMSMapViewをSwiftUIから使うためのラッパー。
struct GoogleMapView: UIViewRepresentable {
    let manholes: [Manhole]
    let nearbyManholeId: String?
    let onSelect: (Manhole) -> Void

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(withLatitude: 36.2048, longitude: 138.2529, zoom: 5)
        let options = GMSMapViewOptions()
        options.camera = camera
        let mapView = GMSMapView(options: options)
        mapView.isMyLocationEnabled = true
        mapView.settings.myLocationButton = true
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        mapView.clear()
        for manhole in manholes {
            guard let id = manhole.id else { continue }
            let marker = GMSMarker(position: CLLocationCoordinate2D(latitude: manhole.lat, longitude: manhole.lng))
            marker.title = manhole.displayTitle
            marker.icon = GMSMarker.markerImage(with: id == nearbyManholeId ? .systemGreen : .systemRed)
            marker.userData = manhole
            marker.map = mapView
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        private let onSelect: (Manhole) -> Void

        init(onSelect: @escaping (Manhole) -> Void) {
            self.onSelect = onSelect
        }

        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            if let manhole = marker.userData as? Manhole {
                onSelect(manhole)
            }
            return true
        }
    }
}
