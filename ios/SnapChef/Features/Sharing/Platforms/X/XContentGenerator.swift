//
//  XContentGenerator.swift
//  SnapChef
//
//  Created on 02/03/2025
//

import SwiftUI
import UIKit

// MARK: - X Tweet Style
enum XTweetStyle: String, CaseIterable {
    case classic = "Classic"
    case viral = "Viral"
    case professional = "Professional"
    case funny = "Funny"
    
    var name: String {
        return rawValue
    }
}

@MainActor
class XContentGenerator: ObservableObject {
    static let shared = XContentGenerator()

    private let imageSize = CGSize(width: 1_200, height: 675) // 16:9 for Twitter cards

    func generateImage(
        for content: ShareContent,
        style: XTweetStyle
    ) async throws -> UIImage {
        // Create the SwiftUI view for the content
        let contentView = XImageContent(
            content: content,
            style: style,
            size: imageSize
        )

        // Render to image
        let renderer = ImageRenderer(content: contentView)
        renderer.scale = 1.0

        guard let image = renderer.uiImage else {
            throw XError.renderingFailed
        }

        return image
    }

    func generateThreadImages(
        for recipe: Recipe,
        style: XTweetStyle
    ) async throws -> [UIImage] {
        var images: [UIImage] = []

        // Title card
        let titleCard = XThreadCard(
            cardType: .title(recipe.name, recipe.description),
            style: style,
            cardNumber: 1,
            totalCards: 4
        )

        if let titleImage = await renderView(titleCard, size: imageSize) {
            images.append(titleImage)
        }

        // Ingredients card
        let ingredientsCard = XThreadCard(
            cardType: .ingredients(recipe.ingredients),
            style: style,
            cardNumber: 2,
            totalCards: 4
        )

        if let ingredientsImage = await renderView(ingredientsCard, size: imageSize) {
            images.append(ingredientsImage)
        }

        // Instructions card
        let instructionsCard = XThreadCard(
            cardType: .instructions(recipe.instructions),
            style: style,
            cardNumber: 3,
            totalCards: 4
        )

        if let instructionsImage = await renderView(instructionsCard, size: imageSize) {
            images.append(instructionsImage)
        }

        // Final card
        let finalCard = XThreadCard(
            cardType: .final(recipe.nutrition),
            style: style,
            cardNumber: 4,
            totalCards: 4
        )

        if let finalImage = await renderView(finalCard, size: imageSize) {
            images.append(finalImage)
        }

        return images
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

// MARK: - X Image Content
struct XImageContent: View {
    let content: ShareContent
    let style: XTweetStyle
    let size: CGSize

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Content based on style
            switch style {
            case .classic:
                ClassicXContent(content: content)
            case .viral:
                ViralXContent(content: content)
            case .professional:
                ProfessionalXContent(content: content)
            case .funny:
                FunnyXContent(content: content)
            }

            // SnapChef branding
            VStack {
                Spacer()
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                    Text("Made with SnapChef")
                        .font(.system(size: 14, weight: .semibold))
                    Text("@snapchef")
                        .font(.system(size: 14))
                        .opacity(0.8)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.3))
                .cornerRadius(20)
                .padding(.bottom, 30)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var backgroundColors: [Color] {
        switch style {
        case .classic:
            return [Color(hex: "#1DA1F2"), Color(hex: "#1470A8")]
        case .viral:
            return [Color(hex: "#FF6B6B"), Color(hex: "#FFE66D")]
        case .professional:
            return [Color(hex: "#2C3E50"), Color(hex: "#34495E")]
        case .funny:
            return [Color(hex: "#F39C12"), Color(hex: "#E74C3C")]
        }
    }
}

// MARK: - Style Templates
struct ClassicXContent: View {
    let content: ShareContent

    var body: some View {
        VStack(spacing: 30) {
            if case .recipe(let recipe) = content.type {
                Text(recipe.name)
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Stats grid
                HStack(spacing: 40) {
                    XStatItem(
                        icon: "clock",
                        value: "\(recipe.prepTime + recipe.cookTime)",
                        label: "minutes"
                    )

                    XStatItem(
                        icon: "flame",
                        value: "\(recipe.nutrition.calories)",
                        label: "calories"
                    )

                    XStatItem(
                        icon: "person.2",
                        value: "\(recipe.servings)",
                        label: "servings"
                    )
                }
            }
        }
    }
}

struct ViralXContent: View {
    let content: ShareContent

    var body: some View {
        ZStack {
            // Emoji rain effect
            ForEach(0..<10, id: \.self) { _ in
                Text("✨")
                    .font(.system(size: 30))
                    .position(
                        x: CGFloat.random(in: 100...1_100),
                        y: CGFloat.random(in: 100...575)
                    )
                    .opacity(0.3)
            }

            VStack(spacing: 20) {
                Text("POV:")
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundColor(.white)

                if case .recipe(let recipe) = content.type {
                    Text("You turned your sad fridge into")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.9))

                    Text(recipe.name)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)

                    Text("Using AI 🤖")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
    }
}

struct ProfessionalXContent: View {
    let content: ShareContent

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            if case .recipe(let recipe) = content.type {
                VStack(alignment: .leading, spacing: 12) {
                    Text("RECIPE")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(2)

                    Text(recipe.name)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)

                    Text(recipe.description)
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(3)
                }

                Divider()
                    .background(Color.white.opacity(0.3))

                HStack(spacing: 50) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PREP TIME")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(recipe.prepTime) min")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("DIFFICULTY")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        Text(recipe.difficulty.rawValue.capitalized)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("SERVINGS")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(recipe.servings)")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct FunnyXContent: View {
    let content: ShareContent

    var body: some View {
        VStack(spacing: 30) {
            if case .recipe(let recipe) = content.type {
                Text("Nobody:")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)

                Text("Absolutely nobody:")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)

                Text("Me at 2am:")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)

                Text("\"I'M GOING TO MAKE\"")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.9))

                Text(recipe.name.uppercased())
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)

                Text("🍳😂🔥")
                    .font(.system(size: 60))
            }
        }
    }
}

struct ThreadStartContent: View {
    let content: ShareContent

    var body: some View {
        VStack(spacing: 30) {
            Text("🧵 THREAD")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
                .tracking(2)

            if case .recipe(let recipe) = content.type {
                Text("How to make")
                    .font(.system(size: 36))
                    .foregroundColor(.white.opacity(0.9))

                Text(recipe.name)
                    .font(.system(size: 52, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Text("A step-by-step guide")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.8))

                Text("1/4")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 20)
            }
        }
    }
}

// MARK: - Thread Cards
struct XThreadCard: View {
    enum CardType {
        case title(String, String)
        case ingredients([Ingredient])
        case instructions([String])
        case final(Nutrition)
    }

    let cardType: CardType
    let style: XTweetStyle
    let cardNumber: Int
    let totalCards: Int

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: "#8E44AD"), Color(hex: "#3498DB")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 30) {
                // Card indicator
                Text("\(cardNumber)/\(totalCards)")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))

                // Content
                switch cardType {
                case .title(let name, let description):
                    VStack(spacing: 20) {
                        Text(name)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text(description)
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineLimit(4)
                    }
                    .padding(.horizontal, 40)

                case .ingredients(let ingredients):
                    VStack(alignment: .leading, spacing: 20) {
                        Text("INGREDIENTS")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(ingredients.prefix(8)) { ingredient in
                                HStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.3))
                                        .frame(width: 8, height: 8)

                                    Text("\(ingredient.quantity) \(ingredient.unit ?? "") \(ingredient.name)")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 60)

                case .instructions(let instructions):
                    VStack(alignment: .leading, spacing: 20) {
                        Text("INSTRUCTIONS")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(Array(instructions.prefix(4).enumerated()), id: \.offset) { index, instruction in
                                HStack(alignment: .top) {
                                    Text("\(index + 1).")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 30)

                                    Text(instruction)
                                        .font(.system(size: 16))
                                        .foregroundColor(.white.opacity(0.9))
                                        .lineLimit(3)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 60)

                case .final(let nutrition):
                    VStack(spacing: 30) {
                        Text("NUTRITION INFO")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)

                        HStack(spacing: 40) {
                            XNutritionItem(label: "Calories", value: "\(nutrition.calories)")
                            XNutritionItem(label: "Protein", value: "\(nutrition.protein)g")
                            XNutritionItem(label: "Carbs", value: "\(nutrition.carbs)g")
                            XNutritionItem(label: "Fat", value: "\(nutrition.fat)g")
                        }

                        Text("Enjoy your meal! 🍽")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }

                Spacer()
            }
            .padding(.top, 40)
        }
    }
}

// MARK: - Supporting Views
struct XStatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.white)

            Text(value)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

struct XNutritionItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))

            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Errors
enum XError: LocalizedError {
    case renderingFailed

    var errorDescription: String? {
        switch self {
        case .renderingFailed:
            return "Failed to generate X content"
        }
    }
}
