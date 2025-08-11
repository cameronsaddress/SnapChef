import SwiftUI

// MARK: - Sub-components
struct InfluencerHeaderView: View {
    let influencer: InfluencerRecipe
    @Binding var sparkleAnimation: Bool
    @State private var showingUserProfile = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile picture
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
                .overlay(
                    Text(influencer.influencerName.prefix(2))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Button(action: {
                    showingUserProfile = true
                }) {
                    HStack(spacing: 4) {
                        Text(influencer.influencerName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#4facfe"))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Text(influencer.followerCount + " followers")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Sparkle animation
            SparkleAnimationView(sparkleAnimation: $sparkleAnimation)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .sheet(isPresented: $showingUserProfile) {
            UserProfileView(
                userID: influencer.influencerHandle.replacingOccurrences(of: "@", with: ""),
                userName: influencer.influencerName
            )
        }
    }
}

struct SparkleAnimationView: View {
    @Binding var sparkleAnimation: Bool
    
    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Image(systemName: "sparkle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "#ffa726"))
                    .offset(x: 20, y: 0)
                    .rotationEffect(.degrees(Double(index) * 120))
                    .scaleEffect(sparkleAnimation ? 1.2 : 0.8)
                    .opacity(sparkleAnimation ? 1 : 0.6)
                    .animation(
                        .easeInOut(duration: 1.5)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: sparkleAnimation
                    )
            }
        }
        .frame(width: 40, height: 40)
    }
}

struct BeforeAfterSliderView: View {
    let influencer: InfluencerRecipe
    @State private var imageOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Before image (left side)
                HStack(spacing: 0) {
                    // Fridge photo
                    Group {
                        if let uiImage = UIImage(named: influencer.beforeImageName) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                        }
                    }
                    .frame(width: geometry.size.width / 2, height: 200)
                    .clipped()
                    .overlay(
                        // Dark filter overlay
                        Rectangle()
                            .fill(Color.black.opacity(0.35))
                    )
                    .overlay(
                        VStack {
                            Spacer()
                            Text("BEFORE")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.6))
                                )
                                .padding(.bottom, 8)
                        }
                    )
                    
                    // After photo
                    Group {
                        if let uiImage = UIImage(named: influencer.afterImageName) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                        }
                    }
                    .frame(width: geometry.size.width / 2, height: 200)
                    .clipped()
                    .overlay(
                        // Dark filter overlay
                        Rectangle()
                            .fill(Color.black.opacity(0.35))
                    )
                    .overlay(
                        VStack {
                            Spacer()
                            Text("AFTER")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.6))
                                )
                                .padding(.bottom, 8)
                        }
                    )
                }
                
                // Sliding divider
                SliderHandleView(imageOffset: $imageOffset, geometry: geometry)
            }
            .frame(height: 200)
            .clipped()
            .onAppear {
                animateSlider(geometry: geometry)
            }
        }
        .frame(height: 200)
    }
    
    private func animateSlider(geometry: GeometryProxy) {
        withAnimation(.easeInOut(duration: 2).delay(0.5)) {
            imageOffset = -geometry.size.width/4
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeInOut(duration: 2)) {
                imageOffset = 0
            }
        }
    }
}

struct SliderHandleView: View {
    @Binding var imageOffset: CGFloat
    let geometry: GeometryProxy
    
    var body: some View {
        Rectangle()
            .fill(Color.white)
            .frame(width: 4)
            .overlay(
                Circle()
                    .fill(Color.white)
                    .frame(width: 40, height: 40)
                    .overlay(
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#667eea"))
                    )
            )
            .offset(x: imageOffset)
            // Gesture disabled for better UX
    }
}

struct RecipeStatsView: View {
    let influencer: InfluencerRecipe
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text(influencer.recipe.recipe.name)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 20) {
                // Likes
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#f5576c"))
                    Text(formatNumber(influencer.likes))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Shares
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#4facfe"))
                    Text(formatNumber(influencer.shares))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Time
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#43e97b"))
                    Text("\(influencer.recipe.recipe.prepTime + influencer.recipe.recipe.cookTime)m")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // CTA button
            CTAButton(onTap: onTap)
        }
        .padding(20)
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.0fK", Double(number) / 1_000)
        }
        return "\(number)"
    }
}

struct CTAButton: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text("See Full Recipe")
                    .font(.system(size: 16, weight: .semibold))
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 16))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: Color(hex: "#667eea").opacity(0.5), radius: 10, y: 5)
        }
    }
}

// MARK: - Main Component
struct InfluencerShowcaseCard: View {
    let influencer: InfluencerRecipe
    let onTap: () -> Void
    
    @State private var imageOffset: CGFloat = 0
    @State private var sparkleAnimation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with influencer info
            InfluencerHeaderView(influencer: influencer, sparkleAnimation: $sparkleAnimation)
            
            // Quote
            Text("\"\(influencer.quote)\"")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            
            // Before/After showcase
            BeforeAfterSliderView(influencer: influencer)
            
            // Recipe name and stats
            RecipeStatsView(influencer: influencer, onTap: onTap)
        }
        .background(
            CardBackgroundView()
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
        .onAppear {
            sparkleAnimation = true
        }
    }
}

struct CardBackgroundView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color.black.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
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
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
            )
    }
}

#Preview {
    ZStack {
        MagicalBackground()
            .ignoresSafeArea()
        
        InfluencerShowcaseCard(
            influencer: InfluencerRecipe.mockInfluencers[0],
            onTap: {}
        )
        .padding()
    }
}