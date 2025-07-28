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
                        SharePlatformButton(
                            platform: .tiktok,
                            recipe: recipe,
                            message: shareMessage,
                            onShare: { trackShare(platform: "tiktok") }
                        )
                        
                        SharePlatformButton(
                            platform: .instagram,
                            recipe: recipe,
                            message: shareMessage,
                            onShare: { trackShare(platform: "instagram") }
                        )
                        
                        SharePlatformButton(
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
        text += "Made with SnapChef - Turn your fridge into a feast! ✨\n"
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

struct SharePlatformButton: View {
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
    case copy
    
    var title: String {
        switch self {
        case .tiktok: return "Share to TikTok"
        case .instagram: return "Share to Instagram"
        case .copy: return "Copy Link"
        }
    }
    
    var icon: String {
        switch self {
        case .tiktok: return "music.note"
        case .instagram: return "camera"
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
            case .copy:
                Color.white.opacity(0.2)
            }
        }
    }
    
    func share(recipe: Recipe, message: String) {
        switch self {
        case .tiktok:
            shareTikTok(recipe: recipe, message: message)
        case .instagram:
            shareInstagram(recipe: recipe, message: message)
        case .copy:
            break // Handled separately
        }
    }
    
    private func shareTikTok(recipe: Recipe, message: String) {
        var text = "#SnapChef #\(recipe.name.replacingOccurrences(of: " ", with: ""))"
        if !message.isEmpty {
            text = "\(message) \(text)"
        }
        text += " #Recipe #Cooking #FoodHack"
        
        // TikTok doesn't have a direct share URL, so we open the app
        if let url = URL(string: "tiktok://") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                // Fallback to App Store
                if let appStoreURL = URL(string: "https://apps.apple.com/app/tiktok/id835599320") {
                    UIApplication.shared.open(appStoreURL)
                }
            }
        }
        
        // Copy text to clipboard for easy paste
        UIPasteboard.general.string = text
    }
    
    private func shareInstagram(recipe: Recipe, message: String) {
        // Instagram Stories deep link
        if let url = URL(string: "instagram-stories://share") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                // Fallback to Instagram app
                if let instagramURL = URL(string: "instagram://") {
                    if UIApplication.shared.canOpenURL(instagramURL) {
                        UIApplication.shared.open(instagramURL)
                    } else {
                        // Fallback to App Store
                        if let appStoreURL = URL(string: "https://apps.apple.com/app/instagram/id389801252") {
                            UIApplication.shared.open(appStoreURL)
                        }
                    }
                }
            }
        }
        
        // Copy text for easy paste
        var text = "🍳 \(recipe.name)\n"
        if !message.isEmpty {
            text += "\(message)\n"
        }
        text += "\nMade with @SnapChef ✨"
        UIPasteboard.general.string = text
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