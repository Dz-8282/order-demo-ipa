import UIKit
import WebKit

/// 承载离线 HTML 的 WKWebView。
/// - 页面从 bundle 内 file:// 加载，无网络也能跑
/// - 接管 <input type="file"> 的点击，弹出「拍照 / 相册 / 文件」
/// - localStorage 位于 App 沙箱，卸载 App 才会清空
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
      assertionFailure("index.html 没有打进 bundle，检查 target 的 Copy Bundle Resources")
      return
    }

    let bundleRoot = Bundle.main.bundleURL
    let fileURL = URL(fileURLWithPath: indexPath)
    if #available(iOS 9.0, *) {
      webView.loadFileURL(fileURL, allowingReadAccessTo: bundleRoot)
    } else {
      webView.load(URLRequest(url: fileURL))
    }
  }

  // MARK: - WKUIDelegate

  /// 让 <input type="file"> 真正弹出相机/相册
  @available(iOS 9.0, *)
  func webView(_ webView: WKWebView,
               runOpenPanelWith parameters: WKOpenPanelParameters,
               initiatedByFrame frame: WKFrameInfo,
               completionHandler: @escaping ([URL]?) -> Void) {
    let sheet = UIAlertController(title: "选择产品图", message: nil, preferredStyle: .actionSheet)
    sheet.addAction(UIAlertAction(title: "拍照", style: .default) { _ in
      self.presentMediaPicker(source: .camera, completionHandler: completionHandler)
    })
    sheet.addAction(UIAlertAction(title: "从相册选择", style: .default) { _ in
      self.presentMediaPicker(source: .photoLibrary, completionHandler: completionHandler)
    })
    sheet.addAction(UIAlertAction(title: "文件", style: .default) { _ in
      self.presentDocumentPicker(completionHandler: completionHandler)
    })
    sheet.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
      completionHandler(nil)
    })

    // iPad 上 action sheet 需要锚点
    if let popover = sheet.popoverPresentationController {
      popover.sourceView = view
      popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
    }
    present(sheet, animated: true)
  }

  private func presentMediaPicker(source: UIImagePickerController.SourceType,
                                  completionHandler: @escaping ([URL]?) -> Void) {
    guard UIImagePickerController.isSourceTypeAvailable(source) else {
      completionHandler(nil)
      return
    }
    let picker = UIImagePickerController()
    picker.sourceType = source
    picker.mediaTypes = ["public.image"]
    picker.delegate = self
    pendingOpenPanel = completionHandler
    present(picker, animated: true)
  }

  private func presentDocumentPicker(completionHandler: @escaping ([URL]?) -> Void) {
    let picker = UIDocumentPickerViewController(documentTypes: ["public.image"], in: .import)
    picker.delegate = self
    pendingOpenPanel = completionHandler
    present(picker, animated: true)
  }

  private var pendingOpenPanel: (([URL]?) -> Void)?

  private func finishOpenPanel(with url: URL?) {
    guard let handler = pendingOpenPanel else { return }
    pendingOpenPanel = nil
    guard let url = url else { handler(nil); return }
    let tmp = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString + "." + (url.pathExtension.isEmpty ? "jpg" : url.pathExtension))
    do {
      try FileManager.default.copyItem(at: url, to: tmp)
      handler([tmp])
    } catch {
      handler([url])
    }
  }

  private func finishOpenPanel(with image: UIImage?) {
    guard let handler = pendingOpenPanel else { return }
    pendingOpenPanel = nil
    guard let image = image, let data = image.jpegData(compressionQuality: 0.9) else { handler(nil); return }
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
    do {
      try data.write(to: tmp)
      handler([tmp])
    } catch {
      handler(nil)
    }
  }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  func imagePickerController(_ picker: UIImagePickerController,
                             didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
    picker.dismiss(animated: true)
    if let url = info[.imageURL] as? URL {
      finishOpenPanel(with: url)
    } else {
      finishOpenPanel(with: info[.originalImage] as? UIImage)
    }
  }

  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true) { [weak self] in
      self?.finishOpenPanel(with: nil)
    }
  }
}

extension ViewController: UIDocumentPickerDelegate {
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    finishOpenPanel(with: urls.first)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finishOpenPanel(with: nil)
  }
}
