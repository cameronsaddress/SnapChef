import SwiftUI

struct TeamChallengeView: View {
    @StateObject private var teamManager = TeamChallengeManager.shared
    @StateObject private var gamificationManager = GamificationManager.shared
    @State private var showCreateTeam = false
    @State private var showJoinTeam = false
    @State private var selectedTeam: Team?
    @State private var searchText = ""
    @State private var joinCode = ""
    @State private var isLoadingTeams = false
    
    var body: some View {
        NavigationView {
            ZStack {
                MagicalBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Section
                        if let currentTeam = teamManager.currentTeam {
                            CurrentTeamCard(team: currentTeam)
                                .padding(.horizontal)
                        } else {
                            NoTeamCard(
                                onCreateTeam: { showCreateTeam = true },
                                onJoinTeam: { showJoinTeam = true }
                            )
                            .padding(.horizontal)
                        }
                        
                        // Active Team Challenges
                        if !teamManager.activeTeamChallenges.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Active Team Challenges")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                
                                ForEach(teamManager.activeTeamChallenges) { challenge in
                                    TeamChallengeCard(challenge: challenge)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        
                        // Leaderboard Section
                        TeamLeaderboardSection()
                            .padding(.horizontal)
                        
                        // Discover Teams
                        DiscoverTeamsSection(
                            searchText: $searchText,
                            onJoinTeam: { team in
                                selectedTeam = team
                                showJoinTeam = true
                            }
                        )
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Team Challenges")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showCreateTeam) {
                CreateTeamView()
            }
            .sheet(isPresented: $showJoinTeam) {
                JoinTeamView(team: selectedTeam, joinCode: $joinCode)
            }
        }
    }
}

// MARK: - Current Team Card
struct CurrentTeamCard: View {
    let team: Team
    @State private var showTeamDetails = false
    
    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 16) {
                HStack {
                    // Team Icon
                    Text(team.imageIcon)
                        .font(.system(size: 50))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(team.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("\(team.members.count) members")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Team Stats
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                                .foregroundColor(.yellow)
                            Text("\(team.totalPoints)")
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        
                        Text("Total Points")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Team Progress
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Weekly Progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(team.weeklyPoints) / \(team.weeklyGoal)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: geometry.size.width * min(Double(team.weeklyPoints) / Double(team.weeklyGoal), 1.0),
                                    height: 8
                                )
                        }
                    }
                    .frame(height: 8)
                }
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: { showTeamDetails = true }) {
                        Label("Details", systemImage: "info.circle")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    Button(action: shareTeamCode) {
                        Label("Invite", systemImage: "person.badge.plus")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding()
        }
        .sheet(isPresented: $showTeamDetails) {
            TeamDetailsView(team: team)
        }
    }
    
    private func shareTeamCode() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else { return }
        
        let activityController = UIActivityViewController(
            activityItems: ["Join my SnapChef team '\(team.name)' with code: \(team.joinCode)"],
            applicationActivities: nil
        )
        
        rootViewController.present(activityController, animated: true)
    }
}

// MARK: - No Team Card
struct NoTeamCard: View {
    let onCreateTeam: () -> Void
    let onJoinTeam: () -> Void
    
    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 20) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color(hex: "#667eea"))
                
                Text("Join a Team!")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Team up with friends to complete challenges together and climb the leaderboard")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 16) {
                    Button("Create Team", action: onCreateTeam)
                        .buttonStyle(PrimaryButtonStyle())
                    
                    Button("Join Team", action: onJoinTeam)
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding()
        }
    }
}

// MARK: - Team Challenge Card
struct TeamChallengeCard: View {
    let challenge: Challenge
    
    var body: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(challenge.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(challenge.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(challenge.points)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: "#667eea"))
                        
                        Text("points")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hex: "#667eea"))
                            .frame(
                                width: geometry.size.width * challenge.currentProgress,
                                height: 6
                            )
                    }
                }
                .frame(height: 6)
                
                HStack {
                    Label(challenge.timeRemaining, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(challenge.currentProgress * 100))% Complete")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color(hex: "#667eea"))
                }
            }
            .padding()
        }
    }
}

// MARK: - Team Leaderboard Section
struct TeamLeaderboardSection: View {
    @StateObject private var teamManager = TeamChallengeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Top Teams This Week")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                NavigationLink(destination: FullTeamLeaderboardView()) {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#667eea"))
                }
            }
            
            VStack(spacing: 12) {
                ForEach(Array(teamManager.topTeams.prefix(3).enumerated()), id: \.element.id) { index, team in
                    TeamLeaderboardRow(team: team, rank: index + 1)
                }
            }
        }
    }
}

// MARK: - Team Leaderboard Row
struct TeamLeaderboardRow: View {
    let team: Team
    let rank: Int
    
    private var rankColor: Color {
        switch rank {
        case 1: return Color(hex: "#FFD700")
        case 2: return Color(hex: "#C0C0C0")
        case 3: return Color(hex: "#CD7F32")
        default: return Color.gray
        }
    }
    
    var body: some View {
        GlassmorphicCard {
            HStack(spacing: 16) {
                // Rank
                Text("#\(rank)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(rankColor)
                    .frame(width: 40)
                
                // Team Icon
                Text(team.imageIcon)
                    .font(.title2)
                
                // Team Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(team.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("\(team.members.count) members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Points
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(team.weeklyPoints)")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Discover Teams Section
struct DiscoverTeamsSection: View {
    @Binding var searchText: String
    let onJoinTeam: (Team) -> Void
    @StateObject private var teamManager = TeamChallengeManager.shared
    
    var filteredTeams: [Team] {
        if searchText.isEmpty {
            return teamManager.publicTeams
        } else {
            return teamManager.publicTeams.filter { team in
                team.name.localizedCaseInsensitiveContains(searchText) ||
                team.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Discover Teams")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search teams...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
            )
            .padding(.horizontal)
            
            // Teams List
            VStack(spacing: 12) {
                ForEach(filteredTeams) { team in
                    DiscoverTeamCard(team: team, onJoin: {
                        onJoinTeam(team)
                    })
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Discover Team Card
struct DiscoverTeamCard: View {
    let team: Team
    let onJoin: () -> Void
    
    var body: some View {
        GlassmorphicCard {
            HStack(spacing: 16) {
                // Team Icon
                Text(team.imageIcon)
                    .font(.system(size: 40))
                
                // Team Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(team.name)
                        .font(.headline)
                    
                    Text(team.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Label("\(team.members.count)", systemImage: "person.2.fill")
                        Label("\(team.weeklyPoints)", systemImage: "star.fill")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Join Button
                Button("Join", action: onJoin)
                    .buttonStyle(SmallPrimaryButtonStyle())
            }
            .padding()
        }
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.2))
            .foregroundColor(.primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

struct SmallPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(hex: "#667eea"))
            .foregroundColor(.white)
            .font(.subheadline)
            .fontWeight(.medium)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

// MARK: - Preview
struct TeamChallengeView_Previews: PreviewProvider {
    static var previews: some View {
        TeamChallengeView()
    }
}