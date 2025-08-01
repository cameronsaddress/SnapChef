import SwiftUI

struct EnhancedShareSheet: View {
    let recipe: Recipe
    @Environment(\.dismiss) var dismiss
    @State private var selectedPlatform: SharePlatform?
    @State private var showShareAnimation = false
    @State private var contentReady = false
    @State private var generatedImage: UIImage?
    
    enum SharePlatform: String, CaseIterable {
        case instagram = "Instagram"
        case tiktok = "TikTok"
        case twitter = "Twitter"
        case messages = "Messages"
        case more = "More"
        
        var icon: String {
            switch self {
            case .instagram: return "camera.fill"
            case .tiktok: return "music.note"
            case .twitter: return "bird.fill"
            case .messages: return "message.fill"
            case .more: return "ellipsis"
            }
        }
        
        var color: Color {
            switch self {
            case .instagram: return Color(hex: "#E4405F")
            case .tiktok: return Color(hex: "#000000")
            case .twitter: return Color(hex: "#1DA1F2")
            case .messages: return Color(hex: "#34C759")
            case .more: return Color(hex: "#667eea")
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                MagicalBackground()
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.3))
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Recipe Preview Card
                        ShareableRecipeCard(recipe: recipe, image: $generatedImage)
                            .scaleEffect(contentReady ? 1 : 0.8)
                            .opacity(contentReady ? 1 : 0)
                        
                        // Share message
                        VStack(spacing: 16) {
                            Text("Share your creation!")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Inspire others with your culinary magic ✨")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .staggeredFade(index: 0, isShowing: contentReady)
                        
                        // Platform grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(SharePlatform.allCases, id: \.self) { platform in
                                SharePlatformButton(
                                    platform: platform,
                                    isSelected: selectedPlatform == platform,
                                    action: {
                                        selectedPlatform = platform
                                        shareToplatform(platform)
                                    }
                                )
                                .staggeredFade(
                                    index: SharePlatform.allCases.firstIndex(of: platform)! + 1,
                                    isShowing: contentReady
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Viral tips
                        ViralTipsCard()
                            .padding(.horizontal, 20)
                            .staggeredFade(index: 6, isShowing: contentReady)
                    }
                    .padding(.vertical, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.2)))
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                contentReady = true
            }
        }
        .overlay(
            Group {
                if showShareAnimation {
                    ShareSuccessAnimation()
                }
            }
        )
    }
    
    private func shareToplatform(_ platform: SharePlatform) {
        // Trigger haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Show success animation
        showShareAnimation = true
        
        // Perform actual share
        switch platform {
        case .instagram:
            shareToInstagram()
        case .tiktok:
            shareToTikTok()
        case .twitter:
            shareToTwitter()
        case .messages:
            shareToMessages()
        case .more:
            showSystemShareSheet()
        }
        
        // Hide animation after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showShareAnimation = false
            dismiss()
        }
    }
    
    private func shareToInstagram() {
        // Instagram-specific sharing logic
    }
    
    private func shareToTikTok() {
        // TikTok-specific sharing logic
    }
    
    private func shareToTwitter() {
        // Twitter-specific sharing logic
    }
    
    private func shareToMessages() {
        // Messages-specific sharing logic
    }
    
    private func showSystemShareSheet() {
        // System share sheet
    }
}

// MARK: - Shareable Recipe Card
struct ShareableRecipeCard: View {
    let recipe: Recipe
    @Binding var image: UIImage?
    @State private var glowAnimation = false
    
    var body: some View {
        GlassmorphicCard(content: {
            VStack(spacing: 0) {
                // Header
                ZStack {
                    // Gradient background
                    LinearGradient(
                        colors: [
                            Color(hex: "#667eea"),
                            Color(hex: "#764ba2"),
                            Color(hex: "#f093fb")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 200)
                    
                    // Recipe image or emoji
                    Text(recipe.difficulty.emoji)
                        .font(.system(size: 80))
                        .scaleEffect(glowAnimation ? 1.1 : 1)
                    
                    // App branding
                    VStack {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("SnapChef")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.3))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .padding(16)
                            Spacer()
                        }
                        Spacer()
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 20) {
                    // Recipe name
                    Text(recipe.name)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    // Stats row
                    HStack(spacing: 24) {
                        ShareStatItem(icon: "clock", value: "\(recipe.prepTime + recipe.cookTime)m", color: Color(hex: "#4facfe"))
                        ShareStatItem(icon: "flame", value: "\(recipe.nutrition.calories) cal", color: Color(hex: "#f093fb"))
                        ShareStatItem(icon: "star.fill", value: recipe.difficulty.rawValue, color: Color(hex: "#ffa726"))
                    }
                    
                    // Description
                    Text(recipe.description)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(3)
                    
                    // Call to action
                    HStack {
                        Text("Try it with SnapChef!")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.forward.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "#667eea"))
                    }
                    .padding(.top, 10)
                }
                .padding(24)
            }
        }, cornerRadius: 24, glowColor: Color(hex: "#f093fb"))
        .frame(maxWidth: 350)
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowAnimation = true
            }
            // Generate shareable image
            generateShareImage()
        }
    }
    
    private func generateShareImage() {
        // Convert view to UIImage for sharing
    }
}

// MARK: - Share Stat Item
struct ShareStatItem: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Share Platform Button
struct SharePlatformButton: View {
    let platform: EnhancedShareSheet.SharePlatform
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            GlassmorphicCard(content: {
                VStack(spacing: 12) {
                    // Platform icon
                    ZStack {
                        Circle()
                            .fill(platform.color.opacity(0.2))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: platform.icon)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(platform.color)
                            .scaleEffect(isPressed ? 1.2 : 1)
                    }
                    
                    Text(platform.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
            }, glowColor: platform.color.opacity(0.6))
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

// MARK: - Viral Tips Card
struct ViralTipsCard: View {
    @State private var currentTip = 0
    let tips = [
        ("📸", "Use natural lighting for best food photos"),
        ("🎵", "Add trending audio to boost engagement"),
        ("⏰", "Post during peak hours (6-9 PM)"),
        ("#️⃣", "Use 5-10 relevant hashtags"),
        ("💬", "Ask questions to encourage comments")
    ]
    
    var body: some View {
        GlassmorphicCard(content: {
            VStack(spacing: 16) {
                HStack {
                    Text("Pro Tips for Going Viral")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("💡")
                        .font(.system(size: 20))
                }
                
                // Animated tip carousel
                TabView(selection: $currentTip) {
                    ForEach(0..<tips.count, id: \.self) { index in
                        HStack(spacing: 12) {
                            Text(tips[index].0)
                                .font(.system(size: 24))
                            
                            Text(tips[index].1)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                .frame(height: 50)
            }
            .padding(20)
        }, glowColor: Color(hex: "#43e97b"))
    }
}

// MARK: - Share Success Animation
struct ShareSuccessAnimation: View {
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var checkmarkScale: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .opacity(opacity)
            
            // Success circle
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
                    .frame(width: 120, height: 120)
                    .scaleEffect(scale)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(checkmarkScale)
            }
            
            // Confetti particles
            ForEach(0..<20) { _ in
                ConfettiParticle()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scale = 1
                opacity = 1
            }
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2)) {
                checkmarkScale = 1
            }
        }
    }
}

struct ConfettiParticle: View {
    @State private var position = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
    @State private var opacity: Double = 1
    
    let color = [
        Color(hex: "#667eea"),
        Color(hex: "#764ba2"),
        Color(hex: "#f093fb"),
        Color(hex: "#4facfe"),
        Color(hex: "#43e97b")
    ].randomElement()!
    
    let velocity = CGVector(
        dx: CGFloat.random(in: -200...200),
        dy: CGFloat.random(in: -300...(-100))
    )
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: CGFloat.random(in: 6...12), height: CGFloat.random(in: 6...12))
            .position(position)
            .opacity(opacity)
            .onAppear {
                withAnimation(.linear(duration: 2)) {
                    position.x += velocity.dx
                    position.y += velocity.dy + 400 // Gravity
                    opacity = 0
                }
            }
    }
}

#Preview {
    EnhancedShareSheet(recipe: MockDataProvider.shared.mockRecipe())
}