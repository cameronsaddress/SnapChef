# SnapChef Premium Strategy Implementation Plan
## "Hook, Habit, Monetize" Freemium Model (2-Tier System)

---

## 📋 Executive Summary
Transform SnapChef from a rigid paywall system to a progressive freemium model with 2 pricing tiers (Starter/Premium) that hooks users first, builds habits, then monetizes at peak engagement.

**Timeline**: 2-3 days of development
**Risk Level**: Low (backwards compatible, gradual rollout)
**Expected Impact**: 3-5x increase in conversion rate
**Pricing Tiers**: 2 (Starter Free + Premium Paid)

---

## 📊 2-Tier Pricing Structure (Matching Current Implementation)

### Starter (Free)
- **Recipes**: 3 per day (after honeymoon)
- **Videos**: 1 per day  
- **Effects**: Basic only
- **Save Favorites**: Limited (10 max)
- **AI Chef**: Default personality
- **Support**: Community
- **Trial**: 7-day premium trial

### Premium ($9.99/mo or $79.99/yr - Save 33%)
- **Recipes**: Unlimited
- **Videos**: Unlimited
- **Effects**: All premium effects & filters
- **Save Favorites**: Unlimited cookbook
- **AI Chef**: Advanced AI with better suggestions
- **Nutrition**: Detailed health insights
- **Support**: Priority support
- **No Ads**: Ad-free experience

**Product IDs** (Already Configured):
- Monthly: `com.snapchef.premium.monthly`
- Yearly: `com.snapchef.premium.yearly`

---

## 🔧 Existing Implementation (Already Built)

### ✅ Completed Components:
- **SubscriptionManager.swift** - Full StoreKit 2 integration
- **SubscriptionView.swift** - Premium upgrade UI with pricing
- **Product IDs** - Monthly & yearly subscriptions configured
- **Transaction handling** - Purchase, restore, and verification
- **Progressive Authentication** - Anonymous tracking & smart prompts

### 🎯 What's Missing (Need to Build):
1. **Usage Limits** - No daily limits currently enforced
2. **Honeymoon Phase** - No progressive onboarding
3. **Usage Counters** - No visual feedback on limits
4. **Smart Paywalls** - No contextual upgrade prompts
5. **Feature Gates** - Premium features not restricted

---

## Phase 1: Foundation Setup (Day 1)
### 1.1 Create User Lifecycle System

#### Task 1.1.1: Create UserLifecycleManager
**File**: `SnapChef/Core/Services/UserLifecycleManager.swift` (NEW)
- [ ] Create UserLifecycleManager class
- [ ] Add properties: installDate, lastActiveDate, daysActive
- [ ] Add counters: recipesCreated, videosShared, challengesCompleted
- [ ] Implement phase detection (honeymoon/trial/standard)
- [ ] Add UserDefaults persistence
- [ ] Add analytics event tracking

#### Task 1.1.2: Create Lifecycle Models
**File**: `SnapChef/Core/Models/UserLifecycle.swift` (NEW)
```swift
enum UserPhase {
    case honeymoon    // Day 1-7: Everything free
    case trial        // Day 8-30: Progressive limits
    case standard     // Day 31+: Full restrictions
}

enum SubscriptionTier {
    case starter      // Free tier with limits
    case premium      // Paid tier with everything
}

struct DailyLimits {
    let recipes: Int          // Starter: 3, Premium: Unlimited
    let videos: Int           // Starter: 1, Premium: Unlimited
    let premiumEffects: Bool  // Starter: false, Premium: true
    let challengeMultiplier: Double  // Starter: 1.0x, Premium: 2.0x
}
```

#### Task 1.1.3: Integrate with AppState
**File**: `SnapChef/Core/ViewModels/AppState.swift` (MODIFY)
- [ ] Add @Published var userLifecycle: UserLifecycleManager
- [ ] Initialize on app launch
- [ ] Update counters when actions occur
- [ ] Add computed property for current limits

---

## Phase 2: Progressive Limits System (Day 1)

### 2.1 Update SubscriptionManager

#### Task 2.1.1: Implement Dynamic Limits
**File**: `SnapChef/Core/Services/SubscriptionManager.swift` (MODIFY)
- [ ] Replace static `dailyRecipeLimit = 100` with dynamic calculation
- [ ] Add method: `getCurrentLimits() -> DailyLimits`
- [ ] Implement phase-based limit logic:
  ```swift
  Honeymoon (Day 1-7): Unlimited
  Week 2 (Day 8-14): 10 recipes, 5 videos
  Week 3-4 (Day 15-30): 5 recipes, 3 videos
  Standard (Day 31+): 3 recipes, 1 video
  ```
- [ ] Add method: `getRemainingRecipes() -> Int`
- [ ] Add method: `getRemainingVideos() -> Int`

#### Task 2.1.2: Create Usage Tracker
**File**: `SnapChef/Core/Services/UsageTracker.swift` (NEW)
- [ ] Track daily recipe generation count
- [ ] Track daily video creation count
- [ ] Track feature usage (which premium features used)
- [ ] Reset counters at midnight
- [ ] Store history for analytics

---

## Phase 3: UI Updates for Usage Visibility (Day 1-2)

### 3.1 Add Usage Counter UI

#### Task 3.1.1: Create Usage Counter Component
**File**: `SnapChef/Components/UsageCounterView.swift` (NEW)
- [ ] Create reusable usage counter view
- [ ] Show "2/3 recipes today" format
- [ ] Animate when approaching limit
- [ ] Change color: green → yellow → red
- [ ] Add "♾️" symbol for unlimited

#### Task 3.1.2: Add Counter to CameraView
**File**: `SnapChef/Features/Camera/CameraView.swift` (MODIFY)
- [ ] Add usage counter overlay (top-right)
- [ ] Show only when < unlimited
- [ ] Pulse animation when 1 remaining
- [ ] Update after each recipe generation

#### Task 3.1.3: Add Counter to TikTokShareView
**File**: `SnapChef/Features/Sharing/Platforms/TikTok/TikTokShareView.swift` (MODIFY)
- [ ] Add video usage counter
- [ ] Show premium effects availability
- [ ] Display "Premium Preview" badge during honeymoon

---

## Phase 4: Smart Paywall System (Day 2)

### 4.1 Enhance Paywall Logic

#### Task 4.1.1: Create Smart Trigger System
**File**: `SnapChef/Core/Services/PaywallTriggerManager.swift` (NEW)
- [ ] Implement trigger conditions:
  ```swift
  - Never show in first 3 days
  - Show after 10 recipes created
  - Show after 3 videos shared
  - Show when accessing locked feature
  - Show at natural break points
  ```
- [ ] Add cooldown period (don't spam)
- [ ] Track dismissals and conversions
- [ ] A/B test different triggers

#### Task 4.1.2: Update PremiumUpgradePrompt
**File**: `SnapChef/Features/Authentication/PremiumUpgradePrompt.swift` (MODIFY)
- [ ] Add contextual messages based on phase
- [ ] Show "Honeymoon Ending" countdown
- [ ] Display features they've been using
- [ ] Add "You've saved $X" calculator
- [ ] Implement soft vs hard paywall modes

#### Task 4.1.3: Create Honeymoon Banner
**File**: `SnapChef/Components/HoneymoonBanner.swift` (NEW)
- [ ] "🎉 Premium Preview: Day 3 of 7"
- [ ] "Enjoying unlimited recipes? Keep them forever →"
- [ ] Dismissible but reappears daily
- [ ] Links to special honeymoon offer

---

## Phase 5: Premium Tier Optimization (Day 2)

### 5.1 Optimize 2-Tier System

#### Task 5.1.1: Update Subscription Products
**File**: `SnapChef/Core/Services/SubscriptionManager.swift` (MODIFY)
- [ ] Define clear Starter (free) tier limits
- [ ] Define comprehensive Premium tier benefits
- [ ] Update `SubscriptionTier` enum to 2 tiers only
- [ ] Simplify tier comparison logic

#### Task 5.1.2: Update SubscriptionView
**File**: `SnapChef/Features/Authentication/SubscriptionView.swift` (MODIFY)
- [ ] Create simple 2-tier comparison UI
- [ ] Show clear feature comparison table (Starter vs Premium)
- [ ] Add "Upgrade to Premium" prominent CTA
- [ ] Display savings with annual plan
- [ ] Simplify pricing display (monthly/annual only)

#### Task 5.1.3: Implement Premium Feature Gates
**Files**: Various feature files (MODIFY)
- [ ] Check `SubscriptionManager.shared.isPremium` for feature access
- [ ] Gate unlimited recipes (remove 3/day limit for premium)
- [ ] Gate unlimited videos (remove 1/day limit for premium)
- [ ] Gate advanced AI features (better recipe suggestions)
- [ ] Gate unlimited favorites (10 max for free users)
- [ ] Gate nutrition tracking (premium only)
- [ ] Gate premium effects & filters in video generation
- [ ] Add "Premium" badges to locked features
- [ ] Show upgrade prompts when hitting limits

---

## Phase 6: Analytics & Tracking (Day 2-3)

### 6.1 Implement Conversion Tracking

#### Task 6.1.1: Add Analytics Events
**File**: `SnapChef/Core/Services/AnalyticsManager.swift` (MODIFY)
- [ ] Track user phase transitions
- [ ] Track paywall impressions/dismissals
- [ ] Track feature usage by tier
- [ ] Track conversion points
- [ ] Track churn indicators

#### Task 6.1.2: Create Metrics Dashboard
**File**: `SnapChef/Features/Admin/MetricsDashboard.swift` (NEW)
- [ ] Show conversion funnel
- [ ] Display retention by phase
- [ ] Track limit hit frequency
- [ ] Monitor feature usage
- [ ] A/B test results

---

## Phase 7: Social Proof & FOMO (Day 3)

### 7.1 Add Social Proof Elements

#### Task 7.1.1: Create Social Proof Banner
**File**: `SnapChef/Components/SocialProofBanner.swift` (NEW)
- [ ] "2,847 chefs upgraded today"
- [ ] "Premium members save 3hr/week"
- [ ] Rotating testimonials
- [ ] Success stories carousel

#### Task 7.1.2: Add FOMO Mechanics
**File**: `SnapChef/Core/Services/FOMOManager.swift` (NEW)
- [ ] Daily deals generator
- [ ] Limited time offers
- [ ] Expiring premium challenges
- [ ] "Last chance" notifications

#### Task 7.1.3: Premium User Showcase
**File**: `SnapChef/Features/Social/PremiumShowcase.swift` (NEW)
- [ ] "Premium Chef of the Week"
- [ ] Featured premium recipes
- [ ] Premium-only leaderboard
- [ ] Success badges display

---

## Phase 8: Testing & Rollout (Day 3)

### 8.1 Testing Strategy

#### Task 8.1.1: Unit Tests
- [ ] Test lifecycle phase calculations
- [ ] Test limit enforcement
- [ ] Test paywall triggers
- [ ] Test tier benefits
- [ ] Test usage tracking

#### Task 8.1.2: Integration Tests
- [ ] Test full user journey
- [ ] Test upgrade flow
- [ ] Test downgrade scenarios
- [ ] Test restoration
- [ ] Test edge cases

#### Task 8.1.3: A/B Testing Setup
- [ ] Create feature flags
- [ ] Define test cohorts
- [ ] Set up metrics tracking
- [ ] Plan rollout percentages

---

## 🚀 Rollout Strategy

### Week 1: Soft Launch (5% of users)
- Enable for new installs only
- Monitor metrics closely
- Fix any critical issues
- Gather initial feedback

### Week 2: Expand (25% of users)
- Include in next app update
- A/B test different limits
- Optimize conversion points
- Refine messaging

### Week 3: Full Rollout (100% of users)
- Enable for all users
- Grandfather existing premium users
- Launch marketing campaign
- Monitor retention metrics

---

## 📊 Success Metrics (2-Tier System)

### Primary KPIs
- **Free-to-Premium Conversion**: Target 5-8% (up from ~2%)
- **Honeymoon-to-Premium**: Target 40% conversion
- **D7 Retention**: Target 35% (up from 25%)
- **ARPU**: Target $0.90 (simpler 2-tier pricing)
- **Premium Retention**: Target 80% monthly retention

### Secondary Metrics
- Paywall dismissal rate
- Feature usage by tier
- Churn by phase
- Support ticket volume
- App store ratings

---

## ⚠️ Risk Mitigation

### Potential Issues & Solutions

1. **User Backlash**
   - Solution: Grandfather existing users
   - Clear communication about changes
   - Special loyalty discounts

2. **Technical Issues**
   - Solution: Feature flags for instant rollback
   - Extensive testing before launch
   - Gradual rollout

3. **Revenue Drop**
   - Solution: A/B test extensively
   - Have rollback plan ready
   - Monitor metrics hourly

---

## 📝 Implementation Checklist

### Pre-Development
- [ ] Review plan with team
- [ ] Set up analytics tracking
- [ ] Create feature flags
- [ ] Design UI mockups
- [ ] Write test cases

### Development (Days 1-3)
- [ ] Phase 1: Foundation Setup
- [ ] Phase 2: Progressive Limits
- [ ] Phase 3: UI Updates
- [ ] Phase 4: Smart Paywalls
- [ ] Phase 5: Premium Tiers
- [ ] Phase 6: Analytics
- [ ] Phase 7: Social Proof
- [ ] Phase 8: Testing

### Post-Development
- [ ] Code review
- [ ] QA testing
- [ ] App Store preparation
- [ ] Marketing materials
- [ ] Support documentation
- [ ] Launch announcement

---

## 🎯 Next Steps

1. **Immediate**: Create UserLifecycleManager.swift
2. **Today**: Update SubscriptionManager with dynamic limits
3. **Tomorrow**: Add UI usage counters
4. **Day 3**: Implement smart paywalls
5. **Day 4**: Testing and refinement
6. **Day 5**: Prepare for rollout

---

## 📚 Reference Files

### Core Files to Modify
- `/SnapChef/Core/Services/SubscriptionManager.swift`
- `/SnapChef/Core/ViewModels/AppState.swift`
- `/SnapChef/Features/Camera/CameraView.swift`
- `/SnapChef/Features/Authentication/PremiumUpgradePrompt.swift`
- `/SnapChef/Features/Authentication/SubscriptionView.swift`

### New Files to Create
- `/SnapChef/Core/Services/UserLifecycleManager.swift`
- `/SnapChef/Core/Models/UserLifecycle.swift`
- `/SnapChef/Core/Services/UsageTracker.swift`
- `/SnapChef/Core/Services/PaywallTriggerManager.swift`
- `/SnapChef/Components/UsageCounterView.swift`
- `/SnapChef/Components/HoneymoonBanner.swift`
- `/SnapChef/Components/SocialProofBanner.swift`

---

## 💡 Pro Tips

1. **Start Conservative**: Better to be too generous than too restrictive initially
2. **Monitor Closely**: Watch metrics hourly during first week
3. **Listen to Users**: Set up feedback channel for premium changes
4. **Iterate Quickly**: Be ready to adjust limits based on data
5. **Communicate Value**: Always show what users get, not what they lose

---

*Last Updated: January 14, 2025*
*Version: 1.0*
*Author: SnapChef Premium Strategy Team*