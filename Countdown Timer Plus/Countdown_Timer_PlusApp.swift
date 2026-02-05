import SwiftUI
import FirebaseCore
import AdSupport
import AppsFlyerLib
import AppTrackingTransparency
import SwiftUI
import FirebaseMessaging

@main
struct CountdownApp: App {
    @StateObject private var listVM = CountdownListViewModel()
    @StateObject private var settingsVM = SettingsViewModel()
    
    var body: some Scene {
        WindowGroup {
            LoadingView()
                .preferredColorScheme(colorScheme(from: settingsVM.settings.theme))
        }
    }
    
    private func colorScheme(from theme: AppTheme) -> ColorScheme? {
        switch theme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}


class AppDelegate: NSObject, UIApplicationDelegate, AppsFlyerLibDelegate, MessagingDelegate, UNUserNotificationCenterDelegate, DeepLinkDelegate {
    private var didRequestConversionDataAgain = false
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.list, .banner])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {

        let userInfo = response.notification.request.content.userInfo

        var urlString: String?

        if let url = userInfo["url"] as? String {
            urlString = url
        } else if let data = userInfo["data"] as? [String: Any],
                  let url = data["url"] as? String {
            urlString = url
        }

        if let urlString = urlString, !urlString.isEmpty {
            print("URL STRING: \(urlString)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                NotificationCenter.default.post(name: .openUrlFromNotification,
                                                object: nil,
                                                userInfo: ["url": urlString])
            }
        } else {
            print("URL not found or empty")
        }

        completionHandler()
    }
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        UIApplication.shared.registerForRemoteNotifications()
        Messaging.messaging().delegate = self
        AppsFlyerLib.shared().appleAppID = "6757925284"
        AppsFlyerLib.shared().appsFlyerDevKey = "pzBMd7RMff8iuBTHbQitna"
        AppsFlyerLib.shared().delegate = self
        AppsFlyerLib.shared().deepLinkDelegate = self
        AppsFlyerLib.shared().isDebug = false
        AppsFlyerLib.shared().waitForATTUserAuthorization(timeoutInterval: 60)
        NotificationCenter.default.addObserver(self, selector: #selector(dnsajkdnasda),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("did register 8989")
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken)) 8989")
        
        if let fcmToken {
            UserDefaults.standard.set(fcmToken, forKey: "fcmToken")
        } else {
            UserDefaults.standard.set("null", forKey: "fcmToken")
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }
    
    private func idfaSave() {
        let userIdfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        UserDefaults.standard.set(userIdfa, forKey: "idfa_of_user")
    }
    
    @objc private func dnsajkdnasda() {
        AppsFlyerLib.shared().start()
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                self.idfaSave()
            }
        } else {
            self.idfaSave()
        }
    }
    
    func onConversionDataFail(_ error: Error) {

    }
    
    func onConversionDataSuccess(_ conversionData: [AnyHashable: Any]) {
        let afUID = AppsFlyerLib.shared().getAppsFlyerUID()
        print("[AppsFlyer] conversionData, conversionData: \(conversionData)")
        UserDefaults.standard.set(afUID, forKey: "apps_flyer_id")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: conversionData, options: [])
            UserDefaults.standard.set(jsonData, forKey: "conversion_data")
        } catch {
            print("Failed to serialize conversionData: \(error)")
        }
        
        if let status = conversionData["af_status"] as? String {
            let isOrganic = (status == "Organic")
            UserDefaults.standard.set(isOrganic, forKey: "is_organic_conversion")
        } else {
            UserDefaults.standard.set(false, forKey: "is_organic_conversion")
        }
        
        if let deepLinkValue = conversionData["deep_link_value"] as? String {
            UserDefaults.standard.set(deepLinkValue, forKey: "deep_link_value")
        }
        
        NotificationCenter.default.post(name: .datraRecieved, object: nil, userInfo: conversionData)
        
        if let status = conversionData["af_status"] as? String, status == "Organic" {
            if !didRequestConversionDataAgain {
                didRequestConversionDataAgain = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    AppsFlyerLib.shared().start()
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: conversionData, options: [])
                        UserDefaults.standard.set(jsonData, forKey: "conversion_data")
                    } catch {
                        print("Failed to serialize conversionData: \(error)")
                    }
                }
            } else {
                print("We have organic conversion")
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .datraRecieved, object: nil)
    }
    
    func didResolveDeepLink(_ result: DeepLinkResult) {
        switch result.status {
        case .found:
            if let deepLink = result.deepLink {
                let deepLinkValue = deepLink.deeplinkValue
                let deepLinkSub1 = deepLink.clickEvent["deep_link_sub1"] as? String
                if let deepLinkValue = deepLinkValue {
                    UserDefaults.standard.set(deepLinkValue, forKey: "deep_link_value")
                }
                if let deepLinkSub1 = deepLinkSub1 {
                    UserDefaults.standard.set(deepLinkSub1, forKey: "deep_link_sub1")
                }
            }
        case .notFound:
            print("not foundas")
        case .failure:
            print("Ошибка при обработке Deep Link: \(result.error?.localizedDescription ?? "Unknown error")")
        }
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        AppsFlyerLib.shared().handleOpen(url, options: options)
        return true
    }
}

extension Notification.Name {
    static let datraRecieved = Notification.Name("datraRecieved")
    static let notificationPermissionResult = Notification.Name("notificationPermissionResult")
    static let openUrlFromNotification = Notification.Name("openUrlFromNotification")
}
