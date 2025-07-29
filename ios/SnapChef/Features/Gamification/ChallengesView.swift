import SwiftUI

struct ChallengesView: View {
    @StateObject private var gamificationManager = GamificationManager.shared
    @State private var selectedTab = 0
    @State private var showChallengeDetail: Challenge?
    @State private var contentVisible = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header with stats
                        ChallengesHeaderView(stats: gamificationManager.userStats)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .staggeredFade(index: 0, isShowing: contentVisible)
                        
                        // Tab selector
                        ChallengeTabSelector(selectedTab: $selectedTab)
                            .padding(.horizontal, 20)
                            .staggeredFade(index: 1, isShowing: contentVisible)
                        
                        // Challenges list
                        VStack(spacing: 16) {
                            ForEach(filteredChallenges.indices, id: \.self) { index in
                                ChallengeCard(
                                    challenge: filteredChallenges[index],
                                    onTap: {
                                        showChallengeDetail = filteredChallenges[index]
                                    }
                                )
                                .staggeredFade(
                                    index: index + 2,
                                    isShowing: contentVisible
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Community progress
                        if selectedTab == 0 || selectedTab == 3 {
                            CommunityProgressCard()
                                .padding(.horizontal, 20)
                                .staggeredFade(
                                    index: filteredChallenges.count + 3,
                                    isShowing: contentVisible
                                )
                        }
                    }
                    .padding(.bottom, 100)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Challenges")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Color(hex: "#ffa726"))
                    }
                }
            }
        }
        .sheet(item: $showChallengeDetail) { challenge in
            ChallengeDetailView(challenge: challenge)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                contentVisible = true
            }
        }
    }
    
    var filteredChallenges: [Challenge] {
        switch selectedTab {
        case 1: // Daily
            return gamificationManager.activeChallenges.filter { $0.type == .daily }
        case 2: // Weekly
            return gamificationManager.activeChallenges.filter { $0.type == .weekly }
        case 3: // Special
            return gamificationManager.activeChallenges.filter { $0.type == .special || $0.type == .community }
        default: // All
            return gamificationManager.activeChallenges
        }
    }
}

// MARK: - Challenges Header
struct ChallengesHeaderView: View {
    let stats: UserGameStats
    @State private var glowAnimation = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Title section
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fridge Whisperer")
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
                    
                    Text("Complete challenges to earn rewards")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                // Animated trophy
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
                    
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(Color(hex: "#ffa726"))
                        .rotationEffect(.degrees(glowAnimation ? 10 : -10))
                }
            }
            
            // Stats cards
            HStack(spacing: 12) {
                QuickStatCard(
                    title: "Completed",
                    value: "\(stats.challengesCompleted)",
                    icon: "checkmark.circle.fill",
                    color: Color(hex: "#43e97b")
                )
                
                QuickStatCard(
                    title: "Streak",
                    value: "\(stats.currentStreak) days",
                    icon: "flame.fill",
                    color: Color(hex: "#f093fb")
                )
                
                QuickStatCard(
                    title: "Rank",
                    value: "#\(stats.weeklyRank ?? 0)",
                    icon: "chart.line.uptrend.xyaxis",
                    color: Color(hex: "#4facfe")
                )
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowAnimation = true
            }
        }
    }
}

// MARK: - Quick Stat Card
struct QuickStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
                
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Challenge Tab Selector
struct ChallengeTabSelector: View {
    @Binding var selectedTab: Int
    let tabs = ["All", "Daily", "Weekly", "Special"]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    TabButton(
                        title: tabs[index],
                        isSelected: selectedTab == index,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedTab = index
                            }
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
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
                            Capsule()
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

// MARK: - Challenge Card
struct ChallengeCard: View {
    let challenge: Challenge
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            GlassmorphicCard {
                VStack(spacing: 16) {
                    // Header
                    HStack {
                        // Challenge type badge
                        HStack(spacing: 6) {
                            Image(systemName: challenge.type.icon)
                                .font(.system(size: 14, weight: .semibold))
                            Text(challenge.type.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(challenge.type.color.opacity(0.3))
                                .overlay(
                                    Capsule()
                                        .stroke(challenge.type.color, lineWidth: 1)
                                )
                        )
                        
                        Spacer()
                        
                        // Time remaining
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 12, weight: .medium))
                            Text(challenge.timeRemaining)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.7))
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: 12) {
                        Text(challenge.title)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text(challenge.description)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Progress
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(challenge.requirement)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Spacer()
                                
                                Text("\(Int(challenge.progress * 100))%")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(challenge.type.color)
                            }
                            
                            // Progress bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.2))
                                        .frame(height: 8)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    challenge.type.color,
                                                    challenge.type.color.opacity(0.7)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geometry.size.width * challenge.progress, height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                        
                        // Reward preview
                        HStack(spacing: 16) {
                            // Points
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "#ffa726"))
                                Text("+\(challenge.reward.points) XP")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            // Badge
                            if challenge.reward.badge != nil {
                                HStack(spacing: 6) {
                                    Image(systemName: "rosette")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color(hex: "#f093fb"))
                                    Text("Badge")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            
                            Spacer()
                            
                            // Participants
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 12, weight: .medium))
                                Text("\(challenge.participants)")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding(20)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Community Progress Card
struct CommunityProgressCard: View {
    @State private var pulseAnimation = false
    
    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Community Power")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Together we're stronger!")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    // Animated icon
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(hex: "#43e97b").opacity(0.3),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 30
                                )
                            )
                            .frame(width: 60, height: 60)
                            .scaleEffect(pulseAnimation ? 1.2 : 1)
                        
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(Color(hex: "#43e97b"))
                    }
                }
                
                // Stats
                HStack(spacing: 30) {
                    VStack(spacing: 4) {
                        Text("847K")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#43e97b"))
                        Text("Recipes")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    VStack(spacing: 4) {
                        Text("45.8K")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#4facfe"))
                        Text("Chefs")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    VStack(spacing: 4) {
                        Text("15d")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#f093fb"))
                        Text("Left")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                // Join button
                MagneticButton(
                    title: "Join Global Challenge",
                    icon: "globe",
                    action: {}
                )
            }
            .padding(24)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }
}

// MARK: - Challenge Detail View
struct ChallengeDetailView: View {
    let challenge: Challenge
    @Environment(\.dismiss) var dismiss
    @State private var isJoining = false
    @State private var joinSuccess = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Challenge icon
                        ChallengeIconView(type: challenge.type)
                        
                        // Title and description
                        VStack(spacing: 16) {
                            Text(challenge.title)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text(challenge.description)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 20)
                        
                        // Requirements
                        RequirementsCard(challenge: challenge)
                            .padding(.horizontal, 20)
                        
                        // Rewards
                        RewardsCard(reward: challenge.reward)
                            .padding(.horizontal, 20)
                        
                        // Leaderboard preview
                        MiniLeaderboardCard(challenge: challenge)
                            .padding(.horizontal, 20)
                        
                        // Join button
                        if !challenge.isCompleted {
                            MagneticButton(
                                title: joinSuccess ? "Joined!" : "Join Challenge",
                                icon: joinSuccess ? "checkmark.circle.fill" : "plus.circle.fill",
                                action: joinChallenge
                            )
                            .padding(.horizontal, 20)
                            .disabled(isJoining || joinSuccess)
                        }
                    }
                    .padding(.vertical, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#667eea"))
                }
            }
        }
    }
    
    private func joinChallenge() {
        isJoining = true
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Simulate join
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isJoining = false
            joinSuccess = true
            GamificationManager.shared.joinChallenge(challenge)
        }
    }
}

// MARK: - Challenge Icon View
struct ChallengeIconView: View {
    let type: ChallengeType
    @State private var rotationAngle = 0.0
    
    var body: some View {
        ZStack {
            // Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            type.color.opacity(0.4),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
            
            // Icon background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            type.color,
                            type.color.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
                .rotationEffect(.degrees(rotationAngle))
            
            // Icon
            Image(systemName: type.icon)
                .font(.system(size: 50, weight: .medium))
                .foregroundColor(.white)
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
}

// MARK: - Requirements Card
struct RequirementsCard: View {
    let challenge: Challenge
    
    var body: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "checklist")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: "#667eea"))
                    
                    Text("Requirements")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    RequirementRow(text: challenge.requirement, isCompleted: false)
                    RequirementRow(text: "Must complete within time limit", isCompleted: false)
                    RequirementRow(text: "Follow app guidelines", isCompleted: true)
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Requirement Row
struct RequirementRow: View {
    let text: String
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isCompleted ? Color(hex: "#43e97b") : .white.opacity(0.5))
            
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(isCompleted ? 0.9 : 0.7))
                .strikethrough(isCompleted)
        }
    }
}

// MARK: - Rewards Card
struct RewardsCard: View {
    let reward: ChallengeReward
    @State private var sparkleAnimation = false
    
    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 20) {
                HStack {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: "#f093fb"))
                    
                    Text("Rewards")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#ffa726"))
                        .rotationEffect(.degrees(sparkleAnimation ? 360 : 0))
                }
                
                VStack(spacing: 16) {
                    // Points
                    RewardRow(
                        icon: "star.fill",
                        title: "\(reward.points) XP",
                        subtitle: "Experience Points",
                        color: Color(hex: "#ffa726")
                    )
                    
                    // Badge
                    if let badge = reward.badge {
                        RewardRow(
                            icon: "rosette",
                            title: badge,
                            subtitle: "Exclusive Badge",
                            color: Color(hex: "#f093fb")
                        )
                    }
                    
                    // Title
                    if let title = reward.title {
                        RewardRow(
                            icon: "crown.fill",
                            title: title,
                            subtitle: "Special Title",
                            color: Color(hex: "#667eea")
                        )
                    }
                    
                    // Unlockable
                    if let unlockable = reward.unlockable {
                        RewardRow(
                            icon: "lock.open.fill",
                            title: unlockable,
                            subtitle: "Exclusive Content",
                            color: Color(hex: "#43e97b")
                        )
                    }
                }
            }
            .padding(20)
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                sparkleAnimation = true
            }
        }
    }
}

// MARK: - Reward Row
struct RewardRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
    }
}

// MARK: - Mini Leaderboard Card
struct MiniLeaderboardCard: View {
    let challenge: Challenge
    
    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: "#4facfe"))
                    
                    Text("Top Participants")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(challenge.participants)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Mock leaderboard entries
                VStack(spacing: 12) {
                    MiniLeaderboardRow(rank: 1, username: "ChefMaster", points: 980)
                    MiniLeaderboardRow(rank: 2, username: "CookingNinja", points: 875)
                    MiniLeaderboardRow(rank: 3, username: "RecipeKing", points: 820)
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Mini Leaderboard Row
struct MiniLeaderboardRow: View {
    let rank: Int
    let username: String
    let points: Int
    
    var rankColor: Color {
        switch rank {
        case 1: return Color(hex: "#ffa726")
        case 2: return Color.gray
        case 3: return Color(hex: "#cd7f32")
        default: return Color.white.opacity(0.7)
        }
    }
    
    var body: some View {
        HStack {
            // Rank
            Text("#\(rank)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(rankColor)
                .frame(width: 30)
            
            // User
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.5))
                
                Text(username)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Points
            Text("\(points) pts")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "#43e97b"))
        }
    }
}

#Preview {
    ChallengesView()
}