import SwiftUI
import FirebaseAuth

 enum Theme {
    static let green = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.38, green: 0.82, blue: 0.64, alpha: 1)
            : UIColor(red: 0.08, green: 0.37, blue: 0.27, alpha: 1)
    })
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
 }
struct RootView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        @Bindable var store = store
        Group {
            if !store.authReady { ProgressView("Загрузка…") }
            else if store.profile != nil {
                TabView {
                    OrdersView().tabItem { Label(store.profile?.role == .courier ? "Заказы по пути" : "Отправления", systemImage: "shippingbox") }
                    if store.profile?.role == .sender && !store.deletionPending { CreateDeliveryView().tabItem { Label("Отправить", systemImage: "plus.circle.fill") } }
                    ProfileView().tabItem { Label("Профиль", systemImage: "person.crop.circle") }
                }
            } else { AuthView() }
        }
        .alert("Не удалось выполнить действие", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("Понятно") { store.error = nil } } message: { Text(store.error ?? "") }
        .onReceive(NotificationCenter.default.publisher(for: .init("FCMToken"))) { event in
            if let token = event.object as? String { Task { try? await store.saveToken(token) } }
        }
    }
}
struct AuthView: View {
    @Environment(AppStore.self) private var store
    @State private var registering = false
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var phone = ""
    @State private var role = Role.sender
    @State private var vehicle = ""
    @State private var capacity = "50"
    @State private var consent = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack { Image(systemName: "arrow.up.right.circle.fill").font(.largeTitle); Text("jol").font(.system(size: 44, weight: .bold, design: .rounded)); Text("ПОСЫЛКИ ПО ПУТИ").font(.caption).tracking(2) }.foregroundStyle(Theme.green)
                    Text("Другой город.\nБлиже, чем кажется.").font(.system(size: 36, weight: .bold)).tracking(-1)
                    Text("Отправляйте вещи с теми, кто уже едет. Между городами Казахстана.").foregroundStyle(.secondary)
                    if store.isConfigured {
                        Picker("Аккаунт", selection: $registering) { Text("Войти").tag(false); Text("Регистрация").tag(true) }.pickerStyle(.segmented)
                        VStack(spacing: 14) {
                            TextField("Электронная почта", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                            SecureField("Пароль", text: $password).textContentType(registering ? .newPassword : .password)
                            if registering {
                                TextField("Ваше имя", text: $name)
                                TextField("Телефон +7XXXXXXXXXX", text: $phone).keyboardType(.phonePad)
                                Picker("Я хочу", selection: $role) { Text("Отправлять").tag(Role.sender); Text("Перевозить").tag(Role.courier) }.pickerStyle(.segmented)
                                if role == .courier { TextField("Автомобиль", text: $vehicle); TextField("Грузоподъёмность, кг", text: $capacity).keyboardType(.decimalPad) }
                            }
                        }.textFieldStyle(.roundedBorder)
                        if registering {
                            Toggle("Принимаю условия сервиса и обработку данных", isOn: $consent).font(.caption)
                            NavigationLink("Условия и данные") { ServiceInfoView() }
                        } else {
                            Button("Восстановить пароль") {
                                Task { await store.perform {
                                    guard !email.isEmpty else { throw ParcelError.invalid("Введите электронную почту.") }
                                    try await Auth.auth().sendPasswordReset(withEmail: email)
                                } }
                            }.font(.caption)
                        }
                        Button(registering ? "Создать аккаунт" : "Войти") {
                            Task { await store.perform {
                                if registering { try await store.register(email: email, password: password, name: name, phone: phone, role: role, vehicle: vehicle, capacity: Double(capacity) ?? 0) }
                                else { try await store.login(email: email, password: password) }
                            } }
                        }.buttonStyle(.borderedProminent).controlSize(.large).disabled(store.busy || (registering && !consent))
                    } else { Text("Firebase ещё не подключён. Проверьте сценарии в локальном деморежиме.").font(.callout).padding().background(Theme.surface, in: RoundedRectangle(cornerRadius: 16)) }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Попробовать на этом устройстве").font(.headline)
                        HStack { demoButton("Отправитель", .sender); demoButton("Перевозчик", .courier) }
                        Text("Демо хранит данные локально. В профиле можно сменить роль и пройти весь путь посылки.").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(24)
            }.background(Theme.background)
        }
    }
    func demoButton(_ label: String, _ role: Role) -> some View {
        Button(label) { Task { await store.perform { try await store.enterDemo(role: role) } } }.buttonStyle(.bordered).disabled(store.busy)
    }
}
struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @State private var deleting = false
    @State private var deletePassword = ""
    var body: some View {
        NavigationStack {
            List {
                if let p = store.profile {
                    Section { Label(p.name, systemImage: "person.crop.circle.fill").font(.title2.bold()); Text(p.phone); Text(p.role == .sender ? "Отправитель" : "Перевозчик"); if p.role == .courier { Text("\(p.vehicle) · до \(Int(p.capacityKg)) кг") } }
                    Section("Доставки") {
                        let done = store.orders.filter { ($0.senderId == p.id || $0.driverId == p.id) && $0.status == .delivered }
                        LabeledContent("Завершено", value: "\(done.count)")
                        if p.role == .courier { LabeledContent("Доход по заказам", value: "\(done.reduce(0) { $0 + $1.price }) ₸"); Text("Комиссия MVP — 0%. Оплата наличными или переводом по договорённости.").font(.caption) }
                    }
                }
                Section {
                    Button("Включить уведомления", systemImage: "bell") { Task { await store.perform { try await store.enableNotifications() } } }
                    if store.demo { Button("Сменить демороль", systemImage: "arrow.triangle.2.circlepath") { Task { await store.perform { try await store.enterDemo(role: store.profile?.role == .sender ? .courier : .sender) } } } }
                    NavigationLink("О сервисе и помощи") { ServiceInfoView() }
                    Button("Выйти") { Task { await store.perform { try await store.logout() } } }
                    Button("Удалить аккаунт", role: .destructive) { deleting = true }
                }
            }.navigationTitle("Профиль").disabled(store.busy)
            .alert("Удалить аккаунт и связанные личные данные?", isPresented: $deleting) { if !store.demo { SecureField("Текущий пароль", text: $deletePassword) }; Button("Удалить аккаунт", role: .destructive) { Task { await store.perform { try await store.deleteAccount(password: deletePassword) } } }; Button("Назад", role: .cancel) {} } message: { Text("Действие необратимо. Сначала завершите или отмените активные доставки.") }
        }
    }
}

struct ServiceInfoView: View {
    var body: some View {
        List {
            Section("Jol — доставка по пути") {
                Text("Перед передачей вещи согласуйте упаковку, стоимость и место встречи в чате. Не передавайте запрещённые или опасные грузы.")
                Text("Наличные или перевод по договорённости. Приложение не принимает платежи; комиссия MVP — 0%.")
            }
            Section("Данные") {
                Text("Профиль содержит имя, телефон, email и сведения об автомобиле. В заказе сохраняются маршрут, адреса, контакты получателя, описание, фото и чат. Адреса и телефоны видят участники заказа. Удаление аккаунта доступно в профиле после завершения или отмены активных доставок.")
                configuredLink("Политика конфиденциальности", "PrivacyPolicyURL")
                configuredLink("Условия сервиса", "TermsURL")
            }
            Section("Поддержка") {
                configuredLink("Связаться с поддержкой", "SupportURL")
                Text("До настройки ссылок это сборка для проверки сценариев. Деморежим хранит данные на устройстве и не организует реальные перевозки.").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("О сервисе")
    }
    @ViewBuilder func configuredLink(_ title: String, _ key: String) -> some View {
        if let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String, let url = URL(string: raw), url.scheme == "https", url.host != nil { Link(title, destination: url) }
        else { Text("\(title): оператор ещё не добавил ссылку").font(.caption).foregroundStyle(.secondary) }
    }
}
