import Foundation
import FirebaseFirestore

extension AppStore {
    func listenTrips() {
        guard let p = profile else { return }
        let db = Firestore.firestore()
        let proposalQuery = db.collection("proposals").whereField(p.role == .sender ? "senderId" : "driverId", isEqualTo: p.id)
        tripListeners.append(proposalQuery.addSnapshotListener { [weak self] snap, error in
            Task { @MainActor in
                guard let self, self.profile?.id == p.id, !self.demo else { return }
                do {
                    if let error { throw error }
                    self.proposals = try snap?.documents.map { try $0.data(as: TripProposal.self) }.sorted { $0.createdAt > $1.createdAt } ?? []
                } catch { self.error = "Не удалось обновить предложения." }
            }
        })
        if p.role == .courier {
            tripListeners.append(db.collection("trips").whereField("driverId", isEqualTo: p.id).addSnapshotListener { [weak self] snap, error in
                Task { @MainActor in
                    guard let self, self.profile?.id == p.id, !self.demo else { return }
                    do {
                        if let error { throw error }
                        self.trips = try snap?.documents.map { try $0.data(as: CarrierTrip.self) }.sorted { $0.departureAt < $1.departureAt } ?? []
                    } catch { self.error = "Не удалось обновить поездки." }
                }
            })
        } else { Task { await refresh() } }
    }
    func loadCatalog(reset: Bool) async throws {
        guard !demo, let p = profile, p.role == .sender else { return }
        var query = Firestore.firestore().collection("trips").whereField("status", isEqualTo: "published").whereField("departureAt", isGreaterThan: Date()).order(by: "departureAt").limit(to: 20)
        if !reset, let catalogCursor { query = query.start(afterDocument: catalogCursor) }
        let result = try await query.getDocuments()
        guard !demo, profile?.id == p.id else { return }
        let values = try result.documents.map { try $0.data(as: CarrierTrip.self) }
        if reset { trips = values } else { for value in values { trips.removeAll { $0.id == value.id }; trips.append(value) } }
        catalogCursor = result.documents.last; catalogHasMore = values.count == 20
    }
    func publishTrip(_ trip: CarrierTrip, details: TripDetails) async throws {
        guard let p = profile else { throw ParcelError.forbidden }; try trip.validate()
        if demo { try await local?.publishTrip(trip, details: details, user: p); await refresh(); return }
        _ = try await call("publishTrip", data: ["id": trip.id, "fromCity": trip.fromCity, "toCity": trip.toCity, "origin": details.origin.payload, "destination": details.destination.payload, "departureAt": trip.departureAt.timeIntervalSince1970 * 1000, "capacityKg": trip.capacityKg, "maxParcels": trip.maxParcels, "maxDetourKm": trip.maxDetourKm, "maxDetourMinutes": trip.maxDetourMinutes, "pickupWindowMinutes": trip.pickupWindowMinutes])
    }
    func closeTrip(_ id: String) async throws {
        guard let p = profile else { throw ParcelError.forbidden }
        if demo { try await local?.closeTrip(id, user: p); await refresh() }
        else { _ = try await call("closeTrip", data: ["id": id]) }
    }
    func tripDetails(_ id: String) async throws -> TripDetails? {
        guard let p = profile else { throw ParcelError.forbidden }
        if demo { return try await local?.tripDetails(id, user: p) }
        return try await Firestore.firestore().collection("trips").document(id).collection("private").document("details").getDocument().data(as: TripDetails.self)
    }
    func propose(deliveryId: String, tripId: String) async throws {
        guard let p = profile else { throw ParcelError.forbidden }
        if demo { try await local?.propose(deliveryId: deliveryId, tripId: tripId, user: p); await refresh() }
        else { _ = try await call("createProposal", data: ["deliveryId": deliveryId, "tripId": tripId]) }
    }
    func respond(_ proposal: TripProposal, action: ProposalStatus, version: Int?) async throws {
        guard let p = profile else { throw ParcelError.forbidden }
        if demo { try await local?.respondProposal(proposal.id, action: action, expectedVersion: version, user: p); await refresh() }
        else { _ = try await call("respondProposal", data: ["id": proposal.id, "action": action.rawValue, "version": version as Any]) }
    }
}
