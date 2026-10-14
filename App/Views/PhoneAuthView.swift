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
    enum Mode { case login, register, reset }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                modeButton("Вход", .login, "person.crop.circle")
                modeButton("Регистрация", .register, "person.badge.plus")
            }
            Button(mode == .reset ? "Восстановление пароля" : "Забыли пароль?") { mode = .reset }
                .font(.subheadline).accessibilityIdentifier("authRecovery")
                .accessibilityAddTraits(mode == .reset ? .isSelected : [])
            if mode == .reset {
                Text("Подтвердите номер кодом и задайте новый пароль.").font(.callout).foregroundStyle(.secondary)
            }
            TextField("Номер телефона +7", text: $phone).keyboardType(.phonePad).textContentType(.telephoneNumber).disabled(auth.verificationID != nil)
            SecureField(mode == .login ? "Пароль" : "Новый пароль: минимум 6 символов", text: $password).textContentType(mode == .login ? .password : .newPassword)
            if mode != .login {
                SecureField("Повторите пароль", text: $repeated).textContentType(.newPassword)
                Text("От 6 до 128 символов. Пробелы разрешены.").font(.caption).foregroundStyle(.secondary)
            }
            if mode == .register {
                TextField("Ваше имя", text: $name).textContentType(.name)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Для чего вам Jol?").font(.headline)
                    roleCard(.sender, title: "Отправитель", subtitle: "Отправлять посылки и выбирать перевозчиков", icon: "shippingbox")
                    roleCard(.courier, title: "Перевозчик", subtitle: "Публиковать поездки и брать заказы по пути", icon: "car.side")
                    Text("Выберите роль для этого аккаунта.").font(.caption).foregroundStyle(.secondary)
                }
                if role == .courier { TextField("Автомобиль", text: $vehicle); TextField("Грузоподъёмность, кг", text: $capacity).keyboardType(.decimalPad) }
                if !LocalBackend.enabled { DisclosureGroup("У меня уже есть аккаунт с email") {
                    Text("Подтвердите прежний аккаунт, затем привяжите номер через SMS. Заказы сохранятся.").font(.caption)
                    TextField("Прежний email", text: $legacyEmail).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Прежний пароль", text: $legacyPassword)
                    Button(migrating ? "Прежний аккаунт подтверждён" : "Подтвердить прежний аккаунт") {
                        Task { await store.perform { try await auth.prepareMigration(email: legacyEmail, password: legacyPassword); migrating = true; legacyPassword = "" } }
                    }.disabled(store.busy || migrating)
                }
                }
                Toggle(LocalBackend.enabled ? "Использую только тестовые данные" : "Принимаю условия сервиса и обработку данных", isOn: $consent).font(.caption)
                NavigationLink("Условия и данные") { ServiceInfoView() }
            }
            if mode != .login {
                #if JOL_LOCAL_SERVER
                Text("Тестовый номер: используйте вымышленный +7XXXXXXXXXX. SMS не отправляется; код появится здесь.").font(.caption).foregroundStyle(.secondary)
                if let localCode = auth.localCode {
                    Label("Тестовый код: \(localCode)", systemImage: "testtube.2").monospacedDigit()
                    Button("Подставить тестовый код") { code = localCode }
                }
                #else
                Text("Для подтверждения номера придёт SMS. Возможна оплата по тарифу оператора.").font(.caption).foregroundStyle(.secondary)
                #endif
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
    private func modeButton(_ title: String, _ value: Mode, _ icon: String) -> some View {
        Button { AppKeyboard.dismiss(); mode = value } label: {
            Label(title, systemImage: icon).font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(mode == value ? Theme.green.opacity(0.12) : Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(mode == value ? Theme.green : Color.secondary.opacity(0.25), lineWidth: mode == value ? 2 : 1) }
        }.buttonStyle(.plain).foregroundStyle(mode == value ? Theme.green : Color.primary)
            .accessibilityAddTraits(mode == value ? .isSelected : [])
    }
    private func roleCard(_ value: Role, title: String, subtitle: String, icon: String) -> some View {
        Button { AppKeyboard.dismiss(); role = value } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.title2).foregroundStyle(Theme.green).frame(width: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundStyle(Color.primary)
                    Text(subtitle).font(.caption).foregroundStyle(Color.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: role == value ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(role == value ? Theme.green : Color.secondary)
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(role == value ? Theme.green.opacity(0.08) : Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(role == value ? Theme.green : Color.secondary.opacity(0.25), lineWidth: role == value ? 2 : 1) }
        }.buttonStyle(.plain).accessibilityElement(children: .combine)
            .accessibilityAddTraits(role == value ? .isSelected : [])
    }
    func validateNewPassword() throws {
        guard password.unicodeScalars.count >= 6, password.unicodeScalars.count <= 128, password.utf8.count <= 512 else { throw ParcelError.invalid("Пароль: от 6 до 128 символов.") }
        guard password == repeated else { throw ParcelError.invalid("Пароли не совпадают.") }
        if mode == .register && !migrating {
            let p = Profile(id: "new", name: name, phone: try PhoneAuthService.normalizedPhone(phone), role: role, vehicle: vehicle, capacityKg: Double(capacity.replacingOccurrences(of: ",", with: ".")) ?? 0)
            try Validation.profile(p)
        }
    }
}
