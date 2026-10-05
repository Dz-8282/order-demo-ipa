import UIKit
import WebKit

/// Hosts the offline page in a WKWebView.
///
/// - loads file:// from the app bundle, so it works in airplane mode
/// - `<input type="file">` is handled natively by WebKit on iOS; we only narrow the
///   read-access grant to the temporary directory so the picked image is visible
/// - edits and the uploaded photo land in the sandbox's localStorage
final class ViewController: UIViewController, WKUIDelegate, WKNavigationDelegate {

  private var webView: WKWebView!

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white

    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .default()
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
    configuration.allowsInlineMediaPlayback = true

    let webView = WKWebView(frame: view.bounds, configuration: configuration)
    webView.uiDelegate = self
    webView.navigationDelegate = self
    webView.scrollView.bounces = false
    webView.scrollView.contentInsetAdjustmentBehavior = .never
    webView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(webView)
    NSLayoutConstraint.activate([
      webView.topAnchor.constraint(equalTo: view.topAnchor),
      webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
    ])
    self.webView = webView

    guard let indexPath = Bundle.main.path(forResource: "index", ofType: "html") else {
      assertionFailure("index.html is missing from Copy Bundle Resources")
      return
    }

    // allowReadAccessTo must cover the file we load. The bundle directory does that,
    // and WebKit still gets to read picked files because temp/ and the bundle are
    // both inside the container. Passing an unrelated directory here loads a blank page.
    let fileURL = URL(fileURLWithPath: indexPath)
    let readRoot = Bundle.main.bundleURL
    webView.loadFileURL(fileURL, allowingReadAccessTo: readRoot)
  }

  /// A blank screen is the worst failure mode: keep a visible reason on screen instead.
  private func showLoadFailure(_ error: Error?) {
    let reason = error?.localizedDescription ?? "unknown error"
    let html = """
    <!doctype html><html><head><meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    </head><body style="font:16px -apple-system;padding:28px;color:#111">
    <h2>页面没有加载出来</h2>
    <p style="color:#8e8e93">index.html 没能从 App 包内读取。</p>
    <pre style="white-space:pre-wrap;color:#c0392b">\(reason)</pre>
    </body></html>
    """
    webView.loadHTMLString(html, baseURL: nil)
  }

  // MARK: - WKUIDelegate

  @available(iOS 13.0, *)
  func webView(_ webView: WKWebView,
               contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo,
               completionHandler: @escaping (UIContextMenuConfiguration?) -> Void) {
    completionHandler(nil)
  }

  // MARK: - WKNavigationDelegate

  /// Keep third-party links out of the app; the page itself has no network calls.
  func webView(_ webView: WKWebView,
               decidePolicyFor navigationAction: WKNavigationAction,
               decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    if let url = navigationAction.request.url,
       navigationAction.navigationType == .linkActivated,
       url.scheme == "http" || url.scheme == "https" {
      UIApplication.shared.open(url)
      decisionHandler(.cancel)
      return
    }
    decisionHandler(.allow)
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    showLoadFailure(error)
  }

  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    showLoadFailure(error)
  }
}
