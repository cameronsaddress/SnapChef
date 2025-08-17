import Foundation
import SwiftUI

// MARK: - AI Chef Persona
struct AIChefPersona: Identifiable, Codable {
    let id: UUID
    let name: String
    let emoji: String
    let personality: PersonalityType
    let voiceStyle: VoiceStyle
    let specialties: [String]
    let catchPhrases: [String]
    let color: String
    var isUnlocked: Bool
    var unlockRequirement: String?

    enum PersonalityType: String, Codable, CaseIterable {
        case gordon = "Gordon (Intense)"
        case julia = "Julia (Encouraging)"
        case salt = "Salt Bae (Dramatic)"
        case bob = "Bob Ross (Calm)"
        case grandma = "Grandma (Loving)"
        case robot = "Robot (Logical)"
        case pirate = "Pirate (Adventurous)"
        case wizard = "Wizard (Mystical)"

        var description: String {
            switch self {
            case .gordon: return "Passionate about perfection, direct feedback"
            case .julia: return "Warm and encouraging, celebrates every attempt"
            case .salt: return "Theatrical and dramatic, makes everything special"
            case .bob: return "Peaceful and calming, no mistakes only happy accidents"
            case .grandma: return "Nurturing and caring, shares family secrets"
            case .robot: return "Precise and efficient, optimizes everything"
            case .pirate: return "Bold and adventurous, searches for flavor treasure"
            case .wizard: return "Magical and mysterious, casts delicious spells"
            }
        }
    }

    enum VoiceStyle: String, Codable {
        case enthusiastic = "Enthusiastic"
        case calm = "Calm"
        case dramatic = "Dramatic"
        case nurturing = "Nurturing"
        case robotic = "Robotic"
        case mystical = "Mystical"
    }
}

// MARK: - Surprise Recipe Mode
struct SurpriseRecipeSettings {
    var isEnabled: Bool = true
    var wildnessLevel: WildnessLevel = .medium
    var allowedCuisines: Set<String> = Set(Cuisine.allCases.map { $0.rawValue })
    var avoidIngredients: Set<String> = []

    enum WildnessLevel: String, CaseIterable {
        case mild = "Mild Surprises"
        case medium = "Moderate Adventures"
        case wild = "Complete Chaos"
        case insane = "Culinary Madness"

        var description: String {
            switch self {
            case .mild: return "Familiar recipes with small twists"
            case .medium: return "Interesting combinations you'll love"
            case .wild: return "Unexpected fusions and bold flavors"
            case .insane: return "Prepare for anything!"
            }
        }

        var color: Color {
            switch self {
            case .mild: return Color(hex: "#43e97b")
            case .medium: return Color(hex: "#4facfe")
            case .wild: return Color(hex: "#f093fb")
            case .insane: return Color(hex: "#ef5350")
            }
        }
    }
}

enum Cuisine: String, CaseIterable {
    case italian = "Italian"
    case mexican = "Mexican"
    case chinese = "Chinese"
    case japanese = "Japanese"
    case thai = "Thai"
    case indian = "Indian"
    case french = "French"
    case greek = "Greek"
    case american = "American"
    case fusion = "Fusion"
}

// MARK: - AI Personality Manager
@MainActor
class AIPersonalityManager: ObservableObject {
    static let shared = AIPersonalityManager()

    @Published var currentPersona: AIChefPersona
    @Published var unlockedPersonas: Set<UUID> = []
    @Published var surpriseSettings = SurpriseRecipeSettings()
    @Published var messageHistory: [AIMessage] = []

    let allPersonas: [AIChefPersona]

    private init() {
        // Initialize all personas
        allPersonas = [
            AIChefPersona(
                id: UUID(),
                name: "Chef Gordon",
                emoji: "👨‍🍳",
                personality: .gordon,
                voiceStyle: .enthusiastic,
                specialties: ["Fine dining", "Perfect execution", "Kitchen discipline"],
                catchPhrases: [
                    "This is absolutely perfect!",
                    "Come on, you can do better!",
                    "Beautiful, just beautiful!",
                    "It's RAW!"
                ],
                color: "#ef5350",
                isUnlocked: true
            ),
            AIChefPersona(
                id: UUID(),
                name: "Chef Julia",
                emoji: "👩‍🍳",
                personality: .julia,
                voiceStyle: .nurturing,
                specialties: ["French cuisine", "Baking", "Teaching"],
                catchPhrases: [
                    "Bon appétit!",
                    "Don't worry, cooking is all about love!",
                    "You're doing wonderfully!",
                    "The secret ingredient is always butter!"
                ],
                color: "#f093fb",
                isUnlocked: true
            ),
            AIChefPersona(
                id: UUID(),
                name: "Salt Master",
                emoji: "🧂",
                personality: .salt,
                voiceStyle: .dramatic,
                specialties: ["Meat dishes", "Seasoning", "Presentation"],
                catchPhrases: [
                    "*dramatically sprinkles salt*",
                    "Let the flavors... dance!",
                    "This needs more... passion!",
                    "Magnificent!"
                ],
                color: "#ffa726",
                isUnlocked: false,
                unlockRequirement: "Create 50 recipes"
            ),
            AIChefPersona(
                id: UUID(),
                name: "Chef Bob",
                emoji: "🎨",
                personality: .bob,
                voiceStyle: .calm,
                specialties: ["Comfort food", "Creativity", "Relaxation"],
                catchPhrases: [
                    "Happy little ingredients",
                    "There are no mistakes, only tasty accidents",
                    "Let's add a happy little spice here",
                    "Every dish needs a friend"
                ],
                color: "#4facfe",
                isUnlocked: false,
                unlockRequirement: "7-day streak"
            ),
            AIChefPersona(
                id: UUID(),
                name: "Grandma Rose",
                emoji: "👵",
                personality: .grandma,
                voiceStyle: .nurturing,
                specialties: ["Home cooking", "Family recipes", "Comfort food"],
                catchPhrases: [
                    "Just like I used to make!",
                    "Come, eat! You're too skinny!",
                    "The secret is love, dear",
                    "This recipe has been in the family for generations"
                ],
                color: "#43e97b",
                isUnlocked: false,
                unlockRequirement: "Complete 'Family Feast' challenge"
            ),
            AIChefPersona(
                id: UUID(),
                name: "ChefBot 3000",
                emoji: "🤖",
                personality: .robot,
                voiceStyle: .robotic,
                specialties: ["Molecular gastronomy", "Precision cooking", "Efficiency"],
                catchPhrases: [
                    "Recipe optimization complete",
                    "Flavor profile: 98.7% optimal",
                    "Nutritional efficiency maximized",
                    "Cooking process initialized"
                ],
                color: "#667eea",
                isUnlocked: false,
                unlockRequirement: "Reach level 10"
            ),
            AIChefPersona(
                id: UUID(),
                name: "Captain Cook",
                emoji: "🏴‍☠️",
                personality: .pirate,
                voiceStyle: .enthusiastic,
                specialties: ["Seafood", "BBQ", "Adventure cooking"],
                catchPhrases: [
                    "Ahoy! Time to plunder some flavors!",
                    "Shiver me timbers, that's tasty!",
                    "X marks the spot for spices!",
                    "Yo ho ho and a bottle of hot sauce!"
                ],
                color: "#1DA1F2",
                isUnlocked: false,
                unlockRequirement: "Share 25 recipes"
            ),
            AIChefPersona(
                id: UUID(),
                name: "Merlin the Mixer",
                emoji: "🧙‍♂️",
                personality: .wizard,
                voiceStyle: .mystical,
                specialties: ["Magical combinations", "Potions", "Enchanted dishes"],
                catchPhrases: [
                    "Abracadabra, let's cook!",
                    "The crystal ball shows... deliciousness!",
                    "By my beard, this is magical!",
                    "The ancient recipes speak to me..."
                ],
                color: "#764ba2",
                isUnlocked: false,
                unlockRequirement: "Create 'Mystical Meal' achievement"
            )
        ]

        // Set default persona
        currentPersona = allPersonas.first!

        // Unlock default personas
        unlockedPersonas.insert(allPersonas[0].id)
        unlockedPersonas.insert(allPersonas[1].id)
    }

    // MARK: - Persona Management

    func selectPersona(_ persona: AIChefPersona) {
        guard unlockedPersonas.contains(persona.id) else { return }
        currentPersona = persona

        // Add welcome message
        addMessage(
            getPersonaGreeting(),
            type: .chef
        )
    }

    func unlockPersona(_ personaId: UUID) {
        unlockedPersonas.insert(personaId)

        // Celebration animation would trigger here
        if let persona = allPersonas.first(where: { $0.id == personaId }) {
            print("Unlocked: \(persona.name)!")
        }
    }

    // MARK: - Message Generation

    func getPersonaGreeting() -> String {
        switch currentPersona.personality {
        case .gordon:
            return "Right, let's get cooking! Show me what you've got in that fridge!"
        case .julia:
            return "Hello dearie! I'm so excited to cook with you today!"
        case .salt:
            return "*adjusts sunglasses* Time to create... magnificence!"
        case .bob:
            return "Well hello there, friend. Let's paint a delicious masterpiece together."
        case .grandma:
            return "Come here, sweetheart! Let's make something that'll warm your soul."
        case .robot:
            return "Greetings, human. Ready to optimize your nutritional intake?"
        case .pirate:
            return "Ahoy matey! Ready to sail the seven seasonings?"
        case .wizard:
            return "Welcome, apprentice! The kitchen spirits await our culinary magic!"
        }
    }

    func generateRecipeIntro(for recipe: Recipe) -> String {
        let phrase = currentPersona.catchPhrases.randomElement() ?? ""

        switch currentPersona.personality {
        case .gordon:
            return "\(recipe.name)! \(phrase) This is going to be absolutely stunning when done right!"
        case .julia:
            return "Oh, we're making \(recipe.name)! \(phrase) You're going to love this!"
        case .salt:
            return "*eyes widen* \(recipe.name)... \(phrase)"
        case .bob:
            return "Today we'll create a happy little \(recipe.name). \(phrase)"
        case .grandma:
            return "\(recipe.name), just like I used to make! \(phrase)"
        case .robot:
            return "Recipe selected: \(recipe.name). \(phrase)"
        case .pirate:
            return "Arr! \(recipe.name) be on the menu! \(phrase)"
        case .wizard:
            return "The spirits have chosen... \(recipe.name)! \(phrase)"
        }
    }

    func generateEncouragement() -> String {
        switch currentPersona.personality {
        case .gordon:
            return ["That's it! Perfect!", "Now you're cooking!", "Excellent technique!"].randomElement()!
        case .julia:
            return ["You're doing beautifully!", "How wonderful!", "Marvelous, dear!"].randomElement()!
        case .salt:
            return ["*nods approvingly*", "The flavor... it speaks!", "Magnificent work!"].randomElement()!
        case .bob:
            return ["What a happy accident!", "Beautiful work, friend", "Just lovely"].randomElement()!
        case .grandma:
            return ["That's my dear!", "Perfect, just perfect!", "You make me so proud!"].randomElement()!
        case .robot:
            return ["Efficiency: Optimal", "Task completed successfully", "Performance: Excellent"].randomElement()!
        case .pirate:
            return ["Aye, that's the way!", "Treasure found!", "Smooth sailing, matey!"].randomElement()!
        case .wizard:
            return ["The magic is strong!", "Excellent spellwork!", "The spirits are pleased!"].randomElement()!
        }
    }

    // MARK: - Surprise Recipe Generation

    func generateSurprisePrompt() -> String {
        let wildness = surpriseSettings.wildnessLevel

        switch wildness {
        case .mild:
            return "Create a familiar recipe with a small twist"
        case .medium:
            return "Mix two cuisines in an interesting way"
        case .wild:
            return "Create an unexpected fusion that somehow works"
        case .insane:
            return "Go completely wild - surprise me with something I've never imagined!"
        }
    }

    func shouldAddSurpriseElement() -> Bool {
        surpriseSettings.isEnabled && Int.random(in: 0...100) < 30 // 30% chance
    }

    // MARK: - Message History

    func addMessage(_ content: String, type: AIMessageType) {
        let message = AIMessage(
            content: content,
            type: type,
            persona: currentPersona,
            timestamp: Date()
        )
        messageHistory.append(message)
    }

    func clearMessageHistory() {
        messageHistory.removeAll()
    }
}

// MARK: - AI Message
struct AIMessage: Identifiable {
    let id = UUID()
    let content: String
    let type: AIMessageType
    let persona: AIChefPersona
    let timestamp: Date
}

enum AIMessageType {
    case chef
    case user
    case system
}
