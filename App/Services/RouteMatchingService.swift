import Foundation
import MapKit
import Observation

@MainActor @Observable final class RouteMatchingService {
    var extraKm: Double?
    var extraMinutes: Int?
    var message: String?
    var calculating = false
    var polylines: [MKPolyline] = []
    private var ticket = UUID()
    private let routing = RoutingService()
    func reset() { ticket = UUID(); routing.reset(); calculating = false; extraKm = nil; extraMinutes = nil; polylines = []; message = nil }
    // Retain accepted pickup/drop-off order. No custom road graph or optimization engine.
    func evaluate(origin: GeoPoint, destination: GeoPoint, stops: [GeoPoint], pickup: GeoPoint, dropoff: GeoPoint, departure: Date) async {
        reset(); let request = ticket; calculating = true
        defer { if ticket == request { calculating = false } }
        if !RouteCompatibility.followsDirection(origin: origin, destination: destination, pickup: pickup, dropoff: dropoff) {
            message = "Точки не лежат по направлению поездки. Предложение можно обсудить отдельно."; return
        }
        do {
            let base = try await route([origin] + stops + [destination], at: departure, request: request)
            let via = try await route([origin] + stops + [pickup, dropoff, destination], at: departure, request: request)
            guard request == ticket, !Task.isCancelled else { return }
            extraKm = RouteCompatibility.detour(baseMeters: base.0, viaMeters: via.0)
            extraMinutes = Int(max(0, via.1 - base.1) / 60)
            polylines = via.2
        } catch {
            guard request == ticket, !Task.isCancelled else { return }
            message = "Apple не вернула автомобильный путь. Совместимость по объезду пока неизвестна."
        }
    }
    private func route(_ points: [GeoPoint], at date: Date, request: UUID) async throws -> (Double, Double, [MKPolyline]) {
        var distance = 0.0, duration = 0.0; var lines: [MKPolyline] = []
        for index in 0..<(points.count - 1) {
            try Task.checkCancellation(); guard request == ticket else { throw CancellationError() }
            if points[index].meters(to: points[index + 1]) < 20 { continue }
            await routing.calculate(from: points[index], to: points[index + 1], departure: date.addingTimeInterval(duration))
            guard let value = routing.route else { throw ParcelError.invalid("Маршрут недоступен.") }
            distance += value.distance; duration += value.expectedTravelTime; lines.append(value.polyline)
        }
        return (distance, duration, lines)
    }
}
