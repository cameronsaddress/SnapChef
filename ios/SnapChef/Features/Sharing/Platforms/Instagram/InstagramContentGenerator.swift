//
//  InstagramContentGenerator.swift
//  SnapChef
//
//  Created on 02/03/2025
//

import SwiftUI
import UIKit
import CoreGraphics

@MainActor
class InstagramContentGenerator: ObservableObject {
    static let shared = InstagramContentGenerator()

    private let storySize = CGSize(width: 1_080, height: 1_920) // 9:16 for Stories
    private let postSize = CGSize(width: 1_080, height: 1_080) // 1:1 for Posts
    private let carouselSize = CGSize(width: 1_080, height: 1_350) // 4:5 for Carousel

    func generateContent(
        template: InstagramTemplate,
        content: ShareContent,
        isStory: Bool,
        backgroundColor: Color,
        sticker: StickerType?
    ) async throws -> UIImage {
        print("🔍 InstagramContentGenerator.generateContent - template: \(template)")
        print("🔍 InstagramContentGenerator.generateContent - beforeImage: \(content.beforeImage != nil), afterImage: \(content.afterImage != nil)")
        if let before = content.beforeImage {
            print("🔍 InstagramContentGenerator.generateContent - beforeImage size: \(before.size)")
        }
        
        let size = isStory ? storySize : postSize

        // Create the SwiftUI view for the content
        let contentView = InstagramContentView(
            template: template,
            content: content,
            size: size,
            backgroundColor: backgroundColor,
            sticker: sticker,
            isStory: isStory
        )

        // Render to image with proper format
        let renderer = ImageRenderer(content: contentView)
        renderer.scale = 1.0 // Use device scale

        // Configure renderer to produce opaque image
        renderer.isOpaque = true

        guard let renderedImage = renderer.uiImage else {
            throw InstagramError.renderingFailed
        }

        // Ensure the image is in the correct format
        return normalizeRenderedImage(renderedImage)
    }

    func generateCarousel(
        recipe: Recipe,
        images: [UIImage],
        template: InstagramTemplate
    ) async throws -> [UIImage] {
        var carouselImages: [UIImage] = []

        // First slide - Recipe title
        let titleSlide = InstagramCarouselSlide(
            slideType: .title,
            recipe: recipe,
            template: template,
            slideNumber: 1,
            totalSlides: images.count + 3
        )

        if let titleImage = await renderView(titleSlide, size: carouselSize) {
            carouselImages.append(titleImage)
        }

        // Ingredients slide
        let ingredientsSlide = InstagramCarouselSlide(
            slideType: .ingredients,
            recipe: recipe,
            template: template,
            slideNumber: 2,
            totalSlides: images.count + 3
        )

        if let ingredientsImage = await renderView(ingredientsSlide, size: carouselSize) {
            carouselImages.append(ingredientsImage)
        }

        // Instructions slides (can be multiple)
        let instructionsSlide = InstagramCarouselSlide(
            slideType: .instructions,
            recipe: recipe,
            template: template,
            slideNumber: 3,
            totalSlides: images.count + 3
        )

        if let instructionsImage = await renderView(instructionsSlide, size: carouselSize) {
            carouselImages.append(instructionsImage)
        }

        // Final result slide
        if let finalImage = images.first {
            let resultSlide = InstagramCarouselSlide(
                slideType: .result(finalImage),
                recipe: recipe,
                template: template,
                slideNumber: images.count + 3,
                totalSlides: images.count + 3
            )

            if let resultImage = await renderView(resultSlide, size: carouselSize) {
                carouselImages.append(resultImage)
            }
        }

        return carouselImages
    }

    private func renderView<V: View>(_ view: V, size: CGSize) async -> UIImage? {
        let renderer = ImageRenderer(
            content: view
                .frame(width: size.width, height: size.height)
        )
        renderer.scale = 1.0
        renderer.isOpaque = true

        guard let image = renderer.uiImage else { return nil }
        return normalizeRenderedImage(image)
    }

    private func normalizeRenderedImage(_ image: UIImage) -> UIImage {
        // Create a new opaque image context (true = opaque, no alpha channel)
        UIGraphicsBeginImageContextWithOptions(image.size, true, image.scale)
        defer { UIGraphicsEndImageContext() }

        // Fill with white background first
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: image.size))

        // Draw the image on top with normal blend mode
        image.draw(in: CGRect(origin: .zero, size: image.size), blendMode: .normal, alpha: 1.0)

        // Get the normalized image
        guard let normalizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            // If normalization fails, return original
            return image
        }

        return normalizedImage
    }
}

// MARK: - Instagram Content View
struct InstagramContentView: View {
    let template: InstagramTemplate
    let content: ShareContent
    let size: CGSize
    let backgroundColor: Color
    let sticker: StickerType?
    let isStory: Bool
    
    var body: some View {
        let _ = print("🔍 InstagramContentView.body - beforeImage: \(content.beforeImage != nil), afterImage: \(content.afterImage != nil)")
        let _ = print("🔍 InstagramContentView.body - template: \(template)")
        
        return ZStack {
            // Use before/after photos or single photo as background
            if let beforeImage = content.beforeImage {
                let _ = print("🔍 InstagramContentView.body - Using photo background with image size: \(beforeImage.size)")
                if let afterImage = content.afterImage {
                    // Show both before and after photos side by side
                    HStack(spacing: 0) {
                        // Before photo (left half)
                        Image(uiImage: beforeImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size.width / 2, height: size.height)
                            .clipped()
                        
                        // After photo (right half)
                        Image(uiImage: afterImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size.width / 2, height: size.height)
                            .clipped()
                    }
                    .frame(width: size.width, height: size.height)
                    .overlay(
                        // Lighter overlay - reduced by 50% again for even better photo visibility
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.2125),  // Was 0.425, now 0.2125 (50% reduction)
                                Color.black.opacity(0.15),     // Was 0.3, now 0.15 (50% reduction)
                                Color.black.opacity(0.2125)    // Was 0.425, now 0.2125 (50% reduction)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                } else {
                    // Only before photo available
                    Image(uiImage: beforeImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height)
                        .clipped()
                        .overlay(
                            // Lighter overlay - reduced by 50% again for even better photo visibility
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.2125),  // Was 0.425, now 0.2125 (50% reduction)
                                    Color.black.opacity(0.15),     // Was 0.3, now 0.15 (50% reduction)
                                    Color.black.opacity(0.2125)    // Was 0.425, now 0.2125 (50% reduction)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            } else {
                // Fallback to color background
                let _ = print("🔍 InstagramContentView.body - No beforeImage, using color background")
                backgroundColor
                    .ignoresSafeArea()
            }
            
            // Content overlay on photo
            PhotoOverlayContent(content: content, isStory: isStory)

            // Sticker overlay (for stories)
            if isStory, let sticker = sticker {
                VStack {
                    HStack {
                        Spacer()
                        StickerView(type: sticker)
                            .padding(20)
                    }
                    Spacer()
                }
            }

            // SnapChef branding - 3x larger with blue background
            VStack {
                Spacer()
                HStack(spacing: 18) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 72, weight: .bold))  // 3x larger: 24 * 3 = 72
                    Text("Made on the free SnapChef App!")
                        .font(.system(size: 72, weight: .bold))  // 3x larger: 24 * 3 = 72
                }
                .foregroundColor(.white)
                .padding(.horizontal, 60)
                .padding(.vertical, 36)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.9))  // Changed to blue background
                )
                .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
                .padding(.bottom, isStory ? 100 : 30)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Caption Generation Helper
private func generateInstagramCaption(for recipe: Recipe) -> String {
    // Just the main line without hashtags for the image overlay
    return "Just turned my sad fridge into \(recipe.name) 🎉"
}

// MARK: - Photo Overlay Content
struct PhotoOverlayContent: View {
    let content: ShareContent
    let isStory: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Top section
            Spacer()
            
            // Main content
            VStack(spacing: 20) {
                if case .recipe(let recipe) = content.type {
                    // Before/After labels if both photos exist
                    if content.beforeImage != nil && content.afterImage != nil {
                        HStack(spacing: 40) {
                            Text("BEFORE")
                                .font(.system(size: isStory ? 18 : 16, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.5))
                                )
                            
                            Text("AFTER")
                                .font(.system(size: isStory ? 18 : 16, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "#00F2EA").opacity(0.8))
                                )
                        }
                        .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 2)
                    }
                    
                    // Share caption with much larger font (doubled)
                    // Generate the same caption that goes to clipboard
                    Text(generateInstagramCaption(for: recipe))
                        .font(.system(size: isStory ? 104 : 84, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 30)
                        .shadow(color: .black.opacity(0.8), radius: 10, x: 0, y: 5)
                    
                    // Remove subtitle and stats for cleaner look
                    // Focus on the main caption text
                }
            }
            
            Spacer()
            Spacer()
        }
    }
}

// MARK: - Instagram Stat Badge
struct InstagramStatBadge: View {
    let icon: String
    let value: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
            Text(value)
                .font(.system(size: 14, weight: .bold))
        }
        .foregroundColor(.white)
        .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
    }
}

// MARK: - Classic Template (keeping for backward compatibility)
struct ClassicTemplate: View {
    let content: ShareContent
    let isStory: Bool
    
    var body: some View {
        PhotoOverlayContent(content: content, isStory: isStory)
    }
}

struct ModernTemplate: View {
    let content: ShareContent
    let isStory: Bool
    
    var body: some View {
        // Use the same photo overlay for consistency
        PhotoOverlayContent(content: content, isStory: isStory)
    }
}

struct MinimalTemplate: View {
    let content: ShareContent
    let isStory: Bool
    
    var body: some View {
        // Use the same photo overlay for consistency
        PhotoOverlayContent(content: content, isStory: isStory)
    }
}

struct BoldTemplate: View {
    let content: ShareContent
    let isStory: Bool
    
    var body: some View {
        // Use the same photo overlay for consistency
        PhotoOverlayContent(content: content, isStory: isStory)
    }
}

struct GradientTemplate: View {
    let content: ShareContent
    let isStory: Bool
    
    var body: some View {
        // Use the same photo overlay for consistency
        PhotoOverlayContent(content: content, isStory: isStory)
    }
}

// MARK: - Supporting Views
struct DiagonalShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.8))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

struct StickerView: View {
    let type: StickerType

    var body: some View {
        VStack(spacing: 4) {
            Text(type.emoji)
                .font(.system(size: 60))

            if type != .custom {
                Text(type.text)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(12)
            }
        }
        .rotationEffect(.degrees(-10))
    }
}

// MARK: - Carousel Slide
struct InstagramCarouselSlide: View {
    enum SlideType {
        case title
        case ingredients
        case instructions
        case result(UIImage)
    }

    let slideType: SlideType
    let recipe: Recipe
    let template: InstagramTemplate
    let slideNumber: Int
    let totalSlides: Int

    var body: some View {
        ZStack {
            // Background
            template.gradient

            // Content based on slide type
            switch slideType {
            case .title:
                TitleSlideContent(recipe: recipe)
            case .ingredients:
                IngredientsSlideContent(recipe: recipe)
            case .instructions:
                InstructionsSlideContent(recipe: recipe)
            case .result(let image):
                ResultSlideContent(recipe: recipe, image: image)
            }

            // Slide indicator
            VStack {
                HStack(spacing: 4) {
                    ForEach(1...totalSlides, id: \.self) { index in
                        Rectangle()
                            .fill(index == slideNumber ? Color.white : Color.white.opacity(0.3))
                            .frame(height: 3)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)

                Spacer()
            }
        }
    }
}

struct TitleSlideContent: View {
    let recipe: Recipe

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text(recipe.name)
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Text(recipe.description)
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }
}

struct IngredientsSlideContent: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("INGREDIENTS")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 100)
                .padding(.horizontal, 30)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(recipe.ingredients) { ingredient in
                    HStack {
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 6, height: 6)
                        Text("\(ingredient.quantity) \(ingredient.unit ?? "") \(ingredient.name)")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}

struct InstructionsSlideContent: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("INSTRUCTIONS")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 100)
                .padding(.horizontal, 30)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(recipe.instructions.prefix(5).enumerated()), id: \.offset) { index, instruction in
                    HStack(alignment: .top) {
                        Text("\(index + 1)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 30)

                        Text(instruction)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}

struct ResultSlideContent: View {
    let recipe: Recipe
    let image: UIImage

    var body: some View {
        VStack {
            Spacer()

            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 600)
                .cornerRadius(20)
                .padding(.horizontal, 30)

            Text("Enjoy your \(recipe.name)!")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .padding(.top, 20)

            Spacer()
        }
    }
}

// MARK: - Errors
enum InstagramError: LocalizedError {
    case renderingFailed
    case templateNotSupported

    var errorDescription: String? {
        switch self {
        case .renderingFailed:
            return "Failed to generate Instagram content"
        case .templateNotSupported:
            return "Template not supported for this content type"
        }
    }
}
