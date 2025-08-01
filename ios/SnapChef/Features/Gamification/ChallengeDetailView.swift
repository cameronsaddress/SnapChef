import SwiftUI

// Note: This file was extracted from ChallengesView.swift
// The full ChallengesView has been moved to Archive/UnusedFeatures/

struct ChallengeDetailView: View {
    let challenge: Challenge
    @Environment(\.dismiss) var dismiss
    @State private var isJoining = false
    @State private var joinSuccess = false
    @StateObject private var gamificationManager = GamificationManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
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
                        RewardsCard(challenge: challenge)
                            .padding(.horizontal, 20)
                        
                        // Leaderboard preview
                        MiniLeaderboardCard(challenge: challenge)
                            .padding(.horizontal, 20)
                        
                        // Join button
                        if !challenge.isCompleted {
                            let isAlreadyJoined = gamificationManager.isChallengeJoined(challenge.id)
                            MagneticButton(
                                title: isAlreadyJoined || joinSuccess ? "Joined!" : "Join Challenge",
                                icon: isAlreadyJoined || joinSuccess ? "checkmark.circle.fill" : "plus.circle.fill",
                                action: isAlreadyJoined ? {} : joinChallenge
                            )
                            .padding(.horizontal, 20)
                            .disabled(isJoining || joinSuccess || isAlreadyJoined)
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
                
                // Top 3 placeholder
                VStack(spacing: 12) {
                    ForEach(1...3, id: \.self) { rank in
                        HStack {
                            Text("\(rank)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(rankColor(rank))
                                .frame(width: 30)
                            
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 32, height: 32)
                            
                            Text("Chef \(rank)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Text("\(1000 - rank * 100) pts")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "#f093fb"))
                        }
                    }
                }
                .padding(.top, 8)
            }
            .padding(20)
        }
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