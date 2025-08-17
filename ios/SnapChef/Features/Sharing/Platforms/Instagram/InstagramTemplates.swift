//
//  InstagramTemplates.swift
//  SnapChef
//
//  Created on 02/03/2025
//

import SwiftUI

// MARK: - Instagram Template
enum InstagramTemplate: String, CaseIterable {
    case classic = "Classic"
    case modern = "Modern"
    case minimal = "Minimal"
    case bold = "Bold"
    case gradient = "Gradient"

    var name: String {
        return rawValue
    }

    var icon: String {
        switch self {
        case .classic: return "square.grid.2x2"
        case .modern: return "rhombus"
        case .minimal: return "minus"
        case .bold: return "bold"
        case .gradient: return "circle.hexagongrid"
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .classic:
            return LinearGradient(
                colors: [Color(hex: "#833AB4"), Color(hex: "#E1306C")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .modern:
            return LinearGradient(
                colors: [Color(hex: "#F77737"), Color(hex: "#FCAF45")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .minimal:
            return LinearGradient(
                colors: [Color(hex: "#8A8A8A"), Color(hex: "#2B2B2B")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .bold:
            return LinearGradient(
                colors: [Color(hex: "#FD1D1D"), Color(hex: "#833AB4")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .gradient:
            return LinearGradient(
                colors: [
                    Color(hex: "#833AB4"),
                    Color(hex: "#C13584"),
                    Color(hex: "#E1306C")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Sticker Type
enum StickerType: String, CaseIterable {
    case poll = "Poll"
    case question = "Question"
    case location = "Location"
    case mention = "Mention"
    case hashtag = "Hashtag"
    case emoji = "Emoji"
    case custom = "Custom"

    var name: String {
        return rawValue
    }

    var emoji: String {
        switch self {
        case .poll: return "📊"
        case .question: return "❓"
        case .location: return "📍"
        case .mention: return "@"
        case .hashtag: return "#"
        case .emoji: return "😋"
        case .custom: return "✨"
        }
    }

    var text: String {
        switch self {
        case .poll: return "Vote Now!"
        case .question: return "Ask me!"
        case .location: return "My Kitchen"
        case .mention: return "@snapchef"
        case .hashtag: return "#SnapChef"
        case .emoji: return "Yummy!"
        case .custom: return ""
        }
    }
}

// MARK: - Instagram Colors
struct InstagramColors {
    static let all: [Color] = [
        Color(hex: "#833AB4"), // Purple
        Color(hex: "#C13584"), // Pink
        Color(hex: "#E1306C"), // Red-Pink
        Color(hex: "#FD1D1D"), // Red
        Color(hex: "#F77737"), // Orange
        Color(hex: "#FCAF45"), // Yellow-Orange
        Color(hex: "#FFDC80"), // Yellow
        Color(hex: "#5B51D8"), // Blue-Purple
        Color(hex: "#405DE6"), // Blue
        Color(hex: "#12A6E4"), // Light Blue
        Color(hex: "#00D4FF"), // Cyan
        Color(hex: "#25F4EE"), // Teal
        Color.black,
        Color.white
    ]
}

// MARK: - Instagram Preview
struct InstagramPreview: View {
    let content: ShareContent
    let template: InstagramTemplate
    let isStory: Bool
    let backgroundColor: Color
    @State private var animationOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Device frame
            RoundedRectangle(cornerRadius: isStory ? 40 : 20)
                .fill(Color.black)
                .frame(
                    width: isStory ? 200 : 300,
                    height: isStory ? 400 : 300
                )
                .overlay(
                    RoundedRectangle(cornerRadius: isStory ? 40 : 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                )

            // Screen content
            RoundedRectangle(cornerRadius: isStory ? 36 : 16)
                .fill(backgroundColor)
                .frame(
                    width: isStory ? 180 : 280,
                    height: isStory ? 380 : 280
                )
                .overlay(
                    previewContent
                )
        }
        .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: true)) {
                animationOffset = 10
            }
        }
        .offset(y: animationOffset)
    }

    @ViewBuilder
    var previewContent: some View {
        VStack(spacing: 12) {
            if case .recipe(let recipe) = content.type {
                // Header
                HStack {
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("@snapchef")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)

                        Text("My Kitchen")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()

                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                // Content preview
                VStack(spacing: 8) {
                    Text(recipe.name)
                        .font(.system(size: isStory ? 18 : 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    // Mini template preview
                    RoundedRectangle(cornerRadius: 8)
                        .fill(template.gradient.opacity(0.3))
                        .frame(height: isStory ? 200 : 140)
                        .overlay(
                            Text(recipe.difficulty.emoji)
                                .font(.system(size: 40))
                        )
                }
                .padding(.horizontal, 12)

                Spacer()

                // Footer
                if isStory {
                    HStack(spacing: 16) {
                        Image(systemName: "heart")
                        Image(systemName: "message")
                        Image(systemName: "paperplane")
                        Spacer()
                        Image(systemName: "bookmark")
                    }
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        }
    }
}

// MARK: - Preview Helpers
extension InstagramShareView {
    static func previewContent() -> ShareContent {
        ShareContent(
            type: .recipe(MockDataProvider.shared.mockRecipe()),
            beforeImage: UIImage(systemName: "photo"),
            afterImage: UIImage(systemName: "photo.fill")
        )
    }
}
