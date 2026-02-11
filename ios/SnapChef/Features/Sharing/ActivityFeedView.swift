import SwiftUI
import CloudKit

// MARK: - Array Extension for Batch Processing (removed duplicate extension)

// MARK: - Identifiable Wrappers for Sheet Presentation
struct IdentifiableRecipe: Identifiable {
    let id: String
    let recipe: Recipe
}

struct IdentifiableChallenge: Identifiable {
    let id: String
    let challenge: Challenge
}

struct IdentifiableUserProfile: Identifiable {
    let id: String
    let userID: String
    let userName: String
}

// MARK: - Activity Item Model
struct ActivityItem: Identifiable {
    let id: String
    let type: ActivityType
    let userID: String
    let userName: String  // This will be populated dynamically by the ActivityFeedManager
    let userPhoto: UIImage?
    let targetUserID: String?
    let targetUserName: String?  // This will be populated dynamically by the ActivityFeedManager
    let recipeID: String?
    let recipeName: String?
    let recipeImage: UIImage?
    let challengeID: String?  // For challenge-related activities
    let timestamp: Date
    let isRead: Bool

    enum ActivityType {
        case follow
        case recipeShared
        case recipeLiked
        case recipeComment
        case challengeCompleted
        case challengeShared  // When user shares a challenge
        case badgeEarned
        case profileUpdated  // Profile changes (username/photo)
        case profilePhotoUpdated  // Profile photo changes

        var icon: String {
            switch self {
            case .follow: return "person.badge.plus"
            case .recipeShared: return "square.and.arrow.up"
            case .recipeLiked: return "heart.fill"
            case .recipeComment: return "bubble.left.fill"
            case .challengeCompleted: return "checkmark.circle.fill"
            case .challengeShared: return "square.and.arrow.up.circle.fill"
            case .badgeEarned: return "medal.fill"
            case .profileUpdated, .profilePhotoUpdated: return "person.crop.circle.badge.checkmark"
            }
        }

        var color: Color {
            switch self {
            case .follow: return Color(hex: "#667eea")
            case .recipeShared: return Color(hex: "#43e97b")
            case .recipeLiked: return Color(hex: "#ff6b6b")
            case .recipeComment: return Color(hex: "#4ecdc4")
            case .challengeCompleted: return Color(hex: "#ffd93d")
            case .challengeShared: return Color(hex: "#9b59b6")
            case .badgeEarned: return Color(hex: "#ff6b6b")
            case .profileUpdated, .profilePhotoUpdated: return Color(hex: "#667eea")
            }
        }
    }

    @MainActor
    var activityText: AttributedString {
        var text = AttributedString()
        
        // Check if this is the current user's own activity
        let currentUserID = UnifiedAuthManager.shared.currentUser?.recordID
        let isOwnActivity = userID == currentUserID

        // User name (bold) - show "You" for own activities
        var userName = AttributedString(isOwnActivity ? "You" : self.userName)
        userName.font = .system(size: 16, weight: .semibold)
        text += userName

        // Activity description
        switch type {
        case .follow:
            text += AttributedString(" started following you")
        case .recipeShared:
            text += AttributedString(" shared a new recipe: ")
            if let recipeName = recipeName {
                var recipe = AttributedString(recipeName)
                recipe.font = .system(size: 16, weight: .medium)
                text += recipe
            }
        case .recipeLiked:
            if isOwnActivity {
                text += AttributedString(" liked a recipe: ")
            } else {
                text += AttributedString(" liked your recipe: ")
            }
            if let recipeName = recipeName {
                var recipe = AttributedString(recipeName)
                recipe.font = .system(size: 16, weight: .medium)
                text += recipe
            }
        case .recipeComment:
            if targetUserID != nil {
                // This is a notification for the recipe owner
                if isOwnActivity {
                    // You commented on someone else's recipe
                    text += AttributedString(" commented on ")
                    if let targetName = targetUserName {
                        var target = AttributedString(targetName + "'s")
                        target.font = .system(size: 16, weight: .medium)
                        text += target
                    }
                    text += AttributedString(" recipe")
                } else {
                    // Someone else commented on your recipe
                    text += AttributedString(" commented on your recipe")
                }
            } else {
                // This is a public activity (recipeCommented type)
                text += AttributedString(" commented on a recipe")
                if let recipeName = recipeName {
                    text += AttributedString(": ")
                    var recipe = AttributedString(recipeName)
                    recipe.font = .system(size: 16, weight: .medium)
                    text += recipe
                }
            }
        case .challengeCompleted:
            text += AttributedString(" completed the challenge: ")
            if let recipeName = recipeName { // Using recipeName for challenge name
                var challenge = AttributedString(recipeName)
                challenge.font = .system(size: 16, weight: .medium)
                text += challenge
            }
        case .challengeShared:
            text += AttributedString(" shared a completed challenge: ")
            if let recipeName = recipeName { // Using recipeName for challenge name
                var challenge = AttributedString(recipeName)
                challenge.font = .system(size: 16, weight: .medium)
                text += challenge
            }
        case .badgeEarned:
            text += AttributedString(" earned a new badge!")
        case .profileUpdated:
            text += AttributedString(" updated their profile")
        case .profilePhotoUpdated:
            text += AttributedString(" updated their profile photo")
        }

        return text
    }
}

// MARK: - Activity Feed View
struct ActivityFeedView: View {
    // Use shared singleton instance for preloaded data
    @StateObject private var feedManager = {
        print("🔍 DEBUG: Using shared ActivityFeedManager singleton")
        return ActivityFeedManager.shared
    }()
    @EnvironmentObject var appState: AppState
    @State private var selectedFilter: ActivityFilter = .all
    @State private var showingRecipeDetail = false
    @State private var selectedRecipeID: String?
    @State private var selectedRecipe: Recipe?
    @State private var isLoadingRecipe = false
    @State private var showingChallengeDetail = false
    @State private var selectedChallengeID: String?
    @State private var selectedChallenge: Challenge?
    
    // Use identifiable wrappers for sheet presentation
    @State private var sheetRecipe: IdentifiableRecipe?
    @State private var sheetChallenge: IdentifiableChallenge?
    @State private var sheetUserProfile: IdentifiableUserProfile?

    enum ActivityFilter: String, CaseIterable {
        case all = "All"
        case social = "Social"
        case recipes = "Recipes"
        case challenges = "Challenges"

        var icon: String {
            switch self {
            case .all: return "sparkles"
            case .social: return "person.2"
            case .recipes: return "fork.knife"
            case .challenges: return "trophy"
            }
        }
    }

    var body: some View {
        let _ = print("🔍 DEBUG: ActivityFeedView body called")
        return NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(ActivityFilter.allCases, id: \.self) { filter in
                                FilterPill(
                                    title: filter.rawValue,
                                    icon: filter.icon,
                                    isSelected: selectedFilter == filter,
                                    action: {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedFilter = filter
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 16)

                    // PHASE 6: Optimized loading states
                    if feedManager.showingSkeletonViews && feedManager.activities.isEmpty {
                        // Only show skeleton for initial load when no cached data
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(0..<5, id: \.self) { _ in
                                    SkeletonActivityView()
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    } else if feedManager.activities.isEmpty && !feedManager.isLoading {
                        // Show empty state only when not loading
                        EmptyActivityView()
                    } else {
                        // Show content (with optional refresh indicator)
                        ScrollView {
                            // PHASE 6: Subtle refresh indicator at top when refreshing
                            if feedManager.isLoading && !feedManager.activities.isEmpty {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                    Text("Updating...")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 8)
                            }
                            
                            LazyVStack(spacing: 16) {
                                ForEach(filteredActivities) { activity in
                                    Button(action: {
                                        handleActivityTap(activity)
                                    }) {
                                        ActivityItemView(activity: activity)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .onAppear {
                                        // Mark activity as read when it appears on screen
                                        if !activity.isRead {
                                            Task {
                                                await feedManager.markActivityAsRead(activity.id)
                                            }
                                        }
                                        
                                        // Load more when approaching end
                                        if activity.id == filteredActivities.last?.id {
                                            Task {
                                                await feedManager.loadMore()
                                            }
                                        }
                                    }
                                }

                                if feedManager.hasMore && feedManager.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                        .padding()
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                        .refreshable {
                            await feedManager.refresh()
                        }
                    }
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await feedManager.refresh()
            }
        }
        .onAppear {
            print("🔍 DEBUG: ActivityFeedView appeared - Start")
            
            // Load activities if empty, otherwise fetch newest
            Task {
                if feedManager.activities.isEmpty {
                    print("📱 ActivityFeedView: No activities, loading...")
                    await feedManager.loadInitialActivities()
                } else {
                    print("✅ ActivityFeedView: Have \(feedManager.activities.count) cached activities, checking for new...")
                    await feedManager.fetchNewestActivitiesOnly()
                }
            }
            
            print("🔍 DEBUG: ActivityFeedView appeared - End")
        }
        .sheet(item: $sheetRecipe) { identifiableRecipe in
            NavigationStack {
                RecipeDetailView(recipe: identifiableRecipe.recipe)
                    .environmentObject(appState)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(hex: "#0f0625"),
                                Color(hex: "#1a0033"),
                                Color(hex: "#0a051a")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .ignoresSafeArea()
                    )
            }
            .onAppear {
                print("🎯 RECIPE SHEET APPEARED")
                print("   - Recipe: \(identifiableRecipe.recipe.name)")
                print("   - ID: \(identifiableRecipe.recipe.id)")
                print("   - Ingredients: \(identifiableRecipe.recipe.ingredients.count)")
                print("   - Instructions: \(identifiableRecipe.recipe.instructions.count)")
            }
        }
        .sheet(item: $sheetChallenge) { identifiableChallenge in
            ChallengeDetailView(challenge: identifiableChallenge.challenge)
                .environmentObject(appState)
                .onAppear {
                    print("🎯 CHALLENGE SHEET APPEARED")
                    print("   - Challenge: \(identifiableChallenge.challenge.title)")
                    print("   - ID: \(identifiableChallenge.challenge.id)")
                    print("   - Type: \(identifiableChallenge.challenge.type)")
                }
        }
        .sheet(item: $sheetUserProfile) { identifiableUserProfile in
            UserProfileView(
                userID: identifiableUserProfile.userID,
                userName: identifiableUserProfile.userName
            )
            .environmentObject(appState)
            .onAppear {
                print("🎯 USER PROFILE SHEET APPEARED")
                print("   - User: \(identifiableUserProfile.userName)")
                print("   - ID: \(identifiableUserProfile.userID)")
            }
        }
    }

    private var filteredActivities: [ActivityItem] {
        switch selectedFilter {
        case .all:
            return feedManager.activities
        case .social:
            return feedManager.activities.filter { $0.type == .follow }
        case .recipes:
            return feedManager.activities.filter {
                $0.type == .recipeShared || $0.type == .recipeLiked || $0.type == .recipeComment
            }
        case .challenges:
            return feedManager.activities.filter {
                $0.type == .challengeCompleted || $0.type == .challengeShared || $0.type == .badgeEarned
            }
        }
    }

    private func handleActivityTap(_ activity: ActivityItem) {
        print("🎯 ACTIVITY TAPPED: \(activity.type)")
        print("🔍 Activity details:")
        print("   - ID: \(activity.id)")
        print("   - Type: \(activity.type)")
        print("   - Recipe ID: \(activity.recipeID ?? "nil")")
        print("   - Recipe Name: \(activity.recipeName ?? "nil")")
        print("   - User Name: \(activity.userName)")
        
        switch activity.type {
        case .recipeShared, .recipeLiked, .recipeComment:
            if let recipeID = activity.recipeID {
                print("🎯 RECIPE ACTIVITY TAPPED - Recipe ID: \(recipeID)")
                selectedRecipeID = recipeID
                loadRecipeAndShowDetail(recipeID: recipeID)
            } else {
                print("⚠️ Activity tapped but no recipe ID available")
                print("⚠️ Activity type: \(activity.type)")
                print("⚠️ Activity: \(activity)")
            }
        case .follow:
            // Navigate to user profile - show the person who performed the follow action (actor)
            print("👥 Follow activity tapped - showing profile of user who followed: \(activity.userName)")
            let userProfile = IdentifiableUserProfile(
                id: activity.userID,
                userID: activity.userID,
                userName: activity.userName
            )
            sheetUserProfile = userProfile
            print("✅ User profile sheet set for follower: \(activity.userName)")
        case .challengeCompleted, .challengeShared:
            // Show challenge detail popup
            let actionType = activity.type == .challengeCompleted ? "completed" : "shared"
            print("🏆 Challenge \(actionType) activity tapped - showing challenge detail")
            if let challengeID = activity.challengeID ?? activity.recipeID {
                // Some activities might store challenge ID in recipeID field
                print("🎯 CHALLENGE ACTIVITY - Challenge ID: \(challengeID)")
                selectedChallengeID = challengeID
                loadChallengeAndShowDetail(challengeID: challengeID)
            } else if let challengeName = activity.recipeName {
                // Try to find challenge by name if no ID
                print("🔍 Looking for challenge by name: \(challengeName)")
                if let challenge = findChallengeByName(challengeName) {
                    selectedChallenge = challenge
                    selectedChallengeID = challenge.id
                    // Show the sheet using the item binding
                    sheetChallenge = IdentifiableChallenge(id: challenge.id, challenge: challenge)
                    print("🎯 sheetChallenge set from name search: \(challenge.title)")
                }
            }
            break
        case .badgeEarned:
            // Show badge detail
            print("🏅 Badge activity tapped - badge detail view not implemented")
            break
        case .profileUpdated, .profilePhotoUpdated:
            // Profile update activities are just for cache refresh, not interactive
            print("👤 Profile update activity - cache refresh only")
            break
        }
    }
    
    private func loadRecipeAndShowDetail(recipeID: String) {
        print("🚀 STARTING loadRecipeAndShowDetail for ID: \(recipeID)")
        
        // Prevent multiple concurrent loads
        guard !isLoadingRecipe else {
            print("⚠️ Already loading a recipe, ignoring duplicate request")
            return
        }
        
        // Try to load recipe from local app state first
        print("🔍 STEP 1: Checking local app state for recipe: \(recipeID)")
        if let localRecipe = findLocalRecipe(by: recipeID) {
            print("✅ FOUND LOCAL RECIPE: \(localRecipe.name)")
            print("🔍 Local recipe data check:")
            print("   - Ingredients: \(localRecipe.ingredients.count)")
            print("   - Instructions: \(localRecipe.instructions.count)")
            print("   - Name: '\(localRecipe.name)'")
            print("   - Description: '\(localRecipe.description)'")
            
            // Set the recipe using the identifiable wrapper
            selectedRecipe = localRecipe
            selectedRecipeID = recipeID
            print("✅ Local recipe set: \(selectedRecipe?.name ?? "nil"), ID: \(recipeID)")
            
            // Show the sheet using the item binding
            sheetRecipe = IdentifiableRecipe(id: recipeID, recipe: localRecipe)
            print("✅ UI STATE UPDATED: sheetRecipe set")
            print("✅ Recipe check before sheet: \(localRecipe.name)")
            return
        }
        
        // If not found locally, try to load from CloudKit asynchronously
        print("🔍 STEP 2: No local recipe found, attempting CloudKit fetch for ID: \(recipeID)")
        print("⚡ CloudKit fetch starting...")
        
        Task { @MainActor in
            isLoadingRecipe = true
            defer { isLoadingRecipe = false }
            
            do {
                // Fetch from CloudKit (this call is already async)
                let recipe = try await CloudKitService.shared.fetchRecipe(by: recipeID)
                print("✅ CLOUDKIT FETCH SUCCESS: \(recipe.name)")
                
                print("🔍 CloudKit recipe data verification:")
                print("   - Recipe ID: \(recipe.id)")
                print("   - Name: '\(recipe.name)' (length: \(recipe.name.count))")
                print("   - Description: '\(recipe.description)' (length: \(recipe.description.count))")
                print("   - Ingredients count: \(recipe.ingredients.count)")
                print("   - Instructions count: \(recipe.instructions.count)")
                print("   - Prep time: \(recipe.prepTime), Cook time: \(recipe.cookTime)")
                print("   - Servings: \(recipe.servings)")
                print("   - Difficulty: \(recipe.difficulty.rawValue)")
                print("   - Nutrition calories: \(recipe.nutrition.calories)")
                
                print("🎯 SETTING CloudKit recipe...")
                selectedRecipe = recipe
                selectedRecipeID = recipeID
                print("✅ CloudKit recipe set: \(recipe.name), ID: \(recipeID)")
                
                // Show the sheet using the item binding
                sheetRecipe = IdentifiableRecipe(id: recipeID, recipe: recipe)
                print("✅ UI STATE UPDATED with CloudKit recipe: sheetRecipe set")
                print("✅ Successfully loaded recipe: \(recipe.name)")
                print("🔍 Recipe details - Ingredients: \(recipe.ingredients.count), Instructions: \(recipe.instructions.count)")
            } catch {
                print("❌ RECIPE LOAD FAILED for ID: \(recipeID)")
                print("❌ Error details: \(error)")
                print("❌ Error type: \(type(of: error))")
                
                // Check if it's a specific "not found" error
                if let ckError = error as? CKError {
                    print("❌ CloudKit Error Code: \(ckError.code)")
                    print("❌ CloudKit Error Description: \(ckError.localizedDescription)")
                    if ckError.code == .unknownItem {
                        print("📄 Recipe \(recipeID) does not exist in CloudKit")
                    }
                } else {
                    print("⚠️ Other error loading recipe: \(error.localizedDescription)")
                }
                
                // Don't show detail view for non-existent recipes
                // Just log and continue - user won't see a broken view
            }
        }
    }
    
    private func findLocalRecipe(by id: String) -> Recipe? {
        // Search through all local recipes
        let foundRecipe = appState.allRecipes.first { $0.id.uuidString == id }
        if foundRecipe != nil {
            print("✅ Found local recipe: \(foundRecipe!.name)")
        } else {
            print("🔍 Recipe \(id) not found locally, will try CloudKit")
        }
        return foundRecipe
    }
    
    private func loadChallengeAndShowDetail(challengeID: String) {
        print("🚀 Loading challenge with ID: \(challengeID)")
        
        // Try to find challenge in GamificationManager
        let gamificationManager = GamificationManager.shared
        
        // Check active challenges
        if let challenge = gamificationManager.activeChallenges.first(where: { $0.id == challengeID }) {
            print("✅ Found active challenge: \(challenge.title)")
            print("   - ID: \(challenge.id)")
            print("   - Type: \(challenge.type)")
            print("   - Description: \(challenge.description)")
            
            // Set the challenge using the identifiable wrapper
            selectedChallenge = challenge
            selectedChallengeID = challengeID
            print("📋 selectedChallenge set to: \(selectedChallenge?.title ?? "nil")")
            
            // Show the sheet using the item binding
            sheetChallenge = IdentifiableChallenge(id: challengeID, challenge: challenge)
            print("🎯 sheetChallenge set")
            print("📋 Final check - challenge: \(challenge.title)")
            return
        }
        
        // If not found in active challenges, create a placeholder
        // This might happen if the challenge has ended but is still in activity feed
        print("⚠️ Challenge not found in active challenges, creating placeholder")
        print("   Available challenges: \(gamificationManager.activeChallenges.map { $0.id })")
        
        // Create a basic challenge object from the ID
        // In a real app, this would fetch from CloudKit or cache
        let placeholderChallenge = Challenge(
            id: challengeID,
            title: "Completed Challenge",
            description: "This challenge has ended",
            type: .special,
            endDate: Date().addingTimeInterval(86400)
        )
        
        // Set the challenge using the identifiable wrapper
        selectedChallenge = placeholderChallenge
        selectedChallengeID = challengeID
        print("📋 selectedChallenge set to placeholder: \(selectedChallenge?.title ?? "nil")")
        
        // Show the sheet using the item binding
        sheetChallenge = IdentifiableChallenge(id: challengeID, challenge: placeholderChallenge)
        print("🎯 sheetChallenge set")
        print("📋 Final check - challenge: \(placeholderChallenge.title)")
    }
    
    private func findChallengeByName(_ name: String) -> Challenge? {
        let gamificationManager = GamificationManager.shared
        
        // Check active challenges
        if let challenge = gamificationManager.activeChallenges.first(where: { $0.title == name }) {
            return challenge
        }
        
        // If not found, return nil
        // In a real app, we could search CloudKit or cache here
        return nil
    }
}

// MARK: - Activity Item View
struct ActivityItemView: View {
    let activity: ActivityItem

    var body: some View {
        HStack(spacing: 16) {
            // User Avatar with profile photo
            ZStack {
                if let userPhoto = activity.userPhoto {
                    Image(uiImage: userPhoto)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                } else {
                    UserAvatarView(
                        userID: activity.userID,
                        username: activity.userName,
                        displayName: activity.userName,
                        size: 50
                    )
                }

                // Activity Type Icon
                Circle()
                    .fill(activity.type.color)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: activity.type.icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .offset(x: 18, y: 18)
            }

            VStack(alignment: .leading, spacing: 6) {
                // Activity Text
                Text(activity.activityText)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .lineLimit(2)

                // Timestamp
                Text(formatTimestamp(activity.timestamp))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            // Recipe Image (if applicable)
            if let recipeImage = activity.recipeImage {
                Image(uiImage: recipeImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(activity.isRead ? 0.05 : 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Filter Pill
struct FilterPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color(hex: "#667eea") : Color.white.opacity(0.1))
            )
        }
    }
}

// MARK: - Empty Activity View
struct EmptyActivityView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))

            Text("No activity yet")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text("Follow other chefs and share recipes\nto see activity here")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Activity Feed Manager
@MainActor
class ActivityFeedManager: ObservableObject {
    // SINGLETON: Shared instance for background preloading
    static let shared = ActivityFeedManager()

    private struct ImageCacheEntry {
        let image: UIImage
        let createdAt: Date
        var lastAccessedAt: Date
    }
    
    @Published var activities: [ActivityItem] = []
    
    // Progressive loading configuration
    private let initialLoadSize = 5    // Show first 5 items instantly
    private let secondLoadSize = 15    // Then load 15 more
    private let batchSize = 25         // Regular batch size for pagination
    
    // Task lifecycle management
    private var currentLoadTask: Task<Void, Never>?
    private var currentRefreshTask: Task<Void, Never>?
    private var backgroundLoadTask: Task<Void, Never>?
    @Published var isLoading = false
    @Published var hasMore = true
    @Published var showingSkeletonViews = false
    
    // Prevent concurrent refreshes
    private var isRefreshing = false

    // Lazy initialization to prevent crashes
    private var cloudKitSync: CloudKitService {
        CloudKitService.shared
    }
    private var lastFetchedRecord: CKRecord?
    // PHASE 5: Enhanced user cache with TTL
    private var userCache: [String: (user: CloudKitUser, timestamp: Date)] = [:] // Cache with timestamps
    private var profilePhotoCache: [String: ImageCacheEntry] = [:]
    private var recipeImageCache: [String: ImageCacheEntry] = [:]
    private var missingRecipeImageIDs: [String: Date] = [:]
    private var profilePhotoCacheHits = 0
    private var profilePhotoCacheMisses = 0
    private var recipeImageCacheHits = 0
    private var recipeImageCacheMisses = 0
    private var lastCacheTelemetryAt = Date.distantPast
    private let cacheTelemetryInterval: TimeInterval = 120
    private let profileImageCacheTTL: TimeInterval = 6 * 60 * 60
    private let recipeImageCacheTTL: TimeInterval = 24 * 60 * 60
    private let missingRecipeImageTTL: TimeInterval = 4 * 60 * 60
    private let profileImageCacheMaxEntries = 80
    private let recipeImageCacheMaxEntries = 120
    private let missingRecipeImageMaxEntries = 200
    private let userCacheTTL: TimeInterval = Double.greatestFiniteMagnitude // Never expire - keep user data forever
    // PHASE 7: Memory management
    private let maxCacheSize = 100 // Maximum number of cached users
    private let maxActivities = 100 // Maximum activities to keep in memory (updated for better UX)
    private var publicDatabase: CKDatabase {
        CKContainer(identifier: CloudKitConfig.containerIdentifier).publicCloudDatabase
    }
    
    // Cache configuration for persistent storage
    private let cacheKey = "ActivityFeedCache"
    private let cacheTimestampKey = "ActivityFeedCacheTimestamp"
    
    // File storage for activities
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private var activitiesDirectory: URL { 
        documentsDirectory.appendingPathComponent("activities")
    }

    func loadInitialActivities() async {
        print("🔍 DEBUG: loadInitialActivities started")
        
        // Cancel any existing load task
        currentLoadTask?.cancel()
        
        // Prevent concurrent loads
        guard !isLoading else {
            print("⚠️ Already loading activities, skipping")
            return
        }
        
        await MainActor.run {
            print("🔍 DEBUG: Setting showingSkeletonViews = true")
            showingSkeletonViews = activities.isEmpty // Only show skeleton if no existing data
            print("🔍 DEBUG: Setting isLoading = true")
            isLoading = true
        }

        print("🔍 DEBUG: Loading cached activities from disk")
        // Load from persistent storage first
        await loadCachedActivities()
        
        // Always fetch newest activities to check for updates
        print("🔍 DEBUG: Fetching newest activities from CloudKit")
        await fetchNewestActivitiesOnly()
        
        await MainActor.run {
            print("🔍 DEBUG: Setting showingSkeletonViews = false")
            showingSkeletonViews = false
            print("🔍 DEBUG: Setting isLoading = false")
            isLoading = false
        }

        emitImageCacheTelemetryIfNeeded(force: true)
        
        print("🔍 DEBUG: loadInitialActivities completed with \(activities.count) activities")
    }

    func loadMore() async {
        guard hasMore && !isLoading else { return }

        isLoading = true

        await fetchActivitiesFromCloudKit(loadMore: true)

        isLoading = false
    }

    func refresh() async {
        // Cancel any existing refresh task
        currentRefreshTask?.cancel()
        
        // Prevent concurrent refreshes
        guard !isRefreshing else { 
            print("⚠️ Refresh already in progress, skipping")
            return 
        }
        
        isRefreshing = true
        defer { 
            isRefreshing = false
        }
        
        // Always fetch only newest activities
        print("🔄 Refresh: fetching newest activities only")
        await fetchNewestActivitiesOnly()
        emitImageCacheTelemetryIfNeeded(force: true)
    }
    
    // Check if we need to fetch new activities
    func needsRefresh() -> Bool {
        // Always return false - we fetch newest on each load, no timer-based refresh
        return false
    }
    
    // Fetch only activities newer than what we have locally
    func fetchNewestActivitiesOnly() async {
        guard let currentUser = UnifiedAuthManager.shared.currentUser,
              let userID = currentUser.recordID else {
            print("❌ No authenticated user for activity fetch")
            return
        }
        
        // Get the timestamp of our newest local activity
        let newestTimestamp = activities.first?.timestamp ?? Date.distantPast
        print("🔍 Fetching activities newer than: \(newestTimestamp)")
        
        do {
            // Fetch followed users
            let followedUsers = await fetchFollowedUsers(for: userID)
            var allUserIDs = followedUsers
            allUserIDs.append(userID) // Include own activities
            
            // Create predicate for activities newer than our newest
            let predicate = NSPredicate(
                format: "%K IN %@ AND %K > %@",
                CKField.Activity.actorID,
                allUserIDs,
                CKField.Activity.timestamp,
                newestTimestamp as NSDate
            )
            
            let query = CKQuery(recordType: CloudKitConfig.activityRecordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: CKField.Activity.timestamp, ascending: false)]
            
            // Use CloudKitActor for safe fetch
            let records = try await cloudKitSync.cloudKitActor.executeQuery(query, desiredKeys: nil, resultsLimit: 50)
            
            var newActivities: [ActivityItem] = []
            for record in records {
                if let activity = await mapCloudKitRecordToActivityItem(record) {
                    newActivities.append(activity)
                }
            }
            
            if !newActivities.isEmpty {
                await mergeNewActivities(newActivities)
                print("✅ Fetched \(newActivities.count) new activities from CloudKit")
            } else {
                print("✅ No new activities since last sync")
            }
            
        } catch {
            print("❌ Failed to fetch newest activities: \(error)")
        }
    }
    
    // Merge new activities with existing ones
    private func mergeNewActivities(_ newActivities: [ActivityItem]) async {
        await MainActor.run {
            // Get existing activity IDs to prevent duplicates
            let existingIds = Set(activities.map { $0.id })
            
            // Filter out duplicates
            let uniqueNew = newActivities.filter { !existingIds.contains($0.id) }
            
            if !uniqueNew.isEmpty {
                // Prepend new activities and re-sort
                activities = (uniqueNew + activities).sorted { $0.timestamp > $1.timestamp }
                
                // Limit to max activities
                if activities.count > maxActivities {
                    activities = Array(activities.prefix(maxActivities))
                }
                
                print("✅ Merged \(uniqueNew.count) new activities (filtered \(newActivities.count - uniqueNew.count) duplicates)")
                
                // Save to disk
                Task {
                    await saveCachedActivities()
                }
            }
        }
    }
    
    // Fetch users that the current user is following
    private func fetchFollowedUsers(for userID: String) async -> [String] {
        do {
            let predicate = NSPredicate(
                format: "%K == %@ AND %K == %d",
                CKField.Follow.followerID,
                userID,
                CKField.Follow.isActive,
                1
            )
            
            let query = CKQuery(recordType: CloudKitConfig.followRecordType, predicate: predicate)
            let records = try await cloudKitSync.cloudKitActor.executeQuery(query, desiredKeys: nil, resultsLimit: 100)
            
            let followedUsers = records.compactMap { record in
                record[CKField.Follow.followingID] as? String
            }
            
            print("📱 Found \(followedUsers.count) followed users")
            return followedUsers
            
        } catch {
            print("❌ Failed to fetch followed users: \(error)")
            return []
        }
    }
    
    /// Preload feed data in background without blocking UI
    func preloadInBackground() async {
        // Always load from disk first, then fetch newest
        if !activities.isEmpty {
            print("📱 Activities already loaded: \(activities.count) items")
            // Still fetch newest to check for updates
            await fetchNewestActivitiesOnly()
            return
        }
        
        // Only preload if not already loading
        guard !isLoading else { 
            print("📱 Preload skipped - already loading")
            return 
        }
        
        print("📱 Starting background preload of social feed...")
        await loadInitialActivities()
        print("📱 Preload complete: \(activities.count) activities ready")
    }

    func markActivityAsRead(_ activityID: String) async {
        // Mark activity as read in CloudKit
        do {
            try await cloudKitSync.markActivityAsRead(activityID)
            
            // Update local activity state
            if let index = activities.firstIndex(where: { $0.id == activityID }) {
                let updatedActivity = activities[index]
                // Create a new ActivityItem with isRead = true
                let readActivity = ActivityItem(
                    id: updatedActivity.id,
                    type: updatedActivity.type,
                    userID: updatedActivity.userID,
                    userName: updatedActivity.userName,
                    userPhoto: updatedActivity.userPhoto,
                    targetUserID: updatedActivity.targetUserID,
                    targetUserName: updatedActivity.targetUserName,
                    recipeID: updatedActivity.recipeID,
                    recipeName: updatedActivity.recipeName,
                    recipeImage: updatedActivity.recipeImage,
                    challengeID: updatedActivity.challengeID,
                    timestamp: updatedActivity.timestamp,
                    isRead: true
                )
                activities[index] = readActivity
                print("✅ Local activity state updated to read: \(activityID)")
            } else {
                print("⚠️ Activity not found in local state: \(activityID)")
            }
        } catch {
            print("❌ Failed to mark activity as read: \(error)")
            // Don't crash the app, just log the error
            // The activity will remain unread in the UI
        }
    }

    private func fetchActivitiesFromCloudKit(loadMore: Bool = false) async {
        print("🔍 DEBUG: fetchActivitiesFromCloudKit started")
        
        // First check if iCloud is available
        let container = CKContainer(identifier: CloudKitConfig.containerIdentifier)
        do {
            let accountStatus = try await container.accountStatus()
            if accountStatus != .available {
                print("⚠️ iCloud not available, status: \(accountStatus)")
                await MainActor.run {
                    activities = generateMockActivities()
                    hasMore = false
                }
                return
            }
        } catch {
            print("❌ Failed to check iCloud status: \(error)")
            await MainActor.run {
                activities = generateMockActivities()
                hasMore = false
            }
            return
        }
        
        guard let currentUser = UnifiedAuthManager.shared.currentUser else {
            print("❌ No current user found")
            await MainActor.run {
                activities = generateMockActivities()
                hasMore = false
            }
            return
        }
        
        guard let userID = currentUser.recordID else {
            print("❌ Current user has no recordID")
            await MainActor.run {
                activities = generateMockActivities()
                hasMore = false
            }
            return
        }
        
        print("🔍 DEBUG: User authenticated with ID: \(userID)")

        do {
            // PHASE 3 OPTIMIZATION: Enhanced parallel fetching with async let
            // Fetch followed users and activities simultaneously instead of sequentially
            print("🚀 Starting parallel fetch with async let...")
            
            // Start both operations simultaneously
            async let followedUsersTask = fetchFollowedUserIDs(for: userID)
            async let targetedActivitiesTask = cloudKitSync.fetchActivityFeed(for: userID, limit: 25)
            
            // Wait for both to complete
            let (followedUserIDs, targetedActivities) = try await (followedUsersTask, targetedActivitiesTask)
            
            print("✅ Parallel fetch complete: \(followedUserIDs.count) followed users, \(targetedActivities.count) targeted activities")
            
            // Now fetch activities from followed users using the IDs we got
            let followedActivities: [CKRecord]
            if !followedUserIDs.isEmpty {
                // Include self in the query
                var queryUserIDs = followedUserIDs
                queryUserIDs.append(userID)
                
                // Limit to prevent CloudKit predicate size issues
                let limitedUserIDs = Array(queryUserIDs.prefix(10))
                
                let activityPredicate = NSPredicate(format: "actorID IN %@", limitedUserIDs)
                let activityQuery = CKQuery(recordType: CloudKitConfig.activityRecordType, predicate: activityPredicate)
                
                // Progressive loading: Use smaller initial batch for instant display
                let fetchLimit = loadMore ? batchSize : initialLoadSize
                
                followedActivities = try await cloudKitSync.cloudKitActor.executeQuery(
                    activityQuery, 
                    desiredKeys: nil, 
                    resultsLimit: fetchLimit
                )
                print("✅ Fetched \(followedActivities.count) activities from followed users")
            } else {
                followedActivities = []
            }
            
            // Combine all activities
            let allActivityRecords = targetedActivities + followedActivities
            print("📊 PERFORMANCE: Total activities before dedup: \(allActivityRecords.count)")
            
            // Remove duplicates based on record ID
            var seenRecordIDs = Set<String>()
            var uniqueRecords: [CKRecord] = []
            for record in allActivityRecords {
                if !seenRecordIDs.contains(record.recordID.recordName) {
                    seenRecordIDs.insert(record.recordID.recordName)
                    uniqueRecords.append(record)
                }
            }
            
            let sortedRecords = uniqueRecords.sorted { record1, record2 in
                let date1 = record1[CKField.Activity.timestamp] as? Date ?? Date.distantPast
                let date2 = record2[CKField.Activity.timestamp] as? Date ?? Date.distantPast
                return date1 > date2
            }
            
            // Take only the most recent activities
            let limitedRecords = Array(sortedRecords.prefix(30))
            
            // Batch fetch all unique user IDs to avoid redundant fetches
            if !limitedRecords.isEmpty {
                await batchFetchUsers(from: limitedRecords)
            }
            
            // Map records to activity items with error handling
            let newActivities = await withTaskGroup(of: ActivityItem?.self) { group in
                for record in limitedRecords {
                    group.addTask {
                        // mapCloudKitRecordToActivityItem doesn't throw, just returns optional
                        return await self.mapCloudKitRecordToActivityItem(record)
                    }
                }
                
                var results: [ActivityItem] = []
                var seenIds = Set<String>()
                for await result in group {
                    if let activity = result {
                        // Filter out duplicate activity IDs
                        if !seenIds.contains(activity.id) {
                            seenIds.insert(activity.id)
                            results.append(activity)
                            print("✅ Added activity \(activity.id) by \(activity.userName)")
                        } else {
                            print("⚠️ Skipping duplicate activity ID: \(activity.id)")
                        }
                    }
                }
                
                // IMPORTANT: Sort results by timestamp to maintain chronological order
                // TaskGroup returns results in completion order, not input order
                let sortedResults = results.sorted { activity1, activity2 in
                    return activity1.timestamp > activity2.timestamp
                }
                
                return sortedResults
            }

            if loadMore {
                // Filter out duplicates before appending
                let existingIds = Set(activities.map { $0.id })
                let uniqueNewActivities = newActivities.filter { !existingIds.contains($0.id) }
                
                if !uniqueNewActivities.isEmpty {
                    activities.append(contentsOf: uniqueNewActivities)
                    // Re-sort after appending to maintain chronological order
                    activities.sort { $0.timestamp > $1.timestamp }
                    print("✅ Added \(uniqueNewActivities.count) unique activities (\(newActivities.count - uniqueNewActivities.count) duplicates filtered)")
                } else {
                    print("⚠️ All \(newActivities.count) activities were duplicates, none added")
                }
                // Always maintain memory limits
                maintainMemoryLimits()
            } else {
                // Sort new activities by timestamp (newest first)
                activities = newActivities.sorted { $0.timestamp > $1.timestamp }
                // Maintain memory limits even on initial load
                maintainMemoryLimits()
            }

            // Check if there are more activities to load
            // Use the actual fetch limit, not hardcoded 25
            let expectedLimit = loadMore ? batchSize : initialLoadSize
            hasMore = newActivities.count >= expectedLimit

            print("✅ Loaded \(newActivities.count) total activities (initial: \(!loadMore))")
            
            // Progressive loading: If this was the initial small batch, load more in background
            if !loadMore && newActivities.count >= initialLoadSize && hasMore {
                // Cancel any existing background load
                backgroundLoadTask?.cancel()
                
                backgroundLoadTask = Task { @MainActor in
                    // Small delay to let UI render first batch
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                    
                    // Check if task was cancelled
                    if !Task.isCancelled {
                        // Load more activities using the existing method
                        await self.fetchActivitiesFromCloudKit(loadMore: true)
                    }
                }
            }
            
            // Save to cache
            await saveCachedActivities()
        } catch {
            print("❌ CloudKit activity fetch error: \(error)")
            // Fallback to cached or mock data
            if activities.isEmpty {
                activities = generateMockActivities()
            }
            hasMore = false
        }
    }

    
    /// Efficiently fetch just the IDs of users being followed
    private func fetchFollowedUserIDs(for userID: String) async throws -> [String] {
        let followingPredicate = NSPredicate(format: "followerID == %@ AND isActive == %d", userID, 1)
        let followingQuery = CKQuery(recordType: "Follow", predicate: followingPredicate)
        
        // Use CloudKitActor for safe query execution
        let cloudKitSync = CloudKitService.shared
        let followRecords = try await cloudKitSync.cloudKitActor.executeQuery(
            followingQuery, 
            desiredKeys: ["followingID"], // Only fetch the ID field we need
            resultsLimit: 50  // Get up to 50 followed users
        )
        
        var followedUserIDs: [String] = []
        for record in followRecords {
            if let followingID = record["followingID"] as? String {
                followedUserIDs.append(followingID)
            }
        }
        
        print("📊 Found \(followedUserIDs.count) followed users")
        return followedUserIDs
    }
    
    private func fetchFollowedUserActivities(limit: Int) async throws -> [CKRecord] {
        guard let currentUser = UnifiedAuthManager.shared.currentUser,
              let currentUserID = currentUser.recordID else {
            return []
        }
        
        // Step 1: Get list of users this person follows
        let followingPredicate = NSPredicate(format: "followerID == %@ AND isActive == %d", currentUserID, 1)
        let followingQuery = CKQuery(recordType: "Follow", predicate: followingPredicate)
        
        var followedUserIDs: [String] = []
        
        do {
            // Use CloudKitService's actor instead of direct database access
            let cloudKitSync = CloudKitService.shared
            let followRecords = try await cloudKitSync.cloudKitActor.executeQuery(followingQuery)
            
            for record in followRecords {
                if let followingID = record["followingID"] as? String {
                    followedUserIDs.append(followingID)
                }
            }
            
            print("📊 Found \(followedUserIDs.count) followed users")
            
            // Add the current user to see their own activities in the feed
            followedUserIDs.append(currentUserID)
            
            // If not following anyone (except themselves), still show own activities
            guard !followedUserIDs.isEmpty else {
                return []
            }
            
            // Step 2: Query activities from those users (limit to prevent crash)
            // CloudKit has a limit on predicate size, so we'll only query for first 10 followed users
            let limitedFollowedUsers = Array(followedUserIDs.prefix(10))
            
            // Create predicate for activities from followed users
            let activityPredicate = NSPredicate(format: "actorID IN %@", limitedFollowedUsers)
            let activityQuery = CKQuery(recordType: CloudKitConfig.activityRecordType, predicate: activityPredicate)
            
            // Use CloudKitActor for safe query execution
            let activities = try await cloudKitSync.cloudKitActor.executeQuery(activityQuery, desiredKeys: nil, resultsLimit: limit)
            
            // Sort by timestamp (use sorted() instead of sort() to avoid mutation)
            let sortedActivities = activities.sorted { record1, record2 in
                let date1 = record1[CKField.Activity.timestamp] as? Date ?? Date.distantPast
                let date2 = record2[CKField.Activity.timestamp] as? Date ?? Date.distantPast
                return date1 > date2
            }
            
            return sortedActivities
            
        } catch {
            print("⚠️ Failed to fetch followed user activities: \(error)")
            return []
        }
    }
    
    /// Batch fetch users to populate cache and avoid redundant individual fetches
    private func batchFetchUsers(from records: [CKRecord]) async {
        // PHASE 3 OPTIMIZATION: Parallel batch fetching with local cache
        // Extract all unique user IDs from activity records
        var userIDsToFetch = Set<String>()
        
        for record in records {
            if let actorID = record[CKField.Activity.actorID] as? String {
                userIDsToFetch.insert(actorID)
            }
            if let targetUserID = record[CKField.Activity.targetUserID] as? String {
                userIDsToFetch.insert(targetUserID)
            }
        }
        
        // PHASE 5: Filter out already cached users with TTL check
        let uncachedUserIDs = userIDsToFetch.filter { userID in
            if userCache[userID] != nil {
                // User is cached, don't fetch again (cache never expires)
                return false
            }
            return true
        }
        
        guard !uncachedUserIDs.isEmpty else {
            print("✅ PHASE 3: All \(userIDsToFetch.count) users already cached")
            return
        }
        
        print("📥 PHASE 3: Batch fetching \(uncachedUserIDs.count) uncached users (of \(userIDsToFetch.count) total)")
        
        // Fetch users in parallel using TaskGroup for better performance
        await withTaskGroup(of: Void.self) { group in
            // Batch into groups of 10 to avoid CloudKit limits
            let batchSize = 10
            let userIDBatches = Array(uncachedUserIDs).chunked(into: batchSize)
            
            for batch in userIDBatches {
                group.addTask {
                    await self.fetchUserBatchDirect(userIDs: batch)
                }
            }
        }
        
        print("✅ PHASE 3: Cached \(uncachedUserIDs.count) users with parallel fetching")
    }
    
    
    /// Direct batch fetch of users using CloudKitActor for safety
    private func fetchUserBatchDirect(userIDs: [String]) async {
        // Filter out nil or empty user IDs
        let validUserIDs = userIDs.filter { !$0.isEmpty }
        guard !validUserIDs.isEmpty else {
            print("⚠️ No valid user IDs to fetch")
            return
        }
        
        // User records in CloudKit have "user_" prefix
        let recordIDs = validUserIDs.map { CKRecord.ID(recordName: "user_\($0)") }
        
        // Use CloudKitActor for safe batch fetch
        let cloudKitSync = CloudKitService.shared
        
        for recordID in recordIDs {
            do {
                let record = try await cloudKitSync.cloudKitActor.fetchRecord(with: recordID)
                let user = CloudKitUser(from: record)
                if let userID = user.recordID {
                    // PHASE 5: Cache with timestamp
                    userCache[userID] = (user: user, timestamp: Date())
                    // print("✅ Cached user \(userID): \(user.displayName) with TTL")
                    // PHASE 7: Trim cache if needed
                    trimUserCacheIfNeeded()
                }
            } catch {
                print("⚠️ Failed to fetch user \(recordID.recordName): \(error)")
                createPlaceholderUser(for: recordID)
            }
        }
    }
    
    private func createPlaceholderUser(for recordID: CKRecord.ID) {
        let placeholderRecord = CKRecord(recordType: CloudKitConfig.userRecordType, recordID: recordID)
        placeholderRecord[CKField.User.displayName] = "Unknown Chef"
        placeholderRecord[CKField.User.username] = "unknown_chef"
        placeholderRecord[CKField.User.totalPoints] = Int64(0)
        placeholderRecord[CKField.User.recipesCreated] = Int64(0)
        placeholderRecord[CKField.User.isVerified] = Int64(0)
        placeholderRecord[CKField.User.createdAt] = Date()
        placeholderRecord[CKField.User.lastLoginAt] = Date()
        placeholderRecord[CKField.User.currentStreak] = Int64(0)
        placeholderRecord[CKField.User.challengesCompleted] = Int64(0)
        placeholderRecord[CKField.User.recipesShared] = Int64(0)
        placeholderRecord[CKField.User.followerCount] = Int64(0)
        placeholderRecord[CKField.User.followingCount] = Int64(0)
        
        let placeholderUser = CloudKitUser(from: placeholderRecord)
        // Store using the raw userID (without "user_" prefix)
        if let userID = placeholderUser.recordID {
            // PHASE 5: Cache placeholder with timestamp
            userCache[userID] = (user: placeholderUser, timestamp: Date())
        }
    }

    // PHASE 7: Memory management - trim cache when it gets too large
    private func trimUserCacheIfNeeded() {
        if userCache.count > maxCacheSize {
            // Sort by timestamp and remove oldest entries
            let sortedCache = userCache.sorted { $0.value.timestamp < $1.value.timestamp }
            let toRemove = sortedCache.prefix(userCache.count - maxCacheSize + 10) // Keep 10 slots free
            
            for (key, _) in toRemove {
                userCache.removeValue(forKey: key)
            }
            
            print("🧹 PHASE 7: Trimmed user cache from \(sortedCache.count) to \(userCache.count) entries")
        }
    }
    
    // PHASE 7: Clean up memory when view is not visible
    func cleanupMemory() {
        // Remove old cached users
        let now = Date()
        userCache = userCache.filter { _, value in
            now.timeIntervalSince(value.timestamp) < 300 // Keep only last 5 minutes
        }
        
        // Trim activities if too many
        if activities.count > 30 {
            activities = Array(activities.prefix(30))
            print("🧹 PHASE 7: Cleaned up memory - keeping 30 most recent activities")
        }
        purgeExpiredImageCaches(now: now)
        trimProfilePhotoCacheIfNeeded()
        trimRecipeImageCacheIfNeeded()
        trimMissingRecipeMarkersIfNeeded()
        
        print("📊 PHASE 7: Memory cleanup complete - \(userCache.count) users, \(activities.count) activities")
    }
    
    // MARK: - Smart Refresh
    
    /// Fetch only activities newer than what we have cached
    private func refreshNewestOnly() async {
        guard let newestTimestamp = activities.first?.timestamp else {
            // No cached data, do full refresh
            await fetchActivitiesFromCloudKit(loadMore: false)
            return
        }
        
        print("🔄 Smart refresh: Fetching only activities newer than \(newestTimestamp)")
        
        guard let currentUser = UnifiedAuthManager.shared.currentUser,
              let userID = currentUser.recordID else {
            print("⚠️ No authenticated user for refresh")
            return
        }
        
        isRefreshing = true
        defer { 
            isRefreshing = false
        }
        
        do {
            // Get followed user IDs
            let followedUserIDs = try await fetchFollowedUserIDs(for: userID)
            var allUserIDs = followedUserIDs
            allUserIDs.append(userID)
            
            // Query for activities newer than our newest
            // Note: Use 'actorID' not 'userID' - CloudKit field name
            let newerPredicate = NSPredicate(
                format: "actorID IN %@ AND timestamp > %@",
                allUserIDs,
                newestTimestamp as NSDate
            )
            
            let query = CKQuery(recordType: CloudKitConfig.activityRecordType, predicate: newerPredicate)
            query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            
            let cloudKitSync = CloudKitService.shared
            let newRecords = try await cloudKitSync.cloudKitActor.executeQuery(
                query,
                desiredKeys: nil,
                resultsLimit: 25
            )
            
            if !newRecords.isEmpty {
                var newActivities: [ActivityItem] = []
                for record in newRecords {
                    if let activity = await mapCloudKitRecordToActivityItem(record) {
                        // Avoid duplicates
                        if !activities.contains(where: { $0.id == activity.id }) {
                            newActivities.append(activity)
                        }
                    }
                }
                
                if !newActivities.isEmpty {
                    // Insert new activities at the front, avoiding duplicates
                    let existingIds = Set(activities.map { $0.id })
                    let uniqueNewActivities = newActivities.filter { !existingIds.contains($0.id) }
                    
                    if !uniqueNewActivities.isEmpty {
                        activities.insert(contentsOf: uniqueNewActivities, at: 0)
                        // Maintain memory limits
                        maintainMemoryLimits()
                        print("✅ Smart refresh: Added \(uniqueNewActivities.count) new activities (\(newActivities.count - uniqueNewActivities.count) duplicates filtered)")
                        await saveCachedActivities()
                    } else {
                        print("⚡ Smart refresh: No new unique activities (all \(newActivities.count) were duplicates)")
                    }
                } else {
                    print("⚡ Smart refresh: No new activities")
                }
            } else {
                print("⚡ Smart refresh: No new activities found")
            }
        } catch {
            print("❌ Smart refresh error: \(error)")
        }
    }
    
    // MARK: - Memory Management
    
    /// Maintain memory limits by keeping only the newest items
    private func maintainMemoryLimits() {
        // Keep only the 100 newest activities
        if activities.count > 100 {
            activities = Array(activities.prefix(100))
            print("📊 Trimmed activities to 100 newest items")
        }
        
        // Keep only the 50 most recently accessed users in cache
        if userCache.count > 50 {
            // This is already a dictionary, so we maintain size differently
            // For now, we'll leave the user cache as-is since it's already efficient
            print("📊 User cache has \(userCache.count) items")
        }

        let now = Date()
        purgeExpiredImageCaches(now: now)
        trimProfilePhotoCacheIfNeeded()
        trimRecipeImageCacheIfNeeded()
        trimMissingRecipeMarkersIfNeeded()
    }
    
    /// Reset singleton for testing or logout
    func reset() {
        print("🔄 Resetting ActivityFeedManager singleton")
        
        // Cancel all tasks first
        currentLoadTask?.cancel()
        currentRefreshTask?.cancel()
        backgroundLoadTask?.cancel()
        currentLoadTask = nil
        currentRefreshTask = nil
        backgroundLoadTask = nil
        
        activities.removeAll()
        userCache.removeAll()
        profilePhotoCache.removeAll()
        recipeImageCache.removeAll()
        missingRecipeImageIDs.removeAll()
        profilePhotoCacheHits = 0
        profilePhotoCacheMisses = 0
        recipeImageCacheHits = 0
        recipeImageCacheMisses = 0
        lastCacheTelemetryAt = .distantPast
        lastFetchedRecord = nil
        hasMore = true
        isLoading = false
        showingSkeletonViews = false
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheTimestampKey)
    }
    
    /// Fetches user display name by userID, using cache when available
    private func fetchUserDisplayName(userID: String) async -> String {
        // print("🔍 DEBUG: fetchUserDisplayName for userID: \(userID)")
        
        // PHASE 5: Check cache with TTL validation
        if let cached = userCache[userID] {
            // Check if cache is still valid
            // Always use cached data - never expires
            if true { // Was: Date().timeIntervalSince(cached.timestamp) < userCacheTTL
                let displayName = cached.user.username ?? cached.user.displayName
                // print("✅ Found cached user: \(displayName) (cache age: \(Int(Date().timeIntervalSince(cached.timestamp)))s)")
                return displayName
            } else {
                print("⏰ User cache expired for \(userID)")
            }
        }
        
        print("⚠️ User not in cache, fetching from CloudKit...")
        
        // This should rarely happen now with batch fetching, but fallback just in case
        do {
            // User records in CloudKit have "user_" prefix
            let userRecordID = CKRecord.ID(recordName: "user_\(userID)")
            print("🔍 Fetching user record with ID: \(userRecordID.recordName)")
            
            let userRecord = try await publicDatabase.record(for: userRecordID)
            let user = CloudKitUser(from: userRecord)
            
            print("✅ Fetched user from CloudKit:")
            print("   - recordID: \(user.recordID ?? "nil")")
            print("   - username: \(user.username ?? "nil")")
            print("   - displayName: \(user.displayName)")
            
            // PHASE 5: Update cache with fresh data and timestamp
            userCache[userID] = (user: user, timestamp: Date())
            // PHASE 7: Trim cache if needed
            trimUserCacheIfNeeded()
            
            let result = user.username ?? user.displayName
            print("⚠️ Individual fetch for \(userID): \(result)")
            return result
        } catch {
            print("❌ Failed to fetch user details for \(userID): \(error)")
            return "Unknown Chef"
        }
    }

    private func imageFromAsset(_ asset: CKAsset?) async -> UIImage? {
        guard let fileURL = asset?.fileURL else { return nil }
        return await Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: fileURL) else { return nil }
            return UIImage(data: data)
        }.value
    }

    private func profilePhotoFromCache(userID: String, now: Date = Date()) -> UIImage? {
        guard var entry = profilePhotoCache[userID] else { return nil }
        if now.timeIntervalSince(entry.createdAt) > profileImageCacheTTL {
            profilePhotoCache.removeValue(forKey: userID)
            return nil
        }
        entry.lastAccessedAt = now
        profilePhotoCache[userID] = entry
        return entry.image
    }

    private func saveProfilePhotoToCache(_ image: UIImage, userID: String, now: Date = Date()) {
        profilePhotoCache[userID] = ImageCacheEntry(image: image, createdAt: now, lastAccessedAt: now)
        trimProfilePhotoCacheIfNeeded()
    }

    private func recipeImageFromCache(recipeID: String, now: Date = Date()) -> UIImage? {
        guard var entry = recipeImageCache[recipeID] else { return nil }
        if now.timeIntervalSince(entry.createdAt) > recipeImageCacheTTL {
            recipeImageCache.removeValue(forKey: recipeID)
            return nil
        }
        entry.lastAccessedAt = now
        recipeImageCache[recipeID] = entry
        return entry.image
    }

    private func saveRecipeImageToCache(_ image: UIImage, recipeID: String, now: Date = Date()) {
        recipeImageCache[recipeID] = ImageCacheEntry(image: image, createdAt: now, lastAccessedAt: now)
        missingRecipeImageIDs.removeValue(forKey: recipeID)
        trimRecipeImageCacheIfNeeded()
    }

    private func isRecipeImageMarkedMissing(_ recipeID: String, now: Date = Date()) -> Bool {
        guard let markedAt = missingRecipeImageIDs[recipeID] else { return false }
        if now.timeIntervalSince(markedAt) > missingRecipeImageTTL {
            missingRecipeImageIDs.removeValue(forKey: recipeID)
            return false
        }
        return true
    }

    private func markRecipeImageMissing(_ recipeID: String, now: Date = Date()) {
        missingRecipeImageIDs[recipeID] = now
        trimMissingRecipeMarkersIfNeeded()
    }

    private func trimProfilePhotoCacheIfNeeded() {
        guard profilePhotoCache.count > profileImageCacheMaxEntries else { return }
        let sortedByAccess = profilePhotoCache.sorted { $0.value.lastAccessedAt < $1.value.lastAccessedAt }
        let removeCount = profilePhotoCache.count - profileImageCacheMaxEntries
        for (key, _) in sortedByAccess.prefix(removeCount) {
            profilePhotoCache.removeValue(forKey: key)
        }
    }

    private func trimRecipeImageCacheIfNeeded() {
        guard recipeImageCache.count > recipeImageCacheMaxEntries else { return }
        let sortedByAccess = recipeImageCache.sorted { $0.value.lastAccessedAt < $1.value.lastAccessedAt }
        let removeCount = recipeImageCache.count - recipeImageCacheMaxEntries
        for (key, _) in sortedByAccess.prefix(removeCount) {
            recipeImageCache.removeValue(forKey: key)
        }
    }

    private func trimMissingRecipeMarkersIfNeeded() {
        guard missingRecipeImageIDs.count > missingRecipeImageMaxEntries else { return }
        let sortedByAge = missingRecipeImageIDs.sorted { $0.value < $1.value }
        let removeCount = missingRecipeImageIDs.count - missingRecipeImageMaxEntries
        for (key, _) in sortedByAge.prefix(removeCount) {
            missingRecipeImageIDs.removeValue(forKey: key)
        }
    }

    private func purgeExpiredImageCaches(now: Date = Date()) {
        profilePhotoCache = profilePhotoCache.filter { _, entry in
            now.timeIntervalSince(entry.createdAt) <= profileImageCacheTTL
        }
        recipeImageCache = recipeImageCache.filter { _, entry in
            now.timeIntervalSince(entry.createdAt) <= recipeImageCacheTTL
        }
        missingRecipeImageIDs = missingRecipeImageIDs.filter { _, markedAt in
            now.timeIntervalSince(markedAt) <= missingRecipeImageTTL
        }
    }

    private func fetchUserPhoto(userID: String) async -> UIImage? {
        if let cached = profilePhotoFromCache(userID: userID) {
            profilePhotoCacheHits += 1
            emitImageCacheTelemetryIfNeeded()
            return cached
        }

        profilePhotoCacheMisses += 1
        guard let photo = await ProfilePhotoManager.shared.getProfilePhoto(for: userID) else {
            emitImageCacheTelemetryIfNeeded()
            return nil
        }

        saveProfilePhotoToCache(photo, userID: userID)
        emitImageCacheTelemetryIfNeeded()
        return photo
    }

    private func recipeImageFromRecord(_ record: CKRecord) async -> UIImage? {
        if let after = await imageFromAsset(record["afterPhotoAsset"] as? CKAsset) {
            return after
        }
        if let before = await imageFromAsset(record["beforePhotoAsset"] as? CKAsset) {
            return before
        }
        return nil
    }

    private func fetchRecipeImage(recipeID: String, prefetchedRecord: CKRecord?) async -> UIImage? {
        if let cached = recipeImageFromCache(recipeID: recipeID) {
            recipeImageCacheHits += 1
            emitImageCacheTelemetryIfNeeded()
            return cached
        }

        if isRecipeImageMarkedMissing(recipeID) {
            recipeImageCacheMisses += 1
            emitImageCacheTelemetryIfNeeded()
            return nil
        }

        recipeImageCacheMisses += 1
        if let prefetchedRecord,
           let image = await recipeImageFromRecord(prefetchedRecord) {
            saveRecipeImageToCache(image, recipeID: recipeID)
            emitImageCacheTelemetryIfNeeded()
            return image
        }

        do {
            let photos = try await cloudKitSync.fetchRecipePhotos(for: recipeID)
            if let image = photos.after ?? photos.before {
                saveRecipeImageToCache(image, recipeID: recipeID)
                emitImageCacheTelemetryIfNeeded()
                return image
            }
            markRecipeImageMissing(recipeID)
            emitImageCacheTelemetryIfNeeded()
            return nil
        } catch {
            print("⚠️ Failed to load recipe image for \(recipeID): \(error)")
            markRecipeImageMissing(recipeID)
            emitImageCacheTelemetryIfNeeded()
            return nil
        }
    }

    private func resolveActivityImage(
        activityType: ActivityItem.ActivityType,
        recipeID: String?,
        prefetchedRecipeRecord: CKRecord?,
        challengeProofImage: UIImage?
    ) async -> UIImage? {
        if let challengeProofImage {
            return challengeProofImage
        }

        guard let recipeID else { return nil }
        guard [.recipeShared, .recipeLiked, .recipeComment, .challengeCompleted, .challengeShared]
            .contains(activityType) else {
            return nil
        }

        return await fetchRecipeImage(recipeID: recipeID, prefetchedRecord: prefetchedRecipeRecord)
    }

    private func emitImageCacheTelemetryIfNeeded(force: Bool = false) {
        let profileTotal = profilePhotoCacheHits + profilePhotoCacheMisses
        let recipeTotal = recipeImageCacheHits + recipeImageCacheMisses
        let combinedTotal = profileTotal + recipeTotal

        guard force || combinedTotal >= 8 else { return }

        let now = Date()
        guard force || now.timeIntervalSince(lastCacheTelemetryAt) >= cacheTelemetryInterval else {
            return
        }

        purgeExpiredImageCaches(now: now)
        lastCacheTelemetryAt = now

        let profileHitRate = profileTotal == 0 ? 0 : Double(profilePhotoCacheHits) / Double(profileTotal)
        let recipeHitRate = recipeTotal == 0 ? 0 : Double(recipeImageCacheHits) / Double(recipeTotal)

        AnalyticsManager.shared.logEvent(
            "activity_feed_image_cache_snapshot",
            parameters: [
                "profile_hit_rate": (profileHitRate * 100).rounded() / 100,
                "recipe_hit_rate": (recipeHitRate * 100).rounded() / 100,
                "profile_samples": profileTotal,
                "recipe_samples": recipeTotal,
                "profile_cache_size": profilePhotoCache.count,
                "recipe_cache_size": recipeImageCache.count,
                "recipe_missing_markers": missingRecipeImageIDs.count
            ]
        )
    }

    private func mapCloudKitRecordToActivityItem(_ record: CKRecord) async -> ActivityItem? {
        guard let id = record[CKField.Activity.id] as? String,
              let typeString = record[CKField.Activity.type] as? String,
              let actorID = record[CKField.Activity.actorID] as? String,
              let timestamp = record[CKField.Activity.timestamp] as? Date else {
            print("❌ Invalid activity record structure")
            return nil
        }

        // Map activity type string to enum
        let activityType: ActivityItem.ActivityType
        switch typeString.lowercased() {
        case "follow":
            activityType = .follow
        case "recipeshared":
            activityType = .recipeShared
        case "recipeliked":
            activityType = .recipeLiked
        case "recipecomment", "recipecommented":  // Support both types
            activityType = .recipeComment
        case "challengecompleted":
            activityType = .challengeCompleted
        case "challengeshared":
            activityType = .challengeShared
        case "badgeearned":
            activityType = .badgeEarned
        case "profileupdated":
            activityType = .profileUpdated
        case "profilephotoupdated":
            activityType = .profilePhotoUpdated
        default:
            activityType = .recipeShared
        }

        // If this is a profile update activity, notify other views to refresh
        // Don't display profile update activities in the feed
        if activityType == .profileUpdated || activityType == .profilePhotoUpdated {
            print("🔄 Profile update activity detected for user \(actorID)")
            
            // Clear any local cached data for this user
            // The fetchUserDisplayName will get fresh data from CloudKit
            
            // Notify other views that this user's profile was updated
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .userProfileUpdated,
                    object: nil,
                    userInfo: ["userID": actorID]
                )
            }
            
            // Don't display in feed
            return nil
        }
        
        // Fetch actor (user) details dynamically
        let actorName = await fetchUserDisplayName(userID: actorID)
        // print("🔍 DEBUG: Creating ActivityItem for \(actorID) with name '\(actorName)'")
        
        // Extract optional fields
        let targetUserID = record[CKField.Activity.targetUserID] as? String
        async let actorPhotoTask = fetchUserPhoto(userID: actorID)
        let targetUserName = targetUserID != nil ? await fetchUserDisplayName(userID: targetUserID!) : nil
        let recipeID = record[CKField.Activity.recipeID] as? String
        let recipeName = record[CKField.Activity.recipeName] as? String
        let challengeName = record[CKField.Activity.challengeName] as? String
        let isReadInt = record[CKField.Activity.isRead] as? Int64 ?? 0
        var validatedRecipeRecord: CKRecord?
        var challengeProofImage: UIImage?

        // For recipe-related activities, validate that the recipe exists
        // Skip activities that reference non-existent recipes to avoid errors
        if let recipeID = recipeID, [.recipeShared, .recipeLiked, .recipeComment].contains(activityType) {
            do {
                // Quick check if recipe exists in CloudKit
                let recipeRecord = try await publicDatabase.record(for: CKRecord.ID(recordName: recipeID))
                validatedRecipeRecord = recipeRecord
                print("✅ Validated recipe exists for activity: \(id)")
            } catch {
                if let ckError = error as? CKError, ckError.code == .unknownItem {
                    print("⚠️ Skipping activity \(id) - recipe \(recipeID) not found")
                    return nil // Skip this activity
                } else {
                    print("⚠️ Error validating recipe \(recipeID) for activity \(id): \(error)")
                    // Continue with the activity even if validation failed due to network issues
                }
            }
        }
        
        // For challenge completion activities, validate that proof was actually submitted
        if activityType == .challengeCompleted {
            let challengeID = record["challengeID"] as? String ?? recipeID
            if let challengeID = challengeID {
                // Check if there's a UserChallenge record with proof submission
                do {
                    // Create a CKRecord.Reference for the challenge ID
                    let challengeReference = CKRecord.Reference(recordID: CKRecord.ID(recordName: challengeID), action: .none)
                    let predicate = NSPredicate(format: "%K == %@ AND challengeID == %@ AND %K == %@",
                                              CKField.UserChallenge.userID, actorID,
                                              challengeReference,
                                              CKField.UserChallenge.status, "completed")
                    let query = CKQuery(recordType: CloudKitConfig.userChallengeRecordType, predicate: predicate)
                    
                    let results = try await publicDatabase.records(matching: query)
                    
                    // Only show challenge completion if there's a completed UserChallenge record with proof
                    if results.matchResults.isEmpty {
                        print("⚠️ Skipping challenge completion activity \(id) - no proof submission found")
                        return nil
                    }
                    
                    // Verify proof image exists in the UserChallenge record
                    if let (_, result) = results.matchResults.first,
                       case .success(let userChallengeRecord) = result {
                        let hasProofImage = userChallengeRecord["proofImage"] != nil
                        if !hasProofImage {
                            print("⚠️ Skipping challenge completion activity \(id) - no proof image found")
                            return nil
                        }
                        if let proofAsset = userChallengeRecord["proofImage"] as? CKAsset {
                            challengeProofImage = await imageFromAsset(proofAsset)
                        }
                        print("✅ Validated challenge completion with proof for activity: \(id)")
                    }
                } catch {
                    print("⚠️ Error validating challenge completion for activity \(id): \(error)")
                    return nil // Skip questionable challenge completion activities
                }
            } else {
                print("⚠️ Skipping challenge completion activity \(id) - no challenge ID found")
                return nil
            }
        }

        // Extract challenge ID if this is a challenge-related activity
        let challengeID = record["challengeID"] as? String
        let actorPhoto = await actorPhotoTask
        let activityImage = await resolveActivityImage(
            activityType: activityType,
            recipeID: recipeID,
            prefetchedRecipeRecord: validatedRecipeRecord,
            challengeProofImage: challengeProofImage
        )
        
        return ActivityItem(
            id: id,
            type: activityType,
            userID: actorID,
            userName: actorName,
            userPhoto: actorPhoto,
            targetUserID: targetUserID,
            targetUserName: targetUserName,
            recipeID: recipeID,
            recipeName: (activityType == .challengeCompleted || activityType == .challengeShared) ? challengeName : recipeName,
            recipeImage: activityImage,
            challengeID: challengeID,
            timestamp: timestamp,
            isRead: isReadInt == 1
        )
    }
    
    // MARK: - Caching Methods
    
    private func loadCachedActivities() async {
        print("🔍 DEBUG: loadCachedActivities - checking for persistent storage")
        
        // Create activities directory if needed
        do {
            try FileManager.default.createDirectory(at: activitiesDirectory, withIntermediateDirectories: true)
        } catch {
            print("❌ Failed to create activities directory: \(error)")
        }
        
        // Load from file storage
        let fileURL = activitiesDirectory.appendingPathComponent("activities.json")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("🔍 DEBUG: No stored activities found")
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cachedData = try decoder.decode(CachedActivityData.self, from: data)
            
            await MainActor.run {
                // Load activities sorted by timestamp (newest first)
                activities = cachedData.activities.sorted { $0.timestamp > $1.timestamp }
            }
            
            print("📱 LocalActivityStorage: Loaded \(activities.count) activities from disk")
        } catch {
            print("❌ Failed to load activities from disk: \(error)")
            // Remove corrupt file
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
    
    private func saveCachedActivities() async {
        // Create activities directory if needed
        do {
            try FileManager.default.createDirectory(at: activitiesDirectory, withIntermediateDirectories: true)
        } catch {
            print("❌ Failed to create activities directory: \(error)")
        }
        
        let fileURL = activitiesDirectory.appendingPathComponent("activities.json")
        
        do {
            // Keep only the most recent activities
            let activitiesToSave = Array(activities.prefix(maxActivities))
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let cachedData = CachedActivityData(activities: activitiesToSave)
            let data = try encoder.encode(cachedData)
            
            try data.write(to: fileURL)
            print("💾 LocalActivityStorage: Saved \(activitiesToSave.count) activities to disk")
        } catch {
            print("❌ Failed to save activities to disk: \(error)")
        }
    }

    private func generateMockActivities() -> [ActivityItem] {
        [
            ActivityItem(
                id: UUID().uuidString,
                type: .follow,
                userID: "user1",
                userName: "Sarah Chen",
                userPhoto: nil,
                targetUserID: nil,
                targetUserName: nil,
                recipeID: nil,
                recipeName: nil,
                recipeImage: nil,
                challengeID: nil,
                timestamp: Date().addingTimeInterval(-3_600),
                isRead: false
            ),
            ActivityItem(
                id: UUID().uuidString,
                type: .recipeShared,
                userID: "user2",
                userName: "Mike Thompson",
                userPhoto: nil,
                targetUserID: nil,
                targetUserName: nil,
                recipeID: "recipe1",
                recipeName: "Perfect Pancakes",
                recipeImage: nil,
                challengeID: nil,
                timestamp: Date().addingTimeInterval(-7_200),
                isRead: true
            ),
            ActivityItem(
                id: UUID().uuidString,
                type: .recipeLiked,
                userID: "user3",
                userName: "Emma Rodriguez",
                userPhoto: nil,
                targetUserID: nil,
                targetUserName: nil,
                recipeID: "recipe2",
                recipeName: "Spicy Tacos",
                recipeImage: nil,
                challengeID: nil,
                timestamp: Date().addingTimeInterval(-10_800),
                isRead: true
            )
            // Removed mock challenge completion activity - only show real completions with proof
        ]
    }
}

// MARK: - Cached Activity Data Model
struct CachedActivityData: Codable {
    let activities: [ActivityItem]
    
    init(activities: [ActivityItem]) {
        self.activities = activities
    }
}

// MARK: - Activity Item Codable Extension
extension ActivityItem: Codable {
    enum CodingKeys: String, CodingKey {
        case id, type, userID, userName, userPhoto, targetUserID, targetUserName
        case recipeID, recipeName, recipeImage, challengeID, timestamp, isRead
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        userID = try container.decode(String.self, forKey: .userID)
        userName = try container.decode(String.self, forKey: .userName)
        userPhoto = nil // UIImage is not codable
        targetUserID = try container.decodeIfPresent(String.self, forKey: .targetUserID)
        targetUserName = try container.decodeIfPresent(String.self, forKey: .targetUserName)
        recipeID = try container.decodeIfPresent(String.self, forKey: .recipeID)
        recipeName = try container.decodeIfPresent(String.self, forKey: .recipeName)
        recipeImage = nil // UIImage is not codable
        challengeID = try container.decodeIfPresent(String.self, forKey: .challengeID)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isRead = try container.decode(Bool.self, forKey: .isRead)
        
        // Decode activity type
        let typeString = try container.decode(String.self, forKey: .type)
        switch typeString {
        case "follow": type = .follow
        case "recipeShared": type = .recipeShared
        case "recipeLiked": type = .recipeLiked
        case "recipeComment": type = .recipeComment
        case "challengeCompleted": type = .challengeCompleted
        case "challengeShared": type = .challengeShared
        case "badgeEarned": type = .badgeEarned
        case "profileUpdated": type = .profileUpdated
        case "profilePhotoUpdated": type = .profilePhotoUpdated
        default: type = .recipeShared
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(userID, forKey: .userID)
        try container.encode(userName, forKey: .userName)
        try container.encodeIfPresent(targetUserID, forKey: .targetUserID)
        try container.encodeIfPresent(targetUserName, forKey: .targetUserName)
        try container.encodeIfPresent(recipeID, forKey: .recipeID)
        try container.encodeIfPresent(recipeName, forKey: .recipeName)
        try container.encodeIfPresent(challengeID, forKey: .challengeID)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(isRead, forKey: .isRead)
        
        // Encode activity type as string
        let typeString: String
        switch type {
        case .follow: typeString = "follow"
        case .recipeShared: typeString = "recipeShared"
        case .recipeLiked: typeString = "recipeLiked"
        case .recipeComment: typeString = "recipeComment"
        case .challengeCompleted: typeString = "challengeCompleted"
        case .challengeShared: typeString = "challengeShared"
        case .badgeEarned: typeString = "badgeEarned"
        case .profileUpdated: typeString = "profileUpdated"
        case .profilePhotoUpdated: typeString = "profilePhotoUpdated"
        }
        try container.encode(typeString, forKey: .type)
    }
}

// MARK: - Skeleton Loading Views
struct SkeletonActivityView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 16) {
            // User Photo Skeleton
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 50, height: 50)
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.3)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .scaleEffect(isAnimating ? 1.2 : 0.8)
                        .opacity(isAnimating ? 0.8 : 0.4)
                )
            
            VStack(alignment: .leading, spacing: 8) {
                // Activity Text Skeleton
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 16)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(8)
                
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 120, height: 14)
                    .cornerRadius(7)
            }
            
            Spacer()
            
            // Recipe Image Skeleton
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .frame(width: 60, height: 60)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .onAppear {
            print("🔍 DEBUG: SkeletonActivityView appeared - Start")
            DispatchQueue.main.async {
                print("🔍 DEBUG: SkeletonActivityView - Async block started")
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
                print("🔍 DEBUG: SkeletonActivityView - Async block completed")
            }
            print("🔍 DEBUG: SkeletonActivityView appeared - End")
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let userProfileUpdated = Notification.Name("userProfileUpdated")
}

#Preview {
    ActivityFeedView()
        .environmentObject(AppState())
}
