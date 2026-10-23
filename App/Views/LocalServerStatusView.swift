#if JOL_LOCAL_SERVER
import SwiftUI

struct LocalServerBanner: View {
    @State private var showStatus = false
    var body: some View {
        Button { showStatus = true } label: {
            Label("Jol Local · тестовые данные", systemImage: "desktopcomputer")
                .font(.caption).frame(maxWidth: .infinity).padding(8)
        }.background(Theme.surface)
            .sheet(isPresented: $showStatus) { LocalServerStatusView() }
    }
}

private struct LocalServerStatusView: View {
    @State private var checking = false
    @State private var status = ""
    var body: some View {
        NavigationStack {
            List {
                Section("Сервер на Mac") {
                    Text(LocalBackend.host).textSelection(.enabled)
                    Text("iPhone и Mac должны быть в одной доверенной Wi-Fi сети. Оставьте Mac включённым и сервер запущенным.")
                    Button(checking ? "Проверяем…" : "Проверить соединение") {
                        checking = true
                        Task {
                            do { try await LocalBackend.checkConnection(); status = "Сервер доступен. Можно регистрироваться и создавать заказы." }
                            catch { status = LocalBackend.connectionMessage(for: error) }
                            checking = false
                        }
                    }.disabled(checking)
                    if !status.isEmpty { Text(status).font(.callout) }
                }
                Section("Бесплатная разработка") {
                    Text("SMS-коды тестовые и показываются в форме. Данные хранятся на Mac. Используйте вымышленные телефоны, адреса и отдельный тестовый пароль.")
                    Text("Обновления заказов и позиции работают в приложении. Push-уведомления и автоматическая облачная очистка данных в этом режиме недоступны.")
                    Text("Карты и поиск адресов используют Apple MapKit; для них нужен интернет.")
                }
            }.navigationTitle("Локальный сервер")
        }
    }
}
#endif
