import SwiftUI
import SafariServices

/// Presents an in-app Safari sheet to avoid bouncing through Universal Links
/// (which can trigger "Open in SnapChef?" prompts when the domain is associated).
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No-op.
    }
}

