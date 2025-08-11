//
//  ShareSheetPresenter.swift
//  SnapChef
//
//  Created on 02/03/2025
//

import SwiftUI
import UIKit

@MainActor
class ShareSheetPresenter {
    static let shared = ShareSheetPresenter()
    private weak var currentActivityController: UIActivityViewController?
    
    private init() {}
    
    func present(items: [Any], from sourceView: UIView? = nil) {
        // Dismiss any existing activity controller first
        if let current = currentActivityController {
            current.dismiss(animated: false) {
                self.presentNew(items: items, from: sourceView)
            }
        } else {
            presentNew(items: items, from: sourceView)
        }
    }
    
    private func presentNew(items: [Any], from sourceView: UIView?) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        // Configure for iPad
        if let popover = activityViewController.popoverPresentationController {
            if let sourceView = sourceView {
                popover.sourceView = sourceView
                popover.sourceRect = sourceView.bounds
            } else {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(
                    x: rootViewController.view.bounds.midX,
                    y: rootViewController.view.bounds.midY,
                    width: 0,
                    height: 0
                )
            }
        }
        
        currentActivityController = activityViewController
        
        // Find the topmost presented view controller
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }
        
        // Present from the topmost controller
        topController.present(activityViewController, animated: true)
    }
    
    func dismiss() {
        currentActivityController?.dismiss(animated: true)
        currentActivityController = nil
    }
}

// MARK: - SwiftUI Bridge
struct SystemShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented {
            ShareSheetPresenter.shared.present(items: items, from: uiViewController.view)
            
            // Reset the binding after a delay to avoid re-presentation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isPresented = false
            }
        }
    }
}