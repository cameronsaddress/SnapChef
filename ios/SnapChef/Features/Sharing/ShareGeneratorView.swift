import SwiftUI
import UIKit

struct ShareGeneratorView: View {
    let recipe: Recipe
    let ingredientsPhoto: UIImage?
    @State private var generatedImage: UIImage?
    @State private var isGenerating = false
    @State private var shareSheet = false
    @State private var selectedStyle: ShareStyle = .vibrant
    @State private var animationPhase = 0.0
    
    enum ShareStyle: String, CaseIterable {
        case vibrant = "Vibrant"
        case minimal = "Minimal"
        case playful = "Playful"
        case elegant = "Elegant"
        
        var emoji: String {
            switch self {
            case .vibrant: return "🎨"
            case .minimal: return "⚪"
            case .playful: return "🎉"
            case .elegant: return "✨"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Preview Section
                        SharePreviewSection(
                            recipe: recipe,
                            ingredientsPhoto: ingredientsPhoto,
                            selectedStyle: selectedStyle,
                            animationPhase: animationPhase
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Style Selector
                        StyleSelectorView(selectedStyle: $selectedStyle)
                            .padding(.horizontal, 20)
                        
                        // Challenge Text Editor
                        ChallengeTextEditor(recipe: recipe)
                            .padding(.horizontal, 20)
                        
                        // Action Buttons
                        VStack(spacing: 16) {
                            MagneticButton(
                                title: "Generate Share Image",
                                icon: "sparkles",
                                action: generateShareImage
                            )
                            
                            if generatedImage != nil {
                                MagneticButton(
                                    title: "Share Now",
                                    icon: "square.and.arrow.up",
                                    action: { shareSheet = true }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Create Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Dismiss action
                    }
                    .foregroundColor(Color(hex: "#667eea"))
                }
            }
        }
        .sheet(isPresented: $shareSheet) {
            if let image = generatedImage {
                ShareSheet(items: [image, generateShareText()])
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                animationPhase = 1
            }
        }
    }
    
    private func generateShareImage() {
        isGenerating = true
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Create the share image
        let renderer = ImageRenderer(content: ShareImageContent(
            recipe: recipe,
            ingredientsPhoto: ingredientsPhoto,
            style: selectedStyle
        ))
        
        renderer.scale = 3.0 // High quality
        
        if let uiImage = renderer.uiImage {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                generatedImage = uiImage
                isGenerating = false
            }
        }
    }
    
    private func generateShareText() -> String {
        return """
        🔥 MY FRIDGE CHALLENGE 🔥
        
        I just turned these random ingredients into \(recipe.name)! 
        
        ⏱ Ready in just \(recipe.prepTime + recipe.cookTime) minutes
        🎯 Difficulty: \(recipe.difficulty.emoji) \(recipe.difficulty.rawValue.capitalized)
        
        Think you can beat my fridge game? 
        Download SnapChef and show me what you got! 👨‍🍳
        
        #FridgeChallenge #SnapChef #CookingMagic
        """
    }
}

// MARK: - Share Preview Section
struct SharePreviewSection: View {
    let recipe: Recipe
    let ingredientsPhoto: UIImage?
    let selectedStyle: ShareGeneratorView.ShareStyle
    let animationPhase: Double
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Preview")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Preview Container
            GeometryReader { geometry in
                ZStack {
                    // Background glow
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "#667eea").opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .blur(radius: 30)
                        .scaleEffect(1.2)
                    
                    // Preview content
                    ShareImageContent(
                        recipe: recipe,
                        ingredientsPhoto: ingredientsPhoto,
                        style: selectedStyle
                    )
                    .scaleEffect(0.85)
                    .rotation3DEffect(
                        .degrees(animationPhase * 360),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )
                }
                .frame(width: geometry.size.width, height: geometry.size.width * 1.4)
            }
            .aspectRatio(1/1.4, contentMode: .fit)
        }
    }
}

// MARK: - Share Image Content
struct ShareImageContent: View {
    let recipe: Recipe
    let ingredientsPhoto: UIImage?
    let style: ShareGeneratorView.ShareStyle
    
    var backgroundGradient: LinearGradient {
        switch style {
        case .vibrant:
            return LinearGradient(
                colors: [
                    Color(hex: "#f093fb"),
                    Color(hex: "#f5576c")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .minimal:
            return LinearGradient(
                colors: [
                    Color(hex: "#e0e0e0"),
                    Color(hex: "#f5f5f5")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .playful:
            return LinearGradient(
                colors: [
                    Color(hex: "#4facfe"),
                    Color(hex: "#00f2fe")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .elegant:
            return LinearGradient(
                colors: [
                    Color(hex: "#667eea"),
                    Color(hex: "#764ba2")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 24)
                .fill(backgroundGradient)
            
            // Pattern overlay
            GeometryReader { geometry in
                ForEach(0..<20) { index in
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 100, height: 100)
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                }
            }
            
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Text("MY FRIDGE CHALLENGE")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(textColor)
                        .tracking(2)
                    
                    Text("Can you beat this?")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textColor.opacity(0.8))
                }
                
                // Before/After Images
                HStack(spacing: 16) {
                    // Before (Ingredients)
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 140, height: 140)
                            
                            if let photo = ingredientsPhoto {
                                Image(uiImage: photo)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 140, height: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            } else {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 40))
                                    .foregroundColor(textColor.opacity(0.5))
                            }
                            
                            // Label
                            VStack {
                                Spacer()
                                Text("BEFORE")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Capsule())
                                    .padding(8)
                            }
                        }
                    }
                    
                    // Arrow
                    Image(systemName: "arrow.right")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(textColor)
                    
                    // After (Recipe)
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
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
                                .frame(width: 140, height: 140)
                            
                            Text(recipe.difficulty.emoji)
                                .font(.system(size: 60))
                            
                            // Label
                            VStack {
                                Spacer()
                                Text("AFTER")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Capsule())
                                    .padding(8)
                            }
                        }
                    }
                }
                
                // Recipe Name
                Text(recipe.name.uppercased())
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 20)
                
                // Stats
                HStack(spacing: 30) {
                    StatBadge(
                        icon: "clock",
                        value: "\(recipe.prepTime + recipe.cookTime)m",
                        color: textColor
                    )
                    
                    StatBadge(
                        icon: "flame",
                        value: "\(recipe.nutrition.calories)",
                        color: textColor
                    )
                    
                    StatBadge(
                        icon: "chart.bar.fill",
                        value: recipe.difficulty.rawValue.capitalized,
                        color: textColor
                    )
                }
                
                Spacer()
                
                // App branding
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .bold))
                    Text("SnapChef")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                }
                .foregroundColor(textColor)
                .padding(.bottom, 30)
            }
            .padding(.top, 40)
        }
        .frame(width: 350, height: 490)
        .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
    }
    
    var textColor: Color {
        switch style {
        case .minimal:
            return Color(hex: "#333333")
        default:
            return .white
        }
    }
}

// MARK: - Stat Badge
struct StatBadge: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
        }
        .foregroundColor(color)
    }
}

// MARK: - Style Selector
struct StyleSelectorView: View {
    @Binding var selectedStyle: ShareGeneratorView.ShareStyle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose Style")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ShareGeneratorView.ShareStyle.allCases, id: \.self) { style in
                        StyleOptionCard(
                            style: style,
                            isSelected: selectedStyle == style,
                            action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedStyle = style
                                }
                            }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Style Option Card
struct StyleOptionCard: View {
    let style: ShareGeneratorView.ShareStyle
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(style.emoji)
                    .font(.system(size: 30))
                
                Text(style.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            }
            .frame(width: 100, height: 100)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [
                                    Color(hex: "#667eea"),
                                    Color(hex: "#764ba2")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? Color.clear : Color.white.opacity(0.3),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Challenge Text Editor
struct ChallengeTextEditor: View {
    let recipe: Recipe
    @State private var challengeText = ""
    @State private var selectedTemplate = 0
    
    let templates = [
        "Just turned my sad fridge into a gourmet meal! 🔥",
        "Who says you need a full pantry to cook amazing food? 👨‍🍳",
        "From empty fridge to THIS masterpiece! Can you beat it? 💪",
        "Plot twist: My fridge scraps became a 5-star meal! ⭐"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Your Challenge")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            // Template selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<templates.count, id: \.self) { index in
                        TemplateChip(
                            text: "Template \(index + 1)",
                            isSelected: selectedTemplate == index,
                            action: {
                                selectedTemplate = index
                                challengeText = templates[index]
                            }
                        )
                    }
                }
            }
            
            // Text editor
            GlassmorphicCard {
                VStack(alignment: .leading, spacing: 12) {
                    TextEditor(text: $challengeText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 100)
                        .onAppear {
                            challengeText = templates[0]
                        }
                    
                    HStack {
                        Spacer()
                        Text("\(challengeText.count)/280")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(20)
            }
        }
    }
}

// MARK: - Template Chip
struct TemplateChip: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(
                            isSelected
                                ? Color(hex: "#4facfe")
                                : Color.white.opacity(0.2)
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    isSelected ? Color.clear : Color.white.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ShareGeneratorView(
        recipe: MockDataProvider.shared.mockRecipe(),
        ingredientsPhoto: nil
    )
}