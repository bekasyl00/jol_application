import XCTest
@testable import ParcelCore

final class GeographyTests: XCTestCase {
    func testOldDetailsDecodeWithoutCoordinates() throws {
        let json = #"{"addressFrom":"A","addressTo":"B","recipientName":"Test","recipientPhone":"+77011234567","comment":""}"#.data(using: .utf8)!
        let details = try JSONDecoder().decode(DeliveryDetails.self, from: json)
        XCTAssertNil(details.pickupPlace)
        XCTAssertNil(details.route)
    }
    func testIntermediateDeliveryAndReverseDirection() {
        let o = GeoPoint(latitude: 50, longitude: 70), t = GeoPoint(latitude: 52, longitude: 72)
        let p = GeoPoint(latitude: 50.5, longitude: 70.5), q = GeoPoint(latitude: 51.5, longitude: 71.5)
        XCTAssertTrue(RouteCompatibility.followsDirection(origin: o, destination: t, pickup: p, dropoff: q))
        XCTAssertFalse(RouteCompatibility.followsDirection(origin: o, destination: t, pickup: q, dropoff: p))
        XCTAssertFalse(RouteCompatibility.followsDirection(origin: o, destination: t, pickup: .init(latitude: 40, longitude: 60), dropoff: q))
        XCTAssertEqual(RouteCompatibility.detour(baseMeters: 100000, viaMeters: 112000), 12)
        XCTAssertNil(RouteCompatibility.detour(baseMeters: .nan, viaMeters: 112000))
        XCTAssertEqual(RouteCompatibility.detour(baseMeters: 100000, viaMeters: 99000), 0)
    }
    func testCoordinateValidationAndCoarseArea() throws {
        let exact = GeoPoint(latitude: 43.2383, longitude: 76.9455)
        XCTAssertEqual(exact.area, GeoPoint(latitude: 43.2, longitude: 76.9))
        XCTAssertFalse(GeoPoint(latitude: .nan, longitude: 0).isValid)
        XCTAssertFalse(GeoPoint(latitude: 91, longitude: 0).isValid)
        let place = SelectedPlace(coordinate: exact, label: "Точка на карте")
        XCTAssertEqual(try JSONDecoder().decode(SelectedPlace.self, from: JSONEncoder().encode(place)), place)
    }
}
