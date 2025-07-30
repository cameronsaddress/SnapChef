import SwiftUI
import UIKit

// MARK: - Social Share View
struct SocialShareView: View {
    @StateObject private var shareManager = SocialShareManager.shared
    let image: UIImage
    let text: String
    let recipe: Recipe
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedPlatform: SocialPlatform?
    @State private var showingReward = false
    @State private var bounceAnimation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header with animation
                        ShareHeaderView()
                            .padding(.top, 20)
                        
                        // Platform Grid
                        PlatformGridView(
                            selectedPlatform: $selectedPlatform,
                            shareManager: shareManager
                        )
                        .padding(.horizontal, 20)
                        
                        // Share Preview
                        SharePreviewCard(image: image, recipe: recipe)
                            .padding(.horizontal, 20)
                            .scaleEffect(bounceAnimation ? 1.05 : 1)
                        
                        // Rewards Section
                        ShareRewardsCard(shareManager: shareManager)
                            .padding(.horizontal, 20)
                        
                        // Share Button
                        if let platform = selectedPlatform {
                            MagneticButton(
                                title: "Share to \(platform.rawValue)",
                                icon: "paperplane.fill",
                                action: {
                                    Task {
                                        try await shareManager.share(
                                            image: image,
                                            text: text,
                                            recipe: recipe,
                                            to: platform
                                        )
                                        showingReward = true
                                    }
                                }
                            )
                            .padding(.horizontal, 20)
                            .disabled(shareManager.isSharing)
                        }
                        
                        // Skip button
                        Button("Maybe Later") {
                            dismiss()
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.bottom, 40)
                    }
                }
                
                // Loading overlay
                if shareManager.isSharing {
                    ShareLoadingOverlay(progress: shareManager.shareProgress)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingReward) {
            ShareRewardView(reward: shareManager.calculateShareRewards())
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                bounceAnimation = true
            }
        }
    }
}

// MARK: - Share Header View
struct ShareHeaderView: View {
    @State private var glowAnimation = false
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Animated glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#f093fb").opacity(0.5),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(glowAnimation ? 1.3 : 1)
                    .opacity(glowAnimation ? 0.3 : 0.8)
                
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(-15))
            }
            
            Text("Share Your Creation!")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Inspire others and earn rewards")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowAnimation = true
            }
        }
    }
}

// MARK: - Platform Grid View
struct PlatformGridView: View {
    @Binding var selectedPlatform: SocialPlatform?
    let shareManager: SocialShareManager
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose Platform")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(SocialPlatform.allCases, id: \.self) { platform in
                    PlatformButton(
                        platform: platform,
                        isSelected: selectedPlatform == platform,
                        isAvailable: shareManager.isPlatformAvailable(platform),
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedPlatform = platform
                            }
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Platform Button
struct PlatformButton: View {
    let platform: SocialPlatform
    let isSelected: Bool
    let isAvailable: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                                ? platform.color
                                : Color.white.opacity(0.2)
                        )
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(
                                    isSelected
                                        ? Color.clear
                                        : Color.white.opacity(0.3),
                                    lineWidth: 2
                                )
                        )
                    
                    Image(systemName: platform.icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                }
                .scaleEffect(isPressed ? 0.9 : 1)
                .opacity(isAvailable ? 1 : 0.5)
                
                Text(platform.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(isAvailable ? 0.9 : 0.5))
            }
        }
        .disabled(!isAvailable)
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Share Preview Card
struct SharePreviewCard: View {
    let image: UIImage
    let recipe: Recipe
    
    var body: some View {
        GlassmorphicCard {
            VStack(spacing: 16) {
                Text("Your Share")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Image preview
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Recipe info
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("\(recipe.prepTime + recipe.cookTime) min • \(recipe.difficulty.emoji)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#43e97b"))
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Share Rewards Card
struct ShareRewardsCard: View {
    let shareManager: SocialShareManager
    
    var body: some View {
        let reward = shareManager.calculateShareRewards()
        
        GlassmorphicCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(Color(hex: "#f093fb"))
                    
                    Text("Share Rewards")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                // Current stats
                HStack(spacing: 30) {
                    VStack(spacing: 4) {
                        Text("\(reward.points)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#43e97b"))
                        Text("Points")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    VStack(spacing: 4) {
                        Text("\(reward.multiplier)x")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#4facfe"))
                        Text("Multiplier")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    VStack(spacing: 4) {
                        Text("\(shareManager.shareCount)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#f093fb"))
                        Text("Total Shares")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                // Progress to next milestone
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Next milestone: \(reward.nextMilestone) shares")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Spacer()
                        
                        Text("\(shareManager.shareCount)/\(reward.nextMilestone)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    ProgressView(value: Double(shareManager.shareCount % 10), total: 10)
                        .tint(Color(hex: "#43e97b"))
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Share Loading Overlay
struct ShareLoadingOverlay: View {
    let progress: Double
    @State private var rotationAngle = 0.0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Animated loader
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 8)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#4facfe"),
                                    Color(hex: "#00f2fe")
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(rotationAngle))
                    
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(progress * 360))
                }
                
                Text("Sharing your masterpiece...")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#4facfe"))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
}

// MARK: - Share Reward View
struct ShareRewardView: View {
    let reward: ShareReward
    @Environment(\.dismiss) var dismiss
    @State private var showConfetti = false
    
    var body: some View {
        ZStack {
            MagicalBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Celebration icon
                Image(systemName: "star.fill")
                    .font(.system(size: 80))
                    .foregroundColor(Color(hex: "#ffa726"))
                    .particleExplosion(trigger: $showConfetti)
                
                Text("Share Complete!")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                if let badge = reward.badge {
                    Text(badge)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(Color(hex: "#43e97b"))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color(hex: "#43e97b").opacity(0.2))
                                .overlay(
                                    Capsule()
                                        .stroke(Color(hex: "#43e97b"), lineWidth: 2)
                                )
                        )
                }
                
                VStack(spacing: 16) {
                    Text("You earned")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("+\(reward.points) XP")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#43e97b"),
                                    Color(hex: "#38f9d7")
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                
                Spacer()
                
                MagneticButton(
                    title: "Awesome!",
                    icon: "hand.thumbsup.fill",
                    action: { dismiss() }
                )
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showConfetti = true
            }
        }
    }
}

#Preview {
    SocialShareView(
        image: UIImage(systemName: "photo")!,
        text: "Check out my amazing recipe!",
        recipe: MockDataProvider.shared.mockRecipe()
    )
}