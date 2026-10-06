import Foundation

public enum Role: String, Codable, Sendable, CaseIterable { case sender, courier }
public struct Profile: Codable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var phone: String
    public var role: Role
    public var vehicle: String
    public var capacityKg: Double
    public init(id: String, name: String, phone: String, role: Role, vehicle: String = "", capacityKg: Double = 0) {
        self.id = id; self.name = name; self.phone = phone; self.role = role; self.vehicle = vehicle; self.capacityKg = capacityKg
    }
}
public enum ParcelSize: String, Codable, Sendable, CaseIterable, Identifiable {
    case packet, bag, box, suitcase
    public var id: String { rawValue }
    public var title: String { switch self { case .packet: "Пакет"; case .bag: "Сумка"; case .box: "Коробка"; case .suitcase: "Чемодан" } }
    public var symbol: String { switch self { case .packet: "envelope"; case .bag: "bag"; case .box: "shippingbox"; case .suitcase: "suitcase.rolling" } }
    public var weight: Double { switch self { case .packet: 1; case .bag: 5; case .box: 10; case .suitcase: 23 } }
    public var volume: Double { switch self { case .packet: 0.005; case .bag: 0.025; case .box: 0.06; case .suitcase: 0.12 } }
}
public enum DeliveryStatus: String, Codable, Sendable, CaseIterable {
    case waiting, accepted, enRoute, pickedUp, delivered, cancelled
    public var title: String { switch self {
    case .waiting: "Ожидает перевозчика"; case .accepted: "Принят перевозчиком"; case .enRoute: "Едет к отправителю"
    case .pickedUp: "Посылка в пути"; case .delivered: "Доставлено"; case .cancelled: "Отменено"
    } }
    public var next: DeliveryStatus? { switch self { case .accepted: .enRoute; case .enRoute: .pickedUp; case .pickedUp: .delivered; default: nil } }
    public var isActive: Bool { self != .delivered && self != .cancelled }
}
public struct Delivery: Codable, Sendable, Identifiable {
    public var id: String
    public var senderId: String
    public var driverId: String?
    public var fromCity: String
    public var toCity: String
    public var itemDescription: String
    public var size: ParcelSize
    public var weight: Double
    public var volume: Double
    public var distanceKm: Double
    public var price: Int
    public var pickupAt: Date
    public var status: DeliveryStatus
    public var createdAt: Date
    public var updatedAt: Date
    public var cancellationReason: String?
    public var review: String?
    public var photoPath: String?
    public init(id: String = UUID().uuidString, senderId: String, fromCity: String, toCity: String, itemDescription: String, size: ParcelSize, weight: Double, volume: Double, distanceKm: Double, price: Int, pickupAt: Date, photoPath: String? = nil) {
        self.id = id; self.senderId = senderId; self.fromCity = fromCity; self.toCity = toCity; self.itemDescription = itemDescription
        self.size = size; self.weight = weight; self.volume = volume; self.distanceKm = distanceKm; self.price = price; self.pickupAt = pickupAt
        self.status = .waiting; self.createdAt = Date(); self.updatedAt = Date(); self.photoPath = photoPath
    }
}
public struct DeliveryDetails: Codable, Sendable {
    public var addressFrom: String
    public var addressTo: String
    public var recipientName: String
    public var recipientPhone: String
    public var comment: String
    public init(addressFrom: String, addressTo: String, recipientName: String, recipientPhone: String, comment: String) {
        self.addressFrom = addressFrom; self.addressTo = addressTo; self.recipientName = recipientName; self.recipientPhone = recipientPhone; self.comment = comment
    }
}
public struct ChatMessage: Codable, Sendable, Identifiable {
    public var id: String
    public var fromUser: String
    public var text: String
    public var timestamp: Date
    public init(id: String = UUID().uuidString, fromUser: String, text: String, timestamp: Date = Date()) { self.id = id; self.fromUser = fromUser; self.text = text; self.timestamp = timestamp }
}
public enum ParcelError: LocalizedError, Sendable {
    case invalid(String), forbidden, alreadyAccepted, invalidTransition
    public var errorDescription: String? { switch self { case .invalid(let message): message; case .forbidden: "Нет доступа к этому действию."; case .alreadyAccepted: "Заказ уже принят другим перевозчиком."; case .invalidTransition: "Обновите заказ: его статус изменился." } }
}
public enum Pricing {
    public static func quote(distanceKm: Double, volume: Double) throws -> Int {
        guard distanceKm.isFinite, volume.isFinite, distanceKm >= 1, distanceKm <= 5000, volume >= 0.001, volume <= 5 else { throw ParcelError.invalid("Проверьте расстояние и объём.") }
        return Int((1000 + distanceKm * 8 + volume * 5000).rounded(.up))
    }
}
public enum Validation {
    public static func profile(_ p: Profile) throws {
        guard (2...80).contains(p.name.trimmingCharacters(in: .whitespacesAndNewlines).count), validPhone(p.phone) else { throw ParcelError.invalid("Укажите имя и телефон в формате +7XXXXXXXXXX.") }
        if p.role == .courier && (p.vehicle.isEmpty || !p.capacityKg.isFinite || p.capacityKg <= 0 || p.capacityKg > 5000) { throw ParcelError.invalid("Укажите автомобиль и грузоподъёмность.") }
    }
    public static func validPhone(_ phone: String) -> Bool { phone.range(of: #"^\+7[0-9]{10}$"#, options: .regularExpression) != nil }
    public static func order(_ d: Delivery, details: DeliveryDetails) throws {
        guard d.fromCity != d.toCity, kazakhstanCities.contains(d.fromCity), kazakhstanCities.contains(d.toCity), (3...500).contains(d.itemDescription.count), d.price > 0, d.price <= 1_000_000,
              d.weight.isFinite, d.weight >= 0.1, d.weight <= 5000,
              !details.addressFrom.isEmpty, !details.addressTo.isEmpty, !details.recipientName.isEmpty,
              validPhone(details.recipientPhone), details.comment.count <= 1000,
              d.pickupAt > Date().addingTimeInterval(-300), d.pickupAt <= Date().addingTimeInterval(366 * 86400) else { throw ParcelError.invalid("Проверьте маршрут, адреса, получателя, дату и цену.") }
        _ = try Pricing.quote(distanceKm: d.distanceKm, volume: d.volume)
    }
}
public let kazakhstanCities = ["Алматы", "Астана", "Шымкент", "Караганда", "Тараз", "Актобе", "Атырау", "Актау", "Павлодар", "Семей", "Өскемен", "Костанай", "Кызылорда", "Петропавловск", "Уральск", "Талдыкорган"]
