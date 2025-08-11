import SwiftUI

struct AchievementGalleryView: View {
    @StateObject private var gamificationManager = GamificationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: AchievementCategory = .all
    @State private var selectedBadge: GameBadge?
    
    // New states for branded share
    @State private var showBrandedShare = false
    @State private var shareContent: ShareContent?
    
    private enum AchievementCategory: String, CaseIterable {
        case all = "All"
        case recipes = "Recipes"
        case challenges = "Challenges"
        case social = "Social"
        case special = "Special"
        
        var icon: String {
            switch self {
            case .all: return "star.fill"
            case .recipes: return "fork.knife"
            case .challenges: return "target"
            case .social: return "person.3.fill"
            case .special: return "sparkles"
            }
        }
    }
    
    private var filteredBadges: [GameBadge] {
        // For now, just return all badges since category isn't implemented
        return gamificationManager.userStats.badges
    }
    
    private var allPossibleBadges: [GameBadge] {
        // This would normally come from a data source
        // For now, return mock badges to show progress
        return [
            GameBadge(name: "First Recipe", icon: "star.fill", description: "Create your first recipe", rarity: .common, unlockedDate: Date()),
            GameBadge(name: "Recipe Explorer", icon: "map.fill", description: "Create 10 recipes", rarity: .common, unlockedDate: Date()),
            GameBadge(name: "Culinary Creator", icon: "sparkles", description: "Create 50 recipes", rarity: .rare, unlockedDate: Date()),
            GameBadge(name: "Master Chef", icon: "crown.fill", description: "Create 100 recipes", rarity: .epic, unlockedDate: Date()),
            GameBadge(name: "Week Warrior", icon: "flame.fill", description: "7-day streak", rarity: .rare, unlockedDate: Date()),
            GameBadge(name: "Dedication Master", icon: "medal.fill", description: "30-day streak", rarity: .legendary, unlockedDate: Date()),
            GameBadge(name: "Social Butterfly", icon: "person.3.fill", description: "Share 10 recipes", rarity: .rare, unlockedDate: Date()),
            GameBadge(name: "Speed Demon", icon: "timer.fill", description: "Complete speed challenge", rarity: .common, unlockedDate: Date()),
            GameBadge(name: "Health Guru", icon: "heart.fill", description: "Create 10 healthy recipes", rarity: .rare, unlockedDate: Date()),
            GameBadge(name: "Perfectionist", icon: "checkmark.seal.fill", description: "5 perfect recipes", rarity: .epic, unlockedDate: Date())
        ]
    }
    
    private var unlockedBadgeIds: Set<UUID> {
        Set(gamificationManager.userStats.badges.map { $0.id })
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Stats Overview
                        statsOverview
                        
                        // Category Filter
                        categoryFilter
                        
                        // Badges Grid
                        badgesGrid
                    }
                    .padding()
                }
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedBadge) { badge in
                BadgeDetailView(badge: badge, showBrandedShare: $showBrandedShare, shareContent: $shareContent)
            }
            // Add branded share popup
            .sheet(isPresented: $showBrandedShare) {
                if let content = shareContent {
                    BrandedSharePopup(content: content)
                }
            }
        }
    }
    
    // MARK: - Stats Overview
    private var statsOverview: some View {
        GlassmorphicCard(content: {
            VStack(spacing: 16) {
                HStack {
                    Text("Collection Progress")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Share button
                    Button(action: { 
                        // Use branded share popup for achievements
                        let achievementText = "🏆 I've unlocked \(gamificationManager.userStats.badges.count) achievements on SnapChef!"
                        shareContent = ShareContent(
                            type: .achievement(achievementText),
                            beforeImage: nil,
                            afterImage: nil
                        )
                        showBrandedShare = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }
                
                // Progress stats
                HStack(spacing: 30) {
                    VStack(spacing: 8) {
                        Text("\(gamificationManager.userStats.badges.count)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#f093fb"))
                        Text("Unlocked")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 8) {
                        Text("\(allPossibleBadges.count)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 8) {
                        let percentage = allPossibleBadges.isEmpty ? 0 : Int(Double(gamificationManager.userStats.badges.count) / Double(allPossibleBadges.count) * 100)
                        Text("\(percentage)%")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#667eea"))
                        Text("Complete")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#f093fb"), Color(hex: "#667eea")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: allPossibleBadges.isEmpty ? 0 : geometry.size.width * (Double(gamificationManager.userStats.badges.count) / Double(allPossibleBadges.count)),
                                height: 12
                            )
                            .animation(.spring(), value: gamificationManager.userStats.badges.count)
                    }
                }
                .frame(height: 12)
            }
            .padding()
        }, glowColor: Color(hex: "#f093fb"))
    }
    
    // MARK: - Category Filter
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(AchievementCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.rawValue,
                        icon: category.icon,
                        isSelected: selectedCategory == category,
                        count: getCountForCategory(category)
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedCategory = category
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Badges Grid
    private var badgesGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            // Show all possible badges with unlock status
            ForEach(allPossibleBadges) { badge in
                let isUnlocked = unlockedBadgeIds.contains(badge.id)
                BadgeCell(
                    badge: badge,
                    isUnlocked: isUnlocked
                ) {
                    if isUnlocked {
                        selectedBadge = badge
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func getCountForCategory(_ category: AchievementCategory) -> Int {
        // Since badges don't have categories yet, just return total count for all
        return gamificationManager.userStats.badges.count
    }
}

// MARK: - Badge Cell
private struct BadgeCell: View {
    let badge: GameBadge
    let isUnlocked: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Badge icon container
                ZStack {
                    Circle()
                        .fill(isUnlocked ? badge.rarity.color.opacity(0.2) : Color.gray.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    if isUnlocked {
                        // Glow effect
                        Circle()
                            .stroke(badge.rarity.color, lineWidth: 2)
                            .frame(width: 84, height: 84)
                            .blur(radius: 4)
                            .opacity(0.6)
                    }
                    
                    Image(systemName: badge.icon)
                        .font(.system(size: 36))
                        .foregroundColor(isUnlocked ? badge.rarity.color : .gray.opacity(0.3))
                    
                    if !isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .offset(x: 25, y: -25)
                    }
                }
                
                // Badge name
                Text(badge.name)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(isUnlocked ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 32)
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isUnlocked)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Category Chip
private struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white : Color.gray.opacity(0.3))
                        )
                }
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color(hex: "#f093fb") : Color.gray.opacity(0.2))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Badge Detail View
private struct BadgeDetailView: View {
    let badge: GameBadge
    @Binding var showBrandedShare: Bool
    @Binding var shareContent: ShareContent?
    @Environment(\.dismiss) private var dismiss
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Badge display
                    ZStack {
                        Circle()
                            .fill(badge.rarity.color.opacity(0.2))
                            .frame(width: 160, height: 160)
                        
                        Circle()
                            .stroke(badge.rarity.color, lineWidth: 3)
                            .frame(width: 168, height: 168)
                            .blur(radius: 8)
                            .opacity(0.6)
                        
                        Image(systemName: badge.icon)
                            .font(.system(size: 80))
                            .foregroundColor(badge.rarity.color)
                    }
                    .rotation3DEffect(
                        .degrees(rotationAngle),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .onAppear {
                        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                            rotationAngle = 360
                        }
                    }
                    
                    // Badge info
                    VStack(spacing: 16) {
                        Text(badge.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(badge.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        // Unlock date
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.secondary)
                            Text("Unlocked \(badge.unlockedDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Rarity indicator
                        HStack(spacing: 4) {
                            let starCount = rarityToStars(badge.rarity)
                            ForEach(0..<starCount, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                            ForEach(0..<(5 - starCount), id: \.self) { _ in
                                Image(systemName: "star")
                                    .font(.caption)
                                    .foregroundColor(.gray.opacity(0.3))
                            }
                        }
                    }
                    
                    // Share button for individual badge
                    Button(action: {
                        let achievementText = "🎯 Just unlocked the \(badge.name) badge on SnapChef!"
                        shareContent = ShareContent(
                            type: .achievement(achievementText),
                            beforeImage: nil,
                            afterImage: nil
                        )
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showBrandedShare = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .medium))
                            Text("Share Achievement")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#f093fb"), Color(hex: "#667eea")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Achievement")
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
    
    // MARK: - Helper Functions
    private func rarityToStars(_ rarity: BadgeRarity) -> Int {
        switch rarity {
        case .common: return 1
        case .rare: return 2
        case .epic: return 3
        case .legendary: return 5
        }
    }
}


// MARK: - Preview
struct AchievementGalleryView_Previews: PreviewProvider {
    static var previews: some View {
        AchievementGalleryView()
    }
}