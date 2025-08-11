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
    
    private let storySize = CGSize(width: 1080, height: 1920) // 9:16 for Stories
    private let postSize = CGSize(width: 1080, height: 1080) // 1:1 for Posts
    private let carouselSize = CGSize(width: 1080, height: 1350) // 4:5 for Carousel
    
    func generateContent(
        template: InstagramTemplate,
        content: ShareContent,
        isStory: Bool,
        backgroundColor: Color,
        sticker: StickerType?
    ) async throws -> UIImage {
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
        
        // Render to image
        let renderer = ImageRenderer(content: contentView)
        renderer.scale = 1.0 // Use device scale
        
        guard let image = renderer.uiImage else {
            throw InstagramError.renderingFailed
        }
        
        return image
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
        return renderer.uiImage
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
        ZStack {
            // Background
            backgroundColor
                .ignoresSafeArea()
            
            // Template-specific content
            switch template {
            case .classic:
                ClassicTemplate(content: content, isStory: isStory)
            case .modern:
                ModernTemplate(content: content, isStory: isStory)
            case .minimal:
                MinimalTemplate(content: content, isStory: isStory)
            case .bold:
                BoldTemplate(content: content, isStory: isStory)
            case .gradient:
                GradientTemplate(content: content, isStory: isStory)
            }
            
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
            
            // SnapChef branding
            VStack {
                Spacer()
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                    Text("Made with SnapChef")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.5))
                .cornerRadius(20)
                .padding(.bottom, isStory ? 100 : 30)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Template Views
struct ClassicTemplate: View {
    let content: ShareContent
    let isStory: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            if case .recipe(let recipe) = content.type {
                Text(recipe.name.uppercased())
                    .font(.system(size: isStory ? 48 : 36, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                // Recipe image placeholder
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: isStory ? 300 : 250, height: isStory ? 400 : 250)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "photo")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text(recipe.difficulty.emoji)
                                .font(.system(size: 80))
                        }
                    )
                
                // Stats
                HStack(spacing: 30) {
                    VStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 24))
                        Text("\(recipe.prepTime + recipe.cookTime)m")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    
                    VStack(spacing: 4) {
                        Image(systemName: "flame")
                            .font(.system(size: 24))
                        Text("\(recipe.nutrition.calories)")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    
                    VStack(spacing: 4) {
                        Image(systemName: "person.2")
                            .font(.system(size: 24))
                        Text("\(recipe.servings)")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
            }
        }
    }
}

struct ModernTemplate: View {
    let content: ShareContent
    let isStory: Bool
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                // Top section with diagonal cut
                ZStack(alignment: .topLeading) {
                    Color.white.opacity(0.1)
                        .frame(height: geometry.size.height * 0.4)
                        .clipShape(DiagonalShape())
                    
                    VStack(alignment: .leading, spacing: 12) {
                        if case .recipe(let recipe) = content.type {
                            Text(recipe.name)
                                .font(.system(size: isStory ? 42 : 32, weight: .heavy))
                                .foregroundColor(.white)
                            
                            Text(recipe.description)
                                .font(.system(size: isStory ? 18 : 16))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(3)
                        }
                    }
                    .padding(30)
                }
                
                Spacer()
                
                // Bottom info
                if case .recipe(let recipe) = content.type {
                    HStack {
                        Label("\(recipe.prepTime + recipe.cookTime) min", systemImage: "clock")
                        Spacer()
                        Label(recipe.difficulty.rawValue, systemImage: "star.fill")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(30)
                }
            }
        }
    }
}

struct MinimalTemplate: View {
    let content: ShareContent
    let isStory: Bool
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            if case .recipe(let recipe) = content.type {
                Text(recipe.name)
                    .font(.system(size: isStory ? 36 : 28, weight: .light))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Divider()
                    .background(Color.white.opacity(0.3))
                    .frame(width: 100)
                
                Text("\(recipe.prepTime + recipe.cookTime) minutes")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
        }
    }
}

struct BoldTemplate: View {
    let content: ShareContent
    let isStory: Bool
    
    var body: some View {
        ZStack {
            // Large emoji background
            if case .recipe(let recipe) = content.type {
                Text(recipe.difficulty.emoji)
                    .font(.system(size: 300))
                    .opacity(0.1)
                
                VStack(spacing: 20) {
                    Text(recipe.name.uppercased())
                        .font(.system(size: isStory ? 52 : 40, weight: .black))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    Text("READY IN \(recipe.prepTime + recipe.cookTime) MINUTES")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
    }
}

struct GradientTemplate: View {
    let content: ShareContent
    let isStory: Bool
    
    var body: some View {
        ZStack {
            // Animated gradient overlay
            LinearGradient(
                colors: [
                    Color.white.opacity(0.1),
                    Color.clear,
                    Color.white.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            if case .recipe(let recipe) = content.type {
                VStack(spacing: 30) {
                    Spacer()
                    
                    Text(recipe.name)
                        .font(.system(size: isStory ? 44 : 34, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    
                    // Gradient divider
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.5),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 2)
                    .frame(width: 200)
                    
                    VStack(spacing: 8) {
                        Text("\(recipe.nutrition.calories) calories")
                        Text("\(recipe.servings) servings")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                }
            }
        }
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