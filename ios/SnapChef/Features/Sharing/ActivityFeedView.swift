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
        
        // For now, load mock data
        // TODO: Implement CloudKit query for real activity data
        activities = generateMockActivities()
        hasMore = false
        
        isLoading = false
    }
    
    func loadMore() async {
        guard hasMore && !isLoading else { return }
        
        isLoading = true
        
        // TODO: Implement pagination with CloudKit
        
        isLoading = false
    }
    
    func refresh() async {
        await loadInitialActivities()
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
                timestamp: Date().addingTimeInterval(-3600),
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
                timestamp: Date().addingTimeInterval(-7200),
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
                timestamp: Date().addingTimeInterval(-10800),
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
                timestamp: Date().addingTimeInterval(-14400),
                isRead: true
            )
        ]
    }
}

#Preview {
    ActivityFeedView()
        .environmentObject(AppState())
}