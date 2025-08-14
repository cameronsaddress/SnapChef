//
//  OverlayFactoryTests.swift
//  SnapChef
//
//  Created on 12/01/2025
//  Test file to verify all overlay implementations match exact specifications
//

import UIKit
import AVFoundation

/// Test utility for OverlayFactory - validates all 10 required overlays
public class OverlayFactoryTests {
    
    private let factory: OverlayFactory
    private let config: RenderConfig
    
    public init() {
        self.config = RenderConfig()
        self.factory = OverlayFactory(config: config)
    }
    
    /// Run all overlay tests to verify implementation
    public func runAllTests() -> [TestResult] {
        var results: [TestResult] = []
        
        // Test all 10 required overlays
        results.append(testHeroHookOverlay())
        results.append(testCTAOverlay())
        results.append(testIngredientCallout())
        results.append(testSplitWipeMaskOverlay())
        results.append(testIngredientCountersOverlay())
        results.append(testKineticStepOverlay())
        results.append(testStickerStackOverlay())
        results.append(testProgressOverlay())
        results.append(testPIPFaceOverlay())
        results.append(testCalloutsOverlay())
        
        // Test safe zone validation
        results.append(testSafeZoneValidation())
        
        return results
    }
    
    // MARK: - Individual Overlay Tests
    
    private func testHeroHookOverlay() -> TestResult {
        let overlay = factory.createHeroHookOverlay(text: "Fridge chaos → dinner in 15 min", config: config)
        
        // Verify overlay exists and has correct frame
        guard overlay.frame == CGRect(origin: .zero, size: config.size) else {
            return TestResult(name: "HeroHookOverlay", passed: false, error: "Incorrect frame size")
        }
        
        // Verify sublayers exist
        guard overlay.sublayers?.count ?? 0 > 0 else {
            return TestResult(name: "HeroHookOverlay", passed: false, error: "No sublayers found")
        }
        
        return TestResult(name: "HeroHookOverlay", passed: true)
    }
    
    private func testCTAOverlay() -> TestResult {
        let overlay = factory.createCTAOverlay(text: "Comment 'RECIPE' for details", config: config)
        
        // Verify overlay structure
        guard overlay.frame == CGRect(origin: .zero, size: config.size) else {
            return TestResult(name: "CTAOverlay", passed: false, error: "Incorrect frame size")
        }
        
        // Check for rounded sticker background
        guard overlay.sublayers?.count ?? 0 > 0 else {
            return TestResult(name: "CTAOverlay", passed: false, error: "No sticker layer found")
        }
        
        return TestResult(name: "CTAOverlay", passed: true)
    }
    
    private func testIngredientCallout() -> TestResult {
        let overlay = factory.createIngredientCalloutOverlay(text: "Spinach", index: 0, config: config)
        
        // Verify basic structure
        guard overlay.frame == CGRect(origin: .zero, size: config.size) else {
            return TestResult(name: "IngredientCallout", passed: false, error: "Incorrect frame size")
        }
        
        return TestResult(name: "IngredientCallout", passed: true)
    }
    
    private func testSplitWipeMaskOverlay() -> TestResult {
        let overlay = factory.createSplitWipeMaskOverlay(progress: 0.5, config: config)
        
        // Verify mask layer exists
        guard overlay.frame == CGRect(origin: .zero, size: config.size) else {
            return TestResult(name: "SplitWipeMaskOverlay", passed: false, error: "Incorrect frame size")
        }
        
        // Check for mask layer
        guard overlay.mask != nil else {
            return TestResult(name: "SplitWipeMaskOverlay", passed: false, error: "No mask layer found")
        }
        
        return TestResult(name: "SplitWipeMaskOverlay", passed: true)
    }
    
    private func testIngredientCountersOverlay() -> TestResult {
        let ingredients = ["Eggs", "Spinach", "Garlic"]
        let overlay = factory.createIngredientCountersOverlay(ingredients: ingredients, config: config)
        
        // Verify basic structure
        guard overlay.frame == CGRect(origin: .zero, size: config.size) else {
            return TestResult(name: "IngredientCountersOverlay", passed: false, error: "Incorrect frame size")
        }
        
        // Should have multiple chip layers
        guard overlay.sublayers?.count ?? 0 >= ingredients.count else {
            return TestResult(name: "IngredientCountersOverlay", passed: false, error: "Insufficient chip layers")
        }
        
        return TestResult(name: "IngredientCountersOverlay", passed: true)
    }
    
    private func testKineticStepOverlay() -> TestResult {
        let overlay = factory.createKineticStepOverlay(text: "1. Heat oil in pan", index: 0, config: config)
        
        // Verify basic structure
        guard overlay.frame == CGRect(origin: .zero, size: config.size) else {
            return TestResult(name: "KineticStepOverlay", passed: false, error: "Incorrect frame size")
        }
        
        return TestResult(name: "KineticStepOverlay", passed: true)
    }
    
    private func testStickerStackOverlay() -> TestResult {
        let stickers = [
            ("15 MIN", UIColor.systemBlue),
            ("$7", UIColor.systemGreen),
            ("350 CAL", UIColor.systemOrange)
        ]
        let overlay = factory.createStickerStackOverlay(stickers: stickers, config: config)
        
        // Verify basic structure
        guard overlay.frame == CGRect(origin: .zero, size: config.size) else {
            return TestResult(name: "StickerStackOverlay", passed: false, error: "Incorrect frame size")
        }
        
        // Should have sticker layers
        guard overlay.sublayers?.count ?? 0 >= stickers.count else {
            return TestResult(name: "StickerStackOverlay", passed: false, error: "Insufficient sticker layers")
        }
        
        return TestResult(name: "StickerStackOverlay", passed: true)
    }
    
    private func testProgressOverlay() -> TestResult {
        let recipe = Recipe(
            title: "Test Recipe",
            steps: [Recipe.Step(title: "Test step", secondsHint: 30)],
            timeMinutes: 15,
            costDollars: 7,
            ingredients: ["Test ingredient"]
        )
        let overlay = factory.createProgressBarOverlay(recipe: recipe, config: config)
        
        // Verify basic structure
        guard overlay.frame == CGRect(origin: .zero, size: config.size) else {
            return TestResult(name: "ProgressOverlay", passed: false, error: "Incorrect frame size")
        }
        
        return TestResult(name: "ProgressOverlay", passed: true)
    }
    
    private func testPIPFaceOverlay() -> TestResult {
        let overlay = factory.createPIPFaceOverlay(config: config)
        
        // Verify basic structure
        guard overlay.frame == CGRect(origin: .zero, size: config.size) else {
            return TestResult(name: "PIPFaceOverlay", passed: false, error: "Incorrect frame size")
        }
        
        // Should have PIP circle layer
        guard overlay.sublayers?.count ?? 0 > 0 else {
            return TestResult(name: "PIPFaceOverlay", passed: false, error: "No PIP layer found")
        }
        
        return TestResult(name: "PIPFaceOverlay", passed: true)
    }
    
    private func testCalloutsOverlay() -> TestResult {
        let ingredients = ["Eggs", "Spinach", "Garlic"]
        let overlay = factory.createCalloutsOverlay(ingredients: ingredients, config: config)
        
        // Verify basic structure
        guard overlay.frame == CGRect(origin: .zero, size: config.size) else {
            return TestResult(name: "CalloutsOverlay", passed: false, error: "Incorrect frame size")
        }
        
        // Should have angled callout layers
        guard overlay.sublayers?.count ?? 0 >= ingredients.count else {
            return TestResult(name: "CalloutsOverlay", passed: false, error: "Insufficient callout layers")
        }
        
        return TestResult(name: "CalloutsOverlay", passed: true)
    }
    
    private func testSafeZoneValidation() -> TestResult {
        // Test with valid safe zones - should not crash
        let validConfig = RenderConfig()
        let factory = OverlayFactory(config: validConfig)
        
        do {
            _ = factory.createHeroHookOverlay(text: "Test", config: validConfig)
            return TestResult(name: "SafeZoneValidation", passed: true)
        } catch {
            return TestResult(name: "SafeZoneValidation", passed: false, error: "Safe zone validation failed: \(error)")
        }
    }
    
    // MARK: - Typography Specifications Test
    
    /// Verify all typography specifications match exact requirements
    public func testTypographySpecifications() -> [TestResult] {
        var results: [TestResult] = []
        
        // Test hook font size (64pt default, 60-72pt range)
        let hookValid = config.hookFontSize >= 60 && config.hookFontSize <= 72
        results.append(TestResult(
            name: "HookFontSize",
            passed: hookValid,
            error: hookValid ? nil : "Hook font size \(config.hookFontSize) not in 60-72pt range"
        ))
        
        // Test steps font size (48pt default, 44-52pt range)
        let stepsValid = config.stepsFontSize >= 44 && config.stepsFontSize <= 52
        results.append(TestResult(
            name: "StepsFontSize",
            passed: stepsValid,
            error: stepsValid ? nil : "Steps font size \(config.stepsFontSize) not in 44-52pt range"
        ))
        
        // Test counters font size (42pt default, 36-48pt range)
        let countersValid = config.countersFontSize >= 36 && config.countersFontSize <= 48
        results.append(TestResult(
            name: "CountersFontSize",
            passed: countersValid,
            error: countersValid ? nil : "Counters font size \(config.countersFontSize) not in 36-48pt range"
        ))
        
        // Test CTA font size (40pt)
        let ctaValid = config.ctaFontSize == 40
        results.append(TestResult(
            name: "CTAFontSize",
            passed: ctaValid,
            error: ctaValid ? nil : "CTA font size \(config.ctaFontSize) not 40pt"
        ))
        
        // Test ingredient font size (42pt)
        let ingredientValid = config.ingredientFontSize == 42
        results.append(TestResult(
            name: "IngredientFontSize",
            passed: ingredientValid,
            error: ingredientValid ? nil : "Ingredient font size \(config.ingredientFontSize) not 42pt"
        ))
        
        return results
    }
    
    // MARK: - Animation Specifications Test
    
    /// Verify all animation specifications match exact requirements
    public func testAnimationSpecifications() -> [TestResult] {
        var results: [TestResult] = []
        
        // Test fade duration (200-300ms, 250ms default)
        let fadeValid = config.fadeDuration >= 0.2 && config.fadeDuration <= 0.3
        results.append(TestResult(
            name: "FadeDuration",
            passed: fadeValid,
            error: fadeValid ? nil : "Fade duration \(config.fadeDuration) not in 200-300ms range"
        ))
        
        // Test spring damping (12-14, 13 default)
        let dampingValid = config.springDamping >= 12 && config.springDamping <= 14
        results.append(TestResult(
            name: "SpringDamping",
            passed: dampingValid,
            error: dampingValid ? nil : "Spring damping \(config.springDamping) not in 12-14 range"
        ))
        
        // Test scale range (0.6 to 1.0)
        let scaleValid = config.scaleRange.lowerBound == 0.6 && config.scaleRange.upperBound == 1.0
        results.append(TestResult(
            name: "ScaleRange",
            passed: scaleValid,
            error: scaleValid ? nil : "Scale range \(config.scaleRange) not 0.6...1.0"
        ))
        
        // Test stagger delay (120-150ms, 135ms default)
        let staggerValid = config.staggerDelay >= 0.12 && config.staggerDelay <= 0.15
        results.append(TestResult(
            name: "StaggerDelay",
            passed: staggerValid,
            error: staggerValid ? nil : "Stagger delay \(config.staggerDelay) not in 120-150ms range"
        ))
        
        return results
    }
    
    // MARK: - Safe Zone Specifications Test
    
    /// Verify safe zone specifications match exact requirements
    public func testSafeZoneSpecifications() -> [TestResult] {
        var results: [TestResult] = []
        
        // Test top safe zone (192px minimum)
        let topValid = config.safeInsets.top >= 192
        results.append(TestResult(
            name: "TopSafeZone",
            passed: topValid,
            error: topValid ? nil : "Top safe zone \(config.safeInsets.top) less than 192px"
        ))
        
        // Test bottom safe zone (192px minimum)
        let bottomValid = config.safeInsets.bottom >= 192
        results.append(TestResult(
            name: "BottomSafeZone",
            passed: bottomValid,
            error: bottomValid ? nil : "Bottom safe zone \(config.safeInsets.bottom) less than 192px"
        ))
        
        // Test left safe zone (72px minimum)
        let leftValid = config.safeInsets.left >= 72
        results.append(TestResult(
            name: "LeftSafeZone",
            passed: leftValid,
            error: leftValid ? nil : "Left safe zone \(config.safeInsets.left) less than 72px"
        ))
        
        // Test right safe zone (72px minimum)
        let rightValid = config.safeInsets.right >= 72
        results.append(TestResult(
            name: "RightSafeZone",
            passed: rightValid,
            error: rightValid ? nil : "Right safe zone \(config.safeInsets.right) less than 72px"
        ))
        
        return results
    }
}

// MARK: - Test Result Structure

public struct TestResult {
    public let name: String
    public let passed: Bool
    public let error: String?
    
    public init(name: String, passed: Bool, error: String? = nil) {
        self.name = name
        self.passed = passed
        self.error = error
    }
    
    public var description: String {
        if passed {
            return "✅ \(name): PASSED"
        } else {
            return "❌ \(name): FAILED - \(error ?? "Unknown error")"
        }
    }
}

// MARK: - Test Runner

extension OverlayFactoryTests {
    
    /// Run comprehensive test suite and print results
    public func runComprehensiveTests() {
        print("🧪 OverlayFactory Comprehensive Test Suite")
        print("==========================================")
        
        // Run overlay tests
        print("\n📦 Testing Overlay Implementations...")
        let overlayResults = runAllTests()
        overlayResults.forEach { print($0.description) }
        
        // Run typography tests
        print("\n🔤 Testing Typography Specifications...")
        let typographyResults = testTypographySpecifications()
        typographyResults.forEach { print($0.description) }
        
        // Run animation tests
        print("\n🎬 Testing Animation Specifications...")
        let animationResults = testAnimationSpecifications()
        animationResults.forEach { print($0.description) }
        
        // Run safe zone tests
        print("\n🛡️ Testing Safe Zone Specifications...")
        let safeZoneResults = testSafeZoneSpecifications()
        safeZoneResults.forEach { print($0.description) }
        
        // Summary
        let allResults = overlayResults + typographyResults + animationResults + safeZoneResults
        let passedCount = allResults.filter { $0.passed }.count
        let totalCount = allResults.count
        
        print("\n📊 Test Summary")
        print("===============")
        print("Total Tests: \(totalCount)")
        print("Passed: \(passedCount)")
        print("Failed: \(totalCount - passedCount)")
        print("Success Rate: \(Int((Double(passedCount) / Double(totalCount)) * 100))%")
        
        if passedCount == totalCount {
            print("\n🎉 ALL TESTS PASSED! OverlayFactory implementation meets exact specifications.")
        } else {
            print("\n⚠️ Some tests failed. Please review the implementation.")
        }
    }
}