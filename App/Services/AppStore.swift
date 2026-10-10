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
    var profile: Profile?
    var orders: [Delivery] = []
    var error: String?
    var busy = false
    var demo = false
    var authReady = false
    var deletionPending = false
    private var local: LocalRepository?
    private static let storageLog = Logger(subsystem: "kz.jol.parcel", category: "DemoStorage")
    private var listeners: [ListenerRegistration] = []
    private var groups: [String: [Delivery]] = [:]
    private var authHandle: AuthStateDidChangeListenerHandle?
    var isConfigured: Bool { FirebaseApp.app() != nil }
    var backend: Functions { Functions.functions(region: "europe-west1") }
    init() {
        if isConfigured {
            authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
                Task { @MainActor in
                    guard let self, !self.demo else { return }
                    if let user {
                        do {
                            let doc = try await Firestore.firestore().collection("users").document(user.uid).getDocument()
                            if doc.data()?["deleting"] as? Bool == true {
                                self.deletionPending = true
                                self.profile = Profile(id: user.uid, name: "Удаление аккаунта", phone: "", role: .sender)
                                self.error = "Удаление было начато. Повторите его в профиле, подтвердив пароль."
                            } else if doc.exists {
                                self.deletionPending = false
                                self.profile = try doc.data(as: Profile.self)
                            } else if self.profile?.id != user.uid { self.profile = nil }
                            if self.profile != nil && !self.deletionPending { self.listen(); await self.syncToken() }
                        } catch { self.error = "Не удалось загрузить профиль." }
                    } else { self.stopListeners(); self.profile = nil; self.orders = [] }
                    self.authReady = true
                }
            }
        } else { authReady = true }
    }
    func perform(_ work: () async throws -> Void) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { try await work() } catch { self.error = error.localizedDescription }
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
        demo = true; stopListeners(); profile = p; await refresh()
    }
    func login(email: String, password: String) async throws {
        demo = false; _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }
    func register(email: String, password: String, name: String, phone: String, role: Role, vehicle: String, capacity: Double) async throws {
        let p = Profile(id: "new", name: name, phone: phone, role: role, vehicle: vehicle, capacityKg: capacity)
        try Validation.profile(p)
        guard password.count >= 8 else { throw ParcelError.invalid("Пароль должен содержать минимум 8 символов.") }
        demo = false
        // Retry profile creation for an existing incomplete registration.
        let user: FirebaseAuth.User
        if let current = Auth.auth().currentUser { user = current }
        else { user = try await Auth.auth().createUser(withEmail: email, password: password).user }
        var saved = p; saved.id = user.uid
        try Firestore.firestore().collection("users").document(user.uid).setData(from: saved)
        profile = saved; listen(); await syncToken()
    }
    func stopListeners() { listeners.forEach { $0.remove() }; listeners = []; groups = [:] }
    func listen() {
        stopListeners(); guard let p = profile else { return }
        let collection = Firestore.firestore().collection("deliveries")
        var queries: [(String, Query)] = [("sender", collection.whereField("senderId", isEqualTo: p.id)), ("driver", collection.whereField("driverId", isEqualTo: p.id))]
        if p.role == .courier { queries.append(("market", collection.whereField("status", isEqualTo: "waiting"))) }
        for (key, query) in queries {
            listeners.append(query.addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if error != nil { self.error = "Не удалось обновить список доставок."; return }
                    do {
                        self.groups[key] = try snapshot?.documents.map { try $0.data(as: Delivery.self) } ?? []
                        var unique: [String: Delivery] = [:]
                        for item in self.groups.values.flatMap({ $0 }) { unique[item.id] = item }
                        self.orders = unique.values.sorted { $0.createdAt > $1.createdAt }
                    } catch { self.error = "Получен заказ в неподдерживаемом формате." }
                }
            })
        }
    }
    func refresh() async { if demo, let p = profile, let local { orders = await local.orders(for: p) } }
    func call(_ name: String, data: [String: Any]) async throws -> Any {
        try await backend.httpsCallable(name).call(data).data
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
            let path = "parcels/\(p.id)/\(d.id)/photo.jpg"
            let meta = StorageMetadata(); meta.contentType = "image/jpeg"
            _ = try await Storage.storage().reference(withPath: path).putDataAsync(photo, metadata: meta); order.photoPath = path
        }
        var payload: [String: Any] = ["id": order.id, "fromCity": order.fromCity, "toCity": order.toCity, "itemDescription": order.itemDescription, "size": order.size.rawValue, "weight": order.weight, "volume": order.volume, "distanceKm": order.distanceKm, "price": order.price, "pickupAt": order.pickupAt.timeIntervalSince1970 * 1000, "addressFrom": details.addressFrom, "addressTo": details.addressTo, "recipientName": details.recipientName, "recipientPhone": details.recipientPhone, "comment": details.comment]
        if let path = order.photoPath { payload["photoPath"] = path }
        do { _ = try await call("createDelivery", data: payload) }
        catch { if let path = order.photoPath { try? await Storage.storage().reference(withPath: path).delete() }; throw error }
    }
    func accept(_ d: Delivery) async throws {
        guard let p = profile else { throw ParcelError.forbidden }
        if demo { try await local?.accept(d.id, user: p); await refresh() }
        else { _ = try await call("acceptDelivery", data: ["id": d.id]) }
    }
    func transition(_ d: Delivery, to status: DeliveryStatus, reason: String = "") async throws {
        guard let p = profile else { throw ParcelError.forbidden }
        if demo { try await local?.transition(d.id, to: status, reason: reason, user: p); await refresh() }
        else { _ = try await call("transitionDelivery", data: ["id": d.id, "status": status.rawValue, "reason": reason]) }
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
        stopListeners()
        if !demo && isConfigured {
            if let uid = Auth.auth().currentUser?.uid, let token = try? await Messaging.messaging().token() {
                try? await Firestore.firestore().collection("users").document(uid).collection("tokens").document(token).delete()
            }
            try Auth.auth().signOut()
        }
        profile = nil; orders = []; demo = false; deletionPending = false
    }
    func deleteAccount(password: String = "") async throws {
        guard let p = profile else { return }
        if demo { try await local?.deleteAccount(p) }
        else {
            guard let user = Auth.auth().currentUser, let email = user.email else { throw ParcelError.forbidden }
            do { _ = try await user.reauthenticate(with: EmailAuthProvider.credential(withEmail: email, password: password)) }
            catch {
                if (error as NSError).code == AuthErrorCode.userNotFound.rawValue && deletionPending { try await logout(); return }
                throw error
            }
            _ = try await user.getIDToken(forcingRefresh: true)
            _ = try await call("deleteAccount", data: [:])
        }
        try await logout()
    }
    func enableNotifications() async throws {
        guard !demo, isConfigured else { throw ParcelError.invalid("Push-уведомления доступны после подключения Firebase.") }
        guard try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) else { return }
        UIApplication.shared.registerForRemoteNotifications(); await syncToken()
    }
    func saveToken(_ token: String) async throws {
        guard !demo, let uid = Auth.auth().currentUser?.uid else { return }
        try await Firestore.firestore().collection("users").document(uid).collection("tokens").document(token).setData(["token": token, "updatedAt": FieldValue.serverTimestamp()])
    }
}

@MainActor enum RouteService {
    static func distance(from: String, to: String) async throws -> Double {
        guard from != to else { throw ParcelError.invalid("Выберите разные города.") }
        let geocoder = CLGeocoder()
        guard let start = try await geocoder.geocodeAddressString("\(from), Казахстан").first?.location,
              let end = try await geocoder.geocodeAddressString("\(to), Казахстан").first?.location else { throw ParcelError.invalid("Не удалось найти город.") }
        let request = MKDirections.Request(); request.source = MKMapItem(placemark: MKPlacemark(coordinate: start.coordinate)); request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end.coordinate)); request.transportType = .automobile
        let response = try await MKDirections(request: request).calculate()
        guard let route = response.routes.first else { throw ParcelError.invalid("Автомобильный маршрут недоступен.") }
        return (route.distance / 1000).rounded(.up)
    }
}

extension AppStore {
    func photoData(_ path: String) async throws -> Data { try await Storage.storage().reference(withPath: path).data(maxSize: 5 * 1024 * 1024) }
}

extension AppStore {
    func syncToken() async {
        guard isConfigured, !demo, profile != nil else { return }
        if let token = try? await Messaging.messaging().token() { try? await saveToken(token) }
    }
}
