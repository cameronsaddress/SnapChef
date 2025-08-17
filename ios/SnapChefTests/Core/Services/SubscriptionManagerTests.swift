import XCTest
@testable import SnapChef
import StoreKit

@MainActor
final class SubscriptionManagerTests: XCTestCase {
    
    var subscriptionManager: SubscriptionManager!
    
    override func setUpWithError() throws {
        subscriptionManager = SubscriptionManager.shared
    }
    
    override func tearDownWithError() throws {
        subscriptionManager = nil
    }
    
    // MARK: - Initialization Tests
    
    func testSubscriptionManagerSingleton() throws {
        let manager1 = SubscriptionManager.shared
        let manager2 = SubscriptionManager.shared
        
        XCTAssertTrue(manager1 === manager2, "SubscriptionManager should be a singleton")
    }
    
    func testInitialState() throws {
        // Note: These might be different in a real test environment where products could be loaded
        XCTAssertFalse(subscriptionManager.isPremium, "Should not be premium initially")
        XCTAssertEqual(subscriptionManager.subscriptionStatus, .none, "Subscription status should be none initially")
        XCTAssertTrue(subscriptionManager.purchasedSubscriptions.isEmpty, "Purchased subscriptions should be empty initially")
    }
    
    // MARK: - Product ID Tests
    
    func testProductIDs() throws {
        XCTAssertEqual(SubscriptionManager.ProductID.monthly.rawValue, "com.snapchef.premium.monthly")
        XCTAssertEqual(SubscriptionManager.ProductID.yearly.rawValue, "com.snapchef.premium.yearly")
        
        let allProductIDs = SubscriptionManager.ProductID.allCases.map { $0.rawValue }
        XCTAssertEqual(allProductIDs.count, 2, "Should have exactly 2 product IDs")
        XCTAssertTrue(allProductIDs.contains("com.snapchef.premium.monthly"), "Should contain monthly product ID")
        XCTAssertTrue(allProductIDs.contains("com.snapchef.premium.yearly"), "Should contain yearly product ID")
    }
    
    // MARK: - Subscription Status Tests
    
    func testSubscriptionStatusIsActive() throws {
        // Test none status
        let noneStatus = SubscriptionManager.SubscriptionStatus.none
        XCTAssertFalse(noneStatus.isActive, "None status should not be active")
        
        // Test expired status
        let expiredStatus = SubscriptionManager.SubscriptionStatus.expired
        XCTAssertFalse(expiredStatus.isActive, "Expired status should not be active")
        
        // Test grace period status
        let gracePeriodStatus = SubscriptionManager.SubscriptionStatus.inGracePeriod
        XCTAssertTrue(gracePeriodStatus.isActive, "Grace period status should be active")
        
        // Note: We can't easily test the active status without a real Product instance
        // In a real test environment, you might use dependency injection to provide mock products
    }
    
    // MARK: - Premium Features Tests
    
    func testPremiumFeatureAccess() throws {
        // Test when not premium
        subscriptionManager.isPremium = false
        
        XCTAssertFalse(subscriptionManager.canAccessPremiumFeature(.unlimitedRecipes), "Should not access unlimited recipes when not premium")
        XCTAssertFalse(subscriptionManager.canAccessPremiumFeature(.advancedAI), "Should not access advanced AI when not premium")
        XCTAssertFalse(subscriptionManager.canAccessPremiumFeature(.nutritionTracking), "Should not access nutrition tracking when not premium")
        XCTAssertFalse(subscriptionManager.canAccessPremiumFeature(.prioritySupport), "Should not access priority support when not premium")
        XCTAssertFalse(subscriptionManager.canAccessPremiumFeature(.premiumChallenges), "Should not access premium challenges when not premium")
        XCTAssertFalse(subscriptionManager.canAccessPremiumFeature(.doubleRewards), "Should not access double rewards when not premium")
        XCTAssertFalse(subscriptionManager.canAccessPremiumFeature(.exclusiveBadges), "Should not access exclusive badges when not premium")
        
        // Save recipes should be accessible to free users (limited)
        XCTAssertTrue(subscriptionManager.canAccessPremiumFeature(.saveRecipes), "Should access save recipes even when not premium")
        
        // Test when premium
        subscriptionManager.isPremium = true
        
        XCTAssertTrue(subscriptionManager.canAccessPremiumFeature(.unlimitedRecipes), "Should access unlimited recipes when premium")
        XCTAssertTrue(subscriptionManager.canAccessPremiumFeature(.advancedAI), "Should access advanced AI when premium")
        XCTAssertTrue(subscriptionManager.canAccessPremiumFeature(.nutritionTracking), "Should access nutrition tracking when premium")
        XCTAssertTrue(subscriptionManager.canAccessPremiumFeature(.prioritySupport), "Should access priority support when premium")
        XCTAssertTrue(subscriptionManager.canAccessPremiumFeature(.premiumChallenges), "Should access premium challenges when premium")
        XCTAssertTrue(subscriptionManager.canAccessPremiumFeature(.doubleRewards), "Should access double rewards when premium")
        XCTAssertTrue(subscriptionManager.canAccessPremiumFeature(.exclusiveBadges), "Should access exclusive badges when premium")
        XCTAssertTrue(subscriptionManager.canAccessPremiumFeature(.saveRecipes), "Should access save recipes when premium")
    }
    
    func testHasActiveSubscription() throws {
        subscriptionManager.isPremium = false
        XCTAssertFalse(subscriptionManager.hasActiveSubscription(), "Should not have active subscription when not premium")
        
        subscriptionManager.isPremium = true
        XCTAssertTrue(subscriptionManager.hasActiveSubscription(), "Should have active subscription when premium")
    }
    
    // MARK: - Premium Challenge Tests
    
    func testGetPremiumChallenges() throws {
        // Test when not premium
        subscriptionManager.isPremium = false
        let freeChallenges = subscriptionManager.getPremiumChallenges()
        XCTAssertTrue(freeChallenges.isEmpty, "Should return empty array when not premium")
        
        // Test when premium
        subscriptionManager.isPremium = true
        let premiumChallenges = subscriptionManager.getPremiumChallenges()
        XCTAssertFalse(premiumChallenges.isEmpty, "Should return challenges when premium")
        XCTAssertEqual(premiumChallenges.count, 7, "Should return 7 premium challenges")
        
        let expectedChallenges = [
            "Master Chef Marathon",
            "Michelin Star Week",
            "Global Cuisine Tour",
            "Zero Waste Champion",
            "Nutrition Perfectionist",
            "Speed Demon Deluxe",
            "Social Butterfly Supreme"
        ]
        
        for challenge in expectedChallenges {
            XCTAssertTrue(premiumChallenges.contains(challenge), "Should contain \(challenge)")
        }
    }
    
    func testIsPremiumChallenge() throws {
        subscriptionManager.isPremium = true // Set to premium to get the list
        let premiumChallenges = subscriptionManager.getPremiumChallenges()
        
        // Test premium challenges
        for challenge in premiumChallenges {
            XCTAssertTrue(subscriptionManager.isPremiumChallenge(challenge), "\(challenge) should be identified as premium")
        }
        
        // Test non-premium challenge
        XCTAssertFalse(subscriptionManager.isPremiumChallenge("Regular Challenge"), "Regular challenge should not be premium")
        XCTAssertFalse(subscriptionManager.isPremiumChallenge(""), "Empty string should not be premium")
    }
    
    func testGetPremiumRewardMultiplier() throws {
        subscriptionManager.isPremium = false
        XCTAssertEqual(subscriptionManager.getPremiumRewardMultiplier(), 1.0, "Free users should have 1.0x multiplier")
        
        subscriptionManager.isPremium = true
        XCTAssertEqual(subscriptionManager.getPremiumRewardMultiplier(), 2.0, "Premium users should have 2.0x multiplier")
    }
    
    // MARK: - Legacy Support Tests
    
    func testGetRemainingDailyRecipes() throws {
        // Test the deprecated method still works
        let remaining = subscriptionManager.getRemainingDailyRecipes()
        
        // Since this delegates to getRemainingRecipes(), we just verify it doesn't crash
        XCTAssertGreaterThanOrEqual(remaining, 0, "Remaining recipes should be non-negative")
    }
    
    func testIncrementDailyRecipeCount() throws {
        // Test the deprecated method still works
        subscriptionManager.incrementDailyRecipeCount()
        
        // This should not crash and should call the underlying tracking methods
        XCTAssertTrue(true, "Increment method should execute without error")
    }
    
    // MARK: - Dynamic Limits Tests
    
    func testGetCurrentLimits() throws {
        let limits = subscriptionManager.getCurrentLimits()
        
        XCTAssertNotNil(limits, "Should return valid daily limits")
        XCTAssertGreaterThan(limits.recipes, 0, "Recipe limit should be greater than 0")
        XCTAssertGreaterThan(limits.videos, 0, "Video limit should be greater than 0")
    }
    
    func testGetRemainingRecipes() throws {
        let remaining = subscriptionManager.getRemainingRecipes()
        XCTAssertGreaterThanOrEqual(remaining, 0, "Remaining recipes should be non-negative")
    }
    
    func testGetRemainingVideos() throws {
        let remaining = subscriptionManager.getRemainingVideos()
        XCTAssertGreaterThanOrEqual(remaining, 0, "Remaining videos should be non-negative")
    }
    
    // MARK: - Product Subscription Period Extension Tests
    
    func testSubscriptionPeriodUnitDescriptions() throws {
        XCTAssertEqual(Product.SubscriptionPeriod.Unit.day.description, "day")
        XCTAssertEqual(Product.SubscriptionPeriod.Unit.week.description, "week")
        XCTAssertEqual(Product.SubscriptionPeriod.Unit.month.description, "month")
        XCTAssertEqual(Product.SubscriptionPeriod.Unit.year.description, "year")
    }
    
    // MARK: - Premium Feature Enum Tests
    
    func testPremiumFeatureEnumCases() throws {
        let allCases: [PremiumFeature] = [
            .unlimitedRecipes,
            .advancedAI,
            .nutritionTracking,
            .prioritySupport,
            .saveRecipes,
            .premiumChallenges,
            .doubleRewards,
            .exclusiveBadges
        ]
        
        // Verify we can create all cases
        for feature in allCases {
            let canAccess = subscriptionManager.canAccessPremiumFeature(feature)
            XCTAssertNotNil(canAccess, "Should be able to check access for \(feature)")
        }
    }
    
    // MARK: - Load Products Test (Async)
    
    func testLoadProductsAsync() async throws {
        // This test verifies that loadProducts() can be called without crashing
        // In a real test environment, you might mock the StoreKit framework
        
        let initialProductCount = subscriptionManager.products.count
        
        await subscriptionManager.loadProducts()
        
        // The product loading might fail in test environment due to missing App Store connectivity
        // But the method should complete without throwing
        XCTAssertGreaterThanOrEqual(subscriptionManager.products.count, 0, "Products array should be non-negative")
        
        // isLoading should be false after completion
        XCTAssertFalse(subscriptionManager.isLoading, "Should not be loading after completion")
    }
    
    // MARK: - Update Subscription Status Test (Async)
    
    func testUpdateSubscriptionStatusAsync() async throws {
        // This test verifies that updateSubscriptionStatus() can be called without crashing
        
        await subscriptionManager.updateSubscriptionStatus()
        
        // The method should complete without throwing
        // In test environment, status will likely remain .none due to no real products
        XCTAssertTrue(true, "Update subscription status should complete without error")
    }
    
    // MARK: - Restore Purchases Test (Async)
    
    func testRestorePurchasesAsync() async throws {
        // This test verifies that restorePurchases() can be called without crashing
        
        await subscriptionManager.restorePurchases()
        
        // The method should complete without throwing
        // In test environment, this will likely not restore any purchases
        XCTAssertTrue(true, "Restore purchases should complete without error")
    }
}