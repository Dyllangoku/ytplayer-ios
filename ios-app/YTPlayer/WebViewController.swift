import UIKit
import WebKit

/// 유튜브 / 유튜브 뮤직 화면 하나
final class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private let homeURL: URL
    private var webView: WKWebView!

    private static let isPlayingJS =
        "(()=>{const v=document.querySelector('video');return !!(v&&!v.paused&&!v.ended)})()"

    init(title: String, url: URL, symbol: String) {
        homeURL = url
        super.init(nibName: nil, bundle: nil)
        self.title = title
        tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: symbol), tag: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .default()   // 두 탭이 로그인 정보 공유
        // 구글 로그인이 막히지 않도록 실제 iOS 버전의 사파리와 같은 이름표를 붙인다
        let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        config.applicationNameForUserAgent = "Version/\(major).0 Mobile/15E148 Safari/604.1"

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true

        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(pullToRefresh(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refresh

        installScript()
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        webView.load(URLRequest(url: homeURL))

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(scriptUpdated),
                           name: .ytScriptUpdated, object: nil)
        center.addObserver(self, selector: #selector(willDeactivate),
                           name: UIScene.willDeactivateNotification, object: nil)
        center.addObserver(self, selector: #selector(didEnterBackground),
                           name: UIScene.didEnterBackgroundNotification, object: nil)
    }

    // MARK: 차단 스크립트 (유튜브 주소에서만)

    private func installScript() {
        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        controller.addUserScript(WKUserScript(source: ScriptManager.shared.source,
                                              injectionTime: .atDocumentStart,
                                              forMainFrameOnly: true))
    }

    private static func isYouTube(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host == "youtube.com" || host.hasSuffix(".youtube.com")
    }

    @objc private func scriptUpdated() {
        if let url = webView.url, Self.isYouTube(url) { installScript() }
        // 재생 중이면 끊지 않고, 다음에 새로고침할 때 적용
        webView.evaluateJavaScript(Self.isPlayingJS) { [weak self] result, _ in
            if (result as? Bool) != true { self?.webView.reload() }
        }
    }

    // MARK: 백그라운드 재생 보조 (재생 여부는 페이지 안에 기록 → 알림 순서 꼬임 방지)

    @objc private func willDeactivate() {
        webView.evaluateJavaScript("window.__ytWas=\(Self.isPlayingJS)", completionHandler: nil)
    }

    @objc private func didEnterBackground() {
        // 아이폰이 앱을 내리면서 멈춘 경우 다시 재생
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.webView.evaluateJavaScript(
                "(()=>{const v=document.querySelector('video');if(window.__ytWas&&v&&v.paused&&!v.ended)v.play().catch(()=>{});})()",
                completionHandler: nil)
        }
    }

    func pauseMedia() {
        webView?.evaluateJavaScript(
            "window.__ytabPauseAll ? __ytabPauseAll() : document.querySelectorAll('video,audio').forEach(m=>m.pause())",
            completionHandler: nil)
    }

    @objc private func pullToRefresh(_ sender: UIRefreshControl) {
        webView.reload()
        sender.endRefreshing()
    }

    // MARK: 링크 처리

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url,
              ["http", "https", "about", "blob", "data"].contains(url.scheme?.lowercased() ?? "") else {
            decisionHandler(.cancel)   // 유튜브 앱·앱스토어로 튕겨 나가는 링크는 막는다
            return
        }
        // 페이지 이동 때마다: 유튜브면 차단 스크립트 넣기, 그 외(구글 로그인 등)면 빼기
        if navigationAction.targetFrame?.isMainFrame ?? true, url.scheme?.hasPrefix("http") == true {
            if Self.isYouTube(url) {
                installScript()
            } else {
                webView.configuration.userContentController.removeAllUserScripts()
            }
        }
        // allow + 2 = 유튜브 앱으로 자동 전환(유니버설 링크) 없이 이 화면에서 열기
        decisionHandler(WKNavigationActionPolicy(rawValue: WKNavigationActionPolicy.allow.rawValue + 2) ?? .allow)
    }

    // 새 창으로 열리는 링크(로그인 등)는 같은 화면에서 연다
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
        return nil
    }
}
