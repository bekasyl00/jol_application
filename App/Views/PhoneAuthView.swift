import SwiftUI

struct PhoneAuthForm: View {
    @Environment(AppStore.self) private var store
    @State private var mode = Mode.login
    @State private var auth = PhoneAuthService()
    @State private var phone = ""
    @State private var password = ""
    @State private var repeated = ""
    @State private var code = ""
    @State private var name = ""
    @State private var role = Role.sender
    @State private var vehicle = ""
    @State private var capacity = "50"
    @State private var consent = false
    @State private var legacyEmail = ""
    @State private var legacyPassword = ""
    @State private var migrating = false
    enum Mode: String, CaseIterable { case login = "Войти", register = "Регистрация", reset = "Восстановление" }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Аккаунт", selection: $mode) { ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu)
            TextField("Номер телефона +7", text: $phone).keyboardType(.phonePad).textContentType(.telephoneNumber).disabled(auth.verificationID != nil)
            SecureField(mode == .login ? "Пароль" : "Новый пароль: минимум 15 символов", text: $password).textContentType(mode == .login ? .password : .newPassword)
            if mode != .login {
                SecureField("Повторите пароль", text: $repeated).textContentType(.newPassword)
                Text("От 15 до 128 символов. Можно использовать длинную фразу; пробелы разрешены.").font(.caption).foregroundStyle(.secondary)
            }
            if mode == .register {
                TextField("Ваше имя", text: $name).textContentType(.name)
                Picker("Я хочу", selection: $role) { Text("Отправлять").tag(Role.sender); Text("Перевозить").tag(Role.courier) }.pickerStyle(.segmented)
                if role == .courier { TextField("Автомобиль", text: $vehicle); TextField("Грузоподъёмность, кг", text: $capacity).keyboardType(.decimalPad) }
                DisclosureGroup("У меня уже есть аккаунт с email") {
                    Text("Подтвердите прежний аккаунт, затем привяжите номер через SMS. Заказы сохранятся.").font(.caption)
                    TextField("Прежний email", text: $legacyEmail).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Прежний пароль", text: $legacyPassword)
                    Button(migrating ? "Прежний аккаунт подтверждён" : "Подтвердить прежний аккаунт") {
                        Task { await store.perform { try await auth.prepareMigration(email: legacyEmail, password: legacyPassword); migrating = true; legacyPassword = "" } }
                    }.disabled(store.busy || migrating)
                }
                Toggle("Принимаю условия сервиса и обработку данных", isOn: $consent).font(.caption)
                NavigationLink("Условия и данные") { ServiceInfoView() }
            }
            if mode != .login {
                Text("Для подтверждения номера придёт SMS. Возможна оплата по тарифу оператора.").font(.caption).foregroundStyle(.secondary)
                if auth.verificationID != nil {
                    TextField("Код из SMS", text: $code).keyboardType(.numberPad).textContentType(.oneTimeCode)
                    Button("Изменить номер") { auth.clearProof(); code = ""; migrating = false }
                }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let seconds = max(0, Int(auth.resendAfter.timeIntervalSince(context.date).rounded(.up)))
                    Button(seconds > 0 ? "Повторный код через \(seconds) с" : (auth.verificationID == nil ? "Получить SMS-код" : "Отправить код ещё раз")) {
                        Task { await store.perform { try validateNewPassword(); try await auth.sendCode(phone: phone) } }
                    }.disabled(store.busy || seconds > 0 || (mode == .register && !consent))
                }
            }
            Button(mode == .login ? "Войти" : mode == .reset ? "Сохранить пароль и войти" : "Завершить регистрацию") {
                Task { await store.perform {
                    if mode == .login { try await store.loginPhone(phone: phone, password: password) }
                    else {
                        try validateNewPassword(); try await auth.prove(code: code)
                        if mode == .register { try await store.finishPhoneRegistration(password: password, name: name, role: role, vehicle: vehicle, capacity: Double(capacity.replacingOccurrences(of: ",", with: ".")) ?? 0) }
                        else { try await store.resetPhonePassword(phone: phone, password: password) }
                    }
                    password = ""; repeated = ""; code = ""; auth.clearProof()
                } }
            }.buttonStyle(.borderedProminent).foregroundStyle(Theme.onAccent).controlSize(.large).disabled(store.busy || (mode != .login && auth.verificationID == nil) || (mode == .register && !consent))
            if store.busy { ProgressView() }
        }.textFieldStyle(.roundedBorder).disabled(store.busy)
            .onChange(of: mode) { auth.clearProof(); code = ""; password = ""; repeated = ""; migrating = false }
    }
    func validateNewPassword() throws {
        guard password.unicodeScalars.count >= 15, password.unicodeScalars.count <= 128, password.utf8.count <= 512 else { throw ParcelError.invalid("Пароль: от 15 до 128 символов.") }
        guard password == repeated else { throw ParcelError.invalid("Пароли не совпадают.") }
        if mode == .register && !migrating {
            let p = Profile(id: "new", name: name, phone: try PhoneAuthService.normalizedPhone(phone), role: role, vehicle: vehicle, capacityKg: Double(capacity.replacingOccurrences(of: ",", with: ".")) ?? 0)
            try Validation.profile(p)
        }
    }
}
