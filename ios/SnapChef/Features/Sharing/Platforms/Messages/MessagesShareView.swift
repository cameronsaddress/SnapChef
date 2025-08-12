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
    @State private var selectedCardStyle: MessageCardStyle = .rotating
    @State private var messageText = ""
    @State private var isGenerating = false
    @State private var generatedCard: UIImage?
    @State private var rotationAngle: Double = 0
    @State private var showingFront = true
    @State private var autoRotateEnabled = true
    @State private var showingMessageComposer = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Messages app-inspired gradient
                LinearGradient(
                    colors: [
                        Color(hex: "#007AFF"),
                        Color(hex: "#0051D5")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "message.fill")
                                    .font(.system(size: 24, weight: .bold))
                                Text("Share via Messages")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            
                            Text("Send an interactive recipe card")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.top, 20)
                        
                        // Rotating Card Preview
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Interactive Card")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Toggle("Auto-rotate", isOn: $autoRotateEnabled)
                                    .toggleStyle(SwitchToggleStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            RotatingCardView(
                                content: content,
                                showingFront: $showingFront,
                                autoRotate: autoRotateEnabled
                            )
                            .frame(height: 400)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    showingFront.toggle()
                                }
                            }
                            
                            Text("Tap card to flip • Recipients can interact with it")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 20)
                        
                        // Card Style Selection
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Card Style")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(MessageCardStyle.allCases, id: \.self) { style in
                                        MessageStyleCard(
                                            style: style,
                                            isSelected: selectedCardStyle == style,
                                            action: {
                                                selectedCardStyle = style
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Message Text
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Message")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            TextEditor(text: $messageText)
                                .frame(height: 100)
                                .padding(12)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                                .scrollContentBackground(.hidden)
                                .onAppear {
                                    if messageText.isEmpty {
                                        messageText = generateMessageText()
                                    }
                                }
                        }
                        .padding(.horizontal, 20)
                        
                        // Features List
                        VStack(spacing: 12) {
                            MessageFeatureRow(
                                icon: "cube.transparent",
                                title: "3D Effect",
                                subtitle: "Interactive rotating card"
                            )
                            
                            MessageFeatureRow(
                                icon: "camera.on.rectangle",
                                title: "Before & After",
                                subtitle: "Shows ingredient transformation"
                            )
                            
                            MessageFeatureRow(
                                icon: "hand.tap",
                                title: "Interactive",
                                subtitle: "Recipients can tap to explore"
                            )
                            
                            MessageFeatureRow(
                                icon: "sparkles",
                                title: "Animated",
                                subtitle: "Smooth transitions and effects"
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // Send Button
                        Button(action: sendMessage) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                                    .frame(height: 56)
                                
                                if isGenerating {
                                    HStack(spacing: 12) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#007AFF")))
                                        Text("Preparing...")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(Color(hex: "#007AFF"))
                                    }
                                } else {
                                    HStack(spacing: 8) {
                                        Image(systemName: "message.fill")
                                        Text("Send Message")
                                    }
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(hex: "#007AFF"))
                                }
                            }
                        }
                        .disabled(isGenerating)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
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
        .sheet(isPresented: $showingMessageComposer) {
            MessageComposerWrapper(
                messageText: messageText,
                image: generatedCard,
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
    
    private func sendMessage() {
        isGenerating = true
        
        Task {
            do {
                // Generate the card image
                let card = try await MessageCardGenerator.shared.generateCard(
                    for: content,
                    style: selectedCardStyle
                )
                
                await MainActor.run {
                    generatedCard = card
                    isGenerating = false
                    
                    // Check if Messages is available
                    if MFMessageComposeViewController.canSendText() {
                        showingMessageComposer = true
                    } else {
                        // Fallback: Save to photos with permission handling
                        saveImageToPhotoLibrary(card)
                        errorMessage = "Messages not available. Card will be saved to Photos."
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isGenerating = false
                }
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
            DispatchQueue.main.async { [parent] in
                parent.onDismiss()
            }
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