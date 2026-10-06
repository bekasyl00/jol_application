import SwiftUI

struct OrdersView: View {
    @Environment(AppStore.self) private var store
    @State private var from = "Все города"
    @State private var to = "Все города"
    @State private var dateFilter = false
    @State private var date = Date()
    @State private var mine = false
    var visible: [Delivery] {
        store.orders.filter { d in
            let owner = d.senderId == store.profile?.id || d.driverId == store.profile?.id
            return (!mine || owner) && (from == "Все города" || d.fromCity == from) && (to == "Все города" || d.toCity == to) && (!dateFilter || Calendar.current.isDate(d.pickupAt, inSameDayAs: date))
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack { Text("JOL / КАЗАХСТАН").font(.caption.bold()).tracking(2); Spacer(); if store.demo { Text("ДЕМО").font(.caption.bold()).padding(6).background(.white, in: Capsule()) } }.foregroundStyle(Theme.green)
                    Text(store.profile?.role == .courier ? "Вы едете.\nПосылка — с вами." : "Ваши вещи.\nНовый маршрут.").font(.system(size: 34, weight: .bold)).tracking(-1)
                    if store.profile?.role == .courier {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Мой маршрут").font(.headline)
                            HStack { cityPicker("Откуда", $from); Image(systemName: "arrow.right"); cityPicker("Куда", $to) }
                            Toggle("На определённую дату", isOn: $dateFilter)
                            if dateFilter { DatePicker("Дата поездки", selection: $date, displayedComponents: .date) }
                            Toggle("Только мои доставки", isOn: $mine)
                        }.padding().background(.white, in: RoundedRectangle(cornerRadius: 20))
                    }
                    HStack { Text(store.profile?.role == .courier ? "Подходящие отправления" : "Мои отправления").font(.headline); Spacer(); Text("\(visible.count)").foregroundStyle(.secondary) }
                    if visible.isEmpty { ContentUnavailableView("Пока нет отправлений", systemImage: "shippingbox", description: Text(store.profile?.role == .courier ? "Измените маршрут или вернитесь позже." : "Оформите первую посылку во вкладке «Отправить».")).padding(.vertical, 24) }
                    ForEach(visible) { d in NavigationLink { DeliveryDetailView(id: d.id) } label: { DeliveryCard(delivery: d) }.buttonStyle(.plain) }
                }.padding(22)
            }.background(Theme.background).navigationTitle(store.profile?.role == .courier ? "По пути" : "Отправления").navigationBarTitleDisplayMode(.inline)
            .refreshable { await store.refresh() }
            .task { await store.refresh() }
        }
    }
    func cityPicker(_ title: String, _ value: Binding<String>) -> some View { Picker(title, selection: value) { Text("Все города").tag("Все города"); ForEach(kazakhstanCities, id: \.self) { Text($0).tag($0) } }.labelsHidden() }
}
struct DeliveryCard: View {
    let delivery: Delivery
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Label(delivery.status.title, systemImage: delivery.status == .delivered ? "checkmark.circle.fill" : "circle.dotted").font(.caption.bold()).foregroundStyle(Theme.green); Spacer(); Text(delivery.pickupAt, format: .dateTime.day().month(.abbreviated)).font(.caption).foregroundStyle(.secondary) }
            HStack { Text(delivery.fromCity); Image(systemName: "arrow.right").foregroundStyle(Theme.green); Text(delivery.toCity) }.font(.title3.bold())
            HStack(spacing: 12) { Image(systemName: delivery.size.symbol).font(.title2).foregroundStyle(Theme.green).frame(width: 44, height: 44).background(Theme.background, in: RoundedRectangle(cornerRadius: 12)); VStack(alignment: .leading) { Text(delivery.itemDescription).lineLimit(1); Text("\(delivery.size.title) · \(delivery.weight, specifier: "%.1f") кг").font(.caption).foregroundStyle(.secondary) }; Spacer(); Text("\(delivery.price) ₸").font(.headline) }
        }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 22))
    }
}
struct DeliveryDetailView: View {
    @Environment(AppStore.self) private var store
    let id: String
    @State private var details: DeliveryDetails?
    @State private var contact: Profile?
    @State private var messages: [ChatMessage] = []
    @State private var message = ""
    @State private var review = ""
    @State private var reason = ""
    @State private var cancelling = false
    @State private var photo: UIImage?
    var delivery: Delivery? { store.orders.first { $0.id == id } }
    var body: some View {
        ScrollView {
            if let d = delivery {
                VStack(alignment: .leading, spacing: 22) {
                    DeliveryCard(delivery: d)
                    if let photo { Image(uiImage: photo).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 18)) }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Путь посылки").font(.headline)
                        ForEach([DeliveryStatus.waiting, .accepted, .enRoute, .pickedUp, .delivered], id: \.rawValue) { status in
                            HStack { Image(systemName: d.status == status ? "largecircle.fill.circle" : "circle").foregroundStyle(d.status == status ? Theme.green : .secondary); Text(status.title).font(.subheadline); Spacer() }
                        }
                        if let reason = d.cancellationReason { Text("Причина отмены: \(reason)").foregroundStyle(.secondary) }
                    }.padding().background(.white, in: RoundedRectangle(cornerRadius: 18))
                    if d.status == .waiting && store.profile?.role == .courier && d.senderId != store.profile?.id {
                        Button("Принять за \(d.price) ₸") { Task { await store.perform { try await store.accept(d) } } }.buttonStyle(.borderedProminent).controlSize(.large)
                        Text("После принятия откроются адреса и контакты. Оплата по договорённости, комиссия 0%.").font(.caption).foregroundStyle(.secondary)
                    }
                    if let details {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(details.addressFrom, systemImage: "circle.circle"); Label(details.addressTo, systemImage: "mappin.circle")
                            Text("Получатель: \(details.recipientName)")
                            Link("Позвонить получателю", destination: URL(string: "tel:\(details.recipientPhone)")!)
                            if !details.comment.isEmpty { Text(details.comment).foregroundStyle(.secondary) }
                            if let contact { Divider(); Text(contact.name).font(.headline); Link("Позвонить: \(contact.phone)", destination: URL(string: "tel:\(contact.phone)")!) }
                        }.padding().background(.white, in: RoundedRectangle(cornerRadius: 18))
                    }
                    if d.driverId == store.profile?.id, let next = d.status.next {
                        Button(next == .enRoute ? "Еду к отправителю" : next == .pickedUp ? "Забрал посылку" : "Подтвердить доставку") { Task { await store.perform { try await store.transition(d, to: next) } } }.buttonStyle(.borderedProminent).controlSize(.large)
                    }
                    if d.senderId == store.profile?.id || d.driverId == store.profile?.id {
                        if [.waiting, .accepted, .enRoute].contains(d.status) { Button("Отменить доставку", role: .destructive) { cancelling = true } }
                        if d.driverId != nil {
                            Text("Чат по заказу").font(.headline)
                            ForEach(messages) { msg in
                                HStack { if msg.fromUser == store.profile?.id { Spacer(minLength: 30) }; Text(msg.text).padding(12).background(msg.fromUser == store.profile?.id ? Theme.green.opacity(0.12) : .white, in: RoundedRectangle(cornerRadius: 14)); if msg.fromUser != store.profile?.id { Spacer(minLength: 30) } }
                            }
                            if d.status.isActive {
                                HStack { TextField("Сообщение", text: $message, axis: .vertical).textFieldStyle(.roundedBorder); Button { Task { await store.perform { try await store.send(id, text: message); message = ""; try await load() } } } label: { Image(systemName: "arrow.up.circle.fill").font(.title) }.disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                            }
                        }
                        if let existing = d.review { Text("Отзыв: \(existing)").padding().background(.white, in: RoundedRectangle(cornerRadius: 14)) }
                        if d.status == .delivered && d.senderId == store.profile?.id && d.review == nil {
                            TextField("Короткий отзыв", text: $review, axis: .vertical).textFieldStyle(.roundedBorder)
                            Button("Оставить отзыв") { Task { await store.perform { try await store.review(id, text: review) } } }.disabled(review.isEmpty)
                        }
                    }
                }.padding(22).disabled(store.busy)
            } else { ContentUnavailableView("Заказ недоступен", systemImage: "shippingbox") }
        }.background(Theme.background).navigationTitle("Доставка").navigationBarTitleDisplayMode(.inline)
        .task(id: delivery?.driverId) { do { try await load() } catch { store.error = error.localizedDescription } }
        .task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(5)); await store.refresh(); try await load() }
                catch is CancellationError { break }
                catch { store.error = "Не удалось обновить чат. Потяните экран вниз для повтора."; break }
            }
        }
        .refreshable { await store.refresh(); do { try await load() } catch { store.error = error.localizedDescription } }
        .alert("Причина отмены", isPresented: $cancelling) {
            TextField("Не менее 3 символов", text: $reason)
            Button("Отменить заказ", role: .destructive) { if let d = delivery { Task { await store.perform { try await store.transition(d, to: .cancelled, reason: reason) } } } }
            Button("Назад", role: .cancel) {}
        }
    }
    func load() async throws {
        guard let d = delivery else { return }
        if d.senderId == store.profile?.id || d.driverId == store.profile?.id {
            details = try await store.details(id); contact = try await store.contact(id); messages = try await store.messages(id)
        }
        if !store.demo, let path = d.photoPath, photo == nil {
            let data = try await store.photoData(path); photo = UIImage(data: data)
        }
    }
}
