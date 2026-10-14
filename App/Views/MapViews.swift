import SwiftUI
import MapKit

struct PlaceField: View {
    let title: String
    let city: String
    @Binding var selection: SelectedPlace?
    @State private var showing = false
    var body: some View {
        Button { showing = true } label: {
            HStack {
                Image(systemName: selection == nil ? "mappin.and.ellipse" : "mappin.circle.fill")
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.caption).foregroundStyle(.secondary)
                    Text(selection?.label ?? "Выбрать адрес или точку").foregroundStyle(.primary).lineLimit(3)
                }
                Spacer(); Image(systemName: "chevron.right").font(.caption)
            }
        }
        .sheet(isPresented: $showing) { LocationPicker(title: title, city: city, selection: $selection) }
    }
}

struct LocationPicker: View {
    let title: String
    let city: String
    @Binding var selection: SelectedPlace?
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var search = LocationSearchService()
    @State private var location = LocationService()
    @State private var position: MapCameraPosition = .automatic
    @State private var region = CityMap.region("Алматы")
    @State private var candidate: SelectedPlace?
    @State private var resolving = false
    @State private var message: String?
    @State private var revision = UUID()
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextField("Улица, дом или место", text: $query).textFieldStyle(.roundedBorder).padding(.horizontal)
                    .accessibilityIdentifier("addressSearch")
                    .onChange(of: query) { candidate = nil; revision = UUID(); resolving = false; search.cancel() }
                if search.searching || resolving { ProgressView("Ищем адрес…") }
                if !search.results.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(search.results, id: \.self) { result in
                                Button { Task { await choose(result) } } label: {
                                    VStack(alignment: .leading) { Text(result.title).foregroundStyle(.primary); Text(result.subtitle).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 9)
                                }; Divider()
                            }
                        }.padding(.horizontal)
                    }.frame(maxHeight: 175)
                }
                Map(position: $position) {
                    if let candidate { Marker(candidate.label, coordinate: candidate.coordinate.coordinate) }
                }
                .onMapCameraChange(frequency: .onEnd) { context in region = context.region }
                .overlay { Image(systemName: "plus").font(.title2.weight(.heavy)).foregroundStyle(Theme.green).allowsHitTesting(false) }
                .overlay(alignment: .top) { Text("Двигайте карту: крестик — точка выбора").font(.caption).padding(8).background(.regularMaterial, in: Capsule()).padding(8) }
                .clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal)
                HStack {
                    Button("Моя позиция", systemImage: "location") { location.request() }.disabled(location.requesting)
                    Spacer()
                    Button("Выбрать под крестиком", systemImage: "mappin") { Task { await chooseCenter() } }.disabled(resolving)
                }.font(.callout).padding(.horizontal)
                if let message = message ?? location.message ?? search.message { Text(message).font(.caption).foregroundStyle(.secondary).padding(.horizontal) }
                if let candidate { Text(candidate.label).font(.callout).lineLimit(3).padding(.horizontal) }
                Button("Подтвердить точку") {
                    guard let candidate else { return }; selection = candidate; dismiss()
                }.buttonStyle(.borderedProminent).controlSize(.large).disabled(candidate == nil || resolving).padding(.bottom)
            }
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } } }
            .task {
                candidate = selection
                region = selection.map { MKCoordinateRegion(center: $0.coordinate.coordinate, latitudinalMeters: 2000, longitudinalMeters: 2000) } ?? CityMap.region(city)
                position = .region(region)
            }
            .task(id: query) {
                do { try await Task.sleep(for: .milliseconds(300)); try Task.checkCancellation(); search.update(query, region: region) } catch {}
            }
            .onChange(of: location.point) {
                if let point = location.point {
                    candidate = nil; revision = UUID()
                    region = MKCoordinateRegion(center: point.coordinate, latitudinalMeters: 1500, longitudinalMeters: 1500)
                    position = .region(region)
                }
            }
            .onDisappear { search.cancel(); revision = UUID() }
        }
    }
    func choose(_ result: MKLocalSearchCompletion) async {
        let ticket = UUID(); revision = ticket; resolving = true; message = nil
        defer { if revision == ticket { resolving = false } }
        do {
            let place = try await search.resolve(result)
            guard revision == ticket else { return }
            candidate = place; search.cancel()
            position = .region(.init(center: place.coordinate.coordinate, latitudinalMeters: 1500, longitudinalMeters: 1500))
        } catch { if revision == ticket { message = "Не удалось найти точку. Выберите её на карте." } }
    }
    func chooseCenter() async {
        let ticket = UUID(); revision = ticket; resolving = true; message = nil; search.cancel()
        let point = GeoPoint(region.center)
        defer { if revision == ticket { resolving = false } }
        let marks = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: point.latitude, longitude: point.longitude))
        guard revision == ticket else { return }
        let mark = marks?.first
        let label = [mark?.locality, mark?.thoroughfare, mark?.subThoroughfare].compactMap { $0 }.joined(separator: ", ")
        candidate = SelectedPlace(coordinate: point, label: label.isEmpty ? "Точка на карте" : label)
    }
}

struct RouteMapView: View {
    let origin: SelectedPlace
    let destination: SelectedPlace
    let route: MKRoute?
    @State private var camera: MapCameraPosition = .automatic
    var body: some View {
        Map(position: $camera) {
            Marker("Откуда", systemImage: "shippingbox", coordinate: origin.coordinate.coordinate).tint(Theme.green)
            Marker("Куда", systemImage: "flag", coordinate: destination.coordinate.coordinate)
            if let route { MapPolyline(route.polyline).stroke(Theme.green, lineWidth: 5) }
        }.frame(height: 240).clipShape(RoundedRectangle(cornerRadius: 16))
            .onChange(of: route?.distance) { camera = .automatic }
            .onChange(of: origin) { camera = .automatic }
            .onChange(of: destination) { camera = .automatic }
    }
}

struct DeliveryRouteView: View {
    let details: DeliveryDetails
    @State private var routing = RoutingService()
    var body: some View {
        if let a = details.pickupPlace, let b = details.dropoffPlace {
            VStack(alignment: .leading, spacing: 10) {
                RouteMapView(origin: a, destination: b, route: routing.route)
                if let route = routing.route { Text("\(route.distance / 1000, specifier: "%.1f") км · около \(Int(route.expectedTravelTime / 60)) мин").font(.subheadline) }
                if routing.calculating { ProgressView("Рассчитываем путь…") }
                if let message = routing.message { Text(message).font(.caption).foregroundStyle(.secondary) }
                Button("Обновить маршрут") { Task { await routing.calculate(from: a.coordinate, to: b.coordinate, departure: Date()) } }.disabled(routing.calculating)
            }.task(id: "\(a.coordinate)|\(b.coordinate)") { await routing.calculate(from: a.coordinate, to: b.coordinate, departure: Date()) }
        } else { Text("В этом заказе ещё нет точек на карте.").font(.caption).foregroundStyle(.secondary) }
    }
}
