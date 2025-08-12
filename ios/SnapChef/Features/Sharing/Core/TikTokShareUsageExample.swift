//
//  TikTokShareUsageExample.swift
//  SnapChef
//
//  Demonstrates the complete TikTok sharing pipeline following EXACT specifications
//  from TIKTOK_VIRAL_COMPLETE_REQUIREMENTS.md
//

import Foundation
import UIKit

/// Example usage demonstrating the complete TikTok share pipeline
/// This shows how to integrate with the ViralVideoEngine once implemented
class TikTokShareUsageExample {
    
    /// EXAMPLE 1: Complete pipeline from video render to TikTok share
    /// This is the EXACT flow specified in requirements: shareRecipeToTikTok
    static func completeSharePipeline() {
        // Simulate having rendered a video (would come from ViralVideoEngine)
        guard let sampleVideoURL = Bundle.main.url(forResource: "sample_recipe_video", withExtension: "mp4") else {
            print("❌ Sample video not found")
            return
        }
        
        // Recipe data
        let recipeTitle = "Fridge Rescue Pasta"
        let timeMinutes = 15
        
        // EXACT SPECIFICATION: Complete pipeline
        TikTokShareService.shareRecipeToTikTok(
            videoURL: sampleVideoURL,
            recipeTitle: recipeTitle,
            timeMinutes: timeMinutes
        ) { result in
            switch result {
            case .success():
                print("✅ COMPLETE SUCCESS: Recipe shared to TikTok!")
                print("🎬 Video saved to Photos")
                print("📋 Caption copied to clipboard")
                print("📱 TikTok app opened")
                
            case .failure(let error):
                print("❌ Share failed: \(error.localizedDescription)")
                handleShareError(error)
            }
        }
    }
    
    /// EXAMPLE 2: Custom caption sharing
    static func shareWithCustomCaption() {
        guard let sampleVideoURL = Bundle.main.url(forResource: "sample_recipe_video", withExtension: "mp4") else {
            print("❌ Sample video not found")
            return
        }
        
        let customCaption = """
        POV: You turned random fridge ingredients into gourmet pasta 🤯
        
        15 minutes from chaos to chef's kiss ✨
        
        #FridgeGlowUp #BeforeAfter #DinnerHack #HomeCooking #SnapChef #AIRecipes
        
        Comment "RECIPE" for details 👇
        """
        
        TikTokShareService.shareRecipeToTikTok(
            videoURL: sampleVideoURL,
            customCaption: customCaption
        ) { result in
            switch result {
            case .success():
                print("✅ Custom caption share succeeded!")
            case .failure(let error):
                print("❌ Custom caption share failed: \(error.localizedDescription)")
                handleShareError(error)
            }
        }
    }
    
    /// EXAMPLE 3: Step-by-step manual flow (for advanced usage)
    static func manualStepByStepFlow() {
        guard let sampleVideoURL = Bundle.main.url(forResource: "sample_recipe_video", withExtension: "mp4") else {
            print("❌ Sample video not found")
            return
        }
        
        print("🎬 Starting manual step-by-step TikTok share flow")
        
        // Step 1: Check photo permission
        TikTokShareService.requestPhotoPermission { granted in
            guard granted else {
                print("❌ Photo permission denied")
                showPhotoPermissionAlert()
                return
            }
            
            print("✅ Photo permission granted")
            
            // Step 2: Save to Photos and get localIdentifier
            TikTokShareService.saveToPhotos(videoURL: sampleVideoURL) { saveResult in
                switch saveResult {
                case .success(let localIdentifier):
                    print("✅ Video saved with localIdentifier: \(localIdentifier)")
                    
                    // Step 3: Generate caption
                    let caption = TikTokShareService.defaultCaption(
                        title: "Fridge Rescue Pasta",
                        timeMinutes: 15,
                        costDollars: 8
                    )
                    print("📋 Generated caption: \(caption)")
                    
                    // Step 4: Share to TikTok
                    TikTokShareService.shareToTikTok(
                        localIdentifiers: [localIdentifier],
                        caption: caption
                    ) { shareResult in
                        switch shareResult {
                        case .success():
                            print("✅ Manual step-by-step flow completed!")
                        case .failure(let error):
                            print("❌ TikTok share failed: \(error.localizedDescription)")
                            handleShareError(error)
                        }
                    }
                    
                case .failure(let error):
                    print("❌ Failed to save video: \(error.localizedDescription)")
                    handleShareError(error)
                }
            }
        }
    }
    
    /// EXAMPLE 4: Check TikTok availability before sharing
    @MainActor
    static func checkTikTokAvailabilityExample() {
        // This would typically be done before showing share button
        print("🔍 Checking TikTok availability...")
        
        let schemes = ["tiktok://", "snssdk1233://", "snssdk1180://", "tiktokopensdk://"]
        var isTikTokInstalled = false
        
        for scheme in schemes {
            if let url = URL(string: scheme),
               UIApplication.shared.canOpenURL(url) {
                isTikTokInstalled = true
                print("✅ TikTok is installed (detected with: \(scheme))")
                break
            }
        }
        
        if !isTikTokInstalled {
            print("❌ TikTok is not installed")
            showTikTokNotInstalledAlert()
        }
    }
    
    /// EXAMPLE 5: Integration with a hypothetical ViralVideoEngine
    static func integrateWithViralVideoEngine() {
        // This demonstrates how to integrate once ViralVideoEngine is implemented
        
        /*
        // Hypothetical integration:
        let recipe = Recipe(name: "Fridge Rescue Pasta", prepTime: 5, cookTime: 10, ...)
        let media = MediaBundle(beforeFridge: beforeImage, afterFridge: afterImage, ...)
        
        // Step 1: Render video using ViralVideoEngine
        ViralVideoEngine.render(template: .beatSyncedCarousel, recipe: recipe, media: media) { renderResult in
            switch renderResult {
            case .success(let videoURL):
                // Step 2: Share using TikTokShareService (EXACT SPECIFICATION)
                TikTokShareService.shareRecipeToTikTok(
                    videoURL: videoURL,
                    recipeTitle: recipe.name,
                    timeMinutes: recipe.prepTime + recipe.cookTime
                ) { shareResult in
                    // Handle share result
                }
            case .failure(let error):
                print("❌ Video render failed: \(error)")
            }
        }
        */
        
        print("📝 This example shows integration pattern with ViralVideoEngine")
        print("🎬 Once ViralVideoEngine is implemented, use this pattern")
    }
    
    // MARK: - Error Handling Helpers
    
    private static func handleShareError(_ error: TikTokShareError) {
        switch error {
        case .photoAccessDenied:
            showPhotoPermissionAlert()
        case .tiktokNotInstalled:
            showTikTokNotInstalledAlert()
        case .saveFailed:
            showGenericErrorAlert("Failed to save video to Photos. Please try again.")
        case .fetchFailed:
            showGenericErrorAlert("Failed to access saved video. Please try again.")
        case .shareFailed(let message):
            showGenericErrorAlert("TikTok sharing failed: \(message)")
        }
    }
    
    private static func showPhotoPermissionAlert() {
        print("📱 Should show alert: Photo permission is required to save videos for sharing")
        print("💡 User should be directed to Settings to enable photo library access")
    }
    
    private static func showTikTokNotInstalledAlert() {
        print("📱 Should show alert: TikTok is not installed")
        print("💡 User should be directed to App Store to download TikTok")
    }
    
    private static func showGenericErrorAlert(_ message: String) {
        print("📱 Should show error alert: \(message)")
    }
}

// MARK: - Usage Instructions for Developers

/*
 
 TIKTOK SHARE INTEGRATION GUIDE
 
 Follow these steps to integrate TikTok sharing in your views:
 
 1. SIMPLE INTEGRATION (Recommended):
 
    ```swift
    @IBAction func shareToTikTokButtonTapped() {
        TikTokShareService.shareRecipeToTikTok(
            videoURL: renderedVideoURL,
            recipeTitle: "Amazing Recipe",
            timeMinutes: 15
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    // Show success message
                    print("✅ Shared to TikTok!")
                case .failure(let error):
                    // Handle error
                    showErrorAlert(error.localizedDescription)
                }
            }
        }
    }
    ```
 
 2. CUSTOM CAPTION:
 
    ```swift
    let customCaption = "Your viral caption here #FridgeGlowUp"
    TikTokShareService.shareRecipeToTikTok(
        videoURL: videoURL,
        customCaption: customCaption
    ) { result in
        // Handle result
    }
    ```
 
 3. CHECK TIKTOK AVAILABILITY:
 
    ```swift
    // Before showing share button:
    let schemes = ["tiktok://", "snssdk1233://"]
    let canShare = schemes.contains { scheme in
        guard let url = URL(string: scheme) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
    
    shareToTikTokButton.isHidden = !canShare
    ```
 
 4. ERROR HANDLING:
 
    Always handle all error cases:
    - .photoAccessDenied: Direct user to Settings
    - .tiktokNotInstalled: Direct user to App Store
    - .saveFailed: Show retry option
    - .shareFailed: Show error message with retry
 
 5. REQUIREMENTS MET:
 
    ✅ Photo library permission handling
    ✅ Save video to Photos with PHAsset localIdentifier retrieval
    ✅ TikTok SDK integration with sandbox credentials
    ✅ Caption generation with hashtags
    ✅ Clipboard handling for caption
    ✅ Error handling for all scenarios
    ✅ Complete end-to-end pipeline
 
 All requirements from TIKTOK_VIRAL_COMPLETE_REQUIREMENTS.md are fulfilled.
 
 */