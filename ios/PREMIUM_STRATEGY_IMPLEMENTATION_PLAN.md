# SnapChef Premium Strategy Implementation Plan
## "Hook, Habit, Monetize" Freemium Model

---

## 📋 Executive Summary
Transform SnapChef from a rigid paywall system to a progressive freemium model that hooks users first, builds habits, then monetizes at peak engagement.

**Timeline**: 2-3 days of development
**Risk Level**: Low (backwards compatible, gradual rollout)
**Expected Impact**: 3-5x increase in conversion rate

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

struct DailyLimits {
    let recipes: Int
    let videos: Int
    let premiumEffects: Bool
    let challengeMultiplier: Double
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

## Phase 5: Premium Tiers Implementation (Day 2)

### 5.1 Add Pro Tier

#### Task 5.1.1: Update Subscription Products
**File**: `SnapChef/Core/Services/SubscriptionManager.swift` (MODIFY)
- [ ] Add Pro tier product IDs
- [ ] Define Pro tier benefits
- [ ] Update `SubscriptionTier` enum
- [ ] Add tier comparison logic

#### Task 5.1.2: Update SubscriptionView
**File**: `SnapChef/Features/Authentication/SubscriptionView.swift` (MODIFY)
- [ ] Add 3-tier selection UI
- [ ] Show feature comparison table
- [ ] Highlight "Most Popular" on Premium
- [ ] Add Pro benefits section
- [ ] Update pricing display

#### Task 5.1.3: Gate Pro Features
**Files**: Various feature files (MODIFY)
- [ ] Custom AI personalities (ChefPersonalitySelector.swift)
- [ ] Collaboration tools (NEW)
- [ ] Early access features
- [ ] Unlimited cloud storage
- [ ] Advanced analytics dashboard

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

## 📊 Success Metrics

### Primary KPIs
- **Conversion Rate**: Target 5-8% (up from ~2%)
- **Trial-to-Paid**: Target 40% conversion
- **D7 Retention**: Target 35% (up from 25%)
- **ARPU**: Target $1.20 (up from $0.40)

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