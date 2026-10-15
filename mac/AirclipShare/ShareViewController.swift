import AppKit
import UniformTypeIdentifiers

/// Finder's Share menu hands file URLs to the running app through the same
/// clipboard path used by Command-C. No file bytes are copied by the extension.
final class ShareViewController: NSViewController {
    private var didProcessRequest = false

    override func loadView() {
        // Finder hosts a share extension's view in a transient window. Keep that
        // host effectively invisible; the main app presents its own confirmation
        // directly beneath the Airclip menu-bar item after capture succeeds.
        preferredContentSize = NSSize(width: 1, height: 1)
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        view.isHidden = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        processSharedFiles()
    }

    private func processSharedFiles() {
        guard !didProcessRequest else { return }
        didProcessRequest = true
        let providers = (extensionContext?.inputItems as? [NSExtensionItem])?
            .flatMap { $0.attachments ?? [] } ?? []
        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL? = if let url = item as? URL { url }
                    else if let data = item as? Data { URL(dataRepresentation: data, relativeTo: nil) }
                    else { nil }
                if let url, url.isFileURL,
                   (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                    lock.lock()
                    urls.append(url)
                    lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            if !urls.isEmpty {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects(urls as [NSURL])
                NSPasteboard.general.setData(Data([1]), forType: NSPasteboard.PasteboardType("com.airclip.share-files"))
            }
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}
