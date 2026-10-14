import Foundation
import FirebaseAuth
import FirebaseCore

@MainActor @Observable final class PhoneAuthService {
    var verificationID: String?
    var verifiedPhone = ""
    var resendAfter = Date.distantPast
    var migrating = false
    #if JOL_LOCAL_SERVER
    var localCode: String?
    #endif
    static func normalizedPhone(_ raw: String) throws -> String {
        let digits = raw.filter(\.isNumber)
        let normalized: String
        if digits.count == 11 && (digits.first == "7" || digits.first == "8") { normalized = "+7" + digits.dropFirst() }
        else if digits.count == 10 { normalized = "+7" + digits }
        else { normalized = "+" + digits }
        guard Validation.validPhone(normalized) else { throw ParcelError.invalid("Введите номер +7XXXXXXXXXX.") }
        return normalized
    }
    func sendCode(phone: String) async throws {
        guard Date() >= resendAfter else { throw ParcelError.invalid("Повторный код можно запросить через минуту.") }
        let normalized = try Self.normalizedPhone(phone)
        #if JOL_LOCAL_SERVER
        do { try await LocalBackend.checkConnection() }
        catch { throw ParcelError.invalid(LocalBackend.connectionHelp) }
        #endif
        // Firebase raises an exception for a missing callback scheme; show a recoverable error first.
        let schemes = (Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? [])
            .flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        guard let options = FirebaseApp.app()?.options else { throw ParcelError.invalid("Firebase ещё не подключён.") }
        let appScheme = "app-" + options.googleAppID.replacingOccurrences(of: ":", with: "-")
        let clientScheme = options.clientID?.components(separatedBy: ".").reversed().joined(separator: ".")
        guard schemes.contains(appScheme) || clientScheme.map({ schemes.contains($0) }) == true else {
            throw ParcelError.invalid("SMS-вход ещё не настроен в этой сборке. Добавьте URL-схему Firebase из инструкции подключения.")
        }
        Auth.auth().languageCode = "ru"
        let id = try await PhoneAuthProvider.provider().verifyPhoneNumber(normalized, uiDelegate: nil)
        verificationID = id; verifiedPhone = normalized; resendAfter = Date().addingTimeInterval(60)
        #if JOL_LOCAL_SERVER
        localCode = try? await LocalBackend.testCode(phone: normalized, session: id)
        #endif
    }
    func prove(code: String) async throws {
        guard let verificationID, code.count == 6, code.allSatisfy(\.isNumber) else { throw ParcelError.invalid("Введите шестизначный SMS-код.") }
        let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: code)
        if migrating, let current = Auth.auth().currentUser {
            if !current.providerData.contains(where: { $0.providerID == "phone" }) { _ = try await current.link(with: credential) }
            _ = try await current.reauthenticate(with: credential)
        } else { _ = try await Auth.auth().signIn(with: credential) }
        // A phone proof has no marketplace permissions; the server separately completes registration/reset.
        _ = try await Auth.auth().currentUser?.getIDToken(forcingRefresh: true)
    }
    func prepareMigration(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password); migrating = true
    }
    func clearProof() {
        verificationID = nil; verifiedPhone = ""; migrating = false
        #if JOL_LOCAL_SERVER
        localCode = nil
        #endif
    }
}

extension AppStore {
    func loginPhone(phone: String, password: String) async throws {
        demo = false
        let number = try PhoneAuthService.normalizedPhone(phone)
        guard let data = try await call("loginPhonePassword", data: ["phone": number, "password": password]) as? [String: Any], let token = data["token"] as? String else { throw ParcelError.invalid("Не удалось открыть сессию.") }
        _ = try await Auth.auth().signIn(withCustomToken: token)
        await loadAuthenticatedUser()
    }
    func finishPhoneRegistration(password: String, name: String, role: Role, vehicle: String, capacity: Double) async throws {
        guard let data = try await call("registerPhone", data: ["password": password, "name": name, "role": role.rawValue, "vehicle": vehicle, "capacityKg": capacity]) as? [String: Any], let token = data["token"] as? String else { throw ParcelError.invalid("Не удалось завершить регистрацию.") }
        _ = try await Auth.auth().signIn(withCustomToken: token)
        await loadAuthenticatedUser()
    }
    func resetPhonePassword(phone: String, password: String) async throws {
        _ = try await call("resetPhonePassword", data: ["password": password])
        try Auth.auth().signOut()
        try await loginPhone(phone: phone, password: password)
    }
    func loadAuthenticatedUser() async {
        guard isConfigured, !demo else { return }
        let generation = UUID(); authLoadGeneration = generation
        guard let user = Auth.auth().currentUser else { stopListeners(); profile = nil; orders = []; authReady = true; return }
        do {
            let result = try await user.getIDTokenResult()
            guard !demo, authLoadGeneration == generation, Auth.auth().currentUser?.uid == user.uid else { return }
            guard result.claims["jolSession"] is String, result.signInProvider == "custom" else {
                stopListeners(); profile = nil; orders = []; authReady = true; return
            }
            try await loadFullProfile(uid: user.uid, generation: generation)
        } catch {
            guard !demo, authLoadGeneration == generation, Auth.auth().currentUser?.uid == user.uid else { return }
            stopListeners(); profile = nil; orders = []
            self.error = "Не удалось загрузить аккаунт. Проверьте сеть или войдите заново."
        }
        if authLoadGeneration == generation { authReady = true }
    }
}
