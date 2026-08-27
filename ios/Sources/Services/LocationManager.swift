import Foundation
import CoreLocation
import UserNotifications

/// GPSチェックイン判定を担当する。
/// フォアグラウンドでは現在地との距離を常時計算し、しきい値内でチェックインボタンを活性化する。
/// バックグラウンドは`CLLocationManager`の同時監視リージョン数が20件に制限されているため、
/// 有意な位置変化(SignificantLocationChange)のたびに現在地から近い上位20件だけを
/// ジオフェンスとして再登録し直す方式で全国規模のポケふたに対応する。
@MainActor
final class LocationManager: NSObject, ObservableObject {
    static let checkInThresholdMeters: CLLocationDistance = 100
    private static let maxMonitoredRegions = 20

    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    /// フォアグラウンドでチェックイン可能な距離内にいるポケふたのID
    @Published var nearbyManholeId: String?
    /// バックグラウンドジオフェンスで検知されたポケふたのID(アプリ側でチェックイン確認UIを出すために消費する)
    @Published var regionEnteredManholeId: String?

    private let manager = CLLocationManager()
    private var manholes: [Manhole] = []
    private var backgroundEnabled = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func updateManholes(_ manholes: [Manhole]) {
        self.manholes = manholes
        evaluateForegroundProximity()
        refreshMonitoredRegionsIfNeeded()
    }

    func requestForegroundAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func setBackgroundCheckInEnabled(_ enabled: Bool) {
        backgroundEnabled = enabled
        if enabled {
            manager.requestAlwaysAuthorization()
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
            manager.startMonitoringSignificantLocationChanges()
            refreshMonitoredRegionsIfNeeded()
        } else {
            manager.stopMonitoringSignificantLocationChanges()
            manager.monitoredRegions.forEach { manager.stopMonitoring(for: $0) }
        }
    }

    func startForegroundUpdates() {
        manager.startUpdatingLocation()
    }

    func stopForegroundUpdates() {
        manager.stopUpdatingLocation()
    }

    /// バックグラウンドジオフェンス通知を確認済みにする(重複してチェックイン確認UIを出さないため)
    func consumeRegionEnteredEvent() {
        regionEnteredManholeId = nil
    }

    private func refreshMonitoredRegionsIfNeeded() {
        guard backgroundEnabled, let current = currentLocation, !manholes.isEmpty else { return }

        let nearest = manholes
            .compactMap { manhole -> (id: String, coordinate: CLLocationCoordinate2D, distance: CLLocationDistance)? in
                guard let id = manhole.id else { return nil }
                let coordinate = CLLocationCoordinate2D(latitude: manhole.lat, longitude: manhole.lng)
                let distance = current.distance(from: CLLocation(latitude: manhole.lat, longitude: manhole.lng))
                return (id, coordinate, distance)
            }
            .sorted { $0.distance < $1.distance }
            .prefix(Self.maxMonitoredRegions)

        manager.monitoredRegions.forEach { manager.stopMonitoring(for: $0) }

        for entry in nearest {
            let region = CLCircularRegion(
                center: entry.coordinate,
                radius: Self.checkInThresholdMeters,
                identifier: entry.id
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false
            manager.startMonitoring(for: region)
        }
    }

    private func evaluateForegroundProximity() {
        guard let current = currentLocation else {
            nearbyManholeId = nil
            return
        }

        let nearest = manholes
            .compactMap { manhole -> (id: String, distance: CLLocationDistance)? in
                guard let id = manhole.id else { return nil }
                let distance = current.distance(from: CLLocation(latitude: manhole.lat, longitude: manhole.lng))
                return (id, distance)
            }
            .min { $0.distance < $1.distance }

        nearbyManholeId = (nearest?.distance ?? .greatestFiniteMagnitude) <= Self.checkInThresholdMeters
            ? nearest?.id
            : nil
    }

    func distance(to manhole: Manhole) -> CLLocationDistance? {
        guard let current = currentLocation else { return nil }
        return current.distance(from: CLLocation(latitude: manhole.lat, longitude: manhole.lng))
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location
            self.evaluateForegroundProximity()
            self.refreshMonitoredRegionsIfNeeded()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        let identifier = region.identifier
        Task { @MainActor in
            self.regionEnteredManholeId = identifier
            self.notifyRegionEntered(manholeId: identifier)
        }
    }
}

private extension LocationManager {
    /// アプリがバックグラウンド/未起動でもユーザーに気付いてもらうためローカル通知を送る。
    func notifyRegionEntered(manholeId: String) {
        let title = manholes.first(where: { $0.id == manholeId })?.displayTitle ?? "ポケふた"
        let content = UNMutableNotificationContent()
        content.title = "ポケふたが近くにあります"
        content.body = "\(title) の近くにいます。アプリを開いてチェックインしましょう。"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "checkin-\(manholeId)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
