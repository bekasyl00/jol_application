import SwiftUI
import MapKit

struct DeliveryTrackingView: View {
    @Environment(AppStore.self) private var store
    let delivery: Delivery
    @State private var observer = TrackingObserver()
    var inProgress: Bool { [.enRoute, .pickedUp].contains(delivery.status) }
    var own: Bool { delivery.driverId == store.profile?.id }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Местоположение перевозчика", systemImage: "location.circle").font(.headline)
            if store.demo { Text("Локальное демо: GPS не публикуется. Живая позиция доступна после подключения Firebase.").font(.caption).foregroundStyle(.secondary) }
            else if inProgress {
                if own {
                    let sharing = store.tracking.activeIds.contains(delivery.id)
                    Button(sharing ? "Остановить передачу позиции" : "Передавать позицию отправителю", systemImage: sharing ? "location.slash" : "location.fill") {
                        Task { await store.perform {
                            if sharing { await store.tracking.stop(id: delivery.id) }
                            else { try await store.tracking.start(id: delivery.id, store: store) }
                        } }
                    }.disabled(store.busy)
                    Text("Позицию видит отправитель этой доставки. Во время передачи приложение использует геолокацию и в фоне. Остановить её можно в любой момент.").font(.caption).foregroundStyle(.secondary)
                    if let message = store.tracking.message { Text(message).font(.caption) }
                }
                TimelineView(.periodic(from: .now, by: 10)) { context in
                    if let latest = observer.latest, latest.visibleUntil > context.date {
                        let stale = context.date.timeIntervalSince(latest.receivedAt) > 60
                        Map { Marker(stale ? "Последняя известная позиция" : "Перевозчик", systemImage: "car.fill", coordinate: latest.coordinate.coordinate).tint(stale ? .gray : Theme.green) }.frame(height: 220).clipShape(RoundedRectangle(cornerRadius: 14))
                        Text(stale ? "Позиция устарела — связь или геолокация недоступны." : "Позиция обновляется во время доставки.").font(.caption)
                        Text("Обновлено \(latest.receivedAt.formatted(date: .omitted, time: .standard)) · точность около \(Int(latest.accuracy)) м").font(.caption).foregroundStyle(.secondary)
                    } else { Text(observer.latest == nil ? observer.message : "Нет свежей позиции более двух минут.").font(.caption).foregroundStyle(.secondary) }
                }
            } else { Text("Передача доступна, когда перевозчик едет к отправителю или везёт посылку.").font(.caption).foregroundStyle(.secondary) }
        }.padding().background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
            .task(id: delivery.status) { if inProgress && !store.demo && store.isConfigured { observer.listen(id: delivery.id) } else { observer.stop() } }
            .onDisappear { observer.stop() }
    }
}
