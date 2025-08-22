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
        case badgeEarned

        var icon: String {
            switch self {
            case .follow: return "person.badge.plus"
            case .recipeShared: return "square.and.arrow.up"
            case .recipeLiked: return "heart.fill"
            case .recipeComment: return "bubble.left.fill"
            case .challengeCompleted: return "checkmark.circle.fill"
            case .badgeEarned: return "medal.fill"
            }
        }

        var color: Color {
            switch self {
            case .follow: return Color(hex: "#667eea")
            case .recipeShared: return Color(hex: "#43e97b")
            case .recipeLiked: return Color(hex: "#ff6b6b")
            case .recipeComment: return Color(hex: "#4ecdc4")
            case .challengeCompleted: return Color(hex: "#ffd93d")
            case .badgeEarned: return Color(hex: "#ff6b6b")
            }
        }
    }

    var activityText: AttributedString {
        var text = AttributedString()

        // User name (bold)
        var userName = AttributedString(self.userName)
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
            text += AttributedString(" liked your recipe: ")
            if let recipeName = recipeName {
                var recipe = AttributedString(recipeName)
                recipe.font = .system(size: 16, weight: .medium)
                text += recipe
            }
        case .recipeComment:
            text += AttributedString(" commented on your recipe")
        case .challengeCompleted:
            text += AttributedString(" completed the challenge: ")
            if let recipeName = recipeName { // Using recipeName for challenge name
                var challenge = AttributedString(recipeName)
                challenge.font = .system(size: 16, weight: .medium)
                text += challenge
            }
        case .badgeEarned:
            text += AttributedString(" earned a new badge!")
        }

        return text
    }
}

// MARK: - Activity Feed View
struct ActivityFeedView: View {
    @StateObject private var feedManager = ActivityFeedManager()
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
        NavigationStack {
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

                    // Activity List
                    if feedManager.showingSkeletonViews {
                        // Skeleton Loading Views
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(0..<5, id: \.self) { _ in
                                    SkeletonActivityView()
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    } else if feedManager.isLoading && feedManager.activities.isEmpty {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Spacer()
                    } else if feedManager.activities.isEmpty {
                        EmptyActivityView()
                    } else {
                        ScrollView {
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
                    }
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await feedManager.refresh()
            }
        }
        .task {
            await feedManager.loadInitialActivities()
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
                $0.type == .challengeCompleted || $0.type == .badgeEarned
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
        case .challengeCompleted:
            // Show challenge detail popup
            print("🏆 Challenge activity tapped - showing challenge detail")
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
                let recipe = try await CloudKitRecipeManager.shared.fetchRecipe(by: recipeID)
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
            // User Photo or Activity Icon
            ZStack {
                if let photo = activity.userPhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(activity.userName.prefix(1).uppercased())
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
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
    @Published var activities: [ActivityItem] = []
    @Published var isLoading = false
    @Published var hasMore = true
    @Published var showingSkeletonViews = false

    private let cloudKitSync = CloudKitSyncService.shared
    private var lastFetchedRecord: CKRecord?
    private var userCache: [String: CloudKitUser] = [:] // Cache for user details
    private let publicDatabase = CKContainer(identifier: CloudKitConfig.containerIdentifier).publicCloudDatabase
    
    // Cache configuration
    private let cacheKey = "ActivityFeedCache"
    private let cacheTimestampKey = "ActivityFeedCacheTimestamp"
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes

    func loadInitialActivities() async {
        showingSkeletonViews = true
        isLoading = true
        activities = []
        lastFetchedRecord = nil

        // Try loading from cache first
        await loadCachedActivities()
        
        if activities.isEmpty {
            await fetchActivitiesFromCloudKit()
        }
        
        showingSkeletonViews = false
        isLoading = false
    }

    func loadMore() async {
        guard hasMore && !isLoading else { return }

        isLoading = true

        await fetchActivitiesFromCloudKit(loadMore: true)

        isLoading = false
    }

    func refresh() async {
        await loadInitialActivities()
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
        guard let currentUser = UnifiedAuthManager.shared.currentUser,
              let userID = currentUser.recordID else {
            print("❌ No authenticated user for activity feed")
            activities = generateMockActivities()
            hasMore = false
            return
        }

        do {
            // Fetch activities where current user is the target (activities for them)
            let targetActivities = try await cloudKitSync.fetchActivityFeed(for: userID, limit: 25)
            
            // Fetch activities from users they follow
            // Note: This is a simplified implementation. In a real app, you'd:
            // 1. First query Follow records to get followingIDs for current user
            // 2. Then query Activity records where actorID is in followingIDs
            // For now, we'll fetch recent public activities as a demonstration
            let publicActivities = try await fetchRecentPublicActivities(limit: 25)
            
            // Combine and sort activities by timestamp
            let allActivityRecords = targetActivities + publicActivities
            let sortedRecords = allActivityRecords.sorted { record1, record2 in
                let date1 = record1[CKField.Activity.timestamp] as? Date ?? Date.distantPast
                let date2 = record2[CKField.Activity.timestamp] as? Date ?? Date.distantPast
                return date1 > date2
            }
            
            // Take only the most recent 50 activities to avoid duplicates
            let limitedRecords = Array(sortedRecords.prefix(50))
            
            // Batch fetch all unique user IDs to avoid redundant fetches
            await batchFetchUsers(from: limitedRecords)
            
            let newActivities = await withTaskGroup(of: ActivityItem?.self) { group in
                for record in limitedRecords {
                    group.addTask {
                        await self.mapCloudKitRecordToActivityItem(record)
                    }
                }
                
                var results: [ActivityItem] = []
                for await result in group {
                    if let activity = result {
                        results.append(activity)
                    }
                }
                return results
            }

            if loadMore {
                activities.append(contentsOf: newActivities)
            } else {
                activities = newActivities
            }

            // Check if there are more activities to load
            hasMore = newActivities.count >= 50

            print("✅ Loaded \(newActivities.count) activities from CloudKit (target: \(targetActivities.count), public: \(publicActivities.count))")
            
            // Save to cache
            await saveCachedActivities()
        } catch {
            print("❌ CloudKit activity fetch error: \(error)")
            // Don't throw here - just fallback to existing behavior
            hasMore = false
        }
    }

    private func fetchRecentPublicActivities(limit: Int) async throws -> [CKRecord] {
        guard let currentUser = UnifiedAuthManager.shared.currentUser,
              let currentUserID = currentUser.recordID else {
            return []
        }
        
        // Since timestamp field may not be queryable, use a simpler query and filter in code
        // Query all activities and filter/sort client-side as a workaround
        let predicate = NSPredicate(format: "TRUEPREDICATE") // Get all records
        
        let query = CKQuery(recordType: CloudKitConfig.activityRecordType, predicate: predicate)
        // Remove sort descriptor since timestamp may not be sortable in CloudKit
        // query.sortDescriptors = [NSSortDescriptor(key: CKField.Activity.timestamp, ascending: false)]

        var activities: [CKRecord] = []

        // Use a direct query to fetch activities
        let results = try await CKContainer(identifier: CloudKitConfig.containerIdentifier).publicCloudDatabase.records(matching: query)
        
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        
        // Collect all valid records first, excluding activities performed by current user
        for (_, result) in results.matchResults {
            if case .success(let record) = result {
                // Filter by timestamp in code since it may not be queryable
                if let timestamp = record[CKField.Activity.timestamp] as? Date,
                   timestamp >= sevenDaysAgo {
                    
                    // IMPORTANT: Exclude activities where current user is the actor
                    // This prevents showing "sisaccount followed you" when sisaccount is the logged-in user
                    if let actorID = record[CKField.Activity.actorID] as? String,
                       actorID != currentUserID {
                        activities.append(record)
                    }
                }
            }
        }
        
        // Sort by timestamp in code since it may not be sortable in CloudKit
        activities.sort { record1, record2 in
            let date1 = record1[CKField.Activity.timestamp] as? Date ?? Date.distantPast
            let date2 = record2[CKField.Activity.timestamp] as? Date ?? Date.distantPast
            return date1 > date2 // Descending order (newest first)
        }
        
        // Return only the requested number of activities
        return Array(activities.prefix(limit))
    }
    
    /// Batch fetch users to populate cache and avoid redundant individual fetches
    private func batchFetchUsers(from records: [CKRecord]) async {
        // Extract all unique user IDs from activity records
        var userIDsToFetch = Set<String>()
        
        for record in records {
            if let actorID = record[CKField.Activity.actorID] as? String {
                if userCache[actorID] == nil {
                    userIDsToFetch.insert(actorID)
                }
            }
            if let targetUserID = record[CKField.Activity.targetUserID] as? String {
                if userCache[targetUserID] == nil {
                    userIDsToFetch.insert(targetUserID)
                }
            }
        }
        
        guard !userIDsToFetch.isEmpty else {
            print("✅ All users already cached, skipping batch fetch")
            return
        }
        
        print("📥 Batch fetching \(userIDsToFetch.count) users")
        
        // Fetch users in batches to avoid overwhelming CloudKit
        let batchSize = 20
        let userIDBatches = Array(userIDsToFetch).chunked(into: batchSize)
        
        await withTaskGroup(of: Void.self) { group in
            for batch in userIDBatches {
                group.addTask {
                    await self.fetchUserBatch(userIDs: batch)
                }
            }
        }
    }
    
    /// Fetch a batch of users by their IDs
    private func fetchUserBatch(userIDs: [String]) async {
        let recordIDs = userIDs.map { CKRecord.ID(recordName: $0) }
        
        do {
            let recordResults = try await publicDatabase.records(for: recordIDs)
            
            for (recordID, result) in recordResults {
                switch result {
                case .success(let record):
                    let user = CloudKitUser(from: record)
                    userCache[recordID.recordName] = user
                case .failure(let error):
                    print("❌ Failed to fetch user \(recordID.recordName): \(error)")
                    // Create placeholder user using a CKRecord - avoid repeated failed fetches
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
                    userCache[recordID.recordName] = CloudKitUser(from: placeholderRecord)
                }
            }
            
            print("✅ Batch fetched \(userIDs.count) users")
        } catch {
            print("❌ Failed to batch fetch users: \(error)")
        }
    }

    /// Fetches user display name by userID, using cache when available
    private func fetchUserDisplayName(userID: String) async -> String {
        // Check cache first to avoid redundant fetches
        if let cachedUser = userCache[userID] {
            return cachedUser.username ?? cachedUser.displayName
        }
        
        // This should rarely happen now with batch fetching, but fallback just in case
        do {
            let userRecord = try await publicDatabase.record(for: CKRecord.ID(recordName: userID))
            let user = CloudKitUser(from: userRecord)
            
            // Update cache with fresh data
            userCache[userID] = user
            
            print("⚠️ Individual fetch for \(userID): \(user.username ?? user.displayName)")
            return user.username ?? user.displayName
        } catch {
            print("❌ Failed to fetch user details for \(userID): \(error)")
            return "Unknown Chef"
        }
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
        case "recipecomment":
            activityType = .recipeComment
        case "challengecompleted":
            activityType = .challengeCompleted
        case "badgeearned":
            activityType = .badgeEarned
        default:
            activityType = .recipeShared
        }

        // Fetch actor (user) details dynamically
        let actorName = await fetchUserDisplayName(userID: actorID)
        
        // Extract optional fields
        let targetUserID = record[CKField.Activity.targetUserID] as? String
        let targetUserName = targetUserID != nil ? await fetchUserDisplayName(userID: targetUserID!) : nil
        let recipeID = record[CKField.Activity.recipeID] as? String
        let recipeName = record[CKField.Activity.recipeName] as? String
        let challengeName = record[CKField.Activity.challengeName] as? String
        let isReadInt = record[CKField.Activity.isRead] as? Int64 ?? 0

        // For recipe-related activities, validate that the recipe exists
        // Skip activities that reference non-existent recipes to avoid errors
        if let recipeID = recipeID, [.recipeShared, .recipeLiked, .recipeComment].contains(activityType) {
            do {
                // Quick check if recipe exists in CloudKit
                let _ = try await publicDatabase.record(for: CKRecord.ID(recordName: recipeID))
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
        
        return ActivityItem(
            id: id,
            type: activityType,
            userID: actorID,
            userName: actorName,
            userPhoto: nil, // TODO: Implement user photo loading
            targetUserID: targetUserID,
            targetUserName: targetUserName,
            recipeID: recipeID,
            recipeName: activityType == .challengeCompleted ? challengeName : recipeName,
            recipeImage: nil, // TODO: Implement recipe image loading
            challengeID: challengeID,
            timestamp: timestamp,
            isRead: isReadInt == 1
        )
    }
    
    // MARK: - Caching Methods
    
    private func loadCachedActivities() async {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let timestamp = UserDefaults.standard.object(forKey: cacheTimestampKey) as? Date,
              Date().timeIntervalSince(timestamp) < cacheExpirationTime else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cachedData = try decoder.decode(CachedActivityData.self, from: data)
            activities = cachedData.activities
            print("✅ Loaded \(activities.count) cached activities")
        } catch {
            print("❌ Failed to load cached activities: \(error)")
        }
    }
    
    private func saveCachedActivities() async {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let cachedData = CachedActivityData(activities: activities)
            let data = try encoder.encode(cachedData)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheTimestampKey)
        } catch {
            print("❌ Failed to save cached activities: \(error)")
        }
    }

    private func generateMockActivities() -> [ActivityItem] {
        [
            ActivityItem(
                id: UUID().uuidString,
                type: .follow,
                userID: "user1",
                userName: "Gordon Ramsay",
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
                userName: "Julia Child",
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
                userName: "Jamie Oliver",
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
        case "badgeEarned": type = .badgeEarned
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
        case .badgeEarned: typeString = "badgeEarned"
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
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    ActivityFeedView()
        .environmentObject(AppState())
}
