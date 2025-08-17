//
//  MessageCardGenerator.swift
//  SnapChef
//
//  Created on 02/03/2025
//

import SwiftUI
import UIKit

@MainActor
class MessageCardGenerator: ObservableObject {
    static let shared = MessageCardGenerator()

    private let cardSize = CGSize(width: 600, height: 800) // High resolution for Messages

    func generateCard(
        for content: ShareContent,
        style: MessageCardStyle
    ) async throws -> UIImage {
        switch style {
        case .rotating:
            return try await generateRotatingCard(content: content)
        case .flip:
            return try await generateFlipCard(content: content)
        case .stack:
            return try await generateStackCard(content: content)
        case .carousel:
            return try await generateCarouselCard(content: content)
        }
    }

    private func generateRotatingCard(content: ShareContent) async throws -> UIImage {
        // Create a composite image showing both sides
        let compositeView = RotatingCardComposite(content: content)

        let renderer = ImageRenderer(content: compositeView)
        renderer.scale = 2.0 // High quality

        guard let image = renderer.uiImage else {
            throw MessageError.renderingFailed
        }

        return image
    }

    private func generateFlipCard(content: ShareContent) async throws -> UIImage {
        let flipView = FlipCardView(content: content)

        let renderer = ImageRenderer(
            content: flipView
                .frame(width: cardSize.width, height: cardSize.height)
        )
        renderer.scale = 2.0

        guard let image = renderer.uiImage else {
            throw MessageError.renderingFailed
        }

        return image
    }

    private func generateStackCard(content: ShareContent) async throws -> UIImage {
        let stackView = StackCardView(content: content)

        let renderer = ImageRenderer(
            content: stackView
                .frame(width: cardSize.width, height: cardSize.height)
        )
        renderer.scale = 2.0

        guard let image = renderer.uiImage else {
            throw MessageError.renderingFailed
        }

        return image
    }

    private func generateCarouselCard(content: ShareContent) async throws -> UIImage {
        let carouselView = CarouselCardView(content: content)

        let renderer = ImageRenderer(
            content: carouselView
                .frame(width: cardSize.width, height: cardSize.height)
        )
        renderer.scale = 2.0

        guard let image = renderer.uiImage else {
            throw MessageError.renderingFailed
        }

        return image
    }
}

// MARK: - Card Styles
struct RotatingCardComposite: View {
    let content: ShareContent

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(hex: "#667eea"),
                    Color(hex: "#764ba2")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 40) {
                // Title
                Text("Tap to Rotate")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                // Cards in perspective
                HStack(spacing: -100) {
                    // Before card (rotated left)
                    SingleCard(content: content, isFront: true)
                        .rotation3DEffect(
                            .degrees(-25),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.5
                        )
                        .scaleEffect(0.9)
                        .offset(x: -20)

                    // After card (rotated right)
                    SingleCard(content: content, isFront: false)
                        .rotation3DEffect(
                            .degrees(25),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.5
                        )
                        .scaleEffect(0.9)
                        .offset(x: 20)
                        .zIndex(1)
                }

                // Instructions
                Text("Interactive 3D Card")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .frame(width: 600, height: 800)
    }
}

struct FlipCardView: View {
    let content: ShareContent

    var body: some View {
        ZStack {
            // Background
            Color(hex: "#007AFF")

            VStack(spacing: 30) {
                if case .recipe(let recipe) = content.type {
                    Text(recipe.name)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    // Flip indicator
                    ZStack {
                        // Front preview
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 300, height: 400)
                            .overlay(
                                VStack {
                                    Text("BEFORE")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)

                                    Image(systemName: "refrigerator")
                                        .font(.system(size: 80))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            )

                        // Flip arrow
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(width: 80, height: 80)
                            )
                            .offset(x: 150, y: 0)
                    }

                    Text("Tap to flip and see the result!")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
    }
}

struct StackCardView: View {
    let content: ShareContent

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(hex: "#43e97b"),
                    Color(hex: "#38f9d7")
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 30) {
                if case .recipe(let recipe) = content.type {
                    Text(recipe.name)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    // Stacked cards effect
                    ZStack {
                        ForEach(0..<3) { index in
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    Color.white.opacity(0.9 - Double(index) * 0.2)
                                )
                                .frame(width: 280 - CGFloat(index * 20),
                                       height: 380 - CGFloat(index * 20))
                                .offset(y: CGFloat(index * 15))
                                .rotationEffect(.degrees(Double(index * 5)))
                        }

                        // Top card content
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                            .frame(width: 280, height: 380)
                            .overlay(
                                VStack(spacing: 20) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 60))
                                        .foregroundColor(Color(hex: "#43e97b"))

                                    Text("Recipe Stack")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(.black)

                                    Text("Swipe through steps")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)
                                }
                            )
                    }

                    HStack(spacing: 20) {
                        Label("\(recipe.prepTime + recipe.cookTime) min", systemImage: "clock")
                        Label("\(recipe.servings) servings", systemImage: "person.2")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                }
            }
        }
    }
}

struct CarouselCardView: View {
    let content: ShareContent

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(hex: "#FF6B6B"),
                    Color(hex: "#FFE66D")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 30) {
                if case .recipe(let recipe) = content.type {
                    Text(recipe.name)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    // Carousel preview
                    HStack(spacing: -50) {
                        ForEach(0..<3) { index in
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .frame(width: 200, height: 300)
                                .overlay(
                                    VStack {
                                        Text(cardTitle(for: index))
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.black)

                                        Image(systemName: cardIcon(for: index))
                                            .font(.system(size: 50))
                                            .foregroundColor(Color(hex: "#FF6B6B"))
                                            .padding(.top, 20)
                                    }
                                )
                                .scaleEffect(index == 1 ? 1.1 : 0.9)
                                .zIndex(index == 1 ? 1 : 0)
                                .opacity(index == 1 ? 1 : 0.7)
                        }
                    }

                    // Dots indicator
                    HStack(spacing: 8) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(index == 1 ? Color.white : Color.white.opacity(0.5))
                                .frame(width: 8, height: 8)
                        }
                    }

                    Text("Swipe to explore")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
    }

    private func cardTitle(for index: Int) -> String {
        switch index {
        case 0: return "Ingredients"
        case 1: return "Recipe"
        case 2: return "Result"
        default: return ""
        }
    }

    private func cardIcon(for index: Int) -> String {
        switch index {
        case 0: return "cart"
        case 1: return "book"
        case 2: return "star.fill"
        default: return "questionmark"
        }
    }
}

struct SingleCard: View {
    let content: ShareContent
    let isFront: Bool

    var body: some View {
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
            .frame(width: 250, height: 350)
            .overlay(
                VStack(spacing: 20) {
                    Text(isFront ? "BEFORE" : "AFTER")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))

                    Image(systemName: isFront ? "refrigerator" : "fork.knife.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.7))

                    if case .recipe(let recipe) = content.type {
                        Text(recipe.name)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
            )
            .shadow(radius: 10)
    }
}

// MARK: - Errors
enum MessageError: LocalizedError {
    case renderingFailed
    case messageServiceUnavailable

    var errorDescription: String? {
        switch self {
        case .renderingFailed:
            return "Failed to generate message card"
        case .messageServiceUnavailable:
            return "Messages app is not available"
        }
    }
}
