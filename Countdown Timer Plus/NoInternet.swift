import SwiftUI

struct NoInternet: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
 
    var isPortrait: Bool {
        verticalSizeClass == .regular && horizontalSizeClass == .compact
    }
    
    var isLandscape: Bool {
        verticalSizeClass == .compact && horizontalSizeClass == .regular
    }
    
    
    var body: some View {
        VStack {
            if isPortrait {
                ZStack {
                    Image("inetport")
                        .resizable()
                        .ignoresSafeArea()
                }
            } else {
                ZStack {
                    Image("inetland")
                        .resizable()
                        .ignoresSafeArea()
                }
            }
        }
    }
}

import SwiftUI
import UIKit
@preconcurrency import WebKit

private var asdqw: String = {
    WKWebView().value(forKey: "userAgent") as? String ?? ""
}()

class CreateDetail: UIViewController, WKNavigationDelegate, WKUIDelegate {
    var czxasd: WKWebView!
    var newPopupWindow: WKWebView?
    private var lastRedirectURL: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    func showControls() async {
        let content = UserDefaults.standard.string(forKey: "config_url") ?? ""
        
        if !content.isEmpty, let url = URL(string: content) {
            loadCookie()
            
            await MainActor.run {
                let webConfiguration = WKWebViewConfiguration()
                webConfiguration.mediaTypesRequiringUserActionForPlayback = []
                webConfiguration.allowsInlineMediaPlayback = true
                let source: String = """
                var meta = document.createElement('meta');
                meta.name = 'viewport';
                meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
                document.getElementsByTagName('head')[0].appendChild(meta);
                """
                let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
                webConfiguration.userContentController.addUserScript(script)
                
                self.czxasd = WKWebView(frame: .zero, configuration: webConfiguration)
                self.czxasd.customUserAgent = asdqw
                self.czxasd.navigationDelegate = self
                self.czxasd.uiDelegate = self
                
                self.czxasd.scrollView.isScrollEnabled = true
                self.czxasd.scrollView.pinchGestureRecognizer?.isEnabled = false
                self.czxasd.scrollView.keyboardDismissMode = .interactive
                self.czxasd.scrollView.minimumZoomScale = 1.0
                self.czxasd.scrollView.maximumZoomScale = 1.0
                self.czxasd.allowsBackForwardNavigationGestures = true
                view.backgroundColor = .black
                self.view.addSubview(self.czxasd)
                self.czxasd.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    self.czxasd.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor),
                    self.czxasd.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor),
                    self.czxasd.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
                    self.czxasd.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor)
                ])
                
                self.loadInfo(with: url)
            }
        }
    }
    
    func loadInfo(with url: URL) {
        czxasd.load(URLRequest(url: url))
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        saveCookie()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorHTTPTooManyRedirects {
            if let url = lastRedirectURL {
                webView.load(URLRequest(url: url))
                return
            }
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() {
            lastRedirectURL = url
            
            if scheme != "http" && scheme != "https" {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
//                    if webView.canGoBack {
//                        webView.goBack()
//                    }
                    
                    decisionHandler(.cancel)
                    return
                }
            }
        }
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let response = navigationResponse.response as? HTTPURLResponse {
            let status = response.statusCode
            
            if (300...399).contains(status) {
                decisionHandler(.allow)
                return
            } else if status == 200 {
                if webView.superview == nil {
                    view.addSubview(webView)
                    
                    webView.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([
                        webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                        webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                        webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                        webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
                    ])
                }
                decisionHandler(.allow)
                return
            } else if status >= 400 {
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }
    
    func loadCookie() {
        let ud: UserDefaults = UserDefaults.standard
        let data: Data? = ud.object(forKey: "cookie") as? Data
        if let cookie = data {
            do {
                let datas: NSArray? = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: cookie)
                if let cookies = datas {
                    for c in cookies {
                        if let cookieObject = c as? HTTPCookie {
                            HTTPCookieStorage.shared.setCookie(cookieObject)
                        }
                    }
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    func saveCookie() {
        let cookieJar: HTTPCookieStorage = HTTPCookieStorage.shared
        if let cookies = cookieJar.cookies {
            do {
                let data: Data = try NSKeyedArchiver.archivedData(withRootObject: cookies, requiringSecureCoding: false)
                let ud: UserDefaults = UserDefaults.standard
                ud.set(data, forKey: "cookie")
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    @available(iOS 15.0, *)
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        DispatchQueue.main.async {
            decisionHandler(.grant)
        }
    }
}

struct Egg: UIViewControllerRepresentable {
    var urlString: String
    
    func makeUIViewController(context: Context) -> CreateDetail {
        let viewController = CreateDetail()
        UserDefaults.standard.set(urlString, forKey: "config_url")
        Task {
            await viewController.showControls()
        }
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: CreateDetail, context: Context) {}
}

extension CreateDetail {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil || !(navigationAction.targetFrame?.isMainFrame ?? false) {
            webView.load(navigationAction.request)
        }
        return nil
    }
    
    func webViewDidClose(_ webView: WKWebView) {
        webView.removeFromSuperview()
        newPopupWindow = nil
    }
}

#Preview {
    NoInternet()
}
