import SwiftUI
import UIKit

struct ShareGeneratorView: View {
    let recipe: Recipe
    let ingredientsPhoto: UIImage?
    @State private var generatedImage: UIImage?
    @State private var afterPhoto: UIImage?
    @State private var isGenerating = false
    @State private var shareSheet = false
    @State private var showingCamera = false
    @State private var selectedStyle: ShareStyle = ShareStyle.allCases.randomElement() ?? .homeCook
    @State private var animationPhase = 0.0
    @State private var cloudKitRecordID: String?
    @State private var shareURL: URL?
    @State private var isUploadingToCloudKit = false
    @State private var showShareReadyMoment = false
    @StateObject private var cloudKitSync = CloudKitService.shared
    @StateObject private var socialShareManager = SocialShareManager.shared

    enum ShareStyle: String, CaseIterable {
        case homeCook = "Home Cook"
        case chefMode = "Chef Mode"
        case foodie = "Foodie Fun"
        case rustic = "Rustic Charm"

        var emoji: String {
            switch self {
            case .homeCook: return "🏠"
            case .chefMode: return "👨‍🍳"
            case .foodie: return "🤤"
            case .rustic: return "🌾"
            }
        }

        var description: String {
            switch self {
            case .homeCook: return "Warm & inviting"
            case .chefMode: return "Professional & clean"
            case .foodie: return "Bold & exciting"
            case .rustic: return "Natural & cozy"
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
                            afterPhoto: $afterPhoto,
                            selectedStyle: selectedStyle,
                            animationPhase: animationPhase,
                            showingCamera: $showingCamera
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                        // Take After Photo Button - styled like MagneticButton
                        MagneticButton(
                            title: afterPhoto != nil ? "Update after photo ✓" : "Take your after photo",
                            icon: "camera.fill",
                            action: {
                                showingCamera = true
                            }
                        )
                        .padding(.horizontal, 20)

                        // Share for Credits Button
                        MagneticButton(
                            title: "Share for Credits",
                            icon: "sparkles",
                            action: generateShareImage
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Create Share")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing:
                Button("Done") {
                    // Dismiss action
                }
                .foregroundColor(Color(hex: "#667eea"))
            )
            .overlay(alignment: .center) {
                if isGenerating || isUploadingToCloudKit {
                    ShareGenerationOverlay(
                        title: isUploadingToCloudKit ? "Syncing your creation..." : "Building your share card..."
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .overlay(alignment: .top) {
                if showShareReadyMoment {
                    ShareReadyMomentCard()
                        .padding(.top, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .sheet(isPresented: $shareSheet) {
            if let image = generatedImage {
                GeneratorShareSheet(items: buildShareItems(image: image))
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            AfterPhotoCaptureView(
                afterPhoto: $afterPhoto,
                recipeID: recipe.id.uuidString
            )
        }
        .onAppear {
            print("🔍 DEBUG: ShareGeneratorView appeared")
            // Fast spin that slows down to 30 degrees
            withAnimation(.easeOut(duration: 1.0)) {
                animationPhase = 0.0833 // 30 degrees / 360 degrees = 0.0833
            }
        }
    }

    private func generateShareImage() {
        isGenerating = true
        isUploadingToCloudKit = true

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // First upload recipe to CloudKit
        Task {
            do {
                // Create image data from the after photo if available
                let imageData = afterPhoto?.jpegData(compressionQuality: 0.8)

                // Upload recipe to CloudKit
                let recordID = try await cloudKitSync.uploadRecipeForSharing(recipe, imageData: imageData)
                cloudKitRecordID = recordID

                // Generate shareable URL
                shareURL = socialShareManager.generateUniversalLink(for: recipe, cloudKitRecordID: recordID)

                await MainActor.run {
                    isUploadingToCloudKit = false

                    // Create the share image
                    let shareContent = ShareImageContent(
                        recipe: recipe,
                        ingredientsPhoto: ingredientsPhoto,
                        afterPhoto: afterPhoto,
                        style: selectedStyle
                    )

                    let renderer = ImageRenderer(content: shareContent)
                    renderer.scale = 3.0 // High quality

                    if let uiImage = renderer.uiImage {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            generatedImage = uiImage
                            isGenerating = false
                        }

                        // Auto-navigate to share sheet after generation
                        Task { @MainActor in
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.76)) {
                                showShareReadyMoment = true
                            }
                            try await Task.sleep(nanoseconds: 800_000_000)
                            withAnimation(.easeOut(duration: 0.28)) {
                                showShareReadyMoment = false
                            }
                            try await Task.sleep(nanoseconds: 220_000_000)
                            shareSheet = true

                            // Award coins for sharing
                            ChefCoinsManager.shared.awardSocialCoins(action: .share)

                            // Track social share streak
                            await StreakManager.shared.recordActivity(for: .socialShare)

                            // Post notification for recipe sharing
                            NotificationCenter.default.post(
                                name: Notification.Name("RecipeShared"),
                                object: nil,
                                userInfo: ["recipeId": recipe.id]
                            )

                            // Create activity for recipe sharing
                            if let userID = UnifiedAuthManager.shared.currentUser?.recordID {
                                do {
                                    try await CloudKitService.shared.createActivity(
                                        type: "recipeShared",
                                        actorID: userID,
                                        recipeID: recipe.id.uuidString,
                                        recipeName: recipe.name
                                    )
                                } catch {
                                    print("Failed to create recipe share activity: \(error)")
                                }
                            }
                            
                            // Track social challenge progress
                            ChallengeProgressTracker.shared.trackAction(.recipeShared, metadata: [
                                "recipeId": recipe.id,
                                "recipeName": recipe.name,
                                "style": selectedStyle.rawValue,
                                "cloudKitRecordID": recordID
                            ])
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    isUploadingToCloudKit = false
                    print("Failed to upload recipe to CloudKit: \(error)")
                    // Still generate the share image even if CloudKit upload fails
                    generateLocalShareImage()
                }
            }
        }
    }

    private func generateLocalShareImage() {
        // Fallback for when CloudKit upload fails
        let shareContent = ShareImageContent(
            recipe: recipe,
            ingredientsPhoto: ingredientsPhoto,
            afterPhoto: afterPhoto,
            style: selectedStyle
        )

        let renderer = ImageRenderer(content: shareContent)
        renderer.scale = 3.0

        if let uiImage = renderer.uiImage {
            generatedImage = uiImage
            withAnimation(.spring(response: 0.45, dampingFraction: 0.76)) {
                showShareReadyMoment = true
            }
            Task { @MainActor in
                try await Task.sleep(nanoseconds: 700_000_000)
                withAnimation(.easeOut(duration: 0.26)) {
                    showShareReadyMoment = false
                }
                try await Task.sleep(nanoseconds: 200_000_000)
                shareSheet = true
            }
        }
    }

    private func generateShareText() -> String {
        var text = """
        🔥 MY FRIDGE CHALLENGE 🔥

        I just turned these random ingredients into \(recipe.name)!

        ⏱ Ready in just \(recipe.prepTime + recipe.cookTime) minutes
        🎯 Difficulty: \(recipe.difficulty.emoji) \(recipe.difficulty.rawValue.capitalized)
        """

        if let shareURL = shareURL {
            text += """


            👨‍🍳 Get the full recipe here:
            \(shareURL.absoluteString)
            """
        }

        text += """


        Think you can beat my fridge game?
        Download SnapChef and show me what you got!

        #FridgeChallenge #SnapChef #CookingMagic
        """

        return text
    }

    private func buildShareItems(image: UIImage) -> [Any] {
        var items: [Any] = [image]

        // Add the share URL if available
        if let shareURL = shareURL {
            items.append(shareURL)
        }

        // Add the share text
        items.append(generateShareText())

        return items
    }
}

// MARK: - Share Preview Section
struct SharePreviewSection: View {
    let recipe: Recipe
    let ingredientsPhoto: UIImage?
    @Binding var afterPhoto: UIImage?
    let selectedStyle: ShareGeneratorView.ShareStyle
    let animationPhase: Double
    @Binding var showingCamera: Bool

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
                        afterPhoto: afterPhoto,
                        style: selectedStyle
                    )
                    .scaleEffect(0.85)
                    .rotation3DEffect(
                        .degrees(animationPhase * 360), // Will be 15 degrees when animationPhase = 0.0417
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )
                    .onTapGesture {
                        // Check if tap is on the after photo area
                        // For simplicity, just open camera when tapping anywhere on preview
                        showingCamera = true
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.width * 1.4)
            }
            .aspectRatio(1 / 1.4, contentMode: .fit)
        }
    }
}

// MARK: - Share Image Content
struct ShareImageContent: View {
    let recipe: Recipe
    let ingredientsPhoto: UIImage?
    let afterPhoto: UIImage?
    let style: ShareGeneratorView.ShareStyle

    @State private var customChefName: String = UserDefaults.standard.string(forKey: "CustomChefName") ?? ""
    @State private var customPhotoData: Data? = SharePhotoHelper.loadCustomPhotoFromFile()

    var backgroundGradient: LinearGradient {
        switch style {
        case .homeCook:
            return LinearGradient(
                colors: [
                    Color(hex: "#ff9966"),
                    Color(hex: "#ff5e62")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .chefMode:
            return LinearGradient(
                colors: [
                    Color(hex: "#2c3e50"),
                    Color(hex: "#34495e")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .foodie:
            return LinearGradient(
                colors: [
                    Color(hex: "#fc466b"),
                    Color(hex: "#3f5efb")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .rustic:
            return LinearGradient(
                colors: [
                    Color(hex: "#8b6f47"),
                    Color(hex: "#6b8e23")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
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
                ForEach(0..<20) { _ in
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

                            if let photo = afterPhoto {
                                Image(uiImage: photo)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 140, height: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            } else {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white.opacity(0.5))
                            }

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

                // App branding with custom chef info
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        // Custom chef photo or default
                        if let photoData = customPhotoData,
                           let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(textColor.opacity(0.3), lineWidth: 2)
                                )
                        } else {
                            Circle()
                                .fill(textColor.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(customChefName.isEmpty ? "SC" : customChefName.prefix(1).uppercased())
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(textColor)
                                )
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Made by \(customChefName.isEmpty ? "SnapChef" : customChefName)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(textColor.opacity(0.8))

                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12, weight: .bold))
                                Text("SnapChef")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(textColor)
                        }
                    }
                }
                .padding(.bottom, 30)
            }
            .padding(.top, 40)
        }
        .frame(width: 350, height: 490)
        .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
    }

    var textColor: Color {
        switch style {
        case .chefMode:
            return Color(hex: "#ecf0f1")
        default:
            return .white
        }
    }
}

private struct ShareGenerationOverlay: View {
    let title: String
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#4facfe").opacity(0.24))
                    .frame(width: pulse ? 88 : 72, height: pulse ? 88 : 72)
                    .blur(radius: pulse ? 10 : 5)

                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.2)
            }

            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.94))
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct ShareReadyMomentCard: View {
    @State private var glow = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .bold))
            Text("Share card ready")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color(hex: "#38f9d7").opacity(glow ? 0.45 : 0.2), radius: glow ? 18 : 8, y: 6)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                glow = true
            }
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

// MARK: - Share Sheet
struct GeneratorShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Photo Storage Helper
struct SharePhotoHelper {
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
    ShareGeneratorView(
        recipe: MockDataProvider.shared.mockRecipe(),
        ingredientsPhoto: nil
    )
}
