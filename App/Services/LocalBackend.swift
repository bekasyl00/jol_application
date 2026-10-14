import Foundation
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
            throw ParcelError.invalid(connectionHelp)
        }
    }
    private static func request(port: Int, path: String) async throws -> Data {
        guard DevelopmentServerAddress.isAllowed(host), let url = URL(string: "http://\(host):\(port)\(path)") else { throw ParcelError.invalid(connectionHelp) }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        request.httpMethod = "GET"
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ParcelError.invalid(connectionHelp) }
        return data
    }
    #endif
}

#if JOL_LOCAL_SERVER
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
