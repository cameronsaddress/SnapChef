import SwiftUI
import StoreKit
import Combine

@MainActor
class PremiumChallengeManager: ObservableObject {
    static let shared = PremiumChallengeManager()

    @Published var isPremiumUser = false
    @Published var premiumChallenges: [Challenge] = []
    @Published var doubleRewardsActive = false
    @Published var exclusiveBadges: [GameBadge] = []
    @Published var premiumLeaderboardAccess = false

    private let subscriptionManager = SubscriptionManager.shared
    private var cancellables = Set<AnyCancellable>()

    // Premium features
    enum PremiumFeature {
        case exclusiveChallenges
        case doubleRewards
        case premiumBadges
        case priorityLeaderboard
        case unlimitedTeams
        case advancedAnalytics

        var title: String {
            switch self {
            case .exclusiveChallenges: return "Exclusive Challenges"
            case .doubleRewards: return "2x Rewards"
            case .premiumBadges: return "Premium Badges"
            case .priorityLeaderboard: return "Priority Leaderboard"
            case .unlimitedTeams: return "Unlimited Teams"
            case .advancedAnalytics: return "Advanced Analytics"
            }
        }

        var description: String {
            switch self {
            case .exclusiveChallenges: return "Access premium-only cooking challenges"
            case .doubleRewards: return "Earn double coins and XP on all challenges"
            case .premiumBadges: return "Unlock exclusive achievement badges"
            case .priorityLeaderboard: return "Special premium leaderboard placement"
            case .unlimitedTeams: return "Join unlimited team challenges"
            case .advancedAnalytics: return "Deep insights into your cooking journey"
            }
        }

        var icon: String {
            switch self {
            case .exclusiveChallenges: return "star.circle.fill"
            case .doubleRewards: return "multiply.circle.fill"
            case .premiumBadges: return "medal.fill"
            case .priorityLeaderboard: return "crown.fill"
            case .unlimitedTeams: return "person.3.fill"
            case .advancedAnalytics: return "chart.line.uptrend.xyaxis"
            }
        }
    }

    private init() {
        setupSubscriptionObserver()
        loadPremiumContent()
    }

    private func setupSubscriptionObserver() {
        // Observe subscription status changes
        subscriptionManager.$isPremium
            .sink { [weak self] isPremium in
                self?.isPremiumUser = isPremium
                self?.doubleRewardsActive = isPremium
                self?.premiumLeaderboardAccess = isPremium

                if isPremium {
                    self?.unlockPremiumFeatures()
                }
            }
            .store(in: &cancellables)
    }

    private func loadPremiumContent() {
        // Create premium-only challenges
        premiumChallenges = [
            Challenge(
                id: "premium_masterchef",
                title: "MasterChef Challenge",
                description: "Create a restaurant-quality dish using only 5 ingredients",
                type: .special,
                category: "premium",
                difficulty: .expert,
                points: 1_000,
                coins: 500,
                startDate: Date(),
                endDate: Date().addingTimeInterval(7 * 24 * 60 * 60),
                requirements: [
                    "Use exactly 5 ingredients",
                    "Present with professional plating",
                    "Include cooking process photos"
                ],
                currentProgress: 0,
                isCompleted: false,
                isActive: true,
                isJoined: false,
                participants: 0,
                completions: 0,
                imageURL: nil,
                isPremium: true
            ),
            Challenge(
                id: "premium_molecular",
                title: "Molecular Gastronomy",
                description: "Experiment with modern cooking techniques",
                type: .weekly,
                category: "premium",
                difficulty: .expert,
                points: 1_500,
                coins: 750,
                startDate: Date(),
                endDate: Date().addingTimeInterval(7 * 24 * 60 * 60),
                requirements: [
                    "Use at least one molecular technique",
                    "Document the scientific process",
                    "Create something visually stunning"
                ],
                currentProgress: 0,
                isCompleted: false,
                isActive: true,
                isJoined: false,
                participants: 0,
                completions: 0,
                imageURL: nil,
                isPremium: true
            ),
            Challenge(
                id: "premium_fusion",
                title: "Fusion Master",
                description: "Combine two different cuisines in one dish",
                type: .weekly,
                category: "premium",
                difficulty: .hard,
                points: 800,
                coins: 400,
                startDate: Date(),
                endDate: Date().addingTimeInterval(7 * 24 * 60 * 60),
                requirements: [
                    "Blend two distinct culinary traditions",
                    "Create a harmonious flavor profile",
                    "Explain your fusion concept"
                ],
                currentProgress: 0,
                isCompleted: false,
                isActive: true,
                isJoined: false,
                participants: 0,
                completions: 0,
                imageURL: nil,
                isPremium: true
            )
        ]

        // Create exclusive badges
        exclusiveBadges = [
            GameBadge(
                name: "Elite Chef",
                icon: "crown.fill",
                description: "Premium member achievement",
                rarity: .legendary,
                unlockedDate: Date()
            ),
            GameBadge(
                name: "Culinary Innovator",
                icon: "lightbulb.fill",
                description: "Complete 5 premium challenges",
                rarity: .epic,
                unlockedDate: Date()
            ),
            GameBadge(
                name: "Master of Fusion",
                icon: "flame.fill",
                description: "Complete all fusion challenges",
                rarity: .legendary,
                unlockedDate: Date()
            )
        ]
    }

    func unlockPremiumFeatures() {
        // Activate all premium features
        doubleRewardsActive = true
        premiumLeaderboardAccess = true

        // Notify user of unlocked features
        NotificationCenter.default.post(
            name: Notification.Name("PremiumFeaturesUnlocked"),
            object: nil
        )

        // Update badges
        if let eliteBadgeIndex = exclusiveBadges.firstIndex(where: { $0.name == "Elite Chef" }) {
            // Badge is already created with current date
        }
    }

    func applyDoubleRewards(basePoints: Int, baseCoins: Int) -> (points: Int, coins: Int) {
        if doubleRewardsActive {
            return (points: basePoints * 2, coins: baseCoins * 2)
        }
        return (points: basePoints, coins: baseCoins)
    }

    func canAccessPremiumChallenge(_ challengeId: String) -> Bool {
        return isPremiumUser || !premiumChallenges.contains(where: { $0.id == challengeId })
    }

    func getPremiumChallengeCount() -> Int {
        return premiumChallenges.filter { $0.isActive }.count
    }

    func updatePremiumChallengeProgress(challengeId: String, progress: Double) {
        guard isPremiumUser else { return }

        if let index = premiumChallenges.firstIndex(where: { $0.id == challengeId }) {
            premiumChallenges[index].currentProgress = progress

            if progress >= 1.0 {
                premiumChallenges[index].isCompleted = true
                awardPremiumBadgeProgress()
            }
        }
    }

    private func awardPremiumBadgeProgress() {
        let completedCount = premiumChallenges.filter { $0.isCompleted }.count

        // Update innovator badge progress
        if completedCount >= 5 {
            if !exclusiveBadges.contains(where: { $0.name == "Culinary Innovator" }) {
                let innovatorBadge = GameBadge(
                    name: "Culinary Innovator",
                    icon: "lightbulb.fill",
                    description: "Complete 5 premium challenges",
                    rarity: .epic,
                    unlockedDate: Date()
                )
                exclusiveBadges.append(innovatorBadge)
            }
        }

        // Check fusion master badge
        let fusionCompleted = premiumChallenges.filter {
            $0.title.contains("Fusion") && $0.isCompleted
        }.count

        if fusionCompleted > 0 {
            if !exclusiveBadges.contains(where: { $0.name == "Master of Fusion" }) {
                let fusionBadge = GameBadge(
                    name: "Master of Fusion",
                    icon: "flame.fill",
                    description: "Complete all fusion challenges",
                    rarity: .legendary,
                    unlockedDate: Date()
                )
                exclusiveBadges.append(fusionBadge)
            }
        }
    }
}

// MARK: - Premium Challenge Card View
struct PremiumChallengeCard: View {
    let challenge: Challenge
    let isLocked: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Premium Badge
                HStack {
                    Label("PREMIUM", systemImage: "crown.fill")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color(hex: "#FFD700"))
                        )

                    Spacer()

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                // Challenge Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(challenge.title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text(challenge.description)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)

                    // Rewards with 2x indicator
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("\(challenge.points)")
                                .fontWeight(.semibold)
                            Text("×2")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "#FFD700"))
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "bitcoinsign.circle.fill")
                                .foregroundColor(Color(hex: "#FFD700"))
                            Text("\(challenge.coins)")
                                .fontWeight(.semibold)
                            Text("×2")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "#FFD700"))
                        }

                        Spacer()

                        // Difficulty
                        Text(challenge.difficulty.label.uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(challenge.difficulty.color.opacity(0.3))
                                    .overlay(
                                        Capsule()
                                            .stroke(challenge.difficulty.color, lineWidth: 1)
                                    )
                            )
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#FFD700").opacity(0.3),
                                Color(hex: "#FFD700").opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#FFD700"),
                                        Color(hex: "#FFA500")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
            )
            .overlay(
                isLocked ?
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.5))
                : nil
            )
        }
        .scaleEffect(isLocked ? 1.0 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isLocked)
    }
}

// MARK: - Premium Features View
struct PremiumFeaturesView: View {
    @StateObject private var premiumManager = PremiumChallengeManager.shared
    @State private var showingSubscriptionView = false

    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 60))
                                .foregroundColor(Color(hex: "#FFD700"))

                            Text("SnapChef Premium")
                                .font(.largeTitle)
                                .fontWeight(.bold)

                            Text("Unlock exclusive challenges and double your rewards")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)

                        // Features List
                        VStack(spacing: 16) {
                            ForEach([
                                PremiumChallengeManager.PremiumFeature.exclusiveChallenges,
                                .doubleRewards,
                                .premiumBadges,
                                .priorityLeaderboard,
                                .unlimitedTeams,
                                .advancedAnalytics
                            ], id: \.title) { feature in
                                PremiumFeatureRow(feature: feature)
                            }
                        }
                        .padding(.horizontal)

                        // Subscribe Button
                        if !premiumManager.isPremiumUser {
                            Button(action: { showingSubscriptionView = true }) {
                                HStack {
                                    Text("Upgrade to Premium")
                                        .fontWeight(.semibold)
                                    Image(systemName: "arrow.right")
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "#FFD700"))
                                )
                            }
                            .padding(.horizontal)
                            .padding(.top, 20)
                        } else {
                            // Premium Status
                            VStack(spacing: 8) {
                                Label("Premium Active", systemImage: "checkmark.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(Color(hex: "#FFD700"))

                                Text("Enjoying all premium benefits")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: "#FFD700").opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(hex: "#FFD700"), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal)
                            .padding(.top, 20)
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingSubscriptionView) {
            SubscriptionView()
        }
    }
}

struct PremiumFeatureRow: View {
    let feature: PremiumChallengeManager.PremiumFeature

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: feature.icon)
                .font(.title2)
                .foregroundColor(Color(hex: "#FFD700"))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(feature.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}
