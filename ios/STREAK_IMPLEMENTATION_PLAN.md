# 🔥 SnapChef Streak System Implementation Plan

## Overview
Complete implementation of a comprehensive streak system with CloudKit integration, push notifications, and gamification features.

## Implementation Phases

### 📋 Phase 1: Core Streak System (Week 1)

#### Task 1.1: Data Models & CloudKit Schema
- [ ] Create `StreakType` enum
- [ ] Create `StreakData` model
- [ ] Create `StreakManager` class
- [ ] Add CloudKit record types:
  - `UserStreak`
  - `StreakHistory`
  - `StreakAchievement`
  - `StreakFreeze`
- [ ] Test build & resolve errors

#### Task 1.2: Basic Streak Tracking
- [ ] Implement daily snap streak
- [ ] Implement recipe creation streak
- [ ] Implement challenge completion streak
- [ ] Add streak calculation logic
- [ ] Test build & resolve errors

#### Task 1.3: CloudKit Integration
- [ ] Create `CloudKitStreakManager`
- [ ] Implement streak sync
- [ ] Add conflict resolution
- [ ] Implement offline caching
- [ ] Test build & resolve errors

#### Task 1.4: UI Components
- [ ] Create `StreakIndicator` view
- [ ] Add streak display to HomeView
- [ ] Create `StreakDetailView`
- [ ] Add streak to ProfileView
- [ ] Test build & resolve errors

#### Task 1.5: Basic Notifications
- [ ] Setup push notification permissions
- [ ] Implement daily reminder (2 hours before midnight)
- [ ] Add streak milestone notifications
- [ ] Test local notifications
- [ ] Test build & resolve errors

### 📋 Phase 2: Advanced Features (Week 2)

#### Task 2.1: Streak Freezes
- [ ] Implement freeze logic
- [ ] Add freeze UI controls
- [ ] CloudKit freeze tracking
- [ ] Premium vs free freeze limits
- [ ] Test build & resolve errors

#### Task 2.2: Streak Insurance
- [ ] Create insurance system
- [ ] Add Chef Coin cost
- [ ] Implement auto-restore
- [ ] Add purchase UI
- [ ] Test build & resolve errors

#### Task 2.3: Rewards & Milestones
- [ ] Create milestone definitions
- [ ] Implement reward distribution
- [ ] Add badge unlocking
- [ ] Create celebration animations
- [ ] Test build & resolve errors

#### Task 2.4: Multipliers
- [ ] Implement XP multipliers
- [ ] Add coin multipliers
- [ ] Create multiplier UI display
- [ ] Cap multipliers at 2.5x
- [ ] Test build & resolve errors

#### Task 2.5: Streak Calendar
- [ ] Create calendar view
- [ ] Add streak history display
- [ ] Color coding for streak types
- [ ] Export calendar feature
- [ ] Test build & resolve errors

### 📋 Phase 3: Social & Analytics (Week 3)

#### Task 3.1: Team Streaks
- [ ] Implement team streak logic
- [ ] Add grace period system
- [ ] Create team streak UI
- [ ] CloudKit team sync
- [ ] Test build & resolve errors

#### Task 3.2: Streak Leaderboard
- [ ] Create leaderboard view
- [ ] Add friend comparisons
- [ ] Implement global rankings
- [ ] Add filtering options
- [ ] Test build & resolve errors

#### Task 3.3: Social Sharing
- [ ] Create streak share cards
- [ ] Add milestone sharing
- [ ] Implement share tracking
- [ ] Add viral rewards
- [ ] Test build & resolve errors

#### Task 3.4: Analytics Dashboard
- [ ] Create analytics models
- [ ] Track break patterns
- [ ] Calculate engagement metrics
- [ ] Create insights view
- [ ] Test build & resolve errors

#### Task 3.5: Power-ups & Store
- [ ] Implement power-up system
- [ ] Create streak store UI
- [ ] Add purchase logic
- [ ] Integrate with ChefCoins
- [ ] Test build & resolve errors

## Technical Architecture

### Data Models

```swift
// StreakType.swift
enum StreakType: String, CaseIterable, Codable {
    case dailySnap = "daily_snap"
    case recipeCreation = "recipe_creation"
    case challengeCompletion = "challenge_completion"
    case socialShare = "social_share"
    case healthyEating = "healthy_eating"
    
    var displayName: String {
        switch self {
        case .dailySnap: return "Daily Snap"
        case .recipeCreation: return "Recipe Creator"
        case .challengeCompletion: return "Challenge Master"
        case .socialShare: return "Social Chef"
        case .healthyEating: return "Healthy Habits"
        }
    }
    
    var icon: String {
        switch self {
        case .dailySnap: return "📸"
        case .recipeCreation: return "👨‍🍳"
        case .challengeCompletion: return "🏆"
        case .socialShare: return "📱"
        case .healthyEating: return "🥗"
        }
    }
}

// StreakData.swift
struct StreakData: Codable {
    let id: UUID
    let type: StreakType
    var currentStreak: Int
    var longestStreak: Int
    var lastActivityDate: Date
    var streakStartDate: Date
    var totalDaysActive: Int
    var frozenUntil: Date?
    var insuranceActive: Bool
    var multiplier: Double
    
    var isActive: Bool {
        let calendar = Calendar.current
        return calendar.isDateInToday(lastActivityDate) || 
               calendar.isDateInYesterday(lastActivityDate)
    }
    
    var daysUntilBreak: Int {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let midnight = calendar.startOfDay(for: tomorrow)
        let hours = calendar.dateComponents([.hour], from: Date(), to: midnight).hour ?? 0
        return hours
    }
}

// StreakMilestone.swift
struct StreakMilestone {
    let days: Int
    let coins: Int
    let badge: String
    let title: String
    let xpBonus: Int
    
    static let milestones = [
        StreakMilestone(days: 3, coins: 10, badge: "🔥", title: "Starter", xpBonus: 50),
        StreakMilestone(days: 7, coins: 50, badge: "📅", title: "Week Warrior", xpBonus: 200),
        StreakMilestone(days: 14, coins: 100, badge: "💪", title: "Two Week Champion", xpBonus: 500),
        StreakMilestone(days: 30, coins: 500, badge: "🌟", title: "Monthly Master", xpBonus: 2000),
        StreakMilestone(days: 50, coins: 1000, badge: "🎯", title: "Streak Elite", xpBonus: 5000),
        StreakMilestone(days: 100, coins: 5000, badge: "👑", title: "Century Chef", xpBonus: 20000),
        StreakMilestone(days: 365, coins: 20000, badge: "🌈", title: "Year Legend", xpBonus: 100000)
    ]
}
```

### CloudKit Schema Updates

```
RECORD TYPE UserStreak (
    userID          STRING QUERYABLE,
    streakType      STRING QUERYABLE,
    currentStreak   INT64 SORTABLE,
    longestStreak   INT64 SORTABLE,
    lastActivityDate TIMESTAMP SORTABLE,
    streakStartDate TIMESTAMP,
    totalDaysActive INT64,
    frozenUntil     TIMESTAMP,
    insuranceActive INT64,
    multiplier      DOUBLE,
    GRANT WRITE TO "_creator",
    GRANT READ TO "_world"
);

RECORD TYPE StreakHistory (
    userID          STRING QUERYABLE,
    streakType      STRING QUERYABLE,
    streakLength    INT64 SORTABLE,
    startDate       TIMESTAMP,
    endDate         TIMESTAMP SORTABLE,
    breakReason     STRING,
    restored        INT64,
    GRANT WRITE TO "_creator",
    GRANT READ TO "_creator"
);

RECORD TYPE StreakAchievement (
    userID          STRING QUERYABLE,
    achievementType STRING QUERYABLE,
    unlockedAt      TIMESTAMP SORTABLE,
    streakLength    INT64,
    rewardsClaimed  INT64,
    badgeIcon       STRING,
    GRANT WRITE TO "_creator",
    GRANT READ TO "_world"
);

RECORD TYPE StreakFreeze (
    userID          STRING QUERYABLE,
    freezeDate      TIMESTAMP SORTABLE,
    freezeType      STRING,
    streakType      STRING,
    remainingFreezes INT64,
    expiresAt       TIMESTAMP,
    GRANT WRITE TO "_creator",
    GRANT READ TO "_creator"
);

RECORD TYPE TeamStreak (
    teamID          STRING QUERYABLE,
    streakType      STRING,
    currentStreak   INT64 SORTABLE,
    memberContributions STRING,
    lastActivityDate TIMESTAMP,
    gracePeriodUntil TIMESTAMP,
    GRANT WRITE TO "_creator",
    GRANT READ TO "_world"
);
```

### Push Notification Payloads

```json
// Streak at risk
{
  "aps": {
    "alert": {
      "title": "🔥 Streak at Risk!",
      "body": "Your 15-day streak ends in 2 hours!"
    },
    "badge": 1,
    "sound": "urgent.wav"
  },
  "streakType": "daily_snap",
  "currentStreak": 15,
  "hoursRemaining": 2
}

// Milestone reached
{
  "aps": {
    "alert": {
      "title": "🎉 Milestone Achieved!",
      "body": "30-day streak! You earned 500 Chef Coins!"
    },
    "sound": "celebration.wav"
  },
  "milestone": 30,
  "reward": 500
}
```

### UI Component Structure

```swift
// StreakIndicator.swift
struct StreakIndicator: View {
    let streak: StreakData
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Animated fire emoji
            Text(fireEmoji)
                .font(.system(size: fontSize))
                .scaleEffect(isAnimating ? 1.2 : 1.0)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(streak.currentStreak) days")
                    .font(.system(size: 16, weight: .bold))
                
                Text(streak.type.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            if streak.multiplier > 1.0 {
                Text("\(String(format: "%.1fx", streak.multiplier))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(8)
            }
        }
    }
    
    private var fireEmoji: String {
        switch streak.currentStreak {
        case 0...2: return "🔥"
        case 3...6: return "🔥🔥"
        case 7...29: return "🔥🔥🔥"
        case 30...99: return "🔥🔥🔥🔥"
        default: return "🔥🔥🔥🔥🔥"
        }
    }
    
    private var fontSize: CGFloat {
        min(24 + CGFloat(streak.currentStreak / 10) * 2, 40)
    }
}
```

## Testing Strategy

### Unit Tests
- Streak calculation logic
- Freeze mechanics
- Insurance restoration
- Multiplier calculations
- Milestone detection

### Integration Tests
- CloudKit sync
- Push notifications
- Team streak coordination
- Offline/online transitions

### UI Tests
- Streak display updates
- Calendar navigation
- Leaderboard scrolling
- Share functionality

## Performance Considerations

### Optimization Points
1. Cache streak data locally in UserDefaults for quick access
2. Batch CloudKit updates every 5 minutes
3. Use lazy loading for streak history
4. Limit leaderboard to top 100
5. Compress streak history older than 30 days

### Memory Management
- Release calendar views when not visible
- Limit animation frame rates
- Cache computed multipliers
- Clean old streak history periodically

## Monetization Integration

### Premium Features
- Unlimited streak freezes (vs 1/month free)
- Automatic streak insurance
- Exclusive streak badges
- 2x streak multipliers
- Streak history export
- Custom streak themes

### Chef Coin Costs
- Streak freeze: 100 coins
- Streak insurance (7 days): 200 coins
- Streak restore: 500 coins
- Double streak day: 300 coins
- Time machine (backfill): 1000 coins

## Success Metrics

### KPIs to Track
- Average streak length
- Streak retention rate (% maintaining 7+ days)
- Recovery rate after break
- Premium conversion from streak features
- Daily active users with streaks
- Notification engagement rate

### Analytics Events
```swift
Analytics.track("streak_started", properties: [
    "type": streakType,
    "user_level": userLevel
])

Analytics.track("streak_broken", properties: [
    "type": streakType,
    "length": streakLength,
    "break_reason": reason
])

Analytics.track("streak_milestone", properties: [
    "days": milestone,
    "rewards_claimed": rewards
])
```

## Risk Mitigation

### Potential Issues & Solutions
1. **Server time zone conflicts**
   - Solution: Always use UTC for calculations
   
2. **CloudKit sync delays**
   - Solution: Optimistic UI updates with reconciliation
   
3. **Notification spam**
   - Solution: Smart notification throttling
   
4. **Streak addiction concerns**
   - Solution: Healthy habit messaging, break encouragement

## Launch Strategy

### Rollout Plan
1. **Soft launch** (Week 1): 10% of users
2. **Monitor & adjust** (Week 2): Fix issues
3. **Full launch** (Week 3): All users
4. **Marketing push** (Week 4): Feature promotion

### Communication
- In-app announcement
- Push notification introduction
- Email to existing users
- Social media campaign

---

**Ready to begin implementation!**