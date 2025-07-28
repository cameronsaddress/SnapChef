import SwiftUI

struct ShareSheet: View {
    let recipe: Recipe
    @Environment(\.dismiss) var dismiss
    @State private var shareMessage = ""
    @State private var showingCopiedAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                GradientBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Preview card
                    SharePreviewCard(recipe: recipe)
                        .padding(.horizontal, 20)
                    
                    // Share message
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Share message")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        
                        TextField("Add a message...", text: $shareMessage, axis: .vertical)
                            .textFieldStyle(ShareTextFieldStyle())
                            .lineLimit(3...5)
                    }
                    .padding(.horizontal, 20)
                    
                    // Share buttons
                    VStack(spacing: 16) {
                        LegacySharePlatformButton(
                            platform: .tiktok,
                            recipe: recipe,
                            message: shareMessage,
                            onShare: { trackShare(platform: "tiktok") }
                        )
                        
                        LegacySharePlatformButton(
                            platform: .instagram,
                            recipe: recipe,
                            message: shareMessage,
                            onShare: { trackShare(platform: "instagram") }
                        )
                        
                        LegacySharePlatformButton(
                            platform: .twitter,
                            recipe: recipe,
                            message: shareMessage,
                            onShare: { trackShare(platform: "twitter") }
                        )
                        
                        LegacySharePlatformButton(
                            platform: .copy,
                            recipe: recipe,
                            message: shareMessage,
                            onShare: {
                                copyToClipboard()
                                trackShare(platform: "clipboard")
                            }
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Reward info
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Earn 5 credits for each share!")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .padding(.top, 20)
            }
            .navigationTitle("Share Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .alert("Copied!", isPresented: $showingCopiedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Recipe link copied to clipboard")
        }
    }
    
    private func trackShare(platform: String) {
        Task {
            do {
                _ = try await NetworkManager.shared.trackShare(recipeId: recipe.id.uuidString, platform: platform)
                HapticManager.notification(.success)
            } catch {
                print("Failed to track share: \(error)")
            }
        }
    }
    
    private func copyToClipboard() {
        let text = formatShareText()
        UIPasteboard.general.string = text
        showingCopiedAlert = true
    }
    
    private func formatShareText() -> String {
        var text = "🍳 \(recipe.name)\n\n"
        if !shareMessage.isEmpty {
            text += "\(shareMessage)\n\n"
        }
        text += "Made with SnapChef - AI-powered recipes from what you already have ✨\n"
        text += "Download: snapchef.app"
        return text
    }
}

struct SharePreviewCard: View {
    let recipe: Recipe
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(recipe.name)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            HStack(spacing: 16) {
                Label("\(recipe.prepTime + recipe.cookTime)m", systemImage: "clock")
                Label("\(recipe.nutrition.calories) cal", systemImage: "flame")
                Text(recipe.difficulty.emoji)
            }
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct LegacySharePlatformButton: View {
    let platform: SharePlatform
    let recipe: Recipe
    let message: String
    let onShare: () -> Void
    
    var body: some View {
        Button(action: {
            platform.share(recipe: recipe, message: message)
            onShare()
        }) {
            HStack {
                Image(systemName: platform.icon)
                    .font(.system(size: 20))
                
                Text(platform.title)
                    .font(.system(size: 17, weight: .semibold))
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14))
                    .opacity(0.7)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(platform.background)
            .cornerRadius(12)
        }
    }
}

enum SharePlatform {
    case tiktok
    case instagram
    case twitter
    case copy
    
    var title: String {
        switch self {
        case .tiktok: return "Share to TikTok"
        case .instagram: return "Share to Instagram"
        case .twitter: return "Share to X"
        case .copy: return "Copy Text"
        }
    }
    
    var icon: String {
        switch self {
        case .tiktok: return "music.note"
        case .instagram: return "camera"
        case .twitter: return "x.circle"
        case .copy: return "doc.on.doc"
        }
    }
    
    var background: some View {
        Group {
            switch self {
            case .tiktok:
                Color.black
            case .instagram:
                LinearGradient(
                    colors: [
                        Color(hex: "#833AB4"),
                        Color(hex: "#F56040"),
                        Color(hex: "#FCAF45")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .twitter:
                Color.black
            case .copy:
                Color.white.opacity(0.2)
            }
        }
    }
    
    func share(recipe: Recipe, message: String) {
        // We'll handle the view controller lookup inside each share method
        switch self {
        case .tiktok:
            shareTikTok(recipe: recipe, message: message)
        case .instagram:
            shareInstagram(recipe: recipe, message: message)
        case .twitter:
            shareTwitter(recipe: recipe, message: message)
        case .copy:
            copyText(recipe: recipe, message: message)
        }
    }
    
    private func shareTikTok(recipe: Recipe, message: String) {
        let text = formatShareText(recipe: recipe, message: message)
        UIPasteboard.general.string = text
        
        if let url = URL(string: "tiktok://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    private func shareInstagram(recipe: Recipe, message: String) {
        let text = formatShareText(recipe: recipe, message: message)
        UIPasteboard.general.string = text
        
        if let url = URL(string: "instagram://camera"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = URL(string: "instagram://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    private func shareTwitter(recipe: Recipe, message: String) {
        let text = formatShareText(recipe: recipe, message: message)
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: "twitter://post?text=\(encodedText)"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = URL(string: "https://twitter.com/intent/tweet?text=\(encodedText)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func copyText(recipe: Recipe, message: String) {
        let text = formatShareText(recipe: recipe, message: message)
        UIPasteboard.general.string = text
    }
    
    private func formatShareText(recipe: Recipe, message: String) -> String {
        var text = ""
        if !message.isEmpty {
            text += "\(message)\n\n"
        }
        text += "🍳 Just made \(recipe.name) with @SnapChef!\n"
        text += "⏱ Only \(recipe.cookTime + recipe.prepTime) minutes\n"
        text += "📱 AI-powered recipes from what you already have\n\n"
        text += "#SnapChef #AIRecipes #HomeCooking"
        return text
    }
}

struct ShareTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .foregroundColor(.white)
            .tint(.white)
    }
}

#Preview {
    ShareSheet(recipe: Recipe(
        id: UUID(),
        name: "Chicken Stir Fry",
        description: "A quick and healthy dish",
        ingredients: [],
        instructions: [],
        cookTime: 15,
        prepTime: 10,
        servings: 4,
        difficulty: .medium,
        nutrition: Nutrition(calories: 320, protein: 28, carbs: 15, fat: 12, fiber: nil, sugar: nil, sodium: nil),
        imageURL: nil,
        createdAt: Date()
    ))
}