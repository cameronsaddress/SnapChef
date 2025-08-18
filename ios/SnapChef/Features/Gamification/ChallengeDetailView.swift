import SwiftUI

// Note: This file was extracted from ChallengesView.swift
// The full ChallengesView has been moved to Archive/UnusedFeatures/

struct ChallengeDetailView: View {
    let challenge: Challenge
    @Environment(\.dismiss) var dismiss
    @State private var isJoining = false
    @State private var joinSuccess = false
    @StateObject private var gamificationManager = GamificationManager.shared
    @StateObject private var authManager = CloudKitAuthManager.shared

    // Get the actual challenge from GamificationManager if it exists
    private var displayChallenge: Challenge {
        if let activeChallenge = gamificationManager.activeChallenges.first(where: {
            $0.id == challenge.id || $0.title == challenge.title
        }) {
            return activeChallenge
        }
        return challenge
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 30) {
                        // Title and description
                        VStack(spacing: 16) {
                            Text(displayChallenge.title)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            Text(displayChallenge.description)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 20)

                        // Join button or Progress at the top
                        if !displayChallenge.isCompleted {
                            let isAlreadyJoined = displayChallenge.isJoined || gamificationManager.isChallengeJoined(displayChallenge.id)

                            if isAlreadyJoined {
                                // Show progress card
                                ProgressCard(challenge: displayChallenge)
                                    .padding(.horizontal, 20)
                            } else {
                                // Show join button
                                MagneticButton(
                                    title: joinSuccess ? "Joined!" : "Join Challenge",
                                    icon: joinSuccess ? "checkmark.circle.fill" : "plus.circle.fill",
                                    action: joinChallenge
                                )
                                .padding(.horizontal, 20)
                                .disabled(isJoining || joinSuccess)
                            }
                        }

                        // Requirements
                        RequirementsCard(challenge: displayChallenge)
                            .padding(.horizontal, 20)

                        // Rewards
                        RewardsCard(challenge: displayChallenge)
                            .padding(.horizontal, 20)

                        // Leaderboard preview
                        MiniLeaderboardCard(challenge: displayChallenge)
                            .padding(.horizontal, 20)
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
        .sheet(isPresented: $authManager.showAuthSheet) {
            CloudKitAuthView(requiredFor: .challenges)
        }
    }

    private func joinChallenge() {
        // Check if authentication is required
        let authManager = CloudKitAuthManager.shared
        if authManager.isAuthRequiredFor(feature: .challenges) {
            authManager.promptAuthForFeature(.challenges)
            return
        }

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
                        startRadius: 40,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .blur(radius: 20)

            // Background
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
                .frame(width: 140, height: 140)
                .shadow(color: type.color.opacity(0.5), radius: 20)

            // Icon
            Image(systemName: type.icon)
                .font(.system(size: 50, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Requirements Card
struct RequirementsCard: View {
    let challenge: Challenge

    var body: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Requirements", systemImage: "checklist")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(Color(hex: "#43e97b"))
                        Text(challenge.requirements.first ?? "Complete the challenge")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                // Time remaining
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(Color(hex: "#4facfe"))
                    Text(challenge.timeRemaining)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#4facfe"))
                }
                .padding(.top, 8)
            }
            .padding(20)
        }
    }
}

// MARK: - Rewards Card
struct RewardsCard: View {
    let challenge: Challenge

    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 20) {
                Label("Rewards", systemImage: "gift")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)

                HStack(spacing: 40) {
                    // Points
                    VStack(spacing: 8) {
                        Text("\(challenge.points)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#f093fb"))
                        Text("Points")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    // Coins
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "bitcoinsign.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.yellow)
                            Text("\(challenge.coins)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.yellow)
                        }
                        Text("Coins")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Mini Leaderboard Card
struct MiniLeaderboardCard: View {
    let challenge: Challenge
    @State private var leaderboardEntries: [LeaderboardEntry] = []
    @State private var isLoading = true

    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 16) {
                HStack {
                    Label("Leaderboard", systemImage: "trophy")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Text("\(challenge.participants) chefs")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }

                // Leaderboard entries
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(height: 100)
                } else if leaderboardEntries.isEmpty {
                    Text("Be the first to complete this challenge!")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(height: 100)
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(leaderboardEntries.prefix(3).enumerated()), id: \.element.id) { index, entry in
                            HStack {
                                Text("\(index + 1)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(rankColor(index + 1))
                                    .frame(width: 30)

                                // Profile image placeholder
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Text(String(entry.username.prefix(1)).uppercased())
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                    )

                                Text(entry.username)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(1)

                                Spacer()

                                Text("\(entry.points) pts")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "#f093fb"))
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(20)
        }
        .onAppear {
            loadLeaderboard()
        }
    }

    private func loadLeaderboard() {
        Task {
            // For now, use mock data or fetch from CloudKit
            // The CloudKit query was failing because recordName isn't queryable
            // We need to query by totalPoints instead
            let entries = await fetchLeaderboardEntries()
            await MainActor.run {
                self.leaderboardEntries = entries
                self.isLoading = false
            }
        }
    }

    private func fetchLeaderboardEntries() async -> [LeaderboardEntry] {
        // For now, return mock data
        // CloudKit leaderboard query not implemented - using mock data
        return [
            LeaderboardEntry(rank: 1, username: "ChefMaster", avatar: "👨‍🍳", points: 1_250, level: 12, country: "USA", isCurrentUser: false),
            LeaderboardEntry(rank: 2, username: "CookieQueen", avatar: "👩‍🍳", points: 980, level: 10, country: "UK", isCurrentUser: false),
            LeaderboardEntry(rank: 3, username: "PastaKing", avatar: "🍝", points: 875, level: 9, country: "Italy", isCurrentUser: false)
        ]
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(hex: "#ffd700")
        case 2: return Color(hex: "#c0c0c0")
        case 3: return Color(hex: "#cd7f32")
        default: return .white
        }
    }
}

// MARK: - Progress Card
struct ProgressCard: View {
    let challenge: Challenge
    @State private var showProofSubmission = false

    private var progressPercentage: Int {
        Int(challenge.currentProgress * 100)
    }

    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 20) {
                Label("Your Progress", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)

                // Progress Circle
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 12)
                        .frame(width: 120, height: 120)

                    // Progress circle
                    Circle()
                        .trim(from: 0, to: challenge.currentProgress)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#4facfe"),
                                    Color(hex: "#00f2fe")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: challenge.currentProgress)

                    // Progress text
                    VStack(spacing: 4) {
                        Text("\(progressPercentage)%")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Complete")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                // Status
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("Status")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        Text("In Progress")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#4facfe"))
                    }

                    Divider()
                        .frame(height: 30)
                        .background(Color.white.opacity(0.2))

                    VStack(spacing: 4) {
                        Text("Time Left")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        Text(challenge.timeRemaining)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }

                // Requirements checklist
                if !challenge.requirements.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(challenge.requirements, id: \.self) { requirement in
                            HStack {
                                Image(systemName: challenge.currentProgress >= 1.0 ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(challenge.currentProgress >= 1.0 ? Color(hex: "#43e97b") : Color.white.opacity(0.5))
                                    .font(.system(size: 16))
                                Text(requirement)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.8))
                                Spacer()
                            }
                        }
                    }
                    .padding(.top, 8)
                }

                // Submit Proof Button
                Button(action: {
                    showProofSubmission = true
                }) {
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18))
                        Text("Submit Completed Challenge")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(hex: "#667eea"),
                                Color(hex: "#764ba2")
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .disabled(challenge.currentProgress >= 1.0)
                .opacity(challenge.currentProgress >= 1.0 ? 0.5 : 1.0)
            }
            .padding(20)
        }
        .sheet(isPresented: $showProofSubmission) {
            ChallengeProofSubmissionView(challenge: challenge)
        }
    }
}

#Preview {
    ChallengeDetailView(challenge: Challenge(
        title: "Pasta Master",
        description: "Create 5 different pasta dishes this week",
        type: .weekly,
        endDate: Date().addingTimeInterval(5 * 24 * 60 * 60),
        requirements: ["Cook 5 pasta recipes"],
        currentProgress: 0.4,
        participants: 234
    ))
}
