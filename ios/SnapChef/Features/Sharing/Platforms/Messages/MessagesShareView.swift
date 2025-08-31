//
//  MessagesShareView.swift
//  SnapChef
//
//  Created on 02/03/2025
//

import SwiftUI
import UIKit
import MessageUI
import Photos

struct MessagesShareView: View {
    let content: ShareContent
    @Environment(\.dismiss) var dismiss
    @State private var isGenerating = true  // Start generating immediately
    @State private var generatedImage: UIImage?
    @State private var showingMessageComposer = false
    @State private var errorMessage: String?
    @State private var autoShare = true  // Auto-share on appear

    var body: some View {
        NavigationStack {
            ZStack {
                // Show loading overlay when auto-sharing
                if autoShare && isGenerating {
                    Color.black.opacity(0.8)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("Creating your message...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(40)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.9))
                    )
                } else {
                    // Clean white background like Instagram
                    Color(UIColor.systemBackground)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                    // Header with X button
                    VStack(spacing: 16) {
                        HStack {
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(width: 30, height: 30)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                Image(systemName: "message.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "#34C759"))
                                Text("Share to Messages")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            // Invisible spacer for balance
                            Color.clear
                                .frame(width: 30, height: 30)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                    .background(Color(UIColor.systemBackground))
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // Large Preview (matching Instagram style)
                            VStack(spacing: 12) {
                                Text("Preview")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Preview with shadow - show generated image or placeholder
                                ZStack {
                                    if let image = generatedImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                    } else {
                                        // Loading state
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color(UIColor.secondarySystemBackground))
                                            .overlay(
                                                VStack(spacing: 12) {
                                                    ProgressView()
                                                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#34C759")))
                                                    Text("Generating preview...")
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.secondary)
                                                }
                                            )
                                    }
                                }
                                .frame(height: UIScreen.main.bounds.height * 0.5)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(UIColor.systemBackground))
                                        .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
                                )
                            }
                            .padding(.horizontal, 20)


                            // Send Button with green Messages theme
                            VStack(spacing: 8) {
                                Button(action: sendMessage) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color(hex: "#34C759"),
                                                        Color(hex: "#30D158")
                                                    ],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(height: 56)

                                        if isGenerating {
                                            HStack(spacing: 12) {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                Text("Generating...")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.white)
                                            }
                                        } else {
                                            HStack(spacing: 8) {
                                                Image(systemName: "message.fill")
                                                Text("Send via Messages")
                                            }
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                        }
                                    }
                                }
                                .disabled(isGenerating)
                                
                                Text("Will open Messages app with your card attached")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                        }
                    }
                }
                }  // Close the else block for loading overlay
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingMessageComposer) {
                MessageComposerWrapper(
                    messageText: generateMessageText(),
                    image: generatedImage,
                    content: content,
                    onDismiss: {
                        showingMessageComposer = false
                    }
                )
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .onAppear {
                print("🔍 DEBUG: MessagesShareView appeared")
                
                // Auto-generate and share when opened
                if autoShare {
                    generateImage()
                    
                    // After image is generated, automatically open Messages
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if generatedImage != nil && !showingMessageComposer {
                            sendMessage()
                        }
                    }
                }
            }
        }
    }
    
    private func generateMessageText() -> String {
        guard case .recipe(let recipe) = content.type else {
            return "Check out what I made with SnapChef! 🍳"
        }

        return """
        Look what I made! 🎉

        \(recipe.name)

        Tap the card to see the before & after transformation!

        Made with SnapChef - the AI that turns your fridge into amazing recipes ✨
        """
    }

    private func generateImage() {
        guard generatedImage == nil else { return } // Don't regenerate if already exists
        
        isGenerating = true
        
        Task {
            do {
                // Generate image using Instagram's content generator (same as Stories)
                let image = try await InstagramContentGenerator.shared.generateContent(
                    template: .modern, // Use modern template
                    content: content,
                    isStory: true, // Use story format (9:16 ratio)
                    backgroundColor: Color(hex: "#34C759"), // Messages green
                    sticker: nil
                )
                
                await MainActor.run {
                    self.generatedImage = image
                    self.isGenerating = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isGenerating = false
                }
            }
        }
    }
    
    private func sendMessage() {
        // Check if Messages is available
        if MFMessageComposeViewController.canSendText() {
            showingMessageComposer = true
        } else {
            // Fallback: Save to photos
            if let image = generatedImage {
                saveImageToPhotoLibrary(image)
                errorMessage = "Messages not available. Image will be saved to Photos."
            }
        }
    }

    private func saveImageToPhotoLibrary(_ image: UIImage) {
        // Check current authorization status first
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        switch status {
        case .authorized, .limited:
            // Already have permission, save the image
            PHPhotoLibrary.shared().performChanges({
                _ = PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                if success {
                    DispatchQueue.main.async {
                        self.errorMessage = "Card saved to Photos successfully!"
                    }
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to save: \(error?.localizedDescription ?? "Unknown error")"
                    }
                }
            }

        case .notDetermined:
            // Need to request permission
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    PHPhotoLibrary.shared().performChanges({
                        _ = PHAssetChangeRequest.creationRequestForAsset(from: image)
                    }) { success, error in
                        DispatchQueue.main.async {
                            if success {
                                self.errorMessage = "Card saved to Photos successfully!"
                            } else {
                                self.errorMessage = "Failed to save: \(error?.localizedDescription ?? "Unknown error")"
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Photo library access denied. Please enable in Settings."
                    }
                }
            }

        case .denied, .restricted:
            errorMessage = "Photo library access denied. Please enable in Settings > Privacy > Photos."

        @unknown default:
            errorMessage = "Unable to access photo library."
        }
    }
    
    // MARK: - Activity Creation
    private func createMessagesShareActivity() async {
        guard UnifiedAuthManager.shared.isAuthenticated,
              let userID = UnifiedAuthManager.shared.currentUser?.recordID else {
            return
        }
        
        var activityType = "messagesCardShared"
        var metadata: [String: Any] = ["platform": "messages"]
        
        // Add content-specific metadata
        switch content.type {
        case .recipe(let recipe):
            activityType = "recipeMessagesCardShared"
            metadata["recipeId"] = recipe.id.uuidString
            metadata["recipeName"] = recipe.name
        case .achievement(let achievementName):
            activityType = "achievementMessagesCardShared"
            metadata["achievementName"] = achievementName
        case .challenge(let challenge):
            activityType = "challengeMessagesCardShared"
            metadata["challengeId"] = challenge.id
            metadata["challengeName"] = challenge.title
        case .profile:
            activityType = "profileMessagesCardShared"
        case .teamInvite(let teamName, let joinCode):
            activityType = "teamInviteMessagesCardShared"
            metadata["teamName"] = teamName
            metadata["joinCode"] = joinCode
        case .leaderboard:
            activityType = "leaderboardMessagesCardShared"
        }
        
        do {
            try await CloudKitSyncService.shared.createActivity(
                type: activityType,
                actorID: userID,
                recipeID: metadata["recipeId"] as? String,
                recipeName: metadata["recipeName"] as? String,
                challengeID: metadata["challengeId"] as? String,
                challengeName: metadata["challengeName"] as? String
            )
        } catch {
            print("Failed to create Messages share activity: \(error)")
        }
    }
}

// MARK: - Supporting Types
enum MessageCardStyle: String, CaseIterable {
    case rotating = "Rotating"
    case flip = "Flip"
    case stack = "Stack"
    case carousel = "Carousel"

    var icon: String {
        switch self {
        case .rotating: return "rotate.3d"
        case .flip: return "rectangle.portrait.rotate"
        case .stack: return "square.stack.3d.up"
        case .carousel: return "rectangle.stack"
        }
    }

    var description: String {
        switch self {
        case .rotating:
            return "3D rotating card"
        case .flip:
            return "Tap to flip"
        case .stack:
            return "Layered stack"
        case .carousel:
            return "Swipeable cards"
        }
    }
}

// MARK: - Components
struct RotatingCardView: View {
    let content: ShareContent
    @Binding var showingFront: Bool
    let autoRotate: Bool
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Back card (After photo)
            CardSide(
                content: content,
                isFront: false,
                rotation: rotation
            )
            .opacity(showingFront ? 0 : 1)
            .rotation3DEffect(
                .degrees(showingFront ? 180 : 0),
                axis: (x: 0, y: 1, z: 0)
            )

            // Front card (Before photo)
            CardSide(
                content: content,
                isFront: true,
                rotation: rotation
            )
            .opacity(showingFront ? 1 : 0)
            .rotation3DEffect(
                .degrees(showingFront ? 0 : -180),
                axis: (x: 0, y: 1, z: 0)
            )
        }
        .rotation3DEffect(
            .degrees(rotation),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
        .onAppear {
            if autoRotate {
                withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
        }
        .onChange(of: autoRotate) { newValue in
            if newValue {
                withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            } else {
                withAnimation(.default) {
                    rotation = 0
                }
            }
        }
    }
}

struct CardSide: View {
    let content: ShareContent
    let isFront: Bool
    let rotation: Double

    var body: some View {
        ZStack {
            // Card background
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: isFront ?
                            [Color(hex: "#667eea"), Color(hex: "#764ba2")] :
                            [Color(hex: "#43e97b"), Color(hex: "#38f9d7")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(radius: 20)

            VStack(spacing: 20) {
                // Title
                Text(isFront ? "BEFORE" : "AFTER")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.8))

                if case .recipe(let recipe) = content.type {
                    // Recipe name
                    Text(recipe.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    // Image placeholder
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 180)
                        .overlay(
                            Image(systemName: isFront ? "refrigerator" : "fork.knife.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.5))
                        )
                        .padding(.horizontal, 20)

                    // Stats
                    if !isFront {
                        HStack(spacing: 30) {
                            VStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 20))
                                Text("\(recipe.prepTime + recipe.cookTime)m")
                                    .font(.system(size: 14, weight: .semibold))
                            }

                            VStack(spacing: 4) {
                                Image(systemName: "flame")
                                    .font(.system(size: 20))
                                Text("\(recipe.nutrition.calories)")
                                    .font(.system(size: 14, weight: .semibold))
                            }

                            VStack(spacing: 4) {
                                Image(systemName: "person.2")
                                    .font(.system(size: 20))
                                Text("\(recipe.servings)")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                    }
                }

                // Instruction
                Text(isFront ? "Tap to see the magic ✨" : "Made with SnapChef 🍳")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: 300)
        .frame(height: 380)
    }
}

struct MessageStyleCard: View {
    let style: MessageCardStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: style.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? Color(hex: "#007AFF") : .white)

                Text(style.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? Color(hex: "#007AFF") : .white)

                Text(style.description)
                    .font(.system(size: 10))
                    .foregroundColor((isSelected ? Color(hex: "#007AFF") : .white).opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .frame(width: 100, height: 100)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MessageFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Message Composer Wrapper
struct MessageComposerWrapper: UIViewControllerRepresentable {
    let messageText: String
    let image: UIImage?
    let content: ShareContent
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = context.coordinator
        controller.body = messageText

        if let image = image,
           let imageData = image.pngData() {
            controller.addAttachmentData(imageData, typeIdentifier: "public.png", filename: "recipe_card.png")
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let parent: MessageComposerWrapper

        init(_ parent: MessageComposerWrapper) {
            self.parent = parent
        }

        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            let parentView = parent
            
            // Create activity for successful message sends
            if result == .sent {
                Task { @MainActor in
                    await parentView.createMessagesShareActivity()
                }
            }
            
            DispatchQueue.main.async {
                parentView.onDismiss()
            }
        }
    }
    
    // MARK: - Activity Creation
    func createMessagesShareActivity() async {
        guard UnifiedAuthManager.shared.isAuthenticated,
              let userID = UnifiedAuthManager.shared.currentUser?.recordID else {
            return
        }
        
        var activityType = "messagesCardShared"
        var metadata: [String: Any] = ["platform": "messages"]
        
        // Add content-specific metadata
        switch content.type {
        case .recipe(let recipe):
            activityType = "recipeMessagesCardShared"
            metadata["recipeId"] = recipe.id.uuidString
            metadata["recipeName"] = recipe.name
        case .achievement(let achievementName):
            activityType = "achievementMessagesCardShared"
            metadata["achievementName"] = achievementName
        case .challenge(let challenge):
            activityType = "challengeMessagesCardShared"
            metadata["challengeId"] = challenge.id
            metadata["challengeName"] = challenge.title
        case .profile:
            activityType = "profileMessagesCardShared"
        case .teamInvite(let teamName, let joinCode):
            activityType = "teamInviteMessagesCardShared"
            metadata["teamName"] = teamName
            metadata["joinCode"] = joinCode
        case .leaderboard:
            activityType = "leaderboardMessagesCardShared"
        }
        
        do {
            try await CloudKitSyncService.shared.createActivity(
                type: activityType,
                actorID: userID,
                recipeID: metadata["recipeId"] as? String,
                recipeName: metadata["recipeName"] as? String,
                challengeID: metadata["challengeId"] as? String,
                challengeName: metadata["challengeName"] as? String
            )
        } catch {
            print("Failed to create Messages share activity: \(error)")
        }
    }
}

// MARK: - Preview
#Preview {
    MessagesShareView(
        content: ShareContent(
            type: .recipe(MockDataProvider.shared.mockRecipe())
        )
    )
}
