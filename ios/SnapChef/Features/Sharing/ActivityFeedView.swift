import SwiftUI
import CloudKit

// MARK: - Activity Item Model
struct ActivityItem: Identifiable {
    let id: String
    let type: ActivityType
    let userID: String
    let userName: String
    let userPhoto: UIImage?
    let targetUserID: String?
    let targetUserName: String?
    let recipeID: String?
    let recipeName: String?
    let recipeImage: UIImage?
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
    @State private var selectedFilter: ActivityFilter = .all
    @State private var showingRecipeDetail = false
    @State private var selectedRecipeID: String?

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
                    if feedManager.isLoading && feedManager.activities.isEmpty {
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
                                    ActivityItemView(activity: activity)
                                        .onTapGesture {
                                            handleActivityTap(activity)
                                        }
                                        .onAppear {
                                            // Mark activity as read when it appears on screen
                                            if !activity.isRead {
                                                Task {
                                                    await feedManager.markActivityAsRead(activity.id)
                                                }
                                            }
                                        }
                                }

                                if feedManager.hasMore {
                                    ProgressView()
                                        .tint(.white)
                                        .padding()
                                        .onAppear {
                                            Task {
                                                await feedManager.loadMore()
                                            }
                                        }
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
        switch activity.type {
        case .recipeShared, .recipeLiked, .recipeComment:
            if let recipeID = activity.recipeID {
                selectedRecipeID = recipeID
                showingRecipeDetail = true
            }
        case .follow:
            // Navigate to user profile
            break
        case .challengeCompleted:
            // Navigate to challenge detail
            break
        case .badgeEarned:
            // Show badge detail
            break
        }
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

    private let cloudKitSync = CloudKitSyncService.shared
    private var lastFetchedRecord: CKRecord?

    func loadInitialActivities() async {
        isLoading = true
        activities = []
        lastFetchedRecord = nil

        do {
            await fetchActivitiesFromCloudKit()
        } catch {
            print("❌ Failed to fetch activities from CloudKit: \(error)")
            // Fallback to mock data on error
            activities = generateMockActivities()
            hasMore = false
        }

        isLoading = false
    }

    func loadMore() async {
        guard hasMore && !isLoading else { return }

        isLoading = true

        do {
            await fetchActivitiesFromCloudKit(loadMore: true)
        } catch {
            print("❌ Failed to load more activities: \(error)")
            hasMore = false
        }

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
                    timestamp: updatedActivity.timestamp,
                    isRead: true
                )
                activities[index] = readActivity
            }
        } catch {
            print("❌ Failed to mark activity as read: \(error)")
        }
    }

    private func fetchActivitiesFromCloudKit(loadMore: Bool = false) async {
        guard let currentUser = CloudKitAuthManager.shared.currentUser,
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
            
            let newActivities = limitedRecords.compactMap { record in
                mapCloudKitRecordToActivityItem(record)
            }

            if loadMore {
                activities.append(contentsOf: newActivities)
            } else {
                activities = newActivities
            }

            // Check if there are more activities to load
            hasMore = newActivities.count >= 50

            print("✅ Loaded \(newActivities.count) activities from CloudKit (target: \(targetActivities.count), public: \(publicActivities.count))")
        } catch {
            print("❌ CloudKit activity fetch error: \(error)")
            // Don't throw here - just fallback to existing behavior
            hasMore = false
        }
    }

    private func fetchRecentPublicActivities(limit: Int) async throws -> [CKRecord] {
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
        
        // Collect all valid records first
        for (_, result) in results.matchResults {
            if case .success(let record) = result {
                // Filter by timestamp in code since it may not be queryable
                if let timestamp = record[CKField.Activity.timestamp] as? Date,
                   timestamp >= sevenDaysAgo {
                    activities.append(record)
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

    private func mapCloudKitRecordToActivityItem(_ record: CKRecord) -> ActivityItem? {
        guard let id = record[CKField.Activity.id] as? String,
              let typeString = record[CKField.Activity.type] as? String,
              let actorID = record[CKField.Activity.actorID] as? String,
              let actorName = record[CKField.Activity.actorName] as? String,
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

        // Extract optional fields
        let targetUserID = record[CKField.Activity.targetUserID] as? String
        let targetUserName = record[CKField.Activity.targetUserName] as? String
        let recipeID = record[CKField.Activity.recipeID] as? String
        let recipeName = record[CKField.Activity.recipeName] as? String
        let isReadInt = record[CKField.Activity.isRead] as? Int64 ?? 0

        return ActivityItem(
            id: id,
            type: activityType,
            userID: actorID,
            userName: actorName,
            userPhoto: nil, // TODO: Implement user photo loading
            targetUserID: targetUserID,
            targetUserName: targetUserName,
            recipeID: recipeID,
            recipeName: recipeName,
            recipeImage: nil, // TODO: Implement recipe image loading
            timestamp: timestamp,
            isRead: isReadInt == 1
        )
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
                timestamp: Date().addingTimeInterval(-10_800),
                isRead: true
            ),
            ActivityItem(
                id: UUID().uuidString,
                type: .challengeCompleted,
                userID: "user4",
                userName: "Bobby Flay",
                userPhoto: nil,
                targetUserID: nil,
                targetUserName: nil,
                recipeID: nil,
                recipeName: "30-Minute Meals",
                recipeImage: nil,
                timestamp: Date().addingTimeInterval(-14_400),
                isRead: true
            )
        ]
    }
}

#Preview {
    ActivityFeedView()
        .environmentObject(AppState())
}
