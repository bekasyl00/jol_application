import Foundation
import Network
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import FirebaseStorage
import FirebaseAppCheck

enum LocalBackend {
    static var enabled: Bool {
        #if JOL_LOCAL_SERVER
        true
        #else
        false
        #endif
    }
    #if JOL_LOCAL_SERVER
    static let projectID = "demo-jol"
    static let host = Bundle.main.object(forInfoDictionaryKey: "JOL_EMULATOR_HOST") as? String ?? ""
    static var configurationError: String?
    static let connectionHelp = "Нет связи с Mac. Запустите сервер Jol, подключите iPhone и Mac к одной Wi-Fi сети и разрешите приложению доступ к локальной сети. Адрес Mac: \(host)."

    static func connectionMessage(for error: Error) -> String {
        if let configurationError { return configurationError }
        let failure = error as NSError
        guard failure.domain == NSURLErrorDomain else { return error.localizedDescription }
        let advice: String
        switch failure.code {
        case URLError.timedOut.rawValue:
            advice = "Mac не ответил вовремя. Дождитесь запуска сервера и повторите проверку."
        case URLError.notConnectedToInternet.rawValue, URLError.dataNotAllowed.rawValue:
            advice = "iOS сообщает, что сеть недоступна для приложения. Проверьте Wi-Fi и доступ Jol Local к локальной сети в настройках iPhone. Если доступ уже включён, выключите и включите его, затем повторите проверку."
        case URLError.cannotConnectToHost.rawValue, URLError.cannotFindHost.rawValue:
            advice = "Не удалось подключиться к серверу. Проверьте Wi-Fi на обоих устройствах и запущен ли сервер на Mac."
        case URLError.appTransportSecurityRequiresSecureConnection.rawValue:
            advice = "Эта сборка блокирует локальное соединение. Обновите Jol Local через Xcode."
        default:
            advice = "Сетевое соединение прервалось. Повторите проверку."
        }
        return "\(advice)\nАдрес Mac: \(host). Код сети: \(failure.code)."
    }

    static func configure() {
        guard DevelopmentServerAddress.isAllowed(host) else {
            configurationError = "Адрес локального сервера не настроен. Запустите сервер на Mac и заново соберите JolParcelLocal."
            return
        }
        // Deliberately fictitious Firebase identifiers; no real project config is loaded.
        let options = FirebaseOptions(googleAppID: "1:1234567890:ios:0000000000000000000000", gcmSenderID: "1234567890")
        // Installations validates the key's shape even with Messaging auto-init disabled.
        options.apiKey = "A" + String(repeating: "0", count: 38)
        options.projectID = projectID
        options.storageBucket = "demo-jol.appspot.com"
        options.bundleID = Bundle.main.bundleIdentifier!
        AppCheck.setAppCheckProviderFactory(LocalAppCheckFactory())
        FirebaseApp.configure(options: options)
        AppCheck.appCheck().isTokenAutoRefreshEnabled = false
        Auth.auth().useEmulator(withHost: host, port: 9099)
        let firestore = Firestore.firestore()
        let settings = firestore.settings
        settings.host = "\(host):8080"
        settings.cacheSettings = MemoryCacheSettings()
        // The local Firestore emulator serves plaintext gRPC, including over the validated LAN host.
        // useEmulator sets the host but does not disable TLS in the Apple SDK.
        settings.isSSLEnabled = false
        firestore.settings = settings
        let functions = Functions.functions(region: "europe-west1")
        functions.useEmulator(withHost: host, port: 5001)
        // Firebase's debug-only opt-in for physical devices on a trusted LAN.
        // This entire setup is compiled only for Local, with a fictitious project and validated host.
        functions.allowInsecureTokenAttachment = true
        Storage.storage().useEmulator(withHost: host, port: 9199)
        // A developer can verify the physical device's network without entering account data.
        if ProcessInfo.processInfo.arguments.contains("--check-local-server") {
            Task {
                do { try await checkConnection(); NSLog("Jol Local connection check: available") }
                catch { NSLog("Jol Local connection check failed: %@", connectionMessage(for: error)) }
            }
        }
    }

    private struct Codes: Decodable {
        struct Code: Decodable { let phoneNumber: String; let sessionInfo: String; let code: String }
        let verificationCodes: [Code]
    }
    static func testCode(phone: String, session: String) async throws -> String? {
        let data = try await request(port: 9099, path: "/emulator/v1/projects/\(projectID)/verificationCodes")
        return try JSONDecoder().decode(Codes.self, from: data).verificationCodes
            .first { $0.phoneNumber == phone && $0.sessionInfo == session }?.code
    }
    static func checkConnection() async throws {
        // Verify every service, including Functions, without reading account data.
        let data = try await request(port: 5001, path: "/\(projectID)/europe-west1/localHealth")
        guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any], response["project"] as? String == projectID else {
            throw ParcelError.invalid("По адресу Mac ответил другой сервис. Перезапустите сервер Jol Local.")
        }
    }
    private static func request(port: Int, path: String) async throws -> Data {
        guard DevelopmentServerAddress.isAllowed(host), let url = URL(string: "http://\(host):\(port)\(path)") else { throw ParcelError.invalid(connectionHelp) }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "GET"
        let data: Data
        let response: URLResponse
        do { (data, response) = try await URLSession.shared.data(for: request) }
        catch {
            let failure = error as NSError
            // Never log response bodies, passwords, SMS codes or authentication tokens.
            NSLog("Jol Local network failure: %@ %ld", failure.domain, failure.code)
            if failure.domain == NSURLErrorDomain && failure.code == URLError.notConnectedToInternet.rawValue {
                let route = await LocalNetworkProbe(host: host, port: port).check()
                NSLog("Jol Local TCP route: %@", route)
                if route == "localNetworkDenied" {
                    throw ParcelError.invalid("iOS блокирует Jol Local: доступ к локальной сети запрещён. Если переключатель уже включён и его повторное включение не помогло, перезагрузите iPhone и проверьте снова. Код сети: −1009 / localNetworkDenied.")
                }
            }
            throw error
        }
        guard let http = response as? HTTPURLResponse else { throw ParcelError.invalid("Сервер вернул ответ в неподдерживаемом формате.") }
        guard http.statusCode == 200 else {
            throw ParcelError.invalid("Mac доступен, но сервер Jol ещё не готов. Повторите проверку после запуска всех сервисов. Код сервера: \(http.statusCode).")
        }
        return data
    }
    #endif
}

#if JOL_LOCAL_SERVER
// Queue-confined one-shot TCP probe; inspects the public Network framework's route reason.
private final class LocalNetworkProbe: @unchecked Sendable {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "kz.jol.local-network-check")
    private var continuation: CheckedContinuation<String, Never>?
    init(host: String, port: Int) {
        connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: UInt16(port))!, using: .tcp)
    }
    func check() async -> String {
        await withCheckedContinuation { result in
            queue.async {
                self.continuation = result
                self.connection.stateUpdateHandler = { [weak self] state in
                    guard let self else { return }
                    switch state {
                    case .ready: self.finish("available")
                    case .waiting, .failed:
                        let reason: String
                        switch self.connection.currentPath?.unsatisfiedReason {
                        case .localNetworkDenied: reason = "localNetworkDenied"
                        case .wifiDenied: reason = "wifiDenied"
                        case .cellularDenied: reason = "cellularDenied"
                        case .notAvailable: reason = "notAvailable"
                        default: reason = "unavailable"
                        }
                        self.finish(reason)
                    default: break
                    }
                }
                self.connection.start(queue: self.queue)
                self.queue.asyncAfter(deadline: .now() + 3) { self.finish("timedOut") }
            }
        }
    }
    private func finish(_ status: String) {
        guard let continuation else { return }
        self.continuation = nil
        connection.stateUpdateHandler = nil
        connection.cancel()
        continuation.resume(returning: status)
    }
}

// An offline provider prevents the SDK from contacting App Attest/App Check servers.
private final class LocalAppCheckFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? { LocalAppCheckProvider() }
}
private final class LocalAppCheckProvider: NSObject, AppCheckProvider {
    func getToken(completion: @escaping (AppCheckToken?, Error?) -> Void) {
        completion(nil, NSError(domain: "JolLocalAppCheck", code: 1, userInfo: [NSLocalizedDescriptionKey: "App Check is disabled only for the local demo project."]))
    }
}
#endif
