import SwiftUI

// MARK: - Leaderboard View
struct LeaderboardView: View {
    @StateObject private var gamificationManager = GamificationManager.shared
    @State private var selectedTimeframe: LeaderboardTimeframe = .weekly
    @State private var selectedRegion: LeaderboardRegion = .global
    @State private var isLoading = false
    @State private var showShareSheet = false
    @State private var searchText = ""
    @State private var animateRankChange = false

    enum LeaderboardTimeframe: String, CaseIterable {
        case daily = "Today"
        case weekly = "This Week"
        case monthly = "This Month"
        case allTime = "All Time"

        var icon: String {
            switch self {
            case .daily: return "sun.max.fill"
            case .weekly: return "calendar"
            case .monthly: return "calendar.badge.clock"
            case .allTime: return "infinity"
            }
        }
    }

    enum LeaderboardRegion: String, CaseIterable {
        case global = "Global"
        case country = "Country"
        case city = "City"
        case friends = "Friends"

        var icon: String {
            switch self {
            case .global: return "globe"
            case .country: return "flag.fill"
            case .city: return "building.2.fill"
            case .friends: return "person.2.fill"
            }
        }
    }

    var filteredLeaderboard: [LeaderboardEntry] {
        let baseLeaderboard = selectedTimeframe == .weekly ? gamificationManager.weeklyLeaderboard : gamificationManager.globalLeaderboard

        if searchText.isEmpty {
            return baseLeaderboard
        } else {
            return baseLeaderboard.filter { entry in
                entry.username.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header with User Stats
                    UserStatsHeader()
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 20)

                    // Filter Controls
                    VStack(spacing: 16) {
                        // Timeframe Selector
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(LeaderboardTimeframe.allCases, id: \.self) { timeframe in
                                    TimeframeButton(
                                        timeframe: timeframe,
                                        isSelected: selectedTimeframe == timeframe
                                    ) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            selectedTimeframe = timeframe
                                            loadLeaderboard()
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // Region Selector
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(LeaderboardRegion.allCases, id: \.self) { region in
                                    RegionButton(
                                        region: region,
                                        isSelected: selectedRegion == region
                                    ) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            selectedRegion = region
                                            loadLeaderboard()
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white.opacity(0.6))

                            TextField("Search players...", text: $searchText)
                                .foregroundColor(.white)
                                .autocapitalization(.none)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 20)

                    // Leaderboard List
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                // Top 3 Players
                                if filteredLeaderboard.count >= 3 && searchText.isEmpty {
                                    TopThreePlayersView(players: Array(filteredLeaderboard.prefix(3)))
                                        .padding(.horizontal, 20)
                                        .padding(.bottom, 20)
                                }

                                // Rest of the leaderboard
                                ForEach(filteredLeaderboard.dropFirst(searchText.isEmpty ? 3 : 0)) { entry in
                                    LeaderboardRow(entry: entry)
                                        .padding(.horizontal, 20)
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)
                                        ))
                                }
                            }
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            LeaderboardShareSheet(items: [generateShareText()])
        }
        .onAppear {
            loadLeaderboard()
            animateRankChange = true
        }
    }

    private func loadLeaderboard() {
        isLoading = true

        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // In real app, fetch from server based on filters
            Task {
                await gamificationManager.updateLeaderboards()
                isLoading = false
            }
        }
    }

    private func generateShareText() -> String {
        let rank = gamificationManager.userStats.weeklyRank ?? 0
        return """
        🏆 I'm ranked #\(rank) on SnapChef this week!

        Level \(gamificationManager.userStats.level) | \(gamificationManager.userStats.totalPoints) points

        Think you can beat me? Download SnapChef and join the competition!

        #SnapChef #CookingChallenge #Leaderboard
        """
    }
}

// MARK: - User Stats Header
struct UserStatsHeader: View {
    @StateObject private var gamificationManager = GamificationManager.shared

    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Ranking")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("#\(gamificationManager.userStats.weeklyRank ?? 0)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(hex: "#43e97b"))
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        HStack(spacing: 12) {
                            StatBubble(
                                icon: "flame.fill",
                                value: "\(gamificationManager.userStats.currentStreak)",
                                label: "Streak"
                            )

                            StatBubble(
                                icon: "star.fill",
                                value: "\(gamificationManager.userStats.level)",
                                label: "Level"
                            )
                        }
                    }
                }

                // Progress to next rank
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Next Rank")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        Spacer()

                        Text("250 points to go")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.2))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: "#667eea"),
                                            Color(hex: "#764ba2")
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * 0.7)
                        }
                    }
                    .frame(height: 8)
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Stat Bubble
struct StatBubble: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.15))
        )
    }
}

// MARK: - Timeframe Button
struct TimeframeButton: View {
    let timeframe: LeaderboardView.LeaderboardTimeframe
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: timeframe.icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(timeframe.rawValue)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? Color(hex: "#667eea") : Color.white.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            .opacity(isSelected ? 0 : 1)
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1)
        }
    }
}

// MARK: - Region Button
struct RegionButton: View {
    let region: LeaderboardView.LeaderboardRegion
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: region.icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(region.rawValue)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? Color(hex: "#f093fb") : Color.white.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            .opacity(isSelected ? 0 : 1)
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1)
        }
    }
}

// MARK: - Top Three Players View
struct TopThreePlayersView: View {
    let players: [LeaderboardEntry]
    @State private var animateIn = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 20) {
            // 2nd Place
            if players.count > 1 {
                TopPlayerCard(entry: players[1], place: 2, height: 140)
                    .scaleEffect(animateIn ? 1 : 0.8)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: animateIn)
            }

            // 1st Place
            if !players.isEmpty {
                TopPlayerCard(entry: players[0], place: 1, height: 180)
                    .scaleEffect(animateIn ? 1 : 0.8)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: animateIn)
            }

            // 3rd Place
            if players.count > 2 {
                TopPlayerCard(entry: players[2], place: 3, height: 120)
                    .scaleEffect(animateIn ? 1 : 0.8)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: animateIn)
            }
        }
        .onAppear {
            animateIn = true
        }
    }
}

// MARK: - Top Player Card
struct TopPlayerCard: View {
    let entry: LeaderboardEntry
    let place: Int
    let height: CGFloat

    var medalColor: Color {
        switch place {
        case 1: return Color(hex: "#ffd700")
        case 2: return Color(hex: "#c0c0c0")
        case 3: return Color(hex: "#cd7f32")
        default: return .gray
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Medal
            ZStack {
                Circle()
                    .fill(medalColor)
                    .frame(width: 50, height: 50)

                Text("\(place)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .shadow(color: medalColor.opacity(0.5), radius: 10)

            // Player Info
            VStack(spacing: 4) {
                Image(systemName: entry.avatar)
                    .font(.system(size: 30))
                    .foregroundColor(.white)

                Text(entry.username)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("\(entry.points)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if let country = entry.country {
                    Text(country)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .frame(width: 100, height: height)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            medalColor.opacity(0.3),
                            medalColor.opacity(0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(medalColor.opacity(0.5), lineWidth: 2)
                )
        )
    }
}

// MARK: - Leaderboard Row
struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    @State private var isPressed = false

    var body: some View {
        GlassmorphicCard {
            HStack(spacing: 16) {
                // Rank
                Text("#\(entry.rank)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(entry.isCurrentUser ? Color(hex: "#667eea") : .white)
                    .frame(width: 50, alignment: .leading)

                // Avatar
                Image(systemName: entry.avatar)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(
                                entry.isCurrentUser
                                    ? Color(hex: "#667eea")
                                    : Color.white.opacity(0.2)
                            )
                    )

                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.username)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        if entry.isCurrentUser {
                            Text("(You)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "#667eea"))
                        }
                    }

                    HStack(spacing: 8) {
                        Label("\(entry.level)", systemImage: "star.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        if let country = entry.country {
                            Text("• \(country)")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }

                Spacer()

                // Points
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(entry.points)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("points")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(16)
        }
        .scaleEffect(isPressed ? 0.98 : 1)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isPressed = false
                }
            }
        }
    }
}

// Share sheet helper
struct LeaderboardShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    LeaderboardView()
}
