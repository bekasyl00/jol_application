import XCTest
@testable import ParcelCore

final class ParcelCoreTests: XCTestCase {
    func testPricingAndInvalidInput() throws {
        XCTAssertEqual(try Pricing.quote(distanceKm: 100, volume: 0.06), 2100)
        XCTAssertThrowsError(try Pricing.quote(distanceKm: .nan, volume: 0.1))
        XCTAssertThrowsError(try Pricing.quote(distanceKm: 100, volume: -.infinity))
        XCTAssertTrue(Validation.validPhone("+77011234567"))
        XCTAssertFalse(Validation.validPhone("77011234567"))
    }
    func testAtomicAcceptanceAndPersistence() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repo = try LocalRepository(directory: directory)
        let sender = Profile(id: "sender", name: "Алия", phone: "+77011234567", role: .sender)
        let a = Profile(id: "a", name: "Арман", phone: "+77011234568", role: .courier, vehicle: "Toyota", capacityKg: 50)
        let b = Profile(id: "b", name: "Бекзат", phone: "+77011234569", role: .courier, vehicle: "Kia", capacityKg: 50)
        let order = Delivery(senderId: sender.id, fromCity: "Алматы", toCity: "Астана", itemDescription: "Книги", size: .box, weight: 10, volume: 0.06, distanceKm: 1200, price: 10900, pickupAt: Date().addingTimeInterval(3600))
        let details = DeliveryDetails(addressFrom: "Адрес 1", addressTo: "Адрес 2", recipientName: "Иван", recipientPhone: "+77011234567", comment: "")
        try await repo.create(order, details: details, user: sender)
        let successes = await withTaskGroup(of: Bool.self) { group in
            for driver in [a, b] { group.addTask { do { try await repo.accept(order.id, user: driver); return true } catch { return false } } }
            var count = 0; for await success in group { if success { count += 1 } }; return count
        }
        XCTAssertEqual(successes, 1)
        let reopened = try LocalRepository(directory: directory)
        let orders = await reopened.orders(for: sender)
        XCTAssertEqual(orders.first?.status, .accepted)
        let winner = orders[0].driverId == a.id ? a : b
        do { try await reopened.transition(order.id, to: .delivered, user: winner); XCTFail("Skipped status") } catch {}
        for status in [DeliveryStatus.enRoute, .pickedUp, .delivered] { try await reopened.transition(order.id, to: status, user: winner) }
        try await reopened.review(order.id, text: "Спасибо!", user: sender)
        let completed = await reopened.orders(for: sender)
        XCTAssertEqual(completed.first?.review, "Спасибо!")
        do { _ = try await reopened.details(order.id, user: winner.id == a.id ? b : a); XCTFail("Contact leak") } catch {}
        try await reopened.deleteAccount(sender)
        let empty = await reopened.orders(for: sender)
        XCTAssertTrue(empty.isEmpty)
    }
}
