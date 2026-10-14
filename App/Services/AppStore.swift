import SwiftUI
import MapKit
import PhotosUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import FirebaseStorage
import FirebaseMessaging
import UserNotifications
import OSLog

@MainActor @Observable final class AppStore {
    let tracking = DeliveryTrackingService()
    var profile: Profile?
    var orders: [Delivery] = []
    var error: String?
    var busy = false
    var demo = false
    var authReady = false
    var authLoadGeneration = UUID()
    var deletionPending = false
    var local: LocalRepository?
    var trips: [CarrierTrip] = []
    var proposals: [TripProposal] = []
    var tripListeners: [ListenerRegistration] = []
    var catalogCursor: DocumentSnapshot?
    var catalogHasMore = false
    private static let storageLog = Logger(subsystem: "kz.jol.parcel", category: "DemoStorage")
    private var listeners: [ListenerRegistration] = []
    private var groups: [String: [Delivery]] = [:]
    private var authHandle: AuthStateDidChangeListenerHandle?
    var isConfigured: Bool {
        #if JOL_DEMO_ONLY
        false
        #else
        FirebaseApp.app() != nil
        #endif
    }
    var backend: Functions { Functions.functions(region: "europe-west1") }
    init() {
        if isConfigured {
            authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, _ in
                Task { @MainActor in await self?.loadAuthenticatedUser() }
            }
        } else { authReady = true }
    }
    func perform(_ work: () async throws -> Void) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { try await work() } catch {
            #if JOL_LOCAL_SERVER
            let failure = error as NSError
            if failure.domain == NSURLErrorDomain ||
                (failure.domain == FunctionsErrorDomain && [FunctionsErrorCode.unavailable.rawValue, FunctionsErrorCode.deadlineExceeded.rawValue].contains(failure.code)) ||
                (failure.domain == AuthErrorDomain && failure.code == AuthErrorCode.networkError.rawValue) {
                self.error = LocalBackend.connectionHelp
            } else { self.error = error.localizedDescription }
            #else
            self.error = error.localizedDescription
            #endif
        }
    }
    private func openDemoStorage() throws -> LocalRepository {
        if let local { return local }
        do {
            let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("JolParcel", isDirectory: true)
            let repository = try LocalRepository(directory: dir)
            local = repository
            return repository
        } catch {
            let failure = error as NSError
            Self.storageLog.error("Demo storage open failed: \(failure.domain, privacy: .public) code=\(failure.code)")
            throw ParcelError.invalid("Не удалось открыть демоданные. Проверьте свободное место и повторите попытку. Существующие данные сохранены.")
        }
    }
    func enterDemo(role: Role) async throws {
        let local = try openDemoStorage()
        let p = Profile(id: role == .sender ? "demo-sender" : "demo-courier", name: role == .sender ? "Алия" : "Арман", phone: role == .sender ? "+77010000001" : "+77010000002", role: role, vehicle: role == .courier ? "Toyota Camry" : "", capacityKg: role == .courier ? 50 : 0)
        try await local.saveProfile(p)
        if isConfigured, Auth.auth().currentUser != nil { try await logout() }
        demo = true; stopListeners(); profile = p; await refresh()
    }
    func loadFullProfile(uid: String, generation: UUID) async throws {
        let doc = try await Firestore.firestore().collection("users").document(uid).getDocument(source: .server)
        guard !demo, authLoadGeneration == generation, Auth.auth().currentUser?.uid == uid else { return }
        if doc.data()?["deleting"] as? Bool == true {
            deletionPending = true
            profile = Profile(id: uid, name: "Удаление аккаунта", phone: "", role: .sender)
            error = "Удаление было начато. Повторите его в профиле."
        } else {
            profile = try doc.data(as: Profile.self); deletionPending = false
            listen(); await syncToken()
        }
    }
    func stopListeners() { listeners.forEach { $0.remove() }; listeners = []; groups = [:]; tripListeners.forEach { $0.remove() }; tripListeners = []; trips = []; proposals = []; catalogCursor = nil }
    func listen() {
        stopListeners(); guard let p = profile else { return }
        listenTrips()
        let collection = Firestore.firestore().collection("deliveries")
        var queries: [(String, Query)] = [("sender", collection.whereField("senderId", isEqualTo: p.id)), ("driver", collection.whereField("driverId", isEqualTo: p.id))]
        if p.role == .courier { queries.append(("market", collection.whereField("status", isEqualTo: "waiting"))) }
        for (key, query) in queries {
            listeners.append(query.addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self, !self.demo, self.profile?.id == p.id else { return }
                    if error != nil { self.error = "Не удалось обновить список доставок."; return }
                    do {
                        self.groups[key] = try snapshot?.documents.map { try $0.data(as: Delivery.self) } ?? []
                        var unique: [String: Delivery] = [:]
                        for item in self.groups.values.flatMap({ $0 }) { unique[item.id] = item }
                        self.orders = unique.values.sorted { $0.createdAt > $1.createdAt }
                        self.tracking.reconcile(orders: self.orders, uid: p.id)
                    } catch { self.error = "Получен заказ в неподдерживаемом формате." }
                }
            })
        }
    }
    func refresh() async {
        if demo, let p = profile, let local { orders = await local.orders(for: p); trips = await local.trips(for: p); proposals = await local.proposals(for: p) }
        else if profile?.role == .sender { do { try await loadCatalog(reset: true) } catch { self.error = error.localizedDescription } }
    }
    func call(_ name: String, data: [String: Any]) async throws -> Any {
        let function = backend.httpsCallable(name)
        #if JOL_LOCAL_SERVER
        function.timeoutInterval = 15
        #endif
        return try await function.call(data).data
    }
    func create(_ d: Delivery, details: DeliveryDetails, photo: Data?) async throws {
        guard let p = profile else { throw ParcelError.forbidden }
        try Validation.order(d, details: details)
        var order = d
        if demo {
            if photo != nil { throw ParcelError.invalid("Фотографии доступны после подключения Firebase. Уберите фото для демозаказа.") }
            try await local?.create(order, details: details, user: p); await refresh(); return
        }
        if let photo {
            guard photo.count <= 5 * 1024 * 1024 else { throw ParcelError.invalid("Фото должно быть не больше 5 МБ.") }
            guard let result = try await call("uploadParcelPhoto", data: ["id": d.id, "base64": photo.base64EncodedString()]) as? [String: Any], let path = result["path"] as? String else { throw ParcelError.invalid("Не удалось загрузить фото.") }
            order.photoPath = path
        }
        var payload: [String: Any] = ["id": order.id, "fromCity": order.fromCity, "toCity": order.toCity, "itemDescription": order.itemDescription, "size": order.size.rawValue, "weight": order.weight, "volume": order.volume, "distanceKm": order.distanceKm, "price": order.price, "pickupAt": order.pickupAt.timeIntervalSince1970 * 1000, "addressFrom": details.addressFrom, "addressTo": details.addressTo, "recipientName": details.recipientName, "recipientPhone": details.recipientPhone, "comment": details.comment]
        if let path = order.photoPath { payload["photoPath"] = path }
        if let place = details.pickupPlace { payload["pickupPlace"] = place.payload }
        if let place = details.dropoffPlace { payload["dropoffPlace"] = place.payload }
        if let source = order.distanceSource { payload["distanceSource"] = source }
        if let route = details.route { payload["route"] = ["distanceMeters": route.distanceMeters, "durationSeconds": route.durationSeconds, "calculatedAt": route.calculatedAt.timeIntervalSince1970 * 1000] }
        _ = try await call("createDelivery", data: payload)
    }
    func accept(_ d: Delivery) async throws {
        guard let p = profile else { throw ParcelError.forbidden }
        if demo { try await local?.accept(d.id, user: p); await refresh() }
        else { _ = try await call("acceptDelivery", data: ["id": d.id]) }
    }
    func transition(_ d: Delivery, to status: DeliveryStatus, reason: String = "") async throws {
        guard let p = profile else { throw ParcelError.forbidden }
        if demo { try await local?.transition(d.id, to: status, reason: reason, user: p); await refresh() }
        else { _ = try await call("transitionDelivery", data: ["id": d.id, "status": status.rawValue, "reason": reason]); if [.delivered, .cancelled].contains(status) { await tracking.stop(id: d.id) } }
    }
    func details(_ id: String) async throws -> DeliveryDetails? {
        guard let p = profile else { throw ParcelError.forbidden }
        if demo { return try await local?.details(id, user: p) }
        return try await Firestore.firestore().collection("deliveries").document(id).collection("private").document("details").getDocument().data(as: DeliveryDetails.self)
    }
    func contact(_ id: String) async throws -> Profile? {
        guard let p = profile else { throw ParcelError.forbidden }
        if demo { return try await local?.contact(id, user: p) }
        guard let data = try await call("deliveryContact", data: ["id": id]) as? [String: Any], !data.isEmpty else { return nil }
        return try JSONDecoder().decode(Profile.self, from: JSONSerialization.data(withJSONObject: data))
    }
    func messages(_ id: String) async throws -> [ChatMessage] {
        guard let p = profile else { throw ParcelError.forbidden }
        if demo { return try await local?.messages(id, user: p) ?? [] }
        return try await Firestore.firestore().collection("deliveries").document(id).collection("messages").order(by: "timestamp").limit(toLast: 100).getDocuments().documents.map { try $0.data(as: ChatMessage.self) }
    }
    func send(_ id: String, text: String) async throws {
        guard let p = profile else { throw ParcelError.forbidden }
        if demo { try await local?.send(id, text: text, user: p) }
        else { _ = try await call("sendMessage", data: ["id": id, "text": text]) }
    }
    func review(_ id: String, text: String) async throws {
        guard let p = profile else { throw ParcelError.forbidden }
        if demo { try await local?.review(id, text: text, user: p); await refresh() }
        else { _ = try await call("reviewDelivery", data: ["id": id, "text": text]) }
    }
    func logout() async throws {
        authLoadGeneration = UUID()
        await tracking.stopAll()
        stopListeners()
        if !demo && isConfigured {
            if !LocalBackend.enabled, let uid = Auth.auth().currentUser?.uid, let token = try? await Messaging.messaging().token() {
                try? await Firestore.firestore().collection("users").document(uid).collection("tokens").document(token).delete()
            }
            // Revoke server session while still authenticated. Offline logout still clears the local session.
            _ = try? await call("revokeSession", data: [:])
            try Auth.auth().signOut()
        }
        profile = nil; orders = []; demo = false; deletionPending = false
    }
    func deleteAccount(password: String = "") async throws {
        await tracking.stopAll()
        guard let p = profile else { return }
        if demo { try await local?.deleteAccount(p) }
        else {
            guard let phone = Auth.auth().currentUser?.phoneNumber, !phone.isEmpty else { throw ParcelError.forbidden }
            try await loginPhone(phone: phone, password: password)
            _ = try await call("deleteAccount", data: [:])
        }
        try await logout()
    }
    func enableNotifications() async throws {
        guard !LocalBackend.enabled else { throw ParcelError.invalid("В локальной сборке изменения видны в открытом приложении. Push-уведомления подключим в облачной версии.") }
        guard !demo, isConfigured else { throw ParcelError.invalid("Push-уведомления доступны после подключения Firebase.") }
        guard try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) else { return }
        UIApplication.shared.registerForRemoteNotifications(); await syncToken()
    }
    func saveToken(_ token: String) async throws {
        guard !LocalBackend.enabled, !demo, let uid = Auth.auth().currentUser?.uid else { return }
        try await Firestore.firestore().collection("users").document(uid).collection("tokens").document(token).setData(["token": token, "updatedAt": FieldValue.serverTimestamp()])
    }
}


extension AppStore {
    func photoData(_ path: String) async throws -> Data {
        let parts = path.split(separator: "/")
        guard parts.count == 4, let response = try await call("parcelPhoto", data: ["id": String(parts[2])]) as? [String: Any], let base64 = response["base64"] as? String, let data = Data(base64Encoded: base64) else { throw ParcelError.invalid("Фото недоступно.") }
        return data
    }
}

extension AppStore {
    func syncToken() async {
        guard !LocalBackend.enabled, isConfigured, !demo, profile != nil else { return }
        if let token = try? await Messaging.messaging().token() { try? await saveToken(token) }
    }
}
