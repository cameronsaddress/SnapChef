import SwiftUI

enum SubscriptionTier: String, CaseIterable {
    case free = "Free"
    case basic = "Basic"
    case premium = "Premium"
    
    var price: String {
        switch self {
        case .free: return "Free"
        case .basic: return "$4.99/mo"
        case .premium: return "$9.99/mo"
        }
    }
    
    var features: [String] {
        switch self {
        case .free: return ["1 meal per day", "Basic recipes", "Standard support"]
        case .basic: return ["2 meals per day", "Enhanced recipes", "Priority support"]
        case .premium: return ["Unlimited meals", "Exclusive recipes", "24/7 support", "AI nutritionist"]
        }
    }
    
    var displayName: String {
        return self.rawValue
    }
}

struct EnhancedProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var deviceManager: DeviceManager
    @State private var showingSubscriptionView = false
    @State private var contentVisible = false
    @State private var profileImageScale: CGFloat = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Full screen animated background
                MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                VStack(spacing: 30) {
                    // Enhanced Profile Header
                    EnhancedProfileHeader(user: authManager.currentUser)
                        .scaleEffect(profileImageScale)
                        .scaleEffect(profileImageScale)
                    
                    // Gamification Stats
                    GamificationStatsView()
                        .staggeredFade(index: 0, isShowing: contentVisible)
                    
                    // Achievement Gallery
                    AchievementGalleryView()
                        .staggeredFade(index: 1, isShowing: contentVisible)
                    
                    // Subscription Status Enhanced
                    EnhancedSubscriptionCard(
                        tier: deviceManager.hasUnlimitedAccess ? .premium : .free,
                        onUpgrade: {
                            showingSubscriptionView = true
                        }
                    )
                    .staggeredFade(index: 2, isShowing: contentVisible)
                    
                    // Social Stats
                    SocialStatsCard()
                        .staggeredFade(index: 3, isShowing: contentVisible)
                    
                    // Settings Section Enhanced
                    EnhancedSettingsSection()
                        .staggeredFade(index: 4, isShowing: contentVisible)
                    
                    // Sign Out Button Enhanced
                    EnhancedSignOutButton {
                        authManager.signOut()
                    }
                    .staggeredFade(index: 5, isShowing: contentVisible)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
                .padding(.top, 20)
            }
            .scrollContentBackground(.hidden)
            }
            .navigationBarHidden(true)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                profileImageScale = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                contentVisible = true
            }
        }
        .sheet(isPresented: $showingSubscriptionView) {
            SubscriptionView()
        }
    }
}

// MARK: - Enhanced Profile Header
struct EnhancedProfileHeader: View {
    let user: User?
    @State private var glowAnimation = false
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                // Animated glow ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "#667eea").opacity(0.6),
                                Color(hex: "#764ba2").opacity(0.4),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(rotationAngle))
                    .scaleEffect(glowAnimation ? 1.1 : 1)
                    .opacity(glowAnimation ? 0.8 : 1)
                
                // Profile container
                GlassmorphicCard(content: {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#667eea"),
                                    Color(hex: "#764ba2")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .overlay(
                            Text((user?.name ?? "?").prefix(1).uppercased())
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        )
                }, cornerRadius: 60)
                .frame(width: 120, height: 120)
                
                // Level badge
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        LevelBadge(level: 12)
                            .offset(x: -10, y: -10)
                    }
                }
                .frame(width: 120, height: 120)
            }
            
            // User info with gradient text
            VStack(spacing: 8) {
                Text(user?.name ?? "Guest Chef")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white, Color.white.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                Text(user?.email ?? "Start your culinary journey")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                // Status pills
                HStack(spacing: 12) {
                    StatusPill(text: "🔥 7 day streak", color: Color(hex: "#f093fb"))
                    StatusPill(text: "⚡ Power user", color: Color(hex: "#4facfe"))
                }
            }
        }
        .padding(.top, 40)
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowAnimation = true
            }
        }
    }
}

// MARK: - Level Badge
struct LevelBadge: View {
    let level: Int
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#43e97b"),
                            Color(hex: "#38f9d7")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)
                .shadow(color: Color(hex: "#43e97b").opacity(0.5), radius: 8)
            
            Text("\(level)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Status Pill
struct StatusPill: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color.opacity(0.3))
                    .overlay(
                        Capsule()
                            .stroke(color.opacity(0.5), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Gamification Stats
struct GamificationStatsView: View {
    @State private var animateValues = false
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Your Epic Stats")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("🏆")
                    .font(.system(size: 24))
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                AnimatedStatCard(
                    title: "Recipes Made",
                    value: animateValues ? 247 : 0,
                    icon: "sparkles",
                    color: Color(hex: "#667eea"),
                    suffix: ""
                )
                
                AnimatedStatCard(
                    title: "Lives Changed",
                    value: animateValues ? 1893 : 0,
                    icon: "heart.fill",
                    color: Color(hex: "#f093fb"),
                    suffix: "+"
                )
                
                AnimatedStatCard(
                    title: "Time Saved",
                    value: animateValues ? 156 : 0,
                    icon: "clock.fill",
                    color: Color(hex: "#4facfe"),
                    suffix: "hrs"
                )
                
                AnimatedStatCard(
                    title: "XP Earned",
                    value: animateValues ? 12500 : 0,
                    icon: "star.fill",
                    color: Color(hex: "#43e97b"),
                    suffix: ""
                )
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
                animateValues = true
            }
        }
    }
}

// MARK: - Animated Stat Card
struct AnimatedStatCard: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color
    let suffix: String
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {}) {
            GlassmorphicCard(content: {
                VStack(spacing: 12) {
                    // Icon with glow
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .blur(radius: 10)
                        
                        Image(systemName: icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(color)
                    }
                    
                    // Animated counter
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(value)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                        
                        Text(suffix)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
            }, glowColor: color)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Achievement Gallery
struct AchievementGalleryView: View {
    let achievements = [
        ("🎯", "First Recipe", true),
        ("🔥", "Week Streak", true),
        ("🌟", "Viral Chef", false),
        ("👨‍🍳", "Master Chef", false),
        ("🚀", "Speed Demon", true),
        ("💎", "Premium Member", false)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Achievements")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(0..<achievements.count, id: \.self) { index in
                    AchievementBadge(
                        emoji: achievements[index].0,
                        title: achievements[index].1,
                        unlocked: achievements[index].2
                    )
                }
            }
        }
    }
}

struct AchievementBadge: View {
    let emoji: String
    let title: String
    let unlocked: Bool
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        unlocked
                            ? LinearGradient(
                                colors: [
                                    Color(hex: "#667eea").opacity(0.3),
                                    Color(hex: "#764ba2").opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(
                                unlocked
                                    ? Color(hex: "#667eea").opacity(0.5)
                                    : Color.white.opacity(0.2),
                                lineWidth: 2
                            )
                    )
                
                Text(unlocked ? emoji : "🔒")
                    .font(.system(size: 30))
                    .scaleEffect(isAnimating && unlocked ? 1.2 : 1)
                    .opacity(unlocked ? 1 : 0.5)
            }
            
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(unlocked ? 0.9 : 0.5))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .onAppear {
            if unlocked {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
    }
}

// MARK: - Enhanced Subscription Card
struct EnhancedSubscriptionCard: View {
    let tier: SubscriptionTier
    let onUpgrade: () -> Void
    
    @State private var shimmerPhase: CGFloat = -1
    @State private var particleTrigger = false
    
    var body: some View {
        Button(action: {
            if tier != .premium {
                particleTrigger = true
                onUpgrade()
            }
        }) {
            GlassmorphicCard(content: {
                VStack(spacing: 20) {
                    // Header with animated badge
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text("Your Plan")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                if tier == .premium {
                                    PremiumBadge()
                                }
                            }
                            
                            Text(tier.displayName)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    tier == .premium
                                        ? LinearGradient(
                                            colors: [
                                                Color(hex: "#43e97b"),
                                                Color(hex: "#38f9d7")
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                        : LinearGradient(
                                            colors: [Color.white],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                )
                        }
                        
                        Spacer()
                        
                        // Animated icon
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            tier == .premium ? Color(hex: "#43e97b").opacity(0.3) : Color(hex: "#f093fb").opacity(0.3),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 40
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: tier == .premium ? "crown.fill" : "sparkles")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(tier == .premium ? Color(hex: "#43e97b") : Color(hex: "#f093fb"))
                                .rotationEffect(.degrees(tier == .premium ? 0 : 15))
                        }
                    }
                    
                    // Benefits or upgrade prompt
                    if tier == .premium {
                        UnlimitedBenefits()
                    } else {
                        UpgradePrompt()
                            .overlay(
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        Color.white.opacity(0.4),
                                        Color.clear
                                    ],
                                    startPoint: UnitPoint(x: shimmerPhase - 0.3, y: 0),
                                    endPoint: UnitPoint(x: shimmerPhase + 0.3, y: 1)
                                )
                                .allowsHitTesting(false)
                            )
                    }
                }
                .padding(24)
            }, glowColor: tier == .premium ? Color(hex: "#43e97b") : Color(hex: "#f093fb"))
        }
        .buttonStyle(PlainButtonStyle())
        .particleExplosion(trigger: $particleTrigger)
        .onAppear {
            if tier != .premium {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    shimmerPhase = 2
                }
            }
        }
    }
}

struct PremiumBadge: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 10, weight: .bold))
            Text("PREMIUM")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#43e97b"),
                            Color(hex: "#38f9d7")
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .scaleEffect(isAnimating ? 1.05 : 1)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

struct UnlimitedBenefits: View {
    let benefits = [
        "Unlimited recipe generation",
        "Advanced AI suggestions",
        "Priority support",
        "Exclusive challenges"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(benefits, id: \.self) { benefit in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#43e97b"))
                    
                    Text(benefit)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                }
            }
        }
    }
}

struct UpgradePrompt: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Unlock unlimited magic ✨")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                Text("Upgrade Now")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(Color(hex: "#f093fb"))
        }
    }
}

// MARK: - Social Stats Card
struct SocialStatsCard: View {
    @State private var isExpanded = false
    
    var body: some View {
        GlassmorphicCard(content: {
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Social Impact")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("You're inspiring thousands!")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                
                if isExpanded {
                    VStack(spacing: 16) {
                        SocialStatRow(icon: "person.2.fill", label: "Followers", value: "2.3K")
                        SocialStatRow(icon: "heart.fill", label: "Likes received", value: "45.6K")
                        SocialStatRow(icon: "bubble.left.fill", label: "Comments", value: "892")
                        SocialStatRow(icon: "link", label: "Recipe shares", value: "1.2K")
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
                }
            }
            .padding(24)
        }, glowColor: Color(hex: "#4facfe"))
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }
    }
}

struct SocialStatRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#4facfe"))
                .frame(width: 24)
            
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Enhanced Settings Section
struct EnhancedSettingsSection: View {
    let settings = [
        ("bell.badge.fill", "Smart Notifications", Color(hex: "#ffa726")),
        ("leaf.fill", "Dietary Magic", Color(hex: "#43e97b")),
        ("sparkles", "AI Preferences", Color(hex: "#667eea")),
        ("shield.lefthalf.filled", "Privacy Vault", Color(hex: "#764ba2"))
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<settings.count, id: \.self) { index in
                EnhancedSettingsRow(
                    icon: settings[index].0,
                    title: settings[index].1,
                    color: settings[index].2
                )
            }
        }
    }
}

struct EnhancedSettingsRow: View {
    let icon: String
    let title: String
    let color: Color
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {}) {
            GlassmorphicCard(content: {
                HStack(spacing: 16) {
                    // Animated icon
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.2))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(color)
                            .scaleEffect(isPressed ? 1.2 : 1)
                    }
                    
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }, glowColor: color)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
            if pressing {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        }, perform: {})
    }
}

// MARK: - Enhanced Sign Out Button
struct EnhancedSignOutButton: View {
    let action: () -> Void
    @State private var showConfirmation = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            showConfirmation = true
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        }) {
            GlassmorphicCard(content: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.left.square.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: "#ef5350"))
                    
                    Text("Sign Out")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }, glowColor: Color(hex: "#ef5350"))
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .alert("Sign Out?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive, action: action)
        } message: {
            Text("You'll need to sign in again to access your recipes and progress.")
        }
    }
}

#Preview {
    ZStack {
        MagicalBackground()
            .ignoresSafeArea()
        
        EnhancedProfileView()
            .environmentObject(AppState())
            .environmentObject(AuthenticationManager())
            .environmentObject(DeviceManager())
    }
}