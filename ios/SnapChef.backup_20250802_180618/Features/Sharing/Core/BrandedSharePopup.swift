//
//  BrandedSharePopup.swift
//  SnapChef
//
//  Created on 02/03/2025
//

import SwiftUI

struct BrandedSharePopup: View {
    @StateObject private var shareService = ShareService.shared
    @State private var selectedPlatform: SharePlatformType?
    @State private var showingPlatformView = false
    @State private var animationScale: CGFloat = 0.8
    @State private var animationOpacity: Double = 0
    @Environment(\.dismiss) var dismiss
    
    let content: ShareContent
    
    // Platform grid layout
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    // Prioritized platforms based on availability
    private var availablePlatforms: [SharePlatformType] {
        SharePlatformType.allCases.filter { platform in
            // Always show system functions
            if platform == .copy || platform == .more || platform == .messages {
                return true
            }
            // Check if app is installed
            return platform.isAvailable
        }
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
                    ForEach(availablePlatforms, id: \.self) { platform in
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
    }
    
    private func handlePlatformSelection(_ platform: SharePlatformType) {
        selectedPlatform = platform
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Handle platform-specific actions
        switch platform {
        case .tiktok, .instagram, .instagramStory:
            // Show platform-specific view
            showingPlatformView = true
            
        case .twitter:
            // Show X-specific view
            showingPlatformView = true
            
        case .facebook, .whatsapp, .copy:
            // Direct share
            Task {
                await shareService.share(to: platform)
                dismiss()
            }
            
        case .messages:
            // Show message composer
            showingPlatformView = true
            
        case .more:
            // Show system share sheet
            Task {
                await shareService.share(to: platform)
            }
        }
    }
    
    @ViewBuilder
    private func platformSpecificView(for platform: SharePlatformType) -> some View {
        switch platform {
        case .tiktok:
            TikTokShareView(content: content)
        case .instagram:
            InstagramShareView(content: content, isStory: false)
        case .instagramStory:
            InstagramShareView(content: content, isStory: true)
        case .twitter:
            XShareView(content: content)
        case .messages:
            MessageShareView(content: content)
        default:
            EmptyView()
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

// MARK: - Platform Specific Views (Placeholders)

// Placeholder for Messages view until fully implemented
struct MessageShareView: View {
    let content: ShareContent
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Message Share")
                    .font(.title)
                Text("Rotating card view coming soon...")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Share via Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
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