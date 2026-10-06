import SwiftUI
import PhotosUI
import MapKit

struct CreateDeliveryView: View {
    @Environment(AppStore.self) private var store
    @State private var from = "Алматы"
    @State private var to = "Астана"
    @State private var addressFrom = ""
    @State private var addressTo = ""
    @State private var recipient = ""
    @State private var phone = ""
    @State private var description = ""
    @State private var comment = ""
    @State private var size = ParcelSize.box
    @State private var weight = "10"
    @State private var volume = "0.06"
    @State private var distance: Double?
    @State private var calculating = false
    @State private var price = ""
    @State private var pickup = Date().addingTimeInterval(3600)
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photo: Data?
    @State private var success = false
    @State private var manualDistance = ""
    var routeKey: String { "\(from)|\(to)" }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Передайте посылку\nтому, кто едет по пути.").font(.title2.bold())
                    Text("Укажите маршрут и вещь — рассчитаем ориентир стоимости.").font(.callout).foregroundStyle(.secondary)
                }
                Section("01 / Маршрут") {
                    Picker("Откуда", selection: $from) { ForEach(kazakhstanCities, id: \.self) { Text($0).tag($0) } }
                    TextField("Адрес передачи", text: $addressFrom)
                    Picker("Куда", selection: $to) { ForEach(kazakhstanCities, id: \.self) { Text($0).tag($0) } }
                    TextField("Адрес получения", text: $addressTo)
                    DatePicker("Когда передать", selection: $pickup, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    Button { Task { await calculate() } } label: { HStack { Label("Рассчитать маршрут", systemImage: "map"); Spacer(); if calculating { ProgressView() } } }.disabled(calculating || from == to)
                    if let distance { Text("Автомобильный маршрут: \(Int(distance)) км").foregroundStyle(.secondary) }
                    if store.demo {
                        TextField("Демо: расстояние вручную, км", text: $manualDistance).keyboardType(.decimalPad)
                        Button("Использовать деморасстояние") { distance = Double(manualDistance); updatePrice() }
                    }
                }
                Section("02 / Посылка") {
                    HStack { ForEach(ParcelSize.allCases) { option in
                        Button { size = option; weight = String(option.weight); volume = String(option.volume); updatePrice() } label: { VStack(spacing: 8) { Image(systemName: option.symbol).font(.title2); Text(option.title).font(.caption) }.frame(maxWidth: .infinity).padding(.vertical, 12).background(size == option ? Theme.green.opacity(0.12) : Theme.background, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(size == option ? Theme.green : .secondary) }.buttonStyle(.plain)
                    } }
                    TextField("Что отправляете?", text: $description, axis: .vertical)
                    HStack { Text("Вес, кг"); Spacer(); TextField("10", text: $weight).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("Объём, м³"); Spacer(); TextField("0.06", text: $volume).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }.onChange(of: volume) { updatePrice() }
                    PhotosPicker(selection: $selectedPhoto, matching: .images) { Label(photo == nil ? "Добавить фото" : "Фото добавлено", systemImage: "photo") }.disabled(store.demo)
                    if let photo, let uiImage = UIImage(data: photo) { Image(uiImage: uiImage).resizable().scaledToFit().frame(maxHeight: 160); Button("Убрать фото", role: .destructive) { self.photo = nil; selectedPhoto = nil } }
                    TextField("Хрупкость, упаковка, условия", text: $comment, axis: .vertical)
                }
                Section("03 / Получатель") { TextField("Имя получателя", text: $recipient); TextField("Телефон +7XXXXXXXXXX", text: $phone).keyboardType(.phonePad) }
                Section("04 / Стоимость") {
                    HStack { Text("Предложение, ₸").font(.headline); Spacer(); TextField("Рассчитайте маршрут", text: $price).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                    Text("Можно изменить цену. Тариф: 1 000 ₸ + 8 ₸/км + 5 000 ₸/м³. Оплата перевозчику по договорённости.").font(.caption).foregroundStyle(.secondary)
                    Button("Опубликовать отправление") { Task { await store.perform { try await submit() } } }.buttonStyle(.borderedProminent).controlSize(.large).disabled(store.busy || distance == nil || calculating)
                }
            }.navigationTitle("Отправить посылку")
            .onChange(of: routeKey) { distance = nil; price = "" }
            .task(id: routeKey) { if !store.demo { await calculate() } }
            .onChange(of: selectedPhoto) {
                Task {
                    guard let selectedPhoto else { return }
                    do {
                        guard let data = try await selectedPhoto.loadTransferable(type: Data.self), let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.65), jpeg.count <= 5 * 1024 * 1024 else { throw ParcelError.invalid("Выберите фото размером до 5 МБ.") }
                        photo = jpeg
                    } catch { store.error = error.localizedDescription }
                }
            }
            .alert("Отправление опубликовано", isPresented: $success) { Button("Готово") {} } message: { Text("Перевозчики увидят заказ в ленте. Следите за ним во вкладке «Отправления».") }
        }
    }
    func updatePrice() { if let distance, let volume = Double(volume.replacingOccurrences(of: ",", with: ".")), let value = try? Pricing.quote(distanceKm: distance, volume: volume) { price = String(value) } }
    func calculate() async {
        calculating = true; defer { calculating = false }
        let original = routeKey
        do { let value = try await RouteService.distance(from: from, to: to); guard original == routeKey, !Task.isCancelled else { return }; distance = value; updatePrice() }
        catch { guard !Task.isCancelled, original == routeKey else { return }; store.error = "MapKit не вернул автомобильный маршрут. Попробуйте позже. В деморежиме можно ввести расстояние вручную." }
    }
    func submit() async throws {
        guard let p = store.profile, let distance else { throw ParcelError.invalid("Сначала рассчитайте маршрут.") }
        let d = Delivery(senderId: p.id, fromCity: from, toCity: to, itemDescription: description, size: size, weight: Double(weight.replacingOccurrences(of: ",", with: ".")) ?? 0, volume: Double(volume.replacingOccurrences(of: ",", with: ".")) ?? 0, distanceKm: distance, price: Int(price) ?? 0, pickupAt: pickup)
        let details = DeliveryDetails(addressFrom: addressFrom, addressTo: addressTo, recipientName: recipient, recipientPhone: phone, comment: comment)
        try await store.create(d, details: details, photo: photo)
        description = ""; comment = ""; selectedPhoto = nil; photo = nil; success = true
    }
}
