import SwiftUI
import MapKit
import CoreLocation

extension GeoPoint {
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    init(_ coordinate: CLLocationCoordinate2D) { self.init(latitude: coordinate.latitude, longitude: coordinate.longitude) }
    var payload: [String: Any] { ["latitude": latitude, "longitude": longitude] }
}
extension SelectedPlace {
    var payload: [String: Any] { ["coordinate": coordinate.payload, "label": label] }
}

@MainActor @Observable final class RoutingService {
    var route: MKRoute?
    var calculating = false
    var message: String?
    private var generation = UUID()
    private var directions: MKDirections?
    private var cache: [String: (Date, MKRoute)] = [:]
    static func key(_ a: GeoPoint, _ b: GeoPoint, _ date: Date) -> String {
        "\(a.latitude)|\(a.longitude)|\(b.latitude)|\(b.longitude)|\(Int(date.timeIntervalSince1970 / 60))"
    }
    func reset() {
        generation = UUID(); directions?.cancel(); directions = nil
        route = nil; message = nil; calculating = false
    }
    func calculate(from: GeoPoint, to: GeoPoint, departure: Date) async {
        reset()
        let ticket = generation
        guard from.isValid, to.isValid, from.meters(to: to) >= 20 else {
            message = "Выберите две разные точки."; return
        }
        let key = Self.key(from, to, departure)
        if let cached = cache[key], Date().timeIntervalSince(cached.0) < 300 { route = cached.1; return }
        calculating = true
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to.coordinate))
        request.transportType = .automobile; request.departureDate = departure
        let pending = MKDirections(request: request); directions = pending
        defer { if ticket == generation { calculating = false; directions = nil } }
        do {
            let response = try await withTaskCancellationHandler {
                try await pending.calculate()
            } onCancel: { Task { @MainActor in pending.cancel() } }
            guard !Task.isCancelled, ticket == generation else { return }
            guard let value = response.routes.first else { throw ParcelError.invalid("Маршрут недоступен.") }
            route = value
            if cache.count >= 24 { cache.removeAll() }
            cache[key] = (Date(), value)
        } catch {
            guard !Task.isCancelled, ticket == generation else { return }
            message = "Автомобильный маршрут недоступен. Точки сохранены; попробуйте повторить расчёт позже."
        }
    }
}

@MainActor @Observable final class LocationSearchService: NSObject, MKLocalSearchCompleterDelegate {
    var results: [MKLocalSearchCompletion] = []
    var searching = false
    var message: String?
    private var completer: MKLocalSearchCompleter?
    private var search: MKLocalSearch?
    func update(_ query: String, region: MKCoordinateRegion) {
        completer?.cancel(); results = []; message = nil
        guard query.trimmingCharacters(in: .whitespaces).count >= 2 else { searching = false; return }
        let next = MKLocalSearchCompleter(); completer = next
        next.region = region; next.resultTypes = [.address, .pointOfInterest]; next.delegate = self
        searching = true; next.queryFragment = query
    }
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard self.completer === completer else { return }
        searching = false; results = Array(completer.results.prefix(8))
        if results.isEmpty { message = "Адрес не найден. Выберите точку на карте." }
    }
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        guard self.completer === completer else { return }
        searching = false; message = "Поиск недоступен. Можно выбрать точку на карте."
    }
    func resolve(_ result: MKLocalSearchCompletion) async throws -> SelectedPlace {
        search?.cancel()
        let pending = MKLocalSearch(request: .init(completion: result)); search = pending
        let response = try await pending.start()
        guard !Task.isCancelled, search === pending, let item = response.mapItems.first else { throw CancellationError() }
        return SelectedPlace(coordinate: GeoPoint(item.placemark.coordinate), label: [result.title, result.subtitle].filter { !$0.isEmpty }.joined(separator: ", "))
    }
    func cancel() { completer?.cancel(); completer = nil; search?.cancel(); search = nil; searching = false; results = [] }
}

@MainActor @Observable final class LocationService: NSObject, CLLocationManagerDelegate {
    var point: GeoPoint?
    var message: String?
    var requesting = false
    private let manager = CLLocationManager()
    override init() { super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyHundredMeters }
    func request() {
        requesting = true; message = nil
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        default: requesting = false; message = "Разрешите геолокацию в настройках iPhone или выберите точку вручную."
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { if requesting { request() } }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        requesting = false
        guard let location = locations.last, location.horizontalAccuracy >= 0, abs(location.timestamp.timeIntervalSinceNow) < 60 else { message = "Не удалось получить свежую позицию."; return }
        point = GeoPoint(location.coordinate)
        if manager.accuracyAuthorization == .reducedAccuracy { message = "Получена приблизительная позиция. Уточните точку на карте." }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { requesting = false; message = "Не удалось определить позицию. Выберите точку на карте." }
}

enum CityMap {
    static func region(_ city: String) -> MKCoordinateRegion {
        let points: [String: (Double, Double)] = ["Алматы": (43.2383,76.9455), "Астана": (51.1282,71.4304), "Шымкент": (42.3155,69.5869), "Караганда": (49.8064,73.0855), "Тараз": (42.9000,71.3667), "Талдыкорган": (45.0156,78.3739), "Актобе": (50.2839,57.1670), "Атырау": (47.0945,51.9238), "Актау": (43.6532,51.1975), "Павлодар": (52.2873,76.9674), "Семей": (50.4111,80.2275), "Өскемен": (49.9483,82.6275), "Костанай": (53.2144,63.6246), "Кызылорда": (44.8488,65.4823), "Петропавловск": (54.8753,69.1628), "Уральск": (51.2278,51.3865)]
        let value = points[city] ?? points["Алматы"]!
        return MKCoordinateRegion(center: .init(latitude: value.0, longitude: value.1), span: .init(latitudeDelta: 0.15, longitudeDelta: 0.15))
    }
}
