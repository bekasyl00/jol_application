import SwiftUI
import MapKit

struct TripsView: View {
    @Environment(AppStore.self) private var store
    @State private var creating = false
    @State private var deliveryId = ""
    @State private var alongRoute = false
    @State private var dateFilter = false
    @State private var date = Date()
    var sender: Bool { store.profile?.role == .sender }
    var availableOrders: [Delivery] { store.orders.filter { $0.senderId == store.profile?.id && $0.status == .waiting } }
    var order: Delivery? { availableOrders.first { $0.id == deliveryId } }
    var visible: [CarrierTrip] {
        store.trips.filter { t in
            if dateFilter && !Calendar.current.isDate(t.departureAt, inSameDayAs: date) { return false }
            if alongRoute, let order {
                guard t.canPropose(order), let p = order.pickupArea, let q = order.dropoffArea else { return false }
                return RouteCompatibility.followsDirection(origin: t.originArea, destination: t.destinationArea, pickup: p, dropoff: q)
            }
            return true
        }
    }
    var body: some View {
        NavigationStack {
            List {
                if sender {
                    Section("Найти перевозчика") {
                        Picker("Мой заказ", selection: $deliveryId) {
                            Text("Выберите отправление").tag("")
                            ForEach(availableOrders) { Text("\($0.fromCity) → \($0.toCity) · \($0.itemDescription)").tag($0.id) }
                        }
                        Toggle("По направлению и свободному месту", isOn: $alongRoute).disabled(order == nil)
                        Toggle("Дата поездки", isOn: $dateFilter)
                        if dateFilter { DatePicker("День", selection: $date, displayedComponents: .date) }
                        Text("Вы предлагаете свой заказ. Перевозчик подтверждает его. Точный адрес открывается после принятия.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section(sender ? "Опубликованные поездки" : "Мои поездки") {
                    if visible.isEmpty { ContentUnavailableView("Поездок пока нет", systemImage: "car", description: Text(sender ? "Измените фильтр или обновите список." : "Опубликуйте, откуда и куда собираетесь ехать.")) }
                    ForEach(visible) { trip in NavigationLink { TripDetailView(id: trip.id, selectedOrderId: deliveryId) } label: { TripCard(trip: trip) } }
                    if sender && store.catalogHasMore && !store.demo { Button("Загрузить ещё поездки") { Task { await store.perform { try await store.loadCatalog(reset: false) } } } }
                }
                if !store.proposals.isEmpty {
                    Section(sender ? "Мои предложения" : "Предложения отправителей") {
                        ForEach(store.proposals) { proposal in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(proposal.fromCity) → \(proposal.toCity)").font(.headline)
                                Text("\(proposal.itemDescription) · \(proposal.weight, specifier: "%.1f") кг · \(proposal.price) ₸")
                                Text(proposal.status.title).font(.caption).foregroundStyle(.secondary)
                                if sender && proposal.status == .pending {
                                    Button("Отозвать предложение") { Task { await store.perform { try await store.respond(proposal, action: .withdrawn, version: nil) } } }
                                } else if !sender, store.trips.contains(where: { $0.id == proposal.tripId }) {
                                    NavigationLink("Открыть поездку") { TripDetailView(id: proposal.tripId, selectedOrderId: "") }
                                }
                            }.padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle(sender ? "Перевозчики" : "Мои поездки")
            .toolbar { if !sender { Button("Добавить", systemImage: "plus") { creating = true } } }
            .sheet(isPresented: $creating) { CreateTripView() }
            .refreshable { await store.refresh() }
            .task { await store.refresh() }
        }
    }
}

struct TripCard: View {
    let trip: CarrierTrip
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(trip.fromCity) → \(trip.toCity)").font(.headline)
            Text(trip.departureAt, format: .dateTime.day().month().hour().minute())
            Text("\(trip.driverName) · \(trip.vehicle)").font(.subheadline)
            Text("Свободно \(trip.availableKg, specifier: "%.1f") кг · \(max(0, trip.maxParcels - trip.acceptedCount)) посылок").font(.caption).foregroundStyle(Theme.green)
            if trip.status != .published { Text("Приём предложений закрыт").font(.caption).foregroundStyle(.secondary) }
        }.padding(.vertical, 6)
    }
}

struct CreateTripView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var from = "Алматы"
    @State private var to = "Астана"
    @State private var origin: SelectedPlace?
    @State private var destination: SelectedPlace?
    @State private var departure = Date().addingTimeInterval(7200)
    @State private var capacity = "50"
    @State private var maxParcels = 5
    @State private var detour = "20"
    @State private var detourMinutes = 30
    @State private var window = 120
    @State private var id = UUID().uuidString
    @State private var routing = RoutingService()
    var key: String { "\(String(describing: origin))|\(String(describing: destination))|\(Int(departure.timeIntervalSince1970 / 60))" }
    var body: some View {
        NavigationStack {
            Form {
                Section("Маршрут поездки") {
                    Picker("Откуда", selection: $from) { ForEach(kazakhstanCities, id: \.self) { Text($0) } }
                    PlaceField(title: "Место отправления", city: from, selection: $origin)
                    Picker("Куда", selection: $to) { ForEach(kazakhstanCities, id: \.self) { Text($0) } }
                    PlaceField(title: "Место назначения", city: to, selection: $destination)
                    DatePicker("Отправление", selection: $departure, in: Date()...)
                    if let origin, let destination { RouteMapView(origin: origin, destination: destination, route: routing.route) }
                    if routing.calculating { ProgressView("Рассчитываем путь…") }
                    if let route = routing.route { Text("\(route.distance / 1000, specifier: "%.1f") км · около \(Int(route.expectedTravelTime / 60)) мин") }
                    if let message = routing.message { Text(message).font(.caption).foregroundStyle(.secondary) }
                }
                Section("Посылки и объезд") {
                    TextField("Общая вместимость, кг", text: $capacity).keyboardType(.decimalPad)
                    Stepper("До \(maxParcels) посылок", value: $maxParcels, in: 1...10)
                    TextField("Дополнительный путь, км", text: $detour).keyboardType(.decimalPad)
                    Stepper("Дополнительное время: \(detourMinutes) мин", value: $detourMinutes, in: 0...240, step: 15)
                    Stepper("Передача в пределах ±\(window) мин от отправления", value: $window, in: 15...1440, step: 15)
                    Text("Вместимость общая для всех принятых посылок. Новые остановки добавляются после уже согласованных. После доставки место не продаётся повторно в этой поездке.").font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Text("В каталоге видны города и приблизительные районы. Точные точки поездки видите только вы.").font(.caption)
                    Button("Опубликовать поездку") { Task { await store.perform { try await publish() } } }.disabled(store.busy || origin == nil || destination == nil)
                }
            }.navigationTitle("Новая поездка").dismissibleKeyboard()
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } } }
                .onAppear { capacity = String(store.profile?.capacityKg ?? 50) }
                .onChange(of: from) { origin = nil }
                .onChange(of: to) { destination = nil }
                .task(id: key) { routing.reset(); if let origin, let destination { await routing.calculate(from: origin.coordinate, to: destination.coordinate, departure: departure) } }
        }
    }
    func publish() async throws {
        guard let driver = store.profile, let origin, let destination else { throw ParcelError.invalid("Подтвердите точки поездки.") }
        let trip = CarrierTrip(id: id, driver: driver, fromCity: from, toCity: to, origin: origin.coordinate, destination: destination.coordinate, departureAt: departure, capacityKg: Double(capacity.replacingOccurrences(of: ",", with: ".")) ?? 0, maxParcels: maxParcels, maxDetourKm: Double(detour.replacingOccurrences(of: ",", with: ".")) ?? -1, maxDetourMinutes: detourMinutes, pickupWindowMinutes: window)
        try await store.publishTrip(trip, details: TripDetails(origin: origin, destination: destination)); dismiss()
    }
}

struct TripDetailView: View {
    @Environment(AppStore.self) private var store
    let id: String
    let selectedOrderId: String
    @State private var details: TripDetails?
    @State private var orderId = ""
    @State private var match = RouteMatchingService()
    @State private var message: String?
    var trip: CarrierTrip? { store.trips.first { $0.id == id } }
    var own: Bool { trip?.driverId == store.profile?.id }
    var order: Delivery? { store.orders.first { $0.id == orderId && $0.senderId == store.profile?.id && $0.status == .waiting } }
    var body: some View {
        List {
            if let trip {
                Section { TripCard(trip: trip) }
                Section("Маршрут") {
                    if own, let details { TripRouteView(trip: trip, details: details) }
                    else { RouteMapView(origin: .init(coordinate: trip.originArea, label: trip.fromCity), destination: .init(coordinate: trip.destinationArea, label: trip.toCity), route: nil); Text("Приблизительные районы отправления и назначения.").font(.caption) }
                    Text("Допустимый объезд: \(trip.maxDetourKm, specifier: "%.0f") км / \(trip.maxDetourMinutes) мин").font(.subheadline)
                }
                if !own {
                    Section("Предложить посылку") {
                        Picker("Заказ", selection: $orderId) {
                            Text("Выберите отправление").tag("")
                            ForEach(store.orders.filter { $0.senderId == store.profile?.id && $0.status == .waiting }) { Text($0.itemDescription + " · " + $0.toCity).tag($0.id) }
                        }
                        if let order {
                            if let existing = store.proposals.first(where: { $0.deliveryId == order.id && $0.tripId == trip.id }) { Text(existing.status.title) }
                            else {
                                Button("Оценить объезд") { Task { await estimate(trip, order) } }.disabled(match.calculating)
                                MatchResultView(match: match, trip: trip, approximate: true)
                                if trip.acceptedCount > 0 { Text("В поездке уже есть остановки. Перевозчик проверит общий объезд со всеми посылками.").font(.caption) }
                                Button("Предложить этот заказ") { Task { await store.perform { try await store.propose(deliveryId: order.id, tripId: trip.id); message = "Предложение отправлено перевозчику." } } }.disabled(store.busy || !trip.canPropose(order))
                                if !trip.canPropose(order) { Text("Не хватает места, поездка закрыта или время передачи вне окна поездки.").font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                        if let message { Text(message).font(.callout) }
                    }
                } else {
                    Section("Предложения") {
                        ForEach(store.proposals.filter { $0.tripId == id }) { proposal in ProposalReviewView(proposal: proposal, trip: trip, details: details) }
                    }
                    if trip.status == .published {
                        Section { Button("Закрыть приём новых посылок") { Task { await store.perform { try await store.closeTrip(id) } } }; Text("Уже принятые доставки остаются активными.").font(.caption) }
                    }
                }
            } else { ContentUnavailableView("Поездка недоступна", systemImage: "car") }
        }.navigationTitle(own ? "Моя поездка" : "Поездка перевозчика")
            .task { orderId = selectedOrderId; await load() }
            .task(id: trip?.version) { await load() }
            .onChange(of: orderId) { match.reset(); message = nil }
    }
    func load() async { if own { do { details = try await store.tripDetails(id) } catch { store.error = error.localizedDescription } } }
    func estimate(_ trip: CarrierTrip, _ order: Delivery) async {
        do {
            guard let d = try await store.details(order.id), let p = d.pickupPlace, let q = d.dropoffPlace else { throw ParcelError.invalid("В заказе нет подтверждённых точек.") }
            guard orderId == order.id else { return }
            await match.evaluate(origin: trip.originArea, destination: trip.destinationArea, stops: [], pickup: p.coordinate, dropoff: q.coordinate, departure: trip.departureAt)
        } catch { store.error = error.localizedDescription }
    }
}

struct MatchResultView: View {
    let match: RouteMatchingService
    let trip: CarrierTrip
    let approximate: Bool
    var body: some View {
        if match.calculating { ProgressView("Считаем дорожный объезд…") }
        if let km = match.extraKm, let minutes = match.extraMinutes {
            Text("Дополнительно ≈ \(km, specifier: "%.1f") км / \(minutes) мин").font(.subheadline)
            Text(km <= trip.maxDetourKm && minutes <= trip.maxDetourMinutes ? "В пределах пожеланий перевозчика" : "Превышает допустимый объезд").font(.caption).foregroundStyle(.secondary)
            if approximate { Text("Предварительно: чужие адреса округлены до районов. После принятия нужно уточнить путь.").font(.caption).foregroundStyle(.secondary) }
        }
        if let message = match.message { Text(message).font(.caption).foregroundStyle(.secondary) }
    }
}

struct ProposalReviewView: View {
    @Environment(AppStore.self) private var store
    let proposal: TripProposal
    let trip: CarrierTrip
    let details: TripDetails?
    @State private var match = RouteMatchingService()
    @State private var confirming = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(proposal.fromCity) → \(proposal.toCity)").font(.headline)
            Text("\(proposal.itemDescription) · \(proposal.weight, specifier: "%.1f") кг · \(proposal.price) ₸")
            Text(proposal.status.title).font(.caption).foregroundStyle(.secondary)
            if proposal.status == .pending {
                Button("Проверить объезд со всеми остановками") { Task { await estimate() } }.disabled(match.calculating)
                MatchResultView(match: match, trip: trip, approximate: true)
                HStack {
                    Button("Принять") { confirming = true }.buttonStyle(.borderedProminent).foregroundStyle(Theme.onAccent)
                    Button("Отклонить") { Task { await store.perform { try await store.respond(proposal, action: .rejected, version: nil) } } }
                }.disabled(store.busy || match.calculating)
            }
        }.padding(.vertical, 6)
            .onChange(of: trip.version) { match.reset() }
            .confirmationDialog("Принять посылку?", isPresented: $confirming, titleVisibility: .visible) {
                Button("Принять и зарезервировать место") { Task { await store.perform { try await store.respond(proposal, action: .accepted, version: trip.version) } } }
            } message: { Text("\(match.extraKm == nil ? "Дорожный объезд не определён. " : "Оценка объезда предварительная. ")После принятия откроются точные адреса. Согласуйте путь с отправителем; посылка добавит две остановки после уже принятых.") }
    }
    func estimate() async {
        guard let details, let p = proposal.pickupArea, let q = proposal.dropoffArea else { match.message = "Нет подтверждённых точек для оценки."; return }
        do {
            var stops: [GeoPoint] = []
            for id in details.deliveryIds {
                guard let d = try await store.details(id), let a = d.pickupPlace, let b = d.dropoffPlace else { throw ParcelError.invalid("Не у всех принятых посылок есть точки. Уточните маршрут вручную.") }
                stops += [a.coordinate, b.coordinate]
            }
            guard store.trips.first(where: { $0.id == trip.id })?.version == trip.version else { return }
            await match.evaluate(origin: details.origin.coordinate, destination: details.destination.coordinate, stops: stops, pickup: p, dropoff: q, departure: trip.departureAt)
        } catch { match.message = error.localizedDescription }
    }
}

struct TripRouteView: View {
    @Environment(AppStore.self) private var store
    let trip: CarrierTrip
    let details: TripDetails
    @State private var stops: [SelectedPlace] = []
    @State private var lines: [MKPolyline] = []
    @State private var message: String?
    @State private var routing = RoutingService()
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Map {
                ForEach(Array(stops.enumerated()), id: \.offset) { index, place in Marker("\(index + 1). \(place.label)", coordinate: place.coordinate.coordinate) }
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in MapPolyline(line).stroke(Theme.green, lineWidth: 4) }
            }.frame(height: 250).clipShape(RoundedRectangle(cornerRadius: 14))
            ForEach(Array(stops.enumerated()), id: \.offset) { index, place in Text("\(index + 1). \(place.label)").font(.caption) }
            if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
            if routing.calculating { ProgressView("Рассчитываем участки…") }
        }.task(id: trip.version) { await load() }
    }
    func load() async {
        lines = []; message = nil; routing.reset()
        do {
            var next = [details.origin]
            for id in details.deliveryIds {
                guard let d = try await store.details(id), let p = d.pickupPlace, let q = d.dropoffPlace else { throw ParcelError.invalid("У старого заказа нет точек. Уточните остановки в карточке доставки.") }
                next += [p, q]
            }
            next.append(details.destination); stops = next
            var elapsed = 0.0
            for i in 0..<(next.count - 1) {
                try Task.checkCancellation()
                if next[i].coordinate.meters(to: next[i + 1].coordinate) < 20 { continue }
                await routing.calculate(from: next[i].coordinate, to: next[i + 1].coordinate, departure: trip.departureAt.addingTimeInterval(elapsed))
                guard let route = routing.route else { lines = []; message = routing.message; return }
                lines.append(route.polyline); elapsed += route.expectedTravelTime
            }
        } catch is CancellationError {} catch { message = error.localizedDescription }
    }
}
