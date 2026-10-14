import Foundation

public struct GeoPoint: Codable, Sendable, Equatable, Hashable {
    public var latitude: Double
    public var longitude: Double
    public init(latitude: Double, longitude: Double) { self.latitude = latitude; self.longitude = longitude }
    public var isValid: Bool { latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude) }
    /// Only this ~11 km cell centre may appear in a marketplace document.
    public var area: GeoPoint { .init(latitude: (latitude * 10).rounded() / 10, longitude: (longitude * 10).rounded() / 10) }
    public func meters(to other: GeoPoint) -> Double {
        let lat1 = latitude * .pi / 180, lat2 = other.latitude * .pi / 180
        let a = pow(sin((lat2 - lat1) / 2), 2) + cos(lat1) * cos(lat2) * pow(sin((other.longitude - longitude) * .pi / 360), 2)
        return 6_371_000 * 2 * atan2(sqrt(min(1, a)), sqrt(max(0, 1 - a)))
    }
}

public struct SelectedPlace: Codable, Sendable, Equatable, Hashable {
    public var coordinate: GeoPoint
    public var label: String
    public init(coordinate: GeoPoint, label: String) { self.coordinate = coordinate; self.label = label }
    public var isValid: Bool { coordinate.isValid && !label.isEmpty && label.count <= 500 }
}

public struct RouteSummary: Codable, Sendable, Equatable {
    public var distanceMeters: Double
    public var durationSeconds: Double
    public var calculatedAt: Date
    public init(distanceMeters: Double, durationSeconds: Double, calculatedAt: Date = Date()) {
        self.distanceMeters = distanceMeters; self.durationSeconds = durationSeconds; self.calculatedAt = calculatedAt
    }
    public var isValid: Bool { distanceMeters.isFinite && durationSeconds.isFinite && distanceMeters > 0 && distanceMeters <= 5_000_000 && durationSeconds > 0 && durationSeconds <= 604800 }
}

public enum RouteCompatibility {
    /// Geometric prefilter only. Never use these values as road distance or ETA.
    public static func followsDirection(origin: GeoPoint, destination: GeoPoint, pickup: GeoPoint, dropoff: GeoPoint, corridorMeters: Double = 100_000) -> Bool {
        let scale = cos((origin.latitude + destination.latitude) * .pi / 360)
        let dx = (destination.longitude - origin.longitude) * scale, dy = destination.latitude - origin.latitude
        let length = dx * dx + dy * dy
        guard length > 0 else { return false }
        func project(_ p: GeoPoint) -> (Double, Double) {
            let x = (p.longitude - origin.longitude) * scale, y = p.latitude - origin.latitude
            let t = (x * dx + y * dy) / length
            let nearest = max(0, min(1, t))
            return (t, hypot(x - nearest * dx, y - nearest * dy) * 111_320)
        }
        let a = project(pickup), b = project(dropoff)
        return a.0 <= b.0 && a.0 >= -0.1 && b.0 <= 1.1 && a.1 <= corridorMeters && b.1 <= corridorMeters
    }
    public static func detour(baseMeters: Double, viaMeters: Double) -> Double? {
        guard baseMeters.isFinite, viaMeters.isFinite, baseMeters > 0, viaMeters > 0 else { return nil }
        // Different alternatives/time estimates can produce a small negative delta.
        return max(0, viaMeters - baseMeters) / 1000
    }
}
