//
//  BrandedSharePopup.swift
//  SnapChef
//
//  Created on 02/03/2025
//

import SwiftUI
import Combine

struct BrandedSharePopup: View {
    @StateObject private var shareService = ShareService.shared
    @State private var selectedPlatform: SharePlatformType?
    @State private var showingPlatformView = false
    @State private var animationScale: CGFloat = 0.8
    @State private var animationOpacity: Double = 0
    @Environment(\.dismiss) var dismiss

    let content: ShareContent

    // Platform grid layout - 3 columns for better visibility
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    // Show all major platforms for consistent experience
    private var displayPlatforms: [SharePlatformType] {
        // Always show these platforms, regardless of installation
        // Users expect to see them and we'll handle fallbacks
        return [
            .tiktok,
            .instagram,
            .instagramStory,
            .twitter,
            .whatsapp,
            .messages,
            .copy,
            .more
        ]
    }

    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dismiss()
                    }
                }

            // Popup content
            VStack(spacing: 0) {
                // Handle bar
                Capsule()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                // Title
                Text("Share your creation")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.bottom, 8)

                // Subtitle
                Text("Choose where to share your masterpiece")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 24)

                // Platform grid
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(displayPlatforms, id: \.self) { platform in
                        PlatformButton(
                            platform: platform,
                            isSelected: selectedPlatform == platform,
                            action: {
                                handlePlatformSelection(platform)
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)

                // Cancel button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dismiss()
                    }
                }) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(radius: 20)
            )
            .padding(.horizontal, 16)
            .scaleEffect(animationScale)
            .opacity(animationOpacity)
            .onAppear {
                print("🔍 DEBUG: BrandedSharePopup appeared")
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    animationScale = 1.0
                    animationOpacity = 1.0
                }
            }
        }
        .sheet(isPresented: $showingPlatformView) {
            if let platform = selectedPlatform {
                platformSpecificView(for: platform)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DismissSharePopup"))) { _ in
            dismiss()
        }
    }

    private func handlePlatformSelection(_ platform: SharePlatformType) {
        selectedPlatform = platform

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Check if app is available or use fallback
        if platform.isAvailable || shouldShowCustomView(platform) {
            // Handle platform-specific actions
            switch platform {
            case .tiktok, .instagram, .instagramStory:
                // Show platform-specific view (works even if app not installed)
                showingPlatformView = true

            case .twitter:
                // Show X-specific view
                showingPlatformView = true

            case .facebook, .whatsapp:
                // Try direct share or fallback to web
                Task {
                    await shareService.share(to: platform)
                    if !platform.isAvailable {
                        // Show instructions or web fallback
                        showWebFallback(for: platform)
                    } else {
                        dismiss()
                    }
                }

            case .messages:
                // Show message composer
                showingPlatformView = true

            case .copy:
                // Direct copy to clipboard
                Task {
                    await shareService.share(to: platform)
                    
                    // Create activity for content sharing via copy
                    await createShareActivity(platform: platform)
                    
                    dismiss()
                }

            case .more:
                // Show system share sheet
                Task {
                    await shareService.share(to: platform)
                    
                    // Create activity for content sharing
                    await createShareActivity(platform: platform)
                }
            }
        } else {
            // Platform not available and no custom view - use web fallback
            showWebFallback(for: platform)
        }
    }

    private func shouldShowCustomView(_ platform: SharePlatformType) -> Bool {
        // These platforms have custom views that work even without the app
        switch platform {
        case .tiktok, .instagram, .instagramStory, .twitter, .messages:
            return true
        default:
            return false
        }
    }

    private func showWebFallback(for platform: SharePlatformType) {
        // Open web version or show instructions
        // This will be handled by ShareService
        Task {
            await shareService.share(to: platform)
        }
    }

    @ViewBuilder
    private func platformSpecificView(for platform: SharePlatformType) -> some View {
        switch platform {
        case .tiktok:
            TikTokShareView(content: content)  // Use the template selection view
        case .instagram:
            InstagramShareView(content: content, isStory: false)
        case .instagramStory:
            InstagramShareView(content: content, isStory: true)
        case .twitter:
            XShareView(content: content)
        case .messages:
            MessagesShareView(content: content)
        default:
            EmptyView()
        }
    }
    
    // MARK: - Activity Creation
    private func createShareActivity(platform: SharePlatformType) async {
        guard CloudKitAuthManager.shared.isAuthenticated,
              let userID = CloudKitAuthManager.shared.currentUser?.recordID,
              let userName = CloudKitAuthManager.shared.currentUser?.displayName else {
            return
        }
        
        var activityType = "contentShared"
        var metadata: [String: Any] = ["platform": platform.rawValue]
        
        // Determine content type and add specific metadata
        switch content.type {
        case .recipe(let recipe):
            activityType = "recipeShared"
            metadata["recipeId"] = recipe.id.uuidString
            metadata["recipeName"] = recipe.name
        case .achievement(let achievementName):
            activityType = "achievementShared"
            metadata["achievementName"] = achievementName
        case .challenge(let challenge):
            activityType = "challengeShared"
            metadata["challengeId"] = challenge.id
            metadata["challengeName"] = challenge.title
        case .profile:
            activityType = "profileShared"
        case .teamInvite(let teamName, let joinCode):
            activityType = "teamInviteShared"
            metadata["teamName"] = teamName
            metadata["joinCode"] = joinCode
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
            print("Failed to create share activity: \(error)")
        }
    }
}

// MARK: - Platform Button
struct PlatformButton: View {
    let platform: SharePlatformType
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Icon container
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    platform.brandColor.opacity(0.8),
                                    platform.brandColor
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(
                            color: platform.brandColor.opacity(0.3),
                            radius: isPressed ? 2 : 8,
                            y: isPressed ? 1 : 4
                        )

                    Image(systemName: platform.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
                .scaleEffect(isPressed ? 0.95 : 1.0)

                // Platform name
                Text(platform.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}

// MARK: - Preview
#Preview {
    BrandedSharePopup(
        content: ShareContent(
            type: .recipe(MockDataProvider.shared.mockRecipe())
        )
    )
}
