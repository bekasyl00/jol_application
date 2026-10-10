import SwiftUI
import FirebaseCore
import FirebaseAppCheck
import FirebaseMessaging
import FirebaseAuth
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        #if !JOL_DEMO_ONLY
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            #if DEBUG
            AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
            #else
            AppCheck.setAppCheckProviderFactory(JolAppCheckFactory())
            #endif
            FirebaseApp.configure(); Messaging.messaging().delegate = self
            UNUserNotificationCenter.current().delegate = self
        }
        #endif
        return true
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) { Messaging.messaging().apnsToken = deviceToken }
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        NotificationCenter.default.post(name: .init("FCMToken"), object: token)
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound] }
}
@main struct JolParcelApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var store: AppStore?
    var body: some Scene {
        WindowGroup {
            Group {
                if let store { RootView().environment(store) }
                else { ProgressView().task { store = AppStore() } }
            }.tint(Theme.green)
        }
    }
}

final class JolAppCheckFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? { AppAttestProvider(app: app) }
}
