import Foundation
import CoreLocation
import FirebaseFirestore

@MainActor @Observable final class DeliveryTrackingService: NSObject, @preconcurrency CLLocationManagerDelegate {
    struct Lease { var sessionId: String; var sequence: Int; var lastPoint: CLLocation?; var lastSent = Date.distantPast; var lastAttempt = Date.distantPast }
    var activeIds: Set<String> = []
    var message: String?
    private var leases: [String: Lease] = [:]
    private let manager = CLLocationManager()
    private weak var store: AppStore?
    private var ownerId: String?
    private var uploading = false
    private var permission: CheckedContinuation<Void, Error>?
    override init() {
        super.init(); manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
    }
    func start(id: String, store: AppStore) async throws {
        guard !store.demo, store.isConfigured, let p = store.profile else { throw ParcelError.invalid("Демо не передаёт GPS. Для живой трансляции подключите Firebase.") }
        guard let d = store.orders.first(where: { $0.id == id && $0.driverId == p.id }), [.enRoute, .pickedUp].contains(d.status) else { throw ParcelError.forbidden }
        self.store = store
        if manager.authorizationStatus == .notDetermined {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                permission = continuation; manager.requestWhenInUseAuthorization()
            }
        }
        guard [.authorizedAlways, .authorizedWhenInUse].contains(manager.authorizationStatus) else { throw ParcelError.invalid("Разрешите геолокацию в настройках iPhone. Адреса можно выбирать вручную.") }
        guard let result = try await store.call("startTracking", data: ["id": id]) as? [String: Any], let sessionId = result["sessionId"] as? String else { throw ParcelError.invalid("Не удалось начать трансляцию.") }
        guard store.profile?.id == p.id, !store.demo,
              store.orders.contains(where: { $0.id == id && $0.driverId == p.id && [.enRoute, .pickedUp].contains($0.status) }) else { return }
        ownerId = p.id; leases[id] = Lease(sessionId: sessionId, sequence: result["sequence"] as? Int ?? 0)
        activeIds = Set(leases.keys); message = nil
        manager.allowsBackgroundLocationUpdates = true; manager.startUpdatingLocation()
    }
    func stop(id: String) async {
        leases[id] = nil; activeIds = Set(leases.keys)
        if leases.isEmpty { manager.stopUpdatingLocation(); manager.allowsBackgroundLocationUpdates = false; ownerId = nil }
        guard let store, !store.demo, store.isConfigured else { return }
        do { _ = try await store.call("stopTracking", data: ["id": id]) }
        catch { message = "Передача на iPhone остановлена. Сервер недоступен; последняя точка будет скрыта не позднее чем через 2 минуты." }
    }
    func stopAll() async {
        let ids = Array(leases.keys)
        manager.stopUpdatingLocation(); leases = [:]; activeIds = []; ownerId = nil
        for id in ids { await stop(id: id) }
    }
    func reconcile(orders: [Delivery], uid: String?) {
        for id in activeIds where uid != ownerId || !orders.contains(where: { $0.id == id && $0.driverId == uid && [.enRoute, .pickedUp].contains($0.status) }) {
            Task { await stop(id: id) }
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let allowed = [.authorizedAlways, .authorizedWhenInUse].contains(manager.authorizationStatus)
        if manager.authorizationStatus != .notDetermined, let continuation = permission {
            permission = nil
            if allowed { continuation.resume() }
            else { continuation.resume(throwing: ParcelError.invalid("Геолокация не разрешена.")) }
        }
        if !allowed && !activeIds.isEmpty { message = "Доступ к геолокации отозван."; Task { await stopAll() } }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let point = locations.last, point.horizontalAccuracy >= 0, point.horizontalAccuracy <= 1000, abs(point.timestamp.timeIntervalSinceNow) < 30, !uploading, !leases.isEmpty else { return }
        guard let store, !store.demo, store.profile?.id == ownerId else { manager.stopUpdatingLocation(); return }
        uploading = true
        Task {
            defer { uploading = false }
            for id in Array(leases.keys) {
                guard var lease = leases[id], Date().timeIntervalSince(lease.lastAttempt) >= 15 else { continue }
                let moved = lease.lastPoint.map { point.distance(from: $0) >= 50 } ?? true
                guard moved || Date().timeIntervalSince(lease.lastSent) >= 60 else { continue }
                lease.sequence += 1; lease.lastAttempt = Date(); leases[id] = lease
                do {
                    _ = try await store.call("updateTracking", data: ["id": id, "sessionId": lease.sessionId, "sequence": lease.sequence, "coordinate": GeoPoint(point.coordinate).payload, "accuracy": point.horizontalAccuracy, "capturedAt": point.timestamp.timeIntervalSince1970 * 1000])
                    guard leases[id]?.sessionId == lease.sessionId else { continue }
                    leases[id]?.lastPoint = point; leases[id]?.lastSent = Date()
                    message = manager.accuracyAuthorization == .reducedAccuracy ? "Передаётся приблизительная позиция." : nil
                } catch {
                    guard leases[id] != nil else { continue }
                    // Permission/precondition failures cannot be repaired by uploading more GPS.
                    let code = (error as NSError).code
                    if [7, 9, 16].contains(code) { await stop(id: id); message = "Трансляция завершена. При необходимости войдите снова и включите её." }
                    else { message = "Нет связи с сервером. Отправитель видит время последнего обновления." }
                }
            }
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        message = "Сейчас нет точной GPS-позиции. Последнее обновление помечено как устаревшее."
    }
}

struct LiveLocation: Decodable {
    var coordinate: GeoPoint
    var accuracy: Double
    var capturedAt: Date
    var receivedAt: Date
    var visibleUntil: Date
}
@MainActor @Observable final class TrackingObserver {
    var latest: LiveLocation?
    var message = "Перевозчик ещё не включил трансляцию."
    private var listener: ListenerRegistration?
    private var generation = UUID()
    func listen(id: String) {
        stop(); let ticket = generation
        listener = Firestore.firestore().collection("deliveries").document(id).collection("private").document("liveLocation").addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self, self.generation == ticket else { return }
                if error != nil { self.latest = nil; self.message = "Трансляция недоступна или завершена."; return }
                do { self.latest = snapshot?.exists == true ? try snapshot?.data(as: LiveLocation.self) : nil }
                catch { self.latest = nil; self.message = "Не удалось получить позицию." }
            }
        }
    }
    func stop() { generation = UUID(); listener?.remove(); listener = nil; latest = nil }
}
