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

    let fileURL = URL(fileURLWithPath: indexPath)
    // Narrow the grant to the temp dir (that is where picked images are staged) plus the bundle.
    let tempDir = FileManager.default.temporaryDirectory
    webView.loadFileURL(fileURL, allowingReadAccessTo: tempDir)
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
}
