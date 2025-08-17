import SwiftUI

struct ChallengeCardView: View {
    let challenge: Challenge
    let onTap: () -> Void

    @State private var isPressed = false
    @State private var particleOffset: CGFloat = 0

    private var progressPercentage: Double {
        min(challenge.currentProgress, 1.0)
    }

    private var progressColor: Color {
        switch challenge.type {
        case .daily:
            return Color(hex: "#4facfe")
        case .weekly:
            return Color(hex: "#f093fb")
        case .special:
            return Color(hex: "#fa709a")
        case .community:
            return Color(hex: "#feca57")
        }
    }

    private var typeIcon: String {
        switch challenge.type {
        case .daily:
            return "sun.max.fill"
        case .weekly:
            return "calendar.badge.clock"
        case .special:
            return "star.fill"
        case .community:
            return "person.3.fill"
        }
    }

    var body: some View {
        Button(action: onTap) {
            GlassmorphicCard(content: {
                VStack(spacing: 12) {
                    // Header
                    HStack {
                        // Type icon with background
                        ZStack {
                            Circle()
                                .fill(progressColor.opacity(0.2))
                                .frame(width: 40, height: 40)

                            Image(systemName: typeIcon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(progressColor)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(challenge.title)
                                .font(.headline)
                                .foregroundColor(.primary)

                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(.caption2)
                                Text("\(challenge.participants)")
                                    .font(.caption)

                                Text("•")
                                    .foregroundColor(.secondary)

                                Image(systemName: "clock.fill")
                                    .font(.caption2)
                                Text(challenge.timeRemaining)
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Reward preview
                        if challenge.points > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "star.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.yellow)
                                Text("\(challenge.points)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }
                    }

                    // Description
                    Text(challenge.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Progress section
                    VStack(spacing: 8) {
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 8)

                                // Progress fill
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: [progressColor, progressColor.opacity(0.7)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * progressPercentage, height: 8)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progressPercentage)

                                // Shimmer effect
                                if progressPercentage > 0 {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0),
                                                    Color.white.opacity(0.5),
                                                    Color.white.opacity(0)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: 60, height: 8)
                                        .offset(x: particleOffset)
                                        .onAppear {
                                            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                                                particleOffset = geometry.size.width
                                            }
                                        }
                                }
                            }
                        }
                        .frame(height: 8)

                        // Progress text
                        HStack {
                            Text(challenge.requirements.first ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            Text("\(Int(progressPercentage * 100))%")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(progressColor)
                        }
                    }

                    // Status badges
                    HStack(spacing: 8) {
                        if challenge.isCompleted {
                            StatusBadge(
                                text: "Completed",
                                icon: "checkmark.circle.fill",
                                color: .green
                            )
                        } else if !challenge.isActive {
                            StatusBadge(
                                text: "Expired",
                                icon: "xmark.circle.fill",
                                color: .red
                            )
                        } else if challenge.isJoined {
                            StatusBadge(
                                text: "Joined",
                                icon: "person.crop.circle.badge.checkmark",
                                color: .blue
                            )
                        }

                        // Leaderboard rank not implemented - would show user's rank in challenge
                        // Feature disabled until leaderboard integration is complete

                        Spacer()
                    }
                }
                .padding()
            }, glowColor: progressColor)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Status Badge Component
private struct StatusBadge: View {
    let text: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.2))
        )
        .foregroundColor(color)
    }
}

// MARK: - Preview
struct ChallengeCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            ChallengeCardView(
                challenge: Challenge(
                    title: "Quick Breakfast",
                    description: "Create 3 breakfast recipes today",
                    type: .daily,
                    points: 100,
                    coins: 10,
                    endDate: Date().addingTimeInterval(86_400),
                    requirements: ["2/3 recipes"],
                    currentProgress: 0.67,
                    participants: 567
                ),
                onTap: {}
            )

            ChallengeCardView(
                challenge: {
                    var challenge = Challenge(
                        title: "Protein Week",
                        description: "Create 10 high-protein recipes",
                        type: .weekly,
                        points: 500,
                        coins: 50,
                        endDate: Date().addingTimeInterval(604_800),
                        requirements: ["10/10 recipes"],
                        currentProgress: 1.0,
                        participants: 2_345
                    )
                    challenge.isCompleted = true
                    return challenge
                }(),
                onTap: {}
            )
        }
        .padding()
        .background(MagicalBackground())
    }
}
