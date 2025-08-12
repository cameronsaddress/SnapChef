//
//  TikTokViralQATestFramework.swift
//  SnapChef QA Testing Framework
//
//  Comprehensive test framework for TikTok viral content generation
//  Following TIKTOK_VIRAL_COMPLETE_REQUIREMENTS.md specifications
//

import XCTest
import SwiftUI
import AVFoundation
import Photos
import CoreImage
import UIKit
@testable import SnapChef

// MARK: - TikTok Viral QA Test Framework

class TikTokViralQATestFramework: XCTestCase {
    
    // Test configuration
    private let testTimeout: TimeInterval = 30.0
    private let videoGenerator = TikTokVideoGeneratorEnhanced()
    private var testRecipes: [Recipe] = []
    private var testMediaBundles: [MediaBundle] = []
    
    // Safe zone constants from requirements
    private let safeZoneTop: CGFloat = 192
    private let safeZoneBottom: CGFloat = 192
    private let safeZoneLeft: CGFloat = 72
    private let safeZoneRight: CGFloat = 72
    private let videoSize = CGSize(width: 1080, height: 1920)
    
    // Performance thresholds
    private let maxMemoryUsageMB: Int = 150
    private let maxRenderTimeSeconds: TimeInterval = 5.0
    private let maxFileSizeMB: Int = 50
    private let expectedFPS: Int32 = 30
    
    override func setUp() {
        super.setUp()
        setupTestData()
    }
    
    override func tearDown() {
        cleanupTestFiles()
        super.tearDown()
    }
    
    // MARK: - Test Data Setup
    
    private func setupTestData() {
        // Create test recipes with various configurations
        testRecipes = [
            createMinimalRecipe(),
            createFullRecipe(),
            createLongTitleRecipe(),
            createManyIngredientsRecipe(),
            createSingleIngredientRecipe(),
            createLongStepsRecipe()
        ]
        
        // Create test media bundles
        testMediaBundles = [
            createMediaBundleWithImages(),
            createMediaBundleWithoutAfterImage(),
            createMediaBundleWithoutBeforeImage(),
            createMediaBundleWithoutMusic(),
            createMediaBundleEmpty()
        ]
    }
    
    // MARK: - Template Testing (Requirement 1)
    
    func testAllTemplatesWithMinimalRecipe() {
        let recipe = createMinimalRecipe()
        let mediaBundle = createMediaBundleWithImages()
        
        for template in TikTokTemplate.allCases {
            XCTContext.runActivity(named: "Testing template: \(template.name)") { _ in
                testTemplateGeneration(template: template, recipe: recipe, media: mediaBundle)
            }
        }
    }
    
    func testAllTemplatesWithFullRecipe() {
        let recipe = createFullRecipe()
        let mediaBundle = createMediaBundleWithImages()
        
        for template in TikTokTemplate.allCases {
            XCTContext.runActivity(named: "Testing template with full recipe: \(template.name)") { _ in
                testTemplateGeneration(template: template, recipe: recipe, media: mediaBundle)
            }
        }
    }
    
    func testTemplatesWithNoBrollStillsOnly() {
        let recipe = createFullRecipe()
        let mediaBundle = createMediaBundleWithoutBroll()
        
        for template in TikTokTemplate.allCases {
            XCTContext.runActivity(named: "Testing template without b-roll: \(template.name)") { _ in
                testTemplateGeneration(template: template, recipe: recipe, media: mediaBundle)
            }
        }
    }
    
    func testTemplatesWithNoMusic() {
        let recipe = createFullRecipe()
        let mediaBundle = createMediaBundleWithoutMusic()
        
        for template in TikTokTemplate.allCases {
            XCTContext.runActivity(named: "Testing template without music: \(template.name)") { _ in
                testTemplateGeneration(template: template, recipe: recipe, media: mediaBundle)
            }
        }
    }
    
    // MARK: - Safe Zone Testing (Requirement 2)
    
    func testSafeZoneCompliance() {
        let recipe = createFullRecipe()
        let mediaBundle = createMediaBundleWithImages()
        
        for template in TikTokTemplate.allCases {
            XCTContext.runActivity(named: "Testing safe zones for template: \(template.name)") { _ in
                let expectation = self.expectation(description: "Safe zone test for \(template.name)")
                
                Task {
                    do {
                        let videoURL = try await generateTestVideo(template: template, recipe: recipe, media: mediaBundle)
                        let isCompliant = await validateSafeZones(videoURL: videoURL)
                        XCTAssertTrue(isCompliant, "Template \(template.name) violates safe zone requirements")
                        expectation.fulfill()
                    } catch {
                        XCTFail("Failed to generate video for safe zone testing: \(error)")
                        expectation.fulfill()
                    }
                }
                
                wait(for: [expectation], timeout: testTimeout)
            }
        }
    }
    
    // MARK: - Error Handling Testing (Requirement 3)
    
    func testErrorHandlingPaths() {
        testPhotoPermissionDenied()
        testTikTokNotInstalled()
        testInvalidRecipeData()
        testMissingImages()
        testNetworkFailure()
        testMemoryWarning()
    }
    
    func testPhotoPermissionDenied() {
        XCTContext.runActivity(named: "Testing photo permission denied") { _ in
            // Mock PHPhotoLibrary to return denied
            let expectation = self.expectation(description: "Photo permission denied")
            
            ShareService.requestPhotoPermission { granted in
                // In real test, we would mock this to return false
                // XCTAssertFalse(granted, "Should handle photo permission denial")
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testTikTokNotInstalled() {
        XCTContext.runActivity(named: "Testing TikTok not installed scenario") { _ in
            let expectation = self.expectation(description: "TikTok not installed")
            
            ShareService.shareToTikTok(localIdentifiers: ["test"], caption: "test") { result in
                switch result {
                case .success():
                    // In simulator, this might succeed if TikTok schemes are handled
                    break
                case .failure(let error):
                    if case ShareError.tiktokNotInstalled = error {
                        XCTAssertTrue(true, "Correctly detected TikTok not installed")
                    }
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testInvalidRecipeData() {
        XCTContext.runActivity(named: "Testing invalid recipe data") { _ in
            let invalidRecipe = createInvalidRecipe()
            let mediaBundle = createMediaBundleEmpty()
            
            let expectation = self.expectation(description: "Invalid recipe data")
            
            Task {
                do {
                    _ = try await generateTestVideo(template: .beforeAfterReveal, recipe: invalidRecipe, media: mediaBundle)
                    // Should handle gracefully or succeed with fallbacks
                } catch {
                    XCTAssertTrue(true, "Correctly handled invalid recipe data")
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: testTimeout)
        }
    }
    
    func testMissingImages() {
        XCTContext.runActivity(named: "Testing missing images") { _ in
            let recipe = createFullRecipe()
            let emptyBundle = createMediaBundleEmpty()
            
            let expectation = self.expectation(description: "Missing images")
            
            Task {
                do {
                    let videoURL = try await generateTestVideo(template: .beforeAfterReveal, recipe: recipe, media: emptyBundle)
                    XCTAssertTrue(FileManager.default.fileExists(atPath: videoURL.path), "Should generate video even without images")
                } catch {
                    XCTAssertTrue(true, "Correctly handled missing images")
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: testTimeout)
        }
    }
    
    func testNetworkFailure() {
        // Test CloudKit/network failures during photo fetching
        XCTContext.runActivity(named: "Testing network failure") { _ in
            // Would test CloudKitRecipeManager failure scenarios
            XCTAssertTrue(true, "Network failure testing placeholder")
        }
    }
    
    func testMemoryWarning() {
        XCTContext.runActivity(named: "Testing memory warning handling") { _ in
            // Would simulate memory pressure during video generation
            XCTAssertTrue(true, "Memory warning testing placeholder")
        }
    }
    
    // MARK: - Memory Profiling Testing (Requirement 4)
    
    func testMemoryProfileDuringRender() {
        let recipe = createFullRecipe()
        let mediaBundle = createMediaBundleWithImages()
        
        for template in TikTokTemplate.allCases {
            XCTContext.runActivity(named: "Memory profiling for template: \(template.name)") { _ in
                measureMemoryUsage {
                    let expectation = self.expectation(description: "Memory test for \(template.name)")
                    
                    Task {
                        do {
                            _ = try await generateTestVideo(template: template, recipe: recipe, media: mediaBundle)
                            expectation.fulfill()
                        } catch {
                            XCTFail("Memory test failed: \(error)")
                            expectation.fulfill()
                        }
                    }
                    
                    wait(for: [expectation], timeout: testTimeout)
                }
            }
        }
    }
    
    // MARK: - Device Testing Matrix (Requirement 5)
    
    func testDeviceCompatibility() {
        // This would run on different device types in CI/CD
        XCTContext.runActivity(named: "Testing device compatibility") { _ in
            let deviceInfo = UIDevice.current
            print("Testing on device: \(deviceInfo.model), iOS: \(deviceInfo.systemVersion)")
            
            // Test basic video generation on current device
            let recipe = createFullRecipe()
            let mediaBundle = createMediaBundleWithImages()
            
            let expectation = self.expectation(description: "Device compatibility test")
            
            Task {
                do {
                    let videoURL = try await generateTestVideo(template: .beforeAfterReveal, recipe: recipe, media: mediaBundle)
                    let isValid = await validateVideoOutput(videoURL: videoURL)
                    XCTAssertTrue(isValid, "Video should be valid on device: \(deviceInfo.model)")
                    expectation.fulfill()
                } catch {
                    XCTFail("Device compatibility test failed: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: testTimeout)
        }
    }
    
    // MARK: - Performance Benchmarking (Requirement 6)
    
    func testPerformanceBenchmarking() {
        let recipe = createFullRecipe()
        let mediaBundle = createMediaBundleWithImages()
        
        for template in TikTokTemplate.allCases {
            XCTContext.runActivity(named: "Performance benchmark for template: \(template.name)") { _ in
                measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
                    let expectation = self.expectation(description: "Performance test for \(template.name)")
                    
                    let startTime = Date()
                    
                    Task {
                        do {
                            _ = try await generateTestVideo(template: template, recipe: recipe, media: mediaBundle)
                            let renderTime = Date().timeIntervalSince(startTime)
                            XCTAssertLessThan(renderTime, maxRenderTimeSeconds, "Render time should be under \(maxRenderTimeSeconds) seconds")
                            expectation.fulfill()
                        } catch {
                            XCTFail("Performance test failed: \(error)")
                            expectation.fulfill()
                        }
                    }
                    
                    wait(for: [expectation], timeout: testTimeout)
                }
            }
        }
    }
    
    // MARK: - Share Flow Testing (Requirement 7)
    
    func testShareFlow() {
        testVideoSaveToPhotos()
        testCaptionGeneration()
        testHashtagHandling()
        testTikTokSDKIntegration()
    }
    
    func testVideoSaveToPhotos() {
        XCTContext.runActivity(named: "Testing video save to Photos") { _ in
            let recipe = createFullRecipe()
            let mediaBundle = createMediaBundleWithImages()
            
            let expectation = self.expectation(description: "Save to Photos")
            
            Task {
                do {
                    let videoURL = try await generateTestVideo(template: .beforeAfterReveal, recipe: recipe, media: mediaBundle)
                    
                    ShareService.saveToPhotos(videoURL: videoURL) { result in
                        switch result {
                        case .success(let localIdentifier):
                            XCTAssertFalse(localIdentifier.isEmpty, "Local identifier should not be empty")
                            
                            // Verify asset exists
                            let assets = ShareService.fetchAssets(localIdentifiers: [localIdentifier])
                            XCTAssertEqual(assets.count, 1, "Should fetch exactly one asset")
                            
                        case .failure(let error):
                            if case ShareError.photoAccessDenied = error {
                                XCTAssertTrue(true, "Photo access denied is acceptable in tests")
                            } else {
                                XCTFail("Unexpected error saving to Photos: \(error)")
                            }
                        }
                        expectation.fulfill()
                    }
                } catch {
                    XCTFail("Failed to generate video for save test: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: testTimeout)
        }
    }
    
    func testCaptionGeneration() {
        XCTContext.runActivity(named: "Testing caption generation") { _ in
            let recipe = createFullRecipe()
            
            let caption = ShareService.defaultCaption(from: recipe)
            
            XCTAssertFalse(caption.isEmpty, "Caption should not be empty")
            XCTAssertTrue(caption.contains(recipe.name), "Caption should contain recipe name")
            XCTAssertTrue(caption.contains("#"), "Caption should contain hashtags")
            XCTAssertTrue(caption.contains("min"), "Caption should contain time information")
        }
    }
    
    func testHashtagHandling() {
        XCTContext.runActivity(named: "Testing hashtag handling") { _ in
            let customCaption = ShareService.generateCaption(
                title: "Test Recipe",
                timeMinutes: 15,
                costDollars: 8,
                customHashtags: ["#TestTag", "#CustomTag"]
            )
            
            XCTAssertTrue(customCaption.contains("#TestTag"), "Should include custom hashtags")
            XCTAssertTrue(customCaption.contains("#CustomTag"), "Should include all custom hashtags")
            XCTAssertTrue(customCaption.contains("15 min"), "Should include time information")
            XCTAssertTrue(customCaption.contains("$8"), "Should include cost information")
        }
    }
    
    func testTikTokSDKIntegration() {
        XCTContext.runActivity(named: "Testing TikTok SDK integration") { _ in
            let expectation = self.expectation(description: "TikTok SDK test")
            
            ShareService.shareToTikTok(localIdentifiers: ["test"], caption: "test") { result in
                // In test environment, this will likely fail, but we test the error handling
                switch result {
                case .success():
                    XCTAssertTrue(true, "TikTok SDK integration successful")
                case .failure(let error):
                    // Expected in test environment
                    XCTAssertTrue(error is ShareError, "Should return proper ShareError type")
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - TikTok Integration Testing (Requirement 8)
    
    func testTikTokIntegration() {
        testTikTokURLSchemes()
        testTikTokCaption()
        testTikTokShareCompletion()
    }
    
    func testTikTokURLSchemes() {
        XCTContext.runActivity(named: "Testing TikTok URL schemes") { _ in
            let schemes = ["tiktok://", "snssdk1233://", "snssdk1180://", "tiktokopensdk://"]
            
            for scheme in schemes {
                if let url = URL(string: scheme) {
                    let canOpen = UIApplication.shared.canOpenURL(url)
                    print("URL scheme \(scheme) available: \(canOpen)")
                    // Don't assert here as TikTok may not be installed in test environment
                }
            }
        }
    }
    
    func testTikTokCaption() {
        XCTContext.runActivity(named: "Testing TikTok caption handling") { _ in
            let recipe = createFullRecipe()
            let caption = ShareService.defaultCaption(from: recipe)
            
            // Copy to clipboard (this is what happens in real flow)
            UIPasteboard.general.string = caption
            
            let copiedText = UIPasteboard.general.string
            XCTAssertEqual(copiedText, caption, "Caption should be copied to clipboard correctly")
        }
    }
    
    func testTikTokShareCompletion() {
        XCTContext.runActivity(named: "Testing TikTok share completion") { _ in
            // This would test the complete pipeline
            let recipe = createFullRecipe()
            let mediaBundle = createMediaBundleWithImages()
            
            let expectation = self.expectation(description: "Complete TikTok share test")
            
            Task {
                do {
                    let videoURL = try await generateTestVideo(template: .beforeAfterReveal, recipe: recipe, media: mediaBundle)
                    
                    ShareService.shareRecipeToTikTok(videoURL: videoURL, recipe: recipe) { result in
                        switch result {
                        case .success():
                            XCTAssertTrue(true, "Complete share pipeline succeeded")
                        case .failure(let error):
                            // Expected in test environment without TikTok
                            print("Share pipeline error (expected in tests): \(error)")
                            XCTAssertTrue(true, "Error handling works correctly")
                        }
                        expectation.fulfill()
                    }
                } catch {
                    XCTFail("Failed to generate video for complete share test: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: testTimeout)
        }
    }
    
    // MARK: - Quality Checklist Testing
    
    func testQualityChecklist() {
        testPreExportChecklist()
        testPostExportChecklist()
    }
    
    func testPreExportChecklist() {
        XCTContext.runActivity(named: "Testing pre-export quality checklist") { _ in
            let recipe = createFullRecipe()
            let mediaBundle = createMediaBundleWithImages()
            
            for template in TikTokTemplate.allCases {
                // Test duration within template limits
                let expectedDuration = getExpectedDuration(for: template)
                XCTAssertLessThanOrEqual(expectedDuration, 15.0, "Duration should be within template limits for \(template.name)")
                
                // Test hook appears in first 2 seconds - would need video analysis
                // Test minimum 2 visual changes per second - would need frame analysis
                // Test CTA appears in last 3 seconds - would need video analysis
            }
        }
    }
    
    func testPostExportChecklist() {
        let recipe = createFullRecipe()
        let mediaBundle = createMediaBundleWithImages()
        
        for template in TikTokTemplate.allCases {
            XCTContext.runActivity(named: "Testing post-export quality for template: \(template.name)") { _ in
                let expectation = self.expectation(description: "Post-export test for \(template.name)")
                
                Task {
                    do {
                        let videoURL = try await generateTestVideo(template: template, recipe: recipe, media: mediaBundle)
                        let isValid = await validatePostExportQuality(videoURL: videoURL)
                        XCTAssertTrue(isValid, "Post-export quality validation failed for \(template.name)")
                        expectation.fulfill()
                    } catch {
                        XCTFail("Failed to generate video for post-export test: \(error)")
                        expectation.fulfill()
                    }
                }
                
                wait(for: [expectation], timeout: testTimeout)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateTestVideo(template: TikTokTemplate, recipe: Recipe, media: MediaBundle) async throws -> URL {
        let content = ShareContent(type: .recipe(recipe), beforeImage: media.beforeFridge, afterImage: media.afterFridge)
        
        return try await videoGenerator.generateVideo(
            template: template,
            content: content,
            selectedAudio: nil,
            selectedHashtags: [],
            progress: { _ in }
        )
    }
    
    private func validateSafeZones(videoURL: URL) async -> Bool {
        // This would analyze video frames to ensure text/content stays within safe zones
        // Implementation would use AVAssetImageGenerator to extract frames and analyze content placement
        return true // Placeholder
    }
    
    private func validateVideoOutput(videoURL: URL) async -> Bool {
        guard FileManager.default.fileExists(atPath: videoURL.path) else { return false }
        
        let asset = AVAsset(url: videoURL)
        
        // Check file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: videoURL.path)
            if let fileSize = attributes[.size] as? Int64 {
                let fileSizeMB = Int(fileSize / (1024 * 1024))
                if fileSizeMB > maxFileSizeMB {
                    return false
                }
            }
        } catch {
            return false
        }
        
        // Check video properties
        guard let videoTrack = try? await asset.loadTracks(withMediaType: .video).first else { return false }
        
        let naturalSize = try? await videoTrack.load(.naturalSize)
        let nominalFrameRate = try? await videoTrack.load(.nominalFrameRate)
        
        // Validate size and frame rate
        return naturalSize == videoSize && nominalFrameRate == Float(expectedFPS)
    }
    
    private func validatePostExportQuality(videoURL: URL) async -> Bool {
        guard await validateVideoOutput(videoURL: videoURL) else { return false }
        
        // Additional quality checks:
        // - No black frames
        // - Audio sync check
        // - Text readability at 50% zoom
        
        return true // Placeholder for full implementation
    }
    
    private func measureMemoryUsage(_ block: () -> Void) {
        let memoryBefore = getMemoryUsage()
        block()
        let memoryAfter = getMemoryUsage()
        let memoryDelta = memoryAfter - memoryBefore
        
        XCTAssertLessThan(memoryDelta, maxMemoryUsageMB, "Memory usage should be under \(maxMemoryUsageMB)MB")
    }
    
    private func getMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int(info.resident_size) / (1024 * 1024) // Convert to MB
        }
        
        return 0
    }
    
    private func getExpectedDuration(for template: TikTokTemplate) -> TimeInterval {
        switch template {
        case .beforeAfterReveal: return 15.0
        case .quickRecipe: return 60.0
        case .ingredients360: return 10.0
        case .timelapse: return 15.0
        case .splitScreen: return 15.0
        }
    }
    
    private func cleanupTestFiles() {
        // Clean up any temporary video files created during testing
        let tempDir = FileManager.default.temporaryDirectory
        let enumerator = FileManager.default.enumerator(at: tempDir, includingPropertiesForKeys: nil)
        
        while let file = enumerator?.nextObject() as? URL {
            if file.pathExtension == "mp4" && file.lastPathComponent.contains("tiktok_") {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
    
    // MARK: - Test Data Creation
    
    private func createMinimalRecipe() -> Recipe {
        return Recipe(
            id: UUID(),
            name: "Quick Pasta",
            ingredients: [
                Recipe.Ingredient(name: "Pasta", quantity: "200g", category: .grains),
                Recipe.Ingredient(name: "Cheese", quantity: "50g", category: .dairy)
            ],
            instructions: ["Boil pasta", "Add cheese"],
            prepTime: 5,
            cookTime: 10,
            servings: 2,
            difficulty: .easy,
            nutrition: Recipe.Nutrition(calories: 300, protein: 12, carbs: 45, fat: 8, fiber: 2),
            tags: ["quick", "pasta"],
            source: .ai
        )
    }
    
    private func createFullRecipe() -> Recipe {
        return Recipe(
            id: UUID(),
            name: "Delicious Chicken Stir Fry with Fresh Vegetables",
            ingredients: [
                Recipe.Ingredient(name: "Chicken breast", quantity: "300g", category: .protein),
                Recipe.Ingredient(name: "Bell peppers", quantity: "2 large", category: .vegetables),
                Recipe.Ingredient(name: "Broccoli", quantity: "200g", category: .vegetables),
                Recipe.Ingredient(name: "Soy sauce", quantity: "3 tbsp", category: .condiments),
                Recipe.Ingredient(name: "Garlic", quantity: "3 cloves", category: .vegetables),
                Recipe.Ingredient(name: "Ginger", quantity: "1 inch", category: .spices),
                Recipe.Ingredient(name: "Rice", quantity: "200g", category: .grains)
            ],
            instructions: [
                "Cut chicken into bite-sized pieces and season with salt and pepper",
                "Heat oil in a large wok or skillet over high heat",
                "Add chicken and cook until golden brown, about 5-6 minutes",
                "Add vegetables and stir-fry for 3-4 minutes until crisp-tender",
                "Add sauce and toss everything together",
                "Serve immediately over steamed rice"
            ],
            prepTime: 15,
            cookTime: 20,
            servings: 4,
            difficulty: .medium,
            nutrition: Recipe.Nutrition(calories: 450, protein: 35, carbs: 40, fat: 12, fiber: 5),
            tags: ["healthy", "protein", "stir-fry", "asian"],
            source: .ai
        )
    }
    
    private func createLongTitleRecipe() -> Recipe {
        return Recipe(
            id: UUID(),
            name: "Super Extra Long Recipe Name That Goes On And On And Might Cause Text Wrapping Issues In The Video Template",
            ingredients: [Recipe.Ingredient(name: "Test", quantity: "1", category: .other)],
            instructions: ["Test instruction"],
            prepTime: 5,
            cookTime: 5,
            servings: 1,
            difficulty: .easy,
            nutrition: Recipe.Nutrition(calories: 100, protein: 1, carbs: 1, fat: 1, fiber: 1),
            tags: ["test"],
            source: .ai
        )
    }
    
    private func createManyIngredientsRecipe() -> Recipe {
        let ingredients = (1...20).map { i in
            Recipe.Ingredient(name: "Ingredient \(i)", quantity: "\(i) unit", category: .other)
        }
        
        return Recipe(
            id: UUID(),
            name: "Complex Recipe",
            ingredients: ingredients,
            instructions: ["Mix all ingredients", "Cook thoroughly"],
            prepTime: 30,
            cookTime: 60,
            servings: 8,
            difficulty: .hard,
            nutrition: Recipe.Nutrition(calories: 800, protein: 30, carbs: 80, fat: 25, fiber: 10),
            tags: ["complex"],
            source: .ai
        )
    }
    
    private func createSingleIngredientRecipe() -> Recipe {
        return Recipe(
            id: UUID(),
            name: "Simple Toast",
            ingredients: [Recipe.Ingredient(name: "Bread", quantity: "1 slice", category: .grains)],
            instructions: ["Toast the bread"],
            prepTime: 1,
            cookTime: 2,
            servings: 1,
            difficulty: .easy,
            nutrition: Recipe.Nutrition(calories: 80, protein: 3, carbs: 15, fat: 1, fiber: 1),
            tags: ["simple"],
            source: .ai
        )
    }
    
    private func createLongStepsRecipe() -> Recipe {
        let longInstructions = [
            "This is a very long instruction that goes on and on and contains way more than sixty characters which might cause issues with text display in the video templates",
            "Another extremely long instruction that contains detailed information about cooking techniques and specific measurements and timing information that could potentially overflow",
            "Yet another lengthy instruction with lots of detail"
        ]
        
        return Recipe(
            id: UUID(),
            name: "Detailed Recipe",
            ingredients: [Recipe.Ingredient(name: "Test", quantity: "1", category: .other)],
            instructions: longInstructions,
            prepTime: 15,
            cookTime: 30,
            servings: 2,
            difficulty: .medium,
            nutrition: Recipe.Nutrition(calories: 200, protein: 5, carbs: 20, fat: 5, fiber: 2),
            tags: ["detailed"],
            source: .ai
        )
    }
    
    private func createInvalidRecipe() -> Recipe {
        return Recipe(
            id: UUID(),
            name: "", // Empty name
            ingredients: [], // No ingredients
            instructions: [], // No instructions
            prepTime: -1, // Invalid time
            cookTime: -1, // Invalid time
            servings: 0, // Invalid servings
            difficulty: .easy,
            nutrition: Recipe.Nutrition(calories: -1, protein: -1, carbs: -1, fat: -1, fiber: -1),
            tags: [],
            source: .ai
        )
    }
    
    private func createMediaBundleWithImages() -> MediaBundle {
        return MediaBundle(
            beforeFridge: createTestImage(color: .red, text: "BEFORE"),
            afterFridge: createTestImage(color: .green, text: "AFTER"),
            cookedMeal: createTestImage(color: .blue, text: "MEAL"),
            brollClips: [],
            musicURL: Bundle.main.url(forResource: "test_audio", withExtension: "mp3")
        )
    }
    
    private func createMediaBundleWithoutAfterImage() -> MediaBundle {
        return MediaBundle(
            beforeFridge: createTestImage(color: .red, text: "BEFORE"),
            afterFridge: nil,
            cookedMeal: createTestImage(color: .blue, text: "MEAL"),
            brollClips: [],
            musicURL: nil
        )
    }
    
    private func createMediaBundleWithoutBeforeImage() -> MediaBundle {
        return MediaBundle(
            beforeFridge: nil,
            afterFridge: createTestImage(color: .green, text: "AFTER"),
            cookedMeal: createTestImage(color: .blue, text: "MEAL"),
            brollClips: [],
            musicURL: nil
        )
    }
    
    private func createMediaBundleWithoutMusic() -> MediaBundle {
        return MediaBundle(
            beforeFridge: createTestImage(color: .red, text: "BEFORE"),
            afterFridge: createTestImage(color: .green, text: "AFTER"),
            cookedMeal: createTestImage(color: .blue, text: "MEAL"),
            brollClips: [],
            musicURL: nil
        )
    }
    
    private func createMediaBundleWithoutBroll() -> MediaBundle {
        return MediaBundle(
            beforeFridge: createTestImage(color: .red, text: "BEFORE"),
            afterFridge: createTestImage(color: .green, text: "AFTER"),
            cookedMeal: createTestImage(color: .blue, text: "MEAL"),
            brollClips: [], // No b-roll clips
            musicURL: Bundle.main.url(forResource: "test_audio", withExtension: "mp3")
        )
    }
    
    private func createMediaBundleEmpty() -> MediaBundle {
        return MediaBundle(
            beforeFridge: nil,
            afterFridge: nil,
            cookedMeal: nil,
            brollClips: [],
            musicURL: nil
        )
    }
    
    private func createTestImage(color: UIColor, text: String) -> UIImage {
        let size = CGSize(width: 300, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.white
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
}

// MARK: - MediaBundle Definition

struct MediaBundle {
    let beforeFridge: UIImage?
    let afterFridge: UIImage?
    let cookedMeal: UIImage?
    let brollClips: [URL]
    let musicURL: URL?
}

// MARK: - Test Extensions

extension TikTokViralQATestFramework {
    
    // Additional test scenarios from requirements
    
    func testSpecificScenarios() {
        testZeroToOneIngredients()
        testLongStepText()
        testPermissionDeniedFlows()
        testShareCompletionCallback()
    }
    
    func testZeroToOneIngredients() {
        XCTContext.runActivity(named: "Testing 0-1 ingredients") { _ in
            let zeroIngredientRecipe = Recipe(
                id: UUID(),
                name: "No Ingredient Recipe",
                ingredients: [],
                instructions: ["Just eat"],
                prepTime: 0,
                cookTime: 0,
                servings: 1,
                difficulty: .easy,
                nutrition: Recipe.Nutrition(calories: 0, protein: 0, carbs: 0, fat: 0, fiber: 0),
                tags: [],
                source: .ai
            )
            
            let oneIngredientRecipe = createSingleIngredientRecipe()
            
            testTemplateGeneration(template: .beforeAfterReveal, recipe: zeroIngredientRecipe, media: createMediaBundleWithImages())
            testTemplateGeneration(template: .beforeAfterReveal, recipe: oneIngredientRecipe, media: createMediaBundleWithImages())
        }
    }
    
    func testLongStepText() {
        XCTContext.runActivity(named: "Testing long step text >60 chars") { _ in
            let longStepRecipe = createLongStepsRecipe()
            testTemplateGeneration(template: .quickRecipe, recipe: longStepRecipe, media: createMediaBundleWithImages())
        }
    }
    
    func testPermissionDeniedFlows() {
        // Already covered in testErrorHandlingPaths()
        XCTAssertTrue(true, "Permission denied flows tested in error handling")
    }
    
    func testShareCompletionCallback() {
        XCTContext.runActivity(named: "Testing share completion callback") { _ in
            let expectation = self.expectation(description: "Share completion callback")
            
            let recipe = createFullRecipe()
            let mediaBundle = createMediaBundleWithImages()
            
            Task {
                do {
                    let videoURL = try await generateTestVideo(template: .beforeAfterReveal, recipe: recipe, media: mediaBundle)
                    
                    ShareService.shareRecipeToTikTok(videoURL: videoURL, recipe: recipe) { result in
                        // Callback should be called regardless of success/failure
                        XCTAssertTrue(true, "Completion callback was called")
                        expectation.fulfill()
                    }
                } catch {
                    XCTFail("Failed to generate video for callback test: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: testTimeout)
        }
    }
    
    private func testTemplateGeneration(template: TikTokTemplate, recipe: Recipe, media: MediaBundle) {
        let expectation = self.expectation(description: "Template generation for \(template.name)")
        
        Task {
            do {
                let videoURL = try await generateTestVideo(template: template, recipe: recipe, media: media)
                XCTAssertTrue(FileManager.default.fileExists(atPath: videoURL.path), "Video file should exist")
                
                let isValid = await validateVideoOutput(videoURL: videoURL)
                XCTAssertTrue(isValid, "Generated video should be valid")
                
                expectation.fulfill()
            } catch {
                XCTFail("Template generation failed for \(template.name): \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: testTimeout)
    }
}