import Foundation

public enum TripStatus: String, Codable, Sendable { case published, closed, cancelled }
public struct CarrierTrip: Codable, Sendable, Identifiable {
    public var id: String
    public var driverId: String
    public var driverName: String
    public var vehicle: String
    public var fromCity: String
    public var toCity: String
    public var originArea: GeoPoint
    public var destinationArea: GeoPoint
    public var departureAt: Date
    public var pickupWindowMinutes: Int
    public var capacityKg: Double
    public var reservedKg: Double = 0
    public var acceptedCount: Int = 0
    public var maxParcels: Int
    public var maxDetourKm: Double
    public var maxDetourMinutes: Int
    public var status: TripStatus = .published
    public var version: Int = 1
    public var createdAt: Date = Date()
    public var availableKg: Double { max(0, capacityKg - reservedKg) }
    public init(id: String = UUID().uuidString, driver: Profile, fromCity: String, toCity: String, origin: GeoPoint, destination: GeoPoint, departureAt: Date, capacityKg: Double, maxParcels: Int = 10, maxDetourKm: Double = 20, maxDetourMinutes: Int = 30, pickupWindowMinutes: Int = 120) {
        self.id = id; self.driverId = driver.id; self.driverName = driver.name; self.vehicle = driver.vehicle
        self.fromCity = fromCity; self.toCity = toCity; originArea = origin.area; destinationArea = destination.area
        self.departureAt = departureAt; self.capacityKg = capacityKg; self.maxParcels = maxParcels
        self.maxDetourKm = maxDetourKm; self.maxDetourMinutes = maxDetourMinutes; self.pickupWindowMinutes = pickupWindowMinutes
    }
    public func validate(now: Date = Date()) throws {
        guard kazakhstanCities.contains(fromCity), kazakhstanCities.contains(toCity), fromCity != toCity,
              originArea.isValid, destinationArea.isValid, capacityKg.isFinite, (0.1...5000).contains(capacityKg),
              (1...10).contains(maxParcels), maxDetourKm.isFinite, (0...300).contains(maxDetourKm),
              (0...240).contains(maxDetourMinutes), (15...1440).contains(pickupWindowMinutes),
              departureAt >= now.addingTimeInterval(-300), departureAt <= now.addingTimeInterval(366 * 86400) else {
            throw ParcelError.invalid("Проверьте города, дату, вместимость и допустимый объезд.")
        }
    }
    public func canPropose(_ delivery: Delivery, now: Date = Date()) -> Bool {
        status == .published && departureAt > now && delivery.status == .waiting && delivery.senderId != driverId
            && delivery.weight <= availableKg && acceptedCount < maxParcels
            && abs(delivery.pickupAt.timeIntervalSince(departureAt)) <= Double(pickupWindowMinutes) * 60
    }
}
public struct TripDetails: Codable, Sendable {
    public var origin: SelectedPlace
    public var destination: SelectedPlace
    /// Acceptance order. Each parcel adds pickup then drop-off before the final destination.
    /// Other senders never receive this document or these identifiers.
    public var deliveryIds: [String] = []
    public init(origin: SelectedPlace, destination: SelectedPlace) { self.origin = origin; self.destination = destination }
}
public enum ProposalStatus: String, Codable, Sendable {
    case pending, accepted, rejected, withdrawn, expired
    public var title: String { switch self { case .pending: "Ожидает ответа"; case .accepted: "Принято"; case .rejected: "Отклонено"; case .withdrawn: "Отозвано"; case .expired: "Уже неактуально" } }
}
public struct TripProposal: Codable, Sendable, Identifiable {
    public var id: String
    public var tripId: String
    public var deliveryId: String
    public var senderId: String
    public var driverId: String
    public var itemDescription: String
    public var fromCity: String
    public var toCity: String
    public var weight: Double
    public var price: Int
    public var pickupAt: Date
    public var pickupArea: GeoPoint?
    public var dropoffArea: GeoPoint?
    public var status: ProposalStatus = .pending
    public var createdAt: Date = Date()
    public init(trip: CarrierTrip, delivery: Delivery) {
        id = delivery.id + "_" + trip.id; tripId = trip.id; deliveryId = delivery.id; senderId = delivery.senderId; driverId = trip.driverId
        itemDescription = delivery.itemDescription; fromCity = delivery.fromCity; toCity = delivery.toCity
        weight = delivery.weight; price = delivery.price; pickupAt = delivery.pickupAt
        pickupArea = delivery.pickupArea; dropoffArea = delivery.dropoffArea
    }
}
