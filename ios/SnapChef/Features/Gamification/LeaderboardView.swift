import SwiftUI

struct LeaderboardView: View {
    @StateObject private var gamificationManager = GamificationManager.shared
    @State private var selectedScope: LeaderboardScope = .weekly
    @State private var showingUserProfile = false
    @State private var contentVisible = false
    @State private var scrollToUser = false
    
    enum LeaderboardScope: String, CaseIterable {
        case weekly = "This Week"
        case global = "All Time"
        case friends = "Friends"
        
        var icon: String {
            switch self {
            case .weekly: return "calendar"
            case .global: return "globe"
            case .friends: return "person.2"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with user rank
                    LeaderboardHeaderView(
                        userStats: gamificationManager.userStats,
                        selectedScope: selectedScope
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                    .staggeredFade(index: 0, isShowing: contentVisible)
                    
                    // Scope selector
                    ScopeSelectorView(selectedScope: $selectedScope)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .staggeredFade(index: 1, isShowing: contentVisible)
                    
                    // Leaderboard list
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                // Top 3 special cards
                                if selectedScope != .friends {
                                    TopThreeView(entries: Array(currentLeaderboard.prefix(3)))
                                        .padding(.horizontal, 20)
                                        .padding(.bottom, 20)
                                        .staggeredFade(index: 2, isShowing: contentVisible)
                                }
                                
                                // Rest of leaderboard
                                ForEach(Array(currentLeaderboard.enumerated()), id: \.element.id) { index, entry in
                                    LeaderboardRowView(
                                        entry: entry,
                                        showRank: index >= 3 || selectedScope == .friends
                                    )
                                    .padding(.horizontal, 20)
                                    .id(entry.isCurrentUser ? "currentUser" : entry.id.uuidString)
                                    .staggeredFade(
                                        index: index + 3,
                                        isShowing: contentVisible
                                    )
                                }
                            }
                            .padding(.bottom, 100)
                        }
                        .onChange(of: scrollToUser) { shouldScroll in
                            if shouldScroll {
                                withAnimation(.spring()) {
                                    proxy.scrollTo("currentUser", anchor: .center)
                                }
                                scrollToUser = false
                            }
                        }
                    }
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { scrollToUser = true }) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Color(hex: "#4facfe"))
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                contentVisible = true
            }
            Task {
                await gamificationManager.updateLeaderboards()
            }
        }
    }
    
    var currentLeaderboard: [LeaderboardEntry] {
        switch selectedScope {
        case .weekly:
            return gamificationManager.weeklyLeaderboard
        case .global:
            return gamificationManager.globalLeaderboard
        case .friends:
            // Mock friends data
            return Array(gamificationManager.weeklyLeaderboard.prefix(10))
        }
    }
}

// MARK: - Leaderboard Header
struct LeaderboardHeaderView: View {
    let userStats: UserGameStats
    let selectedScope: LeaderboardView.LeaderboardScope
    @State private var glowAnimation = false
    
    var currentRank: Int {
        switch selectedScope {
        case .weekly:
            return userStats.weeklyRank ?? 0
        case .global:
            return userStats.globalRank ?? 0
        case .friends:
            return 3 // Mock
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Leaderboard")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color.white.opacity(0.9)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    Text("Compete with chefs worldwide")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
            }
            
            // User rank card
            GlassmorphicCard {
                HStack(spacing: 20) {
                    // Rank badge
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(hex: "#ffa726").opacity(0.3),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 40
                                )
                            )
                            .frame(width: 80, height: 80)
                            .scaleEffect(glowAnimation ? 1.2 : 1)
                        
                        VStack(spacing: 4) {
                            Text("#\(currentRank)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "#ffa726"))
                            
                            Text("Rank")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Position")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 20) {
                            // Points
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "#ffa726"))
                                Text("\(userStats.totalPoints) XP")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            // Level
                            HStack(spacing: 6) {
                                Image(systemName: "shield.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "#667eea"))
                                Text("Level \(userStats.level)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(20)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowAnimation = true
            }
        }
    }
}

// MARK: - Scope Selector
struct ScopeSelectorView: View {
    @Binding var selectedScope: LeaderboardView.LeaderboardScope
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(LeaderboardView.LeaderboardScope.allCases, id: \.self) { scope in
                ScopeButton(
                    scope: scope,
                    isSelected: selectedScope == scope,
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedScope = scope
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Scope Button
struct ScopeButton: View {
    let scope: LeaderboardView.LeaderboardScope
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: scope.icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(scope.rawValue)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [
                                    Color(hex: "#667eea"),
                                    Color(hex: "#764ba2")
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color.clear : Color.white.opacity(0.3),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Top Three View
struct TopThreeView: View {
    let entries: [LeaderboardEntry]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            // Second place
            if entries.count > 1 {
                TopThreeCard(
                    entry: entries[1],
                    rank: 2,
                    height: 140
                )
            }
            
            // First place
            if entries.count > 0 {
                TopThreeCard(
                    entry: entries[0],
                    rank: 1,
                    height: 180
                )
            }
            
            // Third place
            if entries.count > 2 {
                TopThreeCard(
                    entry: entries[2],
                    rank: 3,
                    height: 120
                )
            }
        }
    }
}

// MARK: - Top Three Card
struct TopThreeCard: View {
    let entry: LeaderboardEntry
    let rank: Int
    let height: CGFloat
    @State private var isAnimating = false
    
    var medalColor: Color {
        switch rank {
        case 1: return Color(hex: "#ffa726") // Gold
        case 2: return Color(hex: "#c0c0c0") // Silver
        case 3: return Color(hex: "#cd7f32") // Bronze
        default: return Color.gray
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Medal
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                medalColor,
                                medalColor.opacity(0.7)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 30
                        )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )
                    .scaleEffect(isAnimating ? 1.1 : 1)
                
                Text("\(rank)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            // User info
            VStack(spacing: 8) {
                // Avatar
                Image(systemName: entry.avatar)
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.8))
                
                // Username
                Text(entry.username)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // Points
                Text("\(entry.points)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(medalColor)
                
                // Country flag
                if let country = entry.country {
                    Text(countryFlag(country))
                        .font(.system(size: 24))
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .padding(.vertical, 20)
        .background(
            GlassmorphicCard {
                Color.clear
            }
        )
        .overlay(
            entry.isCurrentUser ?
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "#43e97b"),
                            Color(hex: "#38f9d7")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
            : nil
        )
        .onAppear {
            if rank == 1 {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
    }
    
    private func countryFlag(_ code: String) -> String {
        let base: UInt32 = 127397
        var flag = ""
        for scalar in code.unicodeScalars {
            flag.unicodeScalars.append(UnicodeScalar(base + scalar.value)!)
        }
        return flag
    }
}

// MARK: - Leaderboard Row
struct LeaderboardRowView: View {
    let entry: LeaderboardEntry
    let showRank: Bool
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {}) {
            GlassmorphicCard {
                HStack(spacing: 16) {
                    // Rank
                    if showRank {
                        Text("#\(entry.rank)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(rankColor)
                            .frame(width: 50)
                    }
                    
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: entry.avatar)
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    // User info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.username)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(entry.isCurrentUser ? Color(hex: "#43e97b") : .white)
                            
                            if entry.isCurrentUser {
                                Text("(You)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(hex: "#43e97b").opacity(0.8))
                            }
                        }
                        
                        HStack(spacing: 12) {
                            // Level
                            HStack(spacing: 4) {
                                Image(systemName: "shield.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(hex: "#667eea"))
                                Text("Lvl \(entry.level)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            // Country
                            if let country = entry.country {
                                Text(countryFlag(country))
                                    .font(.system(size: 16))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Points
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(entry.points)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#ffa726"))
                        
                        Text("XP")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .overlay(
                entry.isCurrentUser ?
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "#43e97b"),
                                Color(hex: "#38f9d7")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                : nil
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    var rankColor: Color {
        switch entry.rank {
        case 1: return Color(hex: "#ffa726")
        case 2: return Color(hex: "#c0c0c0")
        case 3: return Color(hex: "#cd7f32")
        case 4...10: return Color(hex: "#667eea")
        case 11...50: return Color(hex: "#4facfe")
        case 51...100: return Color.white.opacity(0.8)
        default: return Color.white.opacity(0.6)
        }
    }
    
    private func countryFlag(_ code: String) -> String {
        let base: UInt32 = 127397
        var flag = ""
        for scalar in code.unicodeScalars {
            flag.unicodeScalars.append(UnicodeScalar(base + scalar.value)!)
        }
        return flag
    }
}

#Preview {
    LeaderboardView()
}