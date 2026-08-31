import WebKit
import SwiftUI

@available(iOS 16.0, *)
final class AuthWebController: NSObject, ObservableObject, WKNavigationDelegate, WKHTTPCookieStoreObserver {
    static let authURL = URL(string: "https://my.centraluniversity.ru")!
    static let cookieName = "bff.cookie"
    static let callbackPath = "/api/account/signin/callback"

    @Published var progress: Double = 0
    @Published var isLoading = true
    @Published var errorText: String?

    let webView: WKWebView

    private var handled = false
    private var progressObservation: NSKeyValueObservation?

    var onCookie: ((String) -> Void)?

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
            DispatchQueue.main.async { self?.progress = view.estimatedProgress }
        }

        configuration.websiteDataStore.httpCookieStore.add(self)
    }

    deinit {
        progressObservation?.invalidate()
        webView.configuration.websiteDataStore.httpCookieStore.remove(self)
    }

    func start() {
        let store = webView.configuration.websiteDataStore
        store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { [weak self] in
            self?.load()
        }
    }

    func reload() {
        errorText = nil
        if webView.url == nil {
            load()
        } else {
            webView.reload()
        }
    }

    private func load() {
        isLoading = true
        errorText = nil
        webView.load(URLRequest(url: Self.authURL))
    }

    func rejectCookie(message: String) {
        handled = false
        errorText = message
    }

    private func checkCookies() {
        guard !handled else { return }
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self, !self.handled else { return }
            let match = cookies.first {
                $0.name == Self.cookieName && $0.domain.contains("centraluniversity.ru") && !$0.value.isEmpty
            }
            guard let match else { return }
            self.handled = true
            self.onCookie?(match.value)
        }
    }

    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        DispatchQueue.main.async { [weak self] in self?.checkCookies() }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        errorText = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        checkCookies()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        errorText = error.localizedDescription
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        decisionHandler(.allow)
        guard let url = navigationResponse.response.url, url.path.contains(Self.callbackPath) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.checkCookies() }
    }
}

@available(iOS 16.0, *)
struct AuthWebViewRepresentable: UIViewRepresentable {
    let controller: AuthWebController

    func makeUIView(context: Context) -> WKWebView {
        controller.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
