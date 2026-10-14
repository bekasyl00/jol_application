// Run on macOS: swiftc -parse-as-library scripts/probe-mapkit.swift -o /tmp/jol-mapkit && /tmp/jol-mapkit
// Public city landmarks only. A desktop probe does not replace the iPhone coverage test.
import Foundation
import MapKit

@main struct CoverageProbe {
    @MainActor static func main() async {
        let places: [(String, Double, Double)] = [
            ("Алматы", 43.2383, 76.9455), ("Астана", 51.1282, 71.4304),
            ("Талдыкорган", 45.0156, 78.3739), ("Караганда", 49.8064, 73.0855),
            ("Шымкент", 42.3155, 69.5869), ("Тараз", 42.9000, 71.3667)
        ]
        print("MapKit automobile probe \(Date().ISO8601Format()) / \(ProcessInfo.processInfo.operatingSystemVersionString)")
        for (start, end) in [(0, 1), (0, 2), (1, 3), (4, 5)] {
            let a = places[start], b = places[end]
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: .init(latitude: a.1, longitude: a.2)))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: .init(latitude: b.1, longitude: b.2)))
            request.transportType = .automobile
            let directions = MKDirections(request: request)
            let timeout = Task { try await Task.sleep(for: .seconds(25)); directions.cancel() }
            defer { timeout.cancel() }
            do {
                let result = try await directions.calculate()
                if let route = result.routes.first {
                    print("\(a.0) -> \(b.0): \(Int(route.distance)) m / \(Int(route.expectedTravelTime)) s")
                } else { print("\(a.0) -> \(b.0): no routes") }
            } catch {
                let e = error as NSError
                print("\(a.0) -> \(b.0): unavailable \(e.domain) \(e.code)")
            }
        }
    }
}
