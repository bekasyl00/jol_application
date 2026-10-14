import Foundation

/// Local demo only. Server transactions enforce ownership across devices in Firebase mode.
public actor LocalRepository {
    private struct Snapshot: Codable {
        var deliveries: [Delivery] = []
        var details: [String: DeliveryDetails] = [:]
        var messages: [String: [ChatMessage]] = [:]
        var profiles: [String: Profile] = [:]
        var trips: [CarrierTrip]?
        var tripDetails: [String: TripDetails]?
        var proposals: [TripProposal]?
    }
    private var state: Snapshot
    private let fileURL: URL
    public init(directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("parcel-demo.json")
        if FileManager.default.fileExists(atPath: fileURL.path) { state = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: fileURL)) }
        else { state = Snapshot() }
    }
    private func commit(_ value: Snapshot) throws {
        try JSONEncoder().encode(value).write(to: fileURL, options: .atomic)
        state = value
    }
    public func saveProfile(_ p: Profile) throws { try Validation.profile(p); var copy = state; copy.profiles[p.id] = p; try commit(copy) }
    public func orders(for p: Profile) -> [Delivery] {
        state.deliveries.filter { $0.senderId == p.id || $0.driverId == p.id || (p.role == .courier && $0.status == .waiting) }.sorted { $0.createdAt > $1.createdAt }
    }
    public func create(_ d: Delivery, details: DeliveryDetails, user: Profile) throws {
        guard user.role == .sender, d.senderId == user.id, d.status == .waiting else { throw ParcelError.forbidden }
        try Validation.order(d, details: details)
        if let existing = state.deliveries.first(where: { $0.id == d.id }) {
            guard existing.senderId == user.id else { throw ParcelError.forbidden }; return
        }
        var copy = state; copy.deliveries.append(d); copy.details[d.id] = details; try commit(copy)
    }
    public func accept(_ id: String, user: Profile) throws {
        guard user.role == .courier, let i = state.deliveries.firstIndex(where: { $0.id == id }), state.deliveries[i].senderId != user.id else { throw ParcelError.forbidden }
        guard state.deliveries[i].status == .waiting, state.deliveries[i].driverId == nil else { throw ParcelError.alreadyAccepted }
        guard state.deliveries[i].weight <= user.capacityKg else { throw ParcelError.invalid("Недостаточная грузоподъёмность.") }
        var copy = state; copy.deliveries[i].driverId = user.id; copy.deliveries[i].status = .accepted; copy.deliveries[i].updatedAt = Date()
        for pi in (copy.proposals ?? []).indices where copy.proposals![pi].deliveryId == id && copy.proposals![pi].status == .pending { copy.proposals![pi].status = .expired }
        try commit(copy)
    }
    public func transition(_ id: String, to status: DeliveryStatus, reason: String = "", user: Profile) throws {
        guard let i = state.deliveries.firstIndex(where: { $0.id == id }) else { throw ParcelError.forbidden }
        let d = state.deliveries[i]
        let canCancel = status == .cancelled && [.waiting, .accepted, .enRoute].contains(d.status) && (d.senderId == user.id || d.driverId == user.id) && (3...500).contains(reason.count)
        guard canCancel || (d.driverId == user.id && d.status.next == status) else { throw ParcelError.invalidTransition }
        var copy = state; copy.deliveries[i].status = status; copy.deliveries[i].updatedAt = Date()
        if canCancel {
            copy.deliveries[i].cancellationReason = reason
            if let tid = d.tripId, let ti = copy.trips?.firstIndex(where: { $0.id == tid }) {
                copy.trips![ti].reservedKg = max(0, copy.trips![ti].reservedKg - d.weight)
                copy.trips![ti].acceptedCount -= 1; copy.trips![ti].version += 1
                copy.tripDetails?[tid]?.deliveryIds.removeAll { $0 == id }
            }
            for pi in (copy.proposals ?? []).indices where copy.proposals![pi].deliveryId == id && copy.proposals![pi].status == .pending { copy.proposals![pi].status = .expired }
        }
        try commit(copy)
    }
    private func participant(_ id: String, _ user: Profile) throws -> Delivery {
        guard let d = state.deliveries.first(where: { $0.id == id }), d.senderId == user.id || d.driverId == user.id else { throw ParcelError.forbidden }; return d
    }
    public func details(_ id: String, user: Profile) throws -> DeliveryDetails? { _ = try participant(id, user); return state.details[id] }
    public func contact(_ id: String, user: Profile) throws -> Profile? { let d = try participant(id, user); return state.profiles[d.senderId == user.id ? (d.driverId ?? "") : d.senderId] }
    public func messages(_ id: String, user: Profile) throws -> [ChatMessage] { _ = try participant(id, user); return state.messages[id] ?? [] }
    public func send(_ id: String, text: String, user: Profile) throws {
        let d = try participant(id, user)
        guard d.driverId != nil, d.status.isActive, (1...2000).contains(text.trimmingCharacters(in: .whitespacesAndNewlines).count) else { throw ParcelError.invalid("Чат доступен для принятого активного заказа. Сообщение — до 2000 символов.") }
        var copy = state; copy.messages[id, default: []].append(ChatMessage(fromUser: user.id, text: text)); try commit(copy)
    }
    public func review(_ id: String, text: String, user: Profile) throws {
        guard let i = state.deliveries.firstIndex(where: { $0.id == id }), state.deliveries[i].senderId == user.id, state.deliveries[i].status == .delivered, (1...500).contains(text.count) else { throw ParcelError.forbidden }
        var copy = state; copy.deliveries[i].review = text; try commit(copy)
    }
    public func deleteAccount(_ user: Profile) throws {
        guard !state.deliveries.contains(where: { ($0.senderId == user.id || $0.driverId == user.id) && $0.status.isActive }) else { throw ParcelError.invalid("Сначала завершите или отмените активные доставки.") }
        var copy = state
        for d in copy.deliveries where d.senderId == user.id || d.driverId == user.id {
            copy.details[d.id] = nil; copy.messages[d.id] = nil
        }
        copy.deliveries.removeAll { $0.senderId == user.id || $0.driverId == user.id }; copy.profiles[user.id] = nil
        for trip in copy.trips ?? [] where trip.driverId == user.id { copy.tripDetails?[trip.id] = nil }
        copy.trips?.removeAll { $0.driverId == user.id }
        copy.proposals?.removeAll { $0.driverId == user.id || $0.senderId == user.id }
        try commit(copy)
    }
    public func trips(for user: Profile) -> [CarrierTrip] {
        (state.trips ?? []).filter { $0.driverId == user.id || (user.role == .sender && $0.status == .published && $0.departureAt > Date()) }.sorted { $0.departureAt < $1.departureAt }
    }
    public func tripDetails(_ id: String, user: Profile) throws -> TripDetails? {
        guard state.trips?.contains(where: { $0.id == id && $0.driverId == user.id }) == true else { throw ParcelError.forbidden }
        return state.tripDetails?[id]
    }
    public func publishTrip(_ trip: CarrierTrip, details: TripDetails, user: Profile) throws {
        guard user.role == .courier, trip.driverId == user.id, trip.capacityKg <= user.capacityKg else { throw ParcelError.forbidden }
        try trip.validate()
        guard details.origin.isValid, details.destination.isValid, details.deliveryIds.isEmpty else { throw ParcelError.invalid("Подтвердите точки поездки.") }
        var copy = state
        if copy.trips?.contains(where: { $0.id == trip.id }) == true { return }
        if copy.trips == nil { copy.trips = [] }; if copy.tripDetails == nil { copy.tripDetails = [:] }
        copy.trips!.append(trip); copy.tripDetails![trip.id] = details; try commit(copy)
    }
    public func closeTrip(_ id: String, user: Profile) throws {
        guard let i = state.trips?.firstIndex(where: { $0.id == id && $0.driverId == user.id }) else { throw ParcelError.forbidden }
        var copy = state; copy.trips![i].status = .closed; copy.trips![i].version += 1
        for pi in (copy.proposals ?? []).indices where copy.proposals![pi].tripId == id && copy.proposals![pi].status == .pending { copy.proposals![pi].status = .expired }
        try commit(copy)
    }
    public func proposals(for user: Profile) -> [TripProposal] {
        (state.proposals ?? []).filter { $0.senderId == user.id || $0.driverId == user.id }.sorted { $0.createdAt > $1.createdAt }
    }
    public func propose(deliveryId: String, tripId: String, user: Profile) throws {
        guard user.role == .sender, let d = state.deliveries.first(where: { $0.id == deliveryId && $0.senderId == user.id }), let t = state.trips?.first(where: { $0.id == tripId }) else { throw ParcelError.forbidden }
        let proposal = TripProposal(trip: t, delivery: d)
        if state.proposals?.contains(where: { $0.id == proposal.id }) == true { return }
        guard t.canPropose(d) else { throw ParcelError.invalid("Поездка уже недоступна, не хватает места или не подходит время передачи.") }
        var copy = state; if copy.proposals == nil { copy.proposals = [] }
        copy.proposals!.append(proposal); try commit(copy)
    }
    public func respondProposal(_ id: String, action: ProposalStatus, expectedVersion: Int?, user: Profile) throws {
        guard let pi = state.proposals?.firstIndex(where: { $0.id == id }) else { throw ParcelError.forbidden }
        let p = state.proposals![pi]
        guard (action == .withdrawn && p.senderId == user.id) || ([.accepted, .rejected].contains(action) && p.driverId == user.id) else { throw ParcelError.forbidden }
        if p.status == action { return }
        guard p.status == .pending else { throw ParcelError.invalid("Предложение уже обработано.") }
        var copy = state
        if action == .accepted {
            guard let ti = copy.trips?.firstIndex(where: { $0.id == p.tripId }), let di = copy.deliveries.firstIndex(where: { $0.id == p.deliveryId }) else { throw ParcelError.forbidden }
            let trip = copy.trips![ti]; let d = copy.deliveries[di]
            guard trip.version == expectedVersion, trip.canPropose(d) else { throw ParcelError.invalid("Поездка изменилась. Обновите предложения и проверьте свободное место.") }
            copy.trips![ti].reservedKg += d.weight; copy.trips![ti].acceptedCount += 1; copy.trips![ti].version += 1
            copy.tripDetails?[trip.id]?.deliveryIds.append(d.id)
            copy.deliveries[di].driverId = user.id; copy.deliveries[di].tripId = trip.id; copy.deliveries[di].status = .accepted; copy.deliveries[di].updatedAt = Date()
            for other in copy.proposals!.indices where copy.proposals![other].deliveryId == d.id && other != pi && copy.proposals![other].status == .pending { copy.proposals![other].status = .expired }
        }
        copy.proposals![pi].status = action; try commit(copy)
    }

}
