import SwiftUI

struct DailyCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var gamificationManager = GamificationManager.shared
    @State private var showingReward = false
    @State private var rewardScale = 0.1
    @State private var confettiOpacity = 0.0
    @State private var streakAnimation = false
    
    private var streakMilestone: Int? {
        let streak = gamificationManager.userStats.currentStreak
        let milestones = [7, 14, 30, 60, 100, 365]
        return milestones.first { streak == $0 }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Streak Counter
                        streakCounterView
                        
                        // Calendar View
                        calendarView
                        
                        // Rewards Section
                        rewardsSection
                        
                        // Check-in Button
                        checkInButton
                    }
                    .padding()
                }
                
                // Confetti overlay
                if showingReward {
                    confettiOverlay
                }
            }
            .navigationTitle("Daily Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Streak Counter
    private var streakCounterView: some View {
        GlassmorphicCard(content: {
            VStack(spacing: 16) {
                // Flame icon with animation
                ZStack {
                    ForEach(0..<3) { index in
                        Image(systemName: "flame.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.orange)
                            .opacity(0.3)
                            .scaleEffect(streakAnimation ? 1.2 : 0.8)
                            .animation(
                                .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                                value: streakAnimation
                            )
                    }
                    
                    Image(systemName: "flame.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.orange)
                }
                .onAppear {
                    streakAnimation = true
                }
                
                // Streak count
                VStack(spacing: 4) {
                    Text("\(gamificationManager.userStats.currentStreak)")
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Day Streak!")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
                
                // Milestone message
                if let milestone = streakMilestone {
                    Text("🎉 \(milestone)-day milestone reached!")
                        .font(.headline)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.2))
                        )
                }
                
                // Best streak
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text("Best: \(gamificationManager.userStats.longestStreak) days")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }, glowColor: .orange)
    }
    
    // MARK: - Calendar View
    private var calendarView: some View {
        GlassmorphicCard(content: {
            VStack(alignment: .leading, spacing: 16) {
                Text("This Week")
                    .font(.headline)
                
                HStack(spacing: 8) {
                    ForEach(0..<7) { dayOffset in
                        let date = Calendar.current.date(byAdding: .day, value: dayOffset - 6, to: Date())!
                        let isToday = Calendar.current.isDateInToday(date)
                        let hasCheckedIn = dayOffset < 6 || gamificationManager.hasCheckedInToday
                        
                        VStack(spacing: 8) {
                            Text(dayOfWeek(from: date))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            ZStack {
                                Circle()
                                    .fill(hasCheckedIn ? Color.orange : Color.gray.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                
                                if hasCheckedIn {
                                    Image(systemName: "checkmark")
                                        .font(.body)
                                        .foregroundColor(.white)
                                        .fontWeight(.semibold)
                                } else {
                                    Text("\(Calendar.current.component(.day, from: date))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if isToday {
                                    Circle()
                                        .stroke(Color.orange, lineWidth: 2)
                                        .frame(width: 44, height: 44)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }, glowColor: Color(hex: "#4facfe"))
    }
    
    // MARK: - Rewards Section
    private var rewardsSection: some View {
        GlassmorphicCard(content: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "gift.fill")
                        .font(.title3)
                        .foregroundColor(Color(hex: "#667eea"))
                    Text("Today's Rewards")
                        .font(.headline)
                }
                
                VStack(spacing: 12) {
                    RewardRow(
                        icon: "star.circle.fill",
                        title: "Daily Points",
                        value: "+50 XP",
                        color: .yellow
                    )
                    
                    if gamificationManager.userStats.currentStreak >= 7 {
                        RewardRow(
                            icon: "flame.circle.fill",
                            title: "Week Streak Bonus",
                            value: "+100 XP",
                            color: .orange
                        )
                    }
                    
                    if let milestone = streakMilestone {
                        RewardRow(
                            icon: "trophy.circle.fill",
                            title: "\(milestone)-Day Milestone",
                            value: "+\(milestone * 10) XP",
                            color: Color(hex: "#667eea")
                        )
                    }
                }
            }
            .padding()
        }, glowColor: Color(hex: "#667eea"))
    }
    
    // MARK: - Check-in Button
    private var checkInButton: some View {
        Button(action: performCheckIn) {
            HStack {
                Image(systemName: gamificationManager.hasCheckedInToday ? "checkmark.circle.fill" : "calendar.badge.plus")
                    .font(.title3)
                
                Text(gamificationManager.hasCheckedInToday ? "Already Checked In!" : "Check In Now")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: gamificationManager.hasCheckedInToday
                                ? [Color.gray, Color.gray.opacity(0.8)]
                                : [Color.orange, Color(hex: "#fa709a")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
        .disabled(gamificationManager.hasCheckedInToday)
        .scaleEffect(showingReward ? rewardScale : 1.0)
    }
    
    // MARK: - Confetti Overlay
    private var confettiOverlay: some View {
        ZStack {
            ForEach(0..<20, id: \.self) { index in
                DailyCheckInConfettiPiece()
                    .opacity(confettiOpacity)
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Helper Methods
    private func performCheckIn() {
        guard !gamificationManager.hasCheckedInToday else { return }
        
        // Perform check-in
        gamificationManager.performDailyCheckIn()
        
        // Animate reward
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            showingReward = true
            rewardScale = 1.2
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.5)) {
            rewardScale = 1.0
        }
        
        withAnimation(.easeIn(duration: 0.5)) {
            confettiOpacity = 1.0
        }
        
        // Hide confetti after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.5)) {
                confettiOpacity = 0.0
            }
        }
    }
    
    private func dayOfWeek(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
}

// MARK: - Supporting Views
private struct RewardRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

private struct DailyCheckInConfettiPiece: View {
    @State private var position = CGPoint(x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                                        y: -50)
    @State private var rotation = Double.random(in: 0...360)
    
    private let color = [Color.red, .blue, .green, .yellow, .orange, .purple].randomElement()!
    private let size = CGFloat.random(in: 8...16)
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
            .position(position)
            .onAppear {
                withAnimation(.linear(duration: Double.random(in: 2...4))) {
                    position.y = UIScreen.main.bounds.height + 50
                    rotation += Double.random(in: 180...720)
                }
            }
    }
}

// MARK: - Preview
struct DailyCheckInView_Previews: PreviewProvider {
    static var previews: some View {
        DailyCheckInView()
    }
}