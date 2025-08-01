# Challenge System Orchestration Plan

## Overview
This document coordinates the multi-agent development of the SnapChef challenge system. All agents must reference this document and update their progress.

## Master Coordination Rules
1. **No Duplication**: Check existing files before creating new ones
2. **Use Existing Components**: Reference existing UI components and managers
3. **Update Documentation**: Keep CLAUDE.md and component docs updated
4. **Log Progress**: Update this file with completed tasks
5. **Maintain State**: Save work state for continuity

## Existing Components to Reuse
- `GlassmorphicCard` - Use for all card UI
- `MagicalBackground` - Use for view backgrounds
- `AppState` - Extend for challenge state
- `GamificationManager` - Already has base challenge logic
- `ChallengeDetailView` - Exists, can be extended
- Navigation: Integrate into existing `ContentView` tab system

## Phase 1: Foundation (Database + Core Logic)
**Status**: NOT STARTED
**Agent**: Database Architecture + Challenge Logic

### Tasks:
- [ ] Create Core Data models in `Core/Models/ChallengeModels.xcdatamodeld`
- [ ] Set up CloudKit container in `Core/Services/CloudKitManager.swift`
- [ ] Extend `GamificationManager` with persistence methods
- [ ] Create `ChallengeGenerator` in `Features/Gamification/ChallengeGenerator.swift`
- [ ] Build `ChallengeProgressTracker` in `Features/Gamification/ChallengeProgressTracker.swift`

### Files to Create:
```
Core/Models/ChallengeModels.xcdatamodeld
Core/Services/CloudKitManager.swift
Features/Gamification/ChallengeGenerator.swift
Features/Gamification/ChallengeProgressTracker.swift
Features/Gamification/ChallengeService.swift
```

### Files to Modify:
```
Features/Gamification/GamificationManager.swift (add persistence)
Core/ViewModels/AppState.swift (add challenge state)
```

## Phase 2: Features (UI + Rewards + Social)
**Status**: NOT STARTED
**Agents**: UI/UX + Rewards + Social

### Tasks:
- [ ] Create Challenge Hub view
- [ ] Build reward system with Chef Coins
- [ ] Implement social features
- [ ] Add notifications

### Files to Create:
```
Features/Gamification/Views/ChallengeHubView.swift
Features/Gamification/Views/ChallengeCardView.swift
Features/Gamification/Views/AchievementGalleryView.swift
Features/Gamification/RewardSystem.swift
Features/Gamification/ChefCoinsManager.swift
Features/Gamification/ChallengeNotificationManager.swift
Features/Gamification/Views/LeaderboardView.swift
```

### Files to Modify:
```
ContentView.swift (add Challenge Hub tab)
Features/Gamification/ChallengeDetailView.swift (enhance with new features)
```

## Phase 3: Integration
**Status**: NOT STARTED
**Agent**: Integration

### Tasks:
- [ ] Connect challenges to recipe generation
- [ ] Link rewards to social sharing
- [ ] Add premium challenges
- [ ] Integrate analytics

### Files to Modify:
```
Features/Camera/CameraView.swift (track challenge progress)
Features/Recipes/RecipeResultsView.swift (complete challenges)
Features/Sharing/ShareGeneratorView.swift (award social points)
Core/Services/SubscriptionManager.swift (premium challenges)
```

## Progress Log

### Session 1 - [DATE]
- Created orchestration plan
- No implementation started yet

## Recovery Instructions
If disconnected, the next session should:
1. Check this file for last completed task
2. Read the Progress Log
3. Continue from the next unchecked task
4. Update progress after each completion

## Agent Commands

### Phase 1 Command:
```
Build the foundation for the challenge system following CHALLENGE_SYSTEM_ORCHESTRATION.md Phase 1. Create Core Data models for challenges, set up CloudKit sync, and build the challenge generation/tracking logic. DO NOT create any UI views yet - only data models and business logic. Reuse existing GamificationManager and extend it rather than replacing.
```

### Phase 2 Command:
```
Build the UI and features for the challenge system following CHALLENGE_SYSTEM_ORCHESTRATION.md Phase 2. Create the Challenge Hub, reward system, and social features. Reuse existing UI components like GlassmorphicCard and MagicalBackground. Add the Challenge Hub to the existing tab navigation in ContentView.
```

### Phase 3 Command:
```
Integrate the challenge system with existing features following CHALLENGE_SYSTEM_ORCHESTRATION.md Phase 3. Connect challenges to recipe generation, social sharing, and subscriptions. Update existing views to track challenge progress. Do not duplicate existing functionality.
```