import XCTest
@testable import ParcelCore

final class TripTests: XCTestCase {
    func testMultipleParcelsReserveCapacityAndMigrateOldSnapshot() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(#"{"deliveries":[],"details":{},"messages":{},"profiles":{}}"#.utf8).write(to: dir.appendingPathComponent("parcel-demo.json"))
        let repo = try LocalRepository(directory: dir)
        let sender = Profile(id: "s", name: "Алия", phone: "+77011234567", role: .sender)
        let driver = Profile(id: "d", name: "Арман", phone: "+77011234568", role: .courier, vehicle: "Kia", capacityKg: 25)
        let a = SelectedPlace(coordinate: .init(latitude: 43.23, longitude: 76.94), label: "А")
        let b = SelectedPlace(coordinate: .init(latitude: 51.12, longitude: 71.43), label: "Б")
        let date = Date().addingTimeInterval(7200)
        let trip = CarrierTrip(driver: driver, fromCity: "Алматы", toCity: "Астана", origin: a.coordinate, destination: b.coordinate, departureAt: date, capacityKg: 25)
        try await repo.publishTrip(trip, details: TripDetails(origin: a, destination: b), user: driver)
        var deliveries: [Delivery] = []
        for _ in 0..<3 {
            let d = Delivery(senderId: sender.id, fromCity: "Алматы", toCity: "Астана", itemDescription: "Книги", size: .box, weight: 10, volume: 0.06, distanceKm: 1200, price: 9000, pickupAt: date)
            try await repo.create(d, details: DeliveryDetails(addressFrom: "A", addressTo: "B", recipientName: "Иван", recipientPhone: "+77011234567", comment: "", pickupPlace: a, dropoffPlace: b), user: sender)
            try await repo.propose(deliveryId: d.id, tripId: trip.id, user: sender)
            deliveries.append(d)
        }
        for d in deliveries.prefix(2) {
            let current = await repo.trips(for: driver)[0]
            try await repo.respondProposal(d.id + "_" + trip.id, action: .accepted, expectedVersion: current.version, user: driver)
        }
        let current = await repo.trips(for: driver)[0]
        XCTAssertEqual(current.acceptedCount, 2); XCTAssertEqual(current.availableKg, 5)
        do { try await repo.respondProposal(deliveries[2].id + "_" + trip.id, action: .accepted, expectedVersion: current.version, user: driver); XCTFail("Overbooked") } catch {}
        do { _ = try await repo.tripDetails(trip.id, user: sender); XCTFail("Private itinerary leaked") } catch {}
        try await repo.transition(deliveries[0].id, to: .cancelled, reason: "Планы изменились", user: sender)
        let afterCancel = await repo.trips(for: driver)[0]
        XCTAssertEqual(afterCancel.availableKg, 15)
        do { try await repo.respondProposal(deliveries[2].id + "_" + trip.id, action: .accepted, expectedVersion: current.version, user: driver); XCTFail("Stale trip accepted") } catch {}
        try await repo.respondProposal(deliveries[2].id + "_" + trip.id, action: .accepted, expectedVersion: afterCancel.version, user: driver)
        let reopened = try LocalRepository(directory: dir)
        let route = try await reopened.tripDetails(trip.id, user: driver)
        XCTAssertEqual(route?.deliveryIds, [deliveries[1].id, deliveries[2].id])
    }
}
