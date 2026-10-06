import Foundation
@main struct CoreSmoke {
    static func main() async throws {
        func check(_ condition: Bool, _ label: String) throws {
            guard condition else { throw ParcelError.invalid("FAIL: \(label)") }
            print("PASS: \(label)")
        }
        try check(try Pricing.quote(distanceKm: 100, volume: 0.06) == 2100, "tariff")
        do { _ = try Pricing.quote(distanceKm: .nan, volume: 1); throw ParcelError.invalid("NaN accepted") } catch ParcelError.invalid(let reason) { try check(reason != "NaN accepted", "invalid input") }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let repo = try LocalRepository(directory: dir)
        let sender = Profile(id: "s", name: "Алия", phone: "+77011234567", role: .sender)
        let a = Profile(id: "a", name: "Арман", phone: "+77011234568", role: .courier, vehicle: "Kia", capacityKg: 20)
        let b = Profile(id: "b", name: "Бекзат", phone: "+77011234569", role: .courier, vehicle: "Toyota", capacityKg: 20)
        try await repo.saveProfile(sender); try await repo.saveProfile(a); try await repo.saveProfile(b)
        let d = Delivery(senderId: sender.id, fromCity: "Алматы", toCity: "Астана", itemDescription: "Книги", size: .box, weight: 10, volume: 0.06, distanceKm: 100, price: 2100, pickupAt: Date().addingTimeInterval(3600))
        let details = DeliveryDetails(addressFrom: "Адрес 1", addressTo: "Адрес 2", recipientName: "Алия", recipientPhone: "+77011234567", comment: "")
        try await repo.create(d, details: details, user: sender)
        let winners = await withTaskGroup(of: Bool.self) { group in
            for p in [a, b] { group.addTask { do { try await repo.accept(d.id, user: p); return true } catch { return false } } }
            var n = 0; for await result in group { if result { n += 1 } }; return n
        }
        try check(winners == 1, "concurrent acceptance: exactly one winner")
        let reopened = try LocalRepository(directory: dir)
        let loaded = await reopened.orders(for: sender)
        try check(loaded.first?.status == .accepted, "persistence after reopen")
        let winner = loaded[0].driverId == a.id ? a : b
        let outsider = winner.id == a.id ? b : a
        do { _ = try await reopened.details(d.id, user: outsider); throw ParcelError.invalid("Contact leaked") } catch ParcelError.forbidden { print("PASS: private addresses denied to outsider") }
        do { try await reopened.transition(d.id, to: .delivered, user: winner); throw ParcelError.invalid("Skipped status") } catch ParcelError.invalidTransition { print("PASS: status cannot skip stages") }
        var deletionBlocked = false
        do { try await reopened.deleteAccount(sender) } catch ParcelError.invalid { deletionBlocked = true }
        try check(deletionBlocked, "active order blocks deletion")
        try await reopened.send(d.id, text: "Здравствуйте", user: sender)
        let messages = try await reopened.messages(d.id, user: winner)
        try check(messages.count == 1, "order chat persisted")
        for status in [DeliveryStatus.enRoute, .pickedUp, .delivered] { try await reopened.transition(d.id, to: status, user: winner) }
        try await reopened.review(d.id, text: "Спасибо!", user: sender)
        let final = await reopened.orders(for: sender)
        try check(final[0].review == "Спасибо!", "delivery and review")
        try await reopened.deleteAccount(sender)
        let empty = await reopened.orders(for: sender)
        try check(empty.isEmpty, "account data deletion")
    }
}
