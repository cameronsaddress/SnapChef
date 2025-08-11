import SwiftUI
import CloudKit

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
    @ObservedObject var cloudKitAuthManager = CloudKitAuthManager.shared
    @EnvironmentObject var gamificationManager: GamificationManager
    @State private var showingSubscriptionView = false
    @State private var showingRecipes = false
    @State private var showingFavorites = false
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
                    
                    // Gamification Stats
                    GamificationStatsView()
                        .staggeredFade(index: 0, isShowing: contentVisible)
                    
                    // Streak Summary
                    StreakSummaryCard()
                        .staggeredFade(index: 1, isShowing: contentVisible)
                    
                    // Collection Progress
                    CollectionProgressView()
                        .staggeredFade(index: 2, isShowing: contentVisible)
                    
                    // Active Challenges
                    ActiveChallengesSection()
                        .staggeredFade(index: 3, isShowing: contentVisible)
                    
                    // Achievement Gallery
                    ProfileAchievementGalleryView()
                        .staggeredFade(index: 4, isShowing: contentVisible)
                    
                    // Subscription Status Enhanced
                    EnhancedSubscriptionCard(
                        tier: deviceManager.hasUnlimitedAccess ? .premium : .free,
                        onUpgrade: {
                            showingSubscriptionView = true
                        }
                    )
                    .staggeredFade(index: 5, isShowing: contentVisible)
                    
                    // Settings Section Enhanced
                    EnhancedSettingsSection()
                        .staggeredFade(index: 6, isShowing: contentVisible)
                    
                    // Sign Out Button (only if authenticated)
                    if cloudKitAuthManager.isAuthenticated {
                        EnhancedSignOutButton(action: {
                            cloudKitAuthManager.signOut()
                        })
                        .staggeredFade(index: 7, isShowing: contentVisible)
                        .padding(.top, 20)
                    }
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
        .sheet(isPresented: $showingRecipes) {
            NavigationStack {
                RecipesView()
                    .navigationTitle("Your Recipes")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarItems(trailing: Button("Done") {
                        showingRecipes = false
                    })
            }
        }
        .sheet(isPresented: $showingFavorites) {
            NavigationStack {
                FavoritesView()
                    .navigationTitle("Favorites")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarItems(trailing: Button("Done") {
                        showingFavorites = false
                    })
            }
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
    @State private var customPhotoData: Data? = ProfilePhotoHelper.loadCustomPhotoFromFile()
    @ObservedObject var cloudKitAuthManager = CloudKitAuthManager.shared
    @StateObject private var cloudKitRecipeManager = CloudKitRecipeManager.shared
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var gamificationManager: GamificationManager
    @EnvironmentObject var authManager: AuthenticationManager
    
    // Computed properties for display
    private var displayName: String {
        // Priority: Auth username > CloudKit username > Custom name > User name > Guest
        if let authUser = authManager.currentUser {
            return authUser.username
        } else if let cloudKitUser = cloudKitAuthManager.currentUser {
            // Prefer username if set, otherwise use display name
            if let username = cloudKitUser.username, !username.isEmpty {
                return username
            } else {
                return cloudKitUser.displayName
            }
        } else if !customName.isEmpty {
            return customName
        } else if let userName = user?.name {
            return userName
        } else {
            return authManager.temporaryUsername
        }
    }
    
    private var profileInitial: String {
        displayName.prefix(1).uppercased()
    }
    
    private var emailDisplay: String {
        if let cloudKitUser = cloudKitAuthManager.currentUser {
            return cloudKitUser.email ?? "Start your culinary journey"
        } else if let userEmail = user?.email {
            return userEmail
        } else {
            return "Start your culinary journey"
        }
    }
    
    private var currentStreak: Int {
        // Use CloudKit streak if available, otherwise calculate from local data
        if let cloudKitUser = cloudKitAuthManager.currentUser {
            return cloudKitUser.currentStreak
        } else {
            return calculateStreak()
        }
    }
    
    private func calculateLevel() -> Int {
        // Calculate level from total points
        if let cloudKitUser = cloudKitAuthManager.currentUser {
            let points = cloudKitUser.totalPoints
            return min(1 + (points / 1000), 99) // Level up every 1000 points, max level 99
        } else {
            // Fallback to recipe count based level
            let recipeCount = appState.allRecipes.count
            return min(1 + (recipeCount / 5), 20) // Level up every 5 recipes for non-authenticated users
        }
    }
    
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
        // Status based on level (which is based on points for authenticated users)
        let level = calculateLevel()
        
        if level >= 50 {
            return "⚡ Master Chef"
        } else if level >= 20 {
            return "🌟 Pro Chef"
        } else if level >= 10 {
            return "💫 Rising Star"
        } else if level >= 5 {
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
                                    if let profileImage = authManager.profileImage {
                                        Image(uiImage: profileImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 120, height: 120)
                                            .clipShape(Circle())
                                    } else if let photoData = customPhotoData,
                                       let uiImage = UIImage(data: photoData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 120, height: 120)
                                            .clipShape(Circle())
                                    } else {
                                        Text(displayName.prefix(1).uppercased())
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
                    Text(displayName)
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
                
                Text(emailDisplay)
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
    @StateObject private var cloudKitRecipeManager = CloudKitRecipeManager.shared
    @State private var animateValues = false
    @State private var showingRecipes = false
    @State private var showingFavorites = false
    
    private func getTotalRecipeCount() -> Int {
        // Combine local recipes with CloudKit recipes
        let localRecipeCount = appState.allRecipes.count
        let cloudKitSavedCount = cloudKitRecipeManager.userSavedRecipeIDs.count
        let cloudKitCreatedCount = cloudKitRecipeManager.userCreatedRecipeIDs.count
        
        // Return the sum of local and CloudKit recipes
        // Note: CloudKit includes both saved and created recipes
        return localRecipeCount + cloudKitSavedCount + cloudKitCreatedCount
    }
    
    private func getTotalFavoritesCount() -> Int {
        // Combine local favorites with CloudKit favorites
        let localFavoritesCount = appState.favoritedRecipeIds.count
        let cloudKitFavoritesCount = cloudKitRecipeManager.userFavoritedRecipeIDs.count
        
        // Return the max to avoid duplicates (CloudKit likely includes all favorites)
        return max(localFavoritesCount, cloudKitFavoritesCount)
    }
    
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
                    value: animateValues ? getTotalRecipeCount() : 0,
                    icon: "sparkles",
                    color: Color(hex: "#667eea"),
                    suffix: "",
                    action: {
                        showingRecipes = true
                    }
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
                    value: animateValues ? getTotalFavoritesCount() : 0,
                    icon: "heart.fill",
                    color: Color(hex: "#4facfe"),
                    suffix: "",
                    action: {
                        showingFavorites = true
                    }
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
            // Load CloudKit recipe references to ensure counts are accurate
            cloudKitRecipeManager.loadUserRecipeReferences()
        }
        .sheet(isPresented: $showingRecipes) {
            NavigationStack {
                RecipesView()
                    .navigationTitle("Your Recipes")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarItems(trailing: Button("Done") {
                        showingRecipes = false
                    })
            }
        }
        .sheet(isPresented: $showingFavorites) {
            NavigationStack {
                FavoritesView()
                    .navigationTitle("Favorites")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarItems(trailing: Button("Done") {
                        showingFavorites = false
                    })
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
    var action: (() -> Void)? = nil
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: { action?() }) {
            GlassmorphicCard(content: {
                VStack(spacing: 8) {
                    // Icon with glow - made smaller
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.2))
                            .frame(width: 36, height: 36)
                            .blur(radius: 8)
                        
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(color)
                    }
                    
                    // Animated counter - made smaller
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(value)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                        
                        Text(suffix)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 16)
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
                HStack(spacing: 16) {
                    // Compact left side
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Plan")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        
                        HStack(spacing: 6) {
                            Text(tier.displayName)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
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
                            
                            if tier == .premium {
                                PremiumBadge()
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Compact upgrade prompt or benefits
                    if tier == .premium {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#43e97b"))
                            Text("Unlimited access")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    } else {
                        HStack(spacing: 6) {
                            Text("Unlock magic")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "#f093fb"))
                        }
                    }
                    
                    // Smaller icon
                    ZStack {
                        Circle()
                            .fill(
                                tier == .premium ? Color(hex: "#43e97b").opacity(0.2) : Color(hex: "#f093fb").opacity(0.2)
                            )
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: tier == .premium ? "crown.fill" : "sparkles")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(tier == .premium ? Color(hex: "#43e97b") : Color(hex: "#f093fb"))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
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


// MARK: - Enhanced Settings Section
struct EnhancedSettingsSection: View {
    @State private var showingAISettings = false
    
    let settings = [
        ("sparkles", "AI Preferences", Color(hex: "#667eea"))
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<settings.count, id: \.self) { index in
                EnhancedSettingsRow(
                    icon: settings[index].0,
                    title: settings[index].1,
                    color: settings[index].2,
                    action: {
                        if index == 0 {
                            showingAISettings = true
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingAISettings) {
            AISettingsView()
        }
    }
}

struct EnhancedSettingsRow: View {
    let icon: String
    let title: String
    let color: Color
    var action: (() -> Void)? = nil
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: { action?() }) {
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
                            // Save photo to file system instead of UserDefaults
                            saveCustomPhotoToFile(photoData)
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
            ProfileImagePicker(selectedImage: $selectedImage)
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
struct ProfileImagePicker: UIViewControllerRepresentable {
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
        let parent: ProfileImagePicker
        
        init(_ parent: ProfileImagePicker) {
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

// MARK: - AI Settings View
struct AISettingsView: View {
    @State private var selectedProvider: String = UserDefaults.standard.string(forKey: "SelectedLLMProvider") ?? "grok"
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // LLM Provider Section
                        VStack(alignment: .leading, spacing: 20) {
                            Text("AI Model Provider")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Choose which AI model to use for recipe generation")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            VStack(spacing: 16) {
                                // Grok Option
                                ProviderOptionCard(
                                    name: "Grok",
                                    description: "Advanced vision AI with culinary expertise",
                                    icon: "brain",
                                    color: Color(hex: "#667eea"),
                                    isSelected: selectedProvider == "grok",
                                    action: {
                                        selectedProvider = "grok"
                                        UserDefaults.standard.set("grok", forKey: "SelectedLLMProvider")
                                    }
                                )
                                
                                // Gemini Option
                                ProviderOptionCard(
                                    name: "Gemini",
                                    description: "Google's multimodal AI for creative recipes",
                                    icon: "sparkles",
                                    color: Color(hex: "#43e97b"),
                                    isSelected: selectedProvider == "gemini",
                                    action: {
                                        selectedProvider = "gemini"
                                        UserDefaults.standard.set("gemini", forKey: "SelectedLLMProvider")
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Performance Note
                        VStack(spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "#4facfe"))
                            
                            Text("Performance may vary between providers. Try both to see which works best for your cooking style!")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 30)
                        .padding(.top, 20)
                    }
                    .padding(.vertical, 30)
                }
            }
            .navigationTitle("AI Preferences")
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
}

// MARK: - Provider Option Card
struct ProviderOptionCard: View {
    let name: String
    let description: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            action()
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }) {
            HStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(color)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(name)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Color(hex: "#43e97b"))
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    
                    Text(description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? color.opacity(0.15) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                isSelected ? color : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Collection Progress View
struct CollectionProgressView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var cloudKitAuthManager = CloudKitAuthManager.shared
    @StateObject private var cloudKitRecipeManager = CloudKitRecipeManager.shared
    @State private var animateProgress = false
    
    var totalRecipes: Int {
        // Use CloudKit recipe counts when available
        if cloudKitAuthManager.isAuthenticated {
            return cloudKitRecipeManager.userCreatedRecipeIDs.count + cloudKitRecipeManager.userSavedRecipeIDs.count
        } else {
            return appState.allRecipes.count
        }
    }
    
    var favoriteRecipes: Int {
        // Use CloudKit favorites when available
        if cloudKitAuthManager.isAuthenticated {
            return cloudKitRecipeManager.userFavoritedRecipeIDs.count
        } else {
            return appState.favoritedRecipeIds.count
        }
    }
    
    var sharedRecipes: Int {
        if let cloudKitUser = cloudKitAuthManager.currentUser {
            return cloudKitUser.recipesShared
        } else {
            return appState.totalShares
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Collection Progress")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("📚")
                    .font(.system(size: 24))
            }
            
            VStack(spacing: 16) {
                CollectionProgressRow(
                    icon: "fork.knife",
                    title: "Recipes Created",
                    value: totalRecipes,
                    maxValue: 100,
                    color: Color(hex: "#667eea"),
                    animate: animateProgress
                )
                
                CollectionProgressRow(
                    icon: "heart.fill",
                    title: "Favorites",
                    value: favoriteRecipes,
                    maxValue: 50,
                    color: Color(hex: "#f093fb"),
                    animate: animateProgress
                )
                
                CollectionProgressRow(
                    icon: "square.and.arrow.up",
                    title: "Shared",
                    value: sharedRecipes,
                    maxValue: 25,
                    color: Color(hex: "#43e97b"),
                    animate: animateProgress
                )
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.5)) {
                animateProgress = true
            }
        }
    }
}

// MARK: - Collection Progress Row
struct CollectionProgressRow: View {
    let icon: String
    let title: String
    let value: Int
    let maxValue: Int
    let color: Color
    let animate: Bool
    
    private var progress: Double {
        min(Double(value) / Double(maxValue), 1.0)
    }
    
    private var percentage: Int {
        Int(progress * 100)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Text("\(value)/\(maxValue)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: animate ? geometry.size.width * progress : 0, height: 8)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: animate)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Achievement Gallery View
struct ProfileAchievementGalleryView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var gamificationManager: GamificationManager
    @ObservedObject var cloudKitAuthManager = CloudKitAuthManager.shared
    @State private var selectedAchievement: ProfileAchievement?
    @State private var cloudKitAchievements: [ProfileAchievement] = []
    
    var achievements: [ProfileAchievement] {
        // Use CloudKit achievements if available, otherwise use defaults
        if !cloudKitAchievements.isEmpty {
            return cloudKitAchievements
        } else {
            return [
                ProfileAchievement(id: "first_recipe", title: "First Recipe", description: "Create your first recipe", icon: "🍳", isUnlocked: false, unlockedDate: nil),
                ProfileAchievement(id: "recipe_explorer", title: "Recipe Explorer", description: "Create 10 recipes", icon: "🧭", isUnlocked: false, unlockedDate: nil),
                ProfileAchievement(id: "master_chef", title: "Master Chef", description: "Create 50 recipes", icon: "👨‍🍳", isUnlocked: false, unlockedDate: nil),
                ProfileAchievement(id: "week_streak", title: "Week Warrior", description: "7 day streak", icon: "🔥", isUnlocked: false, unlockedDate: nil),
                ProfileAchievement(id: "month_streak", title: "Dedicated Chef", description: "30 day streak", icon: "💪", isUnlocked: false, unlockedDate: nil),
                ProfileAchievement(id: "social_butterfly", title: "Social Butterfly", description: "Share 10 recipes", icon: "🦋", isUnlocked: false, unlockedDate: nil)
            ]
        }
    }
    
    private func loadCloudKitAchievements() {
        Task {
            do {
                guard let userID = UserDefaults.standard.string(forKey: "currentUserID") else { return }
                
                let container = CKContainer(identifier: "iCloud.com.snapchefapp.app")
                let privateDB = container.privateCloudDatabase
                
                let predicate = NSPredicate(format: "userID == %@", userID)
                let query = CKQuery(recordType: "Achievement", predicate: predicate)
                
                let (results, _) = try await privateDB.records(matching: query)
                
                var loadedAchievements: [ProfileAchievement] = []
                for (_, result) in results {
                    if let record = try? result.get() {
                        let achievement = ProfileAchievement(
                            id: record["id"] as? String ?? UUID().uuidString,
                            title: record["name"] as? String ?? "Unknown",
                            description: record["description"] as? String ?? "",
                            icon: record["iconName"] as? String ?? "🏆",
                            isUnlocked: true,
                            unlockedDate: record["earnedAt"] as? Date
                        )
                        loadedAchievements.append(achievement)
                    }
                }
                
                await MainActor.run {
                    self.cloudKitAchievements = loadedAchievements
                }
                
                print("✅ Loaded \(loadedAchievements.count) achievements from CloudKit")
            } catch {
                print("❌ Failed to load CloudKit achievements: \(error)")
            }
        }
    }
    
    private func isAchievementUnlocked(_ achievement: ProfileAchievement) -> Bool {
        let recipeCount = cloudKitAuthManager.currentUser?.recipesCreated ?? appState.allRecipes.count
        let sharedCount = cloudKitAuthManager.currentUser?.recipesShared ?? appState.totalShares
        let streak = cloudKitAuthManager.currentUser?.currentStreak ?? 0
        
        switch achievement.id {
        case "first_recipe":
            return recipeCount >= 1
        case "recipe_explorer":
            return recipeCount >= 10
        case "master_chef":
            return recipeCount >= 50
        case "week_streak":
            return streak >= 7
        case "month_streak":
            return streak >= 30
        case "social_butterfly":
            return sharedCount >= 10
        default:
            return false
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Achievements")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("🏆")
                    .font(.system(size: 24))
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(achievements) { achievement in
                    ProfileAchievementBadge(
                        achievement: achievement,
                        isUnlocked: isAchievementUnlocked(achievement)
                    )
                    .onTapGesture {
                        selectedAchievement = achievement
                    }
                }
            }
        }
        .onAppear {
            if cloudKitAuthManager.isAuthenticated {
                loadCloudKitAchievements()
            }
        }
        .sheet(item: $selectedAchievement) { achievement in
            ProfileAchievementDetailView(
                achievement: achievement,
                isUnlocked: isAchievementUnlocked(achievement)
            )
        }
    }
}

// MARK: - Achievement Model
struct ProfileAchievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let isUnlocked: Bool
    let unlockedDate: Date?
}

// MARK: - Achievement Badge
struct ProfileAchievementBadge: View {
    let achievement: ProfileAchievement
    let isUnlocked: Bool
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        isUnlocked
                            ? LinearGradient(
                                colors: [Color(hex: "#43e97b"), Color(hex: "#38f9d7")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(
                                isUnlocked ? Color(hex: "#43e97b") : Color.white.opacity(0.2),
                                lineWidth: 2
                            )
                    )
                    .scaleEffect(isAnimating && isUnlocked ? 1.1 : 1)
                    .shadow(
                        color: isUnlocked ? Color(hex: "#43e97b").opacity(0.5) : Color.clear,
                        radius: isAnimating ? 15 : 5
                    )
                
                Text(achievement.icon)
                    .font(.system(size: 28))
                    .scaleEffect(isUnlocked ? 1 : 0.8)
                    .opacity(isUnlocked ? 1 : 0.5)
            }
            
            Text(achievement.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isUnlocked ? .white : .white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .onAppear {
            if isUnlocked {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
    }
}

// MARK: - Achievement Detail View
struct ProfileAchievementDetailView: View {
    let achievement: ProfileAchievement
    let isUnlocked: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            MagicalBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding()
                
                Spacer()
                
                // Achievement icon
                ZStack {
                    Circle()
                        .fill(
                            isUnlocked
                                ? LinearGradient(
                                    colors: [Color(hex: "#43e97b"), Color(hex: "#38f9d7")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 120, height: 120)
                        .overlay(
                            Circle()
                                .stroke(
                                    isUnlocked ? Color(hex: "#43e97b") : Color.white.opacity(0.2),
                                    lineWidth: 3
                                )
                        )
                    
                    Text(achievement.icon)
                        .font(.system(size: 60))
                        .opacity(isUnlocked ? 1 : 0.5)
                }
                
                // Achievement info
                VStack(spacing: 12) {
                    Text(achievement.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(achievement.description)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                    
                    if isUnlocked {
                        Text("Unlocked! 🎉")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color(hex: "#43e97b"))
                            .padding(.top, 10)
                    } else {
                        Text("Keep cooking to unlock!")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 10)
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
        }
    }
}

// MARK: - Active Challenges Section
struct ActiveChallengesSection: View {
    @StateObject private var gamificationManager = GamificationManager.shared
    @State private var showingChallengeHub = false
    @State private var cloudKitChallenges: [Challenge] = []
    @State private var isLoadingChallenges = false
    
    private var allActiveChallenges: [Challenge] {
        // Combine local and CloudKit challenges
        var combined = gamificationManager.activeChallenges + cloudKitChallenges
        // Remove duplicates by ID
        var seenIds = Set<String>()
        combined = combined.filter { challenge in
            if seenIds.contains(challenge.id) {
                return false
            }
            seenIds.insert(challenge.id)
            return true
        }
        return combined
    }
    
    private func loadCloudKitChallenges() {
        guard !isLoadingChallenges else { return }
        isLoadingChallenges = true
        
        Task {
            do {
                guard let userID = UserDefaults.standard.string(forKey: "currentUserID") else { 
                    await MainActor.run { isLoadingChallenges = false }
                    return 
                }
                
                let container = CKContainer(identifier: "iCloud.com.snapchefapp.app")
                let privateDB = container.privateCloudDatabase
                
                // Fetch user's active challenges
                let predicate = NSPredicate(format: "userID == %@ AND status == %@", userID, "active")
                let query = CKQuery(recordType: "UserChallenge", predicate: predicate)
                
                let (results, _) = try await privateDB.records(matching: query)
                
                var loadedChallenges: [Challenge] = []
                for (_, result) in results {
                    if let record = try? result.get(),
                       let challengeRef = record["challengeID"] as? CKRecord.Reference {
                        // Fetch the actual challenge details
                        let challengeRecord = try await container.publicCloudDatabase.record(for: challengeRef.recordID)
                        
                        // Create Challenge object from CloudKit record
                        let challenge = Challenge(
                            id: challengeRecord["id"] as? String ?? UUID().uuidString,
                            title: challengeRecord["title"] as? String ?? "Unknown Challenge",
                            description: challengeRecord["description"] as? String ?? "",
                            type: ChallengeType(rawValue: challengeRecord["type"] as? String ?? "Daily Challenge") ?? .daily,
                            category: challengeRecord["category"] as? String ?? "general",
                            difficulty: DifficultyLevel(rawValue: challengeRecord["difficulty"] as? Int ?? 1) ?? .easy,
                            points: challengeRecord["points"] as? Int ?? 0,
                            coins: challengeRecord["coins"] as? Int ?? 0,
                            startDate: challengeRecord["startDate"] as? Date ?? Date(),
                            endDate: challengeRecord["endDate"] as? Date ?? Date(),
                            requirements: [],
                            currentProgress: 0,
                            isCompleted: false,
                            isActive: true,
                            isJoined: true, // User has joined if it's in their UserChallenge records
                            participants: challengeRecord["participantCount"] as? Int ?? 0,
                            completions: challengeRecord["completionCount"] as? Int ?? 0,
                            imageURL: challengeRecord["imageURL"] as? String,
                            isPremium: challengeRecord["isPremium"] as? Bool ?? false
                        )
                        loadedChallenges.append(challenge)
                    }
                }
                
                await MainActor.run {
                    self.cloudKitChallenges = loadedChallenges
                    self.isLoadingChallenges = false
                }
                
                print("✅ Loaded \(loadedChallenges.count) active challenges from CloudKit")
            } catch {
                print("❌ Failed to load CloudKit challenges: \(error)")
                await MainActor.run {
                    self.isLoadingChallenges = false
                }
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Challenges")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("\(allActiveChallenges.count) challenges active")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Button(action: { showingChallengeHub = true }) {
                    Text("View All")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#667eea"))
                }
            }
            
            // Active Challenges List
            if allActiveChallenges.isEmpty && !isLoadingChallenges {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.3))
                        Text("No active challenges")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.vertical, 30)
                    Spacer()
                }
            } else if isLoadingChallenges {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#667eea")))
                        .padding(.vertical, 30)
                    Spacer()
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(allActiveChallenges.prefix(3))) { challenge in
                            CompactChallengeCard(challenge: challenge) {
                                showingChallengeHub = true
                            }
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .onAppear {
            if CloudKitAuthManager.shared.isAuthenticated {
                loadCloudKitChallenges()
            }
        }
        .sheet(isPresented: $showingChallengeHub) {
            ChallengeHubView()
        }
    }
}

// MARK: - Compact Challenge Card
struct CompactChallengeCard: View {
    let challenge: Challenge
    let action: () -> Void
    @StateObject private var progressTracker = ChallengeProgressTracker.shared
    
    private var progress: Double {
        challenge.currentProgress
    }
    
    private var timeRemaining: String {
        let remaining = challenge.endDate.timeIntervalSinceNow
        if remaining <= 0 { return "Ended" }
        
        let hours = Int(remaining) / 3600
        let minutes = Int(remaining) % 3600 / 60
        
        if hours > 24 {
            return "\(hours / 24)d left"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Challenge Type Badge
                HStack {
                    Text(challenge.type.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(challenge.type.color.opacity(0.3))
                        )
                    
                    Spacer()
                    
                    Text(timeRemaining)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Challenge Title
                Text(challenge.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Points & Progress
                HStack {
                    Label("\(challenge.points) pts", systemImage: "star.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#ffd93d"))
                    
                    Spacer()
                    
                    // Progress Circle
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 3)
                            .frame(width: 30, height: 30)
                        
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "#43e97b"), Color(hex: "#38f9d7")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(width: 30, height: 30)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(16)
            .frame(width: 200)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                challenge.type.color.opacity(0.3),
                                challenge.type.color.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(challenge.type.color.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Photo Storage Helpers
private func saveCustomPhotoToFile(_ data: Data) {
    guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
    let filePath = documentsPath.appendingPathComponent("customChefPhoto.jpg")
    
    do {
        try data.write(to: filePath)
        // Remove from UserDefaults if it exists
        UserDefaults.standard.removeObject(forKey: "CustomChefPhoto")
        print("✅ Custom photo saved to file system")
    } catch {
        print("❌ Failed to save custom photo: \(error)")
    }
}

struct ProfilePhotoHelper {
    static func loadCustomPhotoFromFile() -> Data? {
        // First, clean up UserDefaults if photo exists there
        if UserDefaults.standard.data(forKey: "CustomChefPhoto") != nil {
            UserDefaults.standard.removeObject(forKey: "CustomChefPhoto")
        }
        
        // Load from file system
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let filePath = documentsPath.appendingPathComponent("customChefPhoto.jpg")
        
        return try? Data(contentsOf: filePath)
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
            .environmentObject(GamificationManager())
    }
}