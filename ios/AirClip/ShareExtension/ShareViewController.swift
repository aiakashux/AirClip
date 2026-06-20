import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

/// Share Extension entry point.
///
/// iOS clipboard reads from extensions are unreliable (the text comes from the share
/// sheet's NSExtensionItem, not from UIPasteboard). This extension:
///   1. Extracts the shared text from the extension context
///   2. Stores it in the App Group container as a pending outbox item
///   3. Opens the main AirClip app via URL scheme so it can encrypt + send on foreground
///
/// The main app reads `AppConfig.appGroupID` defaults on `airclip://send` URL open.
final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        extractSharedText { [weak self] text in
            guard let text, !text.isEmpty else {
                self?.cancel()
                return
            }
            self?.queueAndOpenApp(text: text)
        }
    }

    // MARK: - Text extraction

    private func extractSharedText(completion: @escaping (String?) -> Void) {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem else {
            completion(nil)
            return
        }

        let textType = UTType.plainText.identifier

        for attachment in item.attachments ?? [] {
            if attachment.hasItemConformingToTypeIdentifier(textType) {
                attachment.loadItem(forTypeIdentifier: textType, options: nil) { item, _ in
                    DispatchQueue.main.async {
                        completion(item as? String)
                    }
                }
                return
            }
            // Also try URL (share from Safari, etc.)
            let urlType = UTType.url.identifier
            if attachment.hasItemConformingToTypeIdentifier(urlType) {
                attachment.loadItem(forTypeIdentifier: urlType, options: nil) { item, _ in
                    DispatchQueue.main.async {
                        let urlString = (item as? URL)?.absoluteString ?? (item as? String)
                        completion(urlString)
                    }
                }
                return
            }
        }
        completion(nil)
    }

    // MARK: - Queue + launch

    private func queueAndOpenApp(text: String) {
        // Write to App Group so the main app can read on next foreground
        let defaults = UserDefaults(suiteName: AppConfig.appGroupID)
        defaults?.set(text, forKey: "share_extension_outbox")
        defaults?.set(true, forKey: "widget_send_requested")

        // Open main app — works from an extension
        let url = URL(string: "\(AppConfig.urlScheme)://send")!
        var responder: UIResponder? = self
        while let r = responder {
            if let app = r as? UIApplication {
                app.open(url)
                break
            }
            responder = r.next
        }

        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: "AirClipShare", code: 0))
    }
}
