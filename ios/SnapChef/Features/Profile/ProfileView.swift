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

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var deviceManager: DeviceManager
    @State private var showingSubscriptionView = false
    @State private var contentVisible = false
    @State private var profileImageScale: CGFloat = 0
    
    var body: some View {
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
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
                .padding(.top, 20)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationBarHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
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
    @State private var showingEditProfile = false
    @State private var customName: String = UserDefaults.standard.string(forKey: "CustomChefName") ?? ""
    @State private var customPhotoData: Data? = UserDefaults.standard.data(forKey: "CustomChefPhoto")
    @EnvironmentObject var appState: AppState
    
    private func calculateStreak() -> Int {
        // Get all recipe creation dates
        let recipeDates = appState.allRecipes.map { $0.createdAt }
        
        // Calculate based on consecutive days with recipes
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var checkDate = today
        
        // Check backwards from today
        while streak < 365 { // Limit check to last 365 days
            let hasRecipeOnDate = recipeDates.contains { date in
                calendar.isDate(date, inSameDayAs: checkDate)
            }
            
            if hasRecipeOnDate {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else if streak > 0 {
                // If we've started counting and there's a gap, stop
                break
            } else {
                // If we haven't found any recipes yet, keep looking back
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
                
                // Stop if we've gone back more than 30 days without finding anything
                if calendar.dateComponents([.day], from: checkDate, to: today).day ?? 0 > 30 {
                    break
                }
            }
        }
        
        return streak
    }
    
    private func calculateUserStatus() -> String {
        let recipeCount = appState.allRecipes.count
        
        if recipeCount >= 50 {
            return "⚡ Master Chef"
        } else if recipeCount >= 20 {
            return "🌟 Pro Chef"
        } else if recipeCount >= 10 {
            return "💫 Rising Star"
        } else if recipeCount >= 5 {
            return "🔥 Home Cook"
        } else {
            return "🌱 Beginner"
        }
    }
    
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
                Button(action: { showingEditProfile = true }) {
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
                                Group {
                                    if let photoData = customPhotoData,
                                       let uiImage = UIImage(data: photoData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 120, height: 120)
                                            .clipShape(Circle())
                                    } else {
                                        Text((customName.isEmpty ? (user?.name ?? "Guest") : customName).prefix(1).uppercased())
                                            .font(.system(size: 48, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                }
                            )
                    }, cornerRadius: 60)
                    .frame(width: 120, height: 120)
                }
                .buttonStyle(PlainButtonStyle())
                
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
                Button(action: { showingEditProfile = true }) {
                    Text(customName.isEmpty ? (user?.name ?? "Guest Chef") : customName)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.white, Color.white.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                Text(user?.email ?? "Start your culinary journey")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                // Status pills
                HStack(spacing: 12) {
                    StatusPill(text: "🔥 \(calculateStreak()) day streak", color: Color(hex: "#f093fb"))
                    StatusPill(text: calculateUserStatus(), color: Color(hex: "#4facfe"))
                }
                
                // Food Preferences Card
                FoodPreferencesCard()
                    .padding(.top, 16)
            }
        }
        .padding(.top, 40)
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView(
                customName: $customName,
                customPhotoData: $customPhotoData
            )
        }
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
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var deviceManager: DeviceManager
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
                    title: "Your Recipes",
                    value: animateValues ? appState.allRecipes.count : 0,
                    icon: "sparkles",
                    color: Color(hex: "#667eea"),
                    suffix: ""
                )
                
                AnimatedStatCard(
                    title: "Snaps Taken",
                    value: animateValues ? appState.totalSnapsTaken : 0,
                    icon: "camera.fill",
                    color: Color(hex: "#f093fb"),
                    suffix: ""
                )
                
                AnimatedStatCard(
                    title: "Favorites",
                    value: animateValues ? appState.favoritedRecipeIds.count : 0,
                    icon: "heart.fill",
                    color: Color(hex: "#4facfe"),
                    suffix: ""
                )
                
                AnimatedStatCard(
                    title: "Days Active",
                    value: animateValues ? Calendar.current.dateComponents([.day], from: appState.userJoinDate, to: Date()).day ?? 0 : 0,
                    icon: "flame.fill",
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
                    }
                }
                .padding(24)
                .overlay(
                    tier != .premium ? 
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
                    : nil
                )
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
    @EnvironmentObject var appState: AppState
    @State private var isExpanded = true
    
    var body: some View {
        GlassmorphicCard(content: {
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Social")
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
                        SocialStatRow(icon: "person.2.fill", label: "Followers", value: "0")
                        SocialStatRow(icon: "heart.fill", label: "Likes received", value: "\(appState.totalLikes)")
                        SocialStatRow(icon: "bubble.left.fill", label: "Comments", value: "0")
                        SocialStatRow(icon: "link", label: "Recipe shares", value: "\(appState.totalShares)")
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
        ("sparkles", "AI Preferences", Color(hex: "#667eea"))
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

// MARK: - Edit Profile View
struct EditProfileView: View {
    @Binding var customName: String
    @Binding var customPhotoData: Data?
    @Environment(\.dismiss) var dismiss
    
    @State private var tempName: String = ""
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    
    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Profile Photo
                    Button(action: { showingImagePicker = true }) {
                        ZStack {
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
                                .frame(width: 150, height: 150)
                            
                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 150, height: 150)
                                    .clipShape(Circle())
                            } else if let photoData = customPhotoData,
                                      let uiImage = UIImage(data: photoData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 150, height: 150)
                                    .clipShape(Circle())
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                    Text("Add Photo")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                            
                            // Edit overlay
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Circle()
                                        .fill(Color(hex: "#43e97b"))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Image(systemName: "pencil")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                        .offset(x: -10, y: -10)
                                }
                            }
                            .frame(width: 150, height: 150)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Name Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Chef Name")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        TextField("Enter your chef name", text: $tempName)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                    }
                    .padding(.horizontal, 30)
                    
                    // Additional Options
                    VStack(spacing: 20) {
                        NavigationLink(destination: FoodPreferencesView()) {
                            ProfileOptionRow(
                                icon: "fork.knife",
                                title: "Your Food Types",
                                subtitle: "Update cuisine preferences"
                            )
                        }
                        
                        NavigationLink(destination: NotificationSettingsView()) {
                            ProfileOptionRow(
                                icon: "bell",
                                title: "Notifications",
                                subtitle: "Manage alerts & reminders"
                            )
                        }
                        
                        NavigationLink(destination: PrivacySettingsView()) {
                            ProfileOptionRow(
                                icon: "lock.shield",
                                title: "Privacy",
                                subtitle: "Control your data"
                            )
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 20)
                    
                    Spacer()
                }
                .padding(.top, 30)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // Save the changes
                        customName = tempName
                        if let image = selectedImage {
                            customPhotoData = image.jpegData(compressionQuality: 0.8)
                        }
                        
                        // Persist to UserDefaults
                        UserDefaults.standard.set(customName, forKey: "CustomChefName")
                        if let photoData = customPhotoData {
                            UserDefaults.standard.set(photoData, forKey: "CustomChefPhoto")
                        }
                        
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "#43e97b"))
                }
            }
        }
        .onAppear {
            tempName = customName
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
    }
}

// MARK: - Profile Option Row
struct ProfileOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(Color(hex: "#667eea"))
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Notification Settings View
struct NotificationSettingsView: View {
    @State private var dailyReminders = true
    @State private var challengeAlerts = true
    @State private var recipeRecommendations = false
    @State private var socialUpdates = true
    
    var body: some View {
        ZStack {
            MagicalBackground()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    NeumorphicToggle(isOn: $dailyReminders, label: "Daily Cooking Reminders")
                    NeumorphicToggle(isOn: $challengeAlerts, label: "Challenge Notifications")
                    NeumorphicToggle(isOn: $recipeRecommendations, label: "Recipe Recommendations")
                    NeumorphicToggle(isOn: $socialUpdates, label: "Social Updates")
                }
                .padding(20)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Privacy Settings View
struct PrivacySettingsView: View {
    @State private var shareAnalytics = true
    @State private var personalizedAds = false
    @State private var publicProfile = true
    
    var body: some View {
        ZStack {
            MagicalBackground()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    NeumorphicToggle(isOn: $shareAnalytics, label: "Share Analytics")
                    NeumorphicToggle(isOn: $personalizedAds, label: "Personalized Recommendations")
                    NeumorphicToggle(isOn: $publicProfile, label: "Public Profile")
                    
                    // Delete Account Button
                    Button(action: {
                        // Show delete account confirmation
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .font(.system(size: 18, weight: .medium))
                            Text("Delete Account")
                                .font(.system(size: 18, weight: .medium))
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.red.opacity(0.5), lineWidth: 1)
                        )
                    }
                    .padding(.top, 40)
                }
                .padding(20)
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Food Preferences Card
struct FoodPreferencesCard: View {
    @State private var selectedPreferences: [String] = UserDefaults.standard.stringArray(forKey: "SelectedFoodPreferences") ?? []
    @State private var showingPreferencesView = false
    @State private var isAnimating = false
    
    var body: some View {
        Button(action: {
            showingPreferencesView = true
        }) {
            HStack(spacing: 16) {
                // Animated food icon
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "#667eea").opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 60, height: 60)
                        .scaleEffect(isAnimating ? 1.2 : 1)
                    
                    Text("🍽")
                        .font(.system(size: 36))
                        .scaleEffect(isAnimating ? 1.1 : 1)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Food Type Choices")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#667eea"),
                                    Color(hex: "#764ba2")
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    if selectedPreferences.isEmpty {
                        Text("Tap to select your favorites!")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    } else {
                        Text("\(selectedPreferences.count) cuisines selected")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(hex: "#667eea"))
                    .offset(x: isAnimating ? 5 : 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#667eea").opacity(0.5),
                                        Color(hex: "#764ba2").opacity(0.5)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
            )
            .shadow(
                color: Color(hex: "#667eea").opacity(0.3),
                radius: isAnimating ? 20 : 10,
                y: isAnimating ? 10 : 5
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
        .fullScreenCover(isPresented: $showingPreferencesView) {
            FoodPreferencesView()
                .onDisappear {
                    // Refresh preferences after dismissal
                    selectedPreferences = UserDefaults.standard.stringArray(forKey: "SelectedFoodPreferences") ?? []
                }
        }
    }
}

#Preview {
    ZStack {
        MagicalBackground()
            .ignoresSafeArea()
        
        ProfileView()
            .environmentObject(AppState())
            .environmentObject(AuthenticationManager())
            .environmentObject(DeviceManager())
    }
}