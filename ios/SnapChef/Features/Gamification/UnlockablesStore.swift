import Foundation
import SwiftUI

// MARK: - Unlockable Item Types
enum UnlockableType: String, CaseIterable, Codable {
    case theme = "Theme"
    case badge = "Badge"
    case title = "Title"
    case stickerPack = "Sticker Pack"
    case recipeCollection = "Recipe Collection"
    case profileFrame = "Profile Frame"
    case effect = "Visual Effect"
    case booster = "Booster"

    var icon: String {
        switch self {
        case .theme: return "paintbrush.fill"
        case .badge: return "shield.fill"
        case .title: return "crown.fill"
        case .stickerPack: return "face.smiling.fill"
        case .recipeCollection: return "book.fill"
        case .profileFrame: return "person.crop.square.fill"
        case .effect: return "sparkles"
        case .booster: return "bolt.fill"
        }
    }
}

// MARK: - Unlockable Item
struct UnlockableItem: Identifiable, Codable {
    let id: String
    let type: UnlockableType
    let name: String
    let description: String
    let price: Int
    let previewImage: String?
    let rarity: ItemRarity
    let category: String
    let isLimitedTime: Bool
    let expirationDate: Date?
    var isPurchased: Bool = false
    var isEquipped: Bool = false
    var purchaseDate: Date?

    enum ItemRarity: String, Codable, CaseIterable {
        case common = "Common"
        case rare = "Rare"
        case epic = "Epic"
        case legendary = "Legendary"
        case seasonal = "Seasonal"

        var color: Color {
            switch self {
            case .common: return .gray
            case .rare: return Color(hex: "#4facfe")
            case .epic: return Color(hex: "#667eea")
            case .legendary: return Color(hex: "#f093fb")
            case .seasonal: return Color(hex: "#fa709a")
            }
        }

        var glowIntensity: Double {
            switch self {
            case .common: return 0.1
            case .rare: return 0.3
            case .epic: return 0.5
            case .legendary: return 0.8
            case .seasonal: return 0.6
            }
        }
    }
}

// MARK: - Store Category
struct StoreCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let description: String
    let types: [UnlockableType]
}

// MARK: - Unlockables Store Manager
@MainActor
class UnlockablesStore: ObservableObject {
    static let shared = UnlockablesStore()

    @Published var allItems: [UnlockableItem] = []
    @Published var purchasedItems: [UnlockableItem] = []
    @Published var equippedItems: [String: String] = [:] // type -> itemId
    @Published var featuredItems: [UnlockableItem] = []
    @Published var limitedTimeItems: [UnlockableItem] = []
    @Published var isLoadingStore = false

    private let chefCoinsManager = ChefCoinsManager.shared
    private let userDefaults = UserDefaults.standard

    // Store categories
    let categories: [StoreCategory] = [
        StoreCategory(
            name: "Themes",
            icon: "paintbrush.fill",
            description: "Customize your app appearance",
            types: [.theme]
        ),
        StoreCategory(
            name: "Profile",
            icon: "person.crop.circle.fill",
            description: "Personalize your profile",
            types: [.badge, .title, .profileFrame]
        ),
        StoreCategory(
            name: "Content",
            icon: "square.grid.2x2.fill",
            description: "Unlock new content",
            types: [.stickerPack, .recipeCollection]
        ),
        StoreCategory(
            name: "Effects",
            icon: "wand.and.stars",
            description: "Special effects and boosters",
            types: [.effect, .booster]
        )
    ]

    private init() {
        loadStore()
        loadPurchasedItems()
        loadEquippedItems()
    }

    // MARK: - Store Management

    /// Load store items
    private func loadStore() {
        // In a real app, this would fetch from server
        allItems = createMockStoreItems()
        updateFeaturedItems()
        updateLimitedTimeItems()
    }

    /// Update featured items
    private func updateFeaturedItems() {
        featuredItems = allItems
            .filter { !$0.isPurchased }
            .shuffled()
            .prefix(6)
            .map { $0 }
    }

    /// Update limited time items
    private func updateLimitedTimeItems() {
        let now = Date()
        limitedTimeItems = allItems
            .filter { $0.isLimitedTime && ($0.expirationDate ?? now) > now && !$0.isPurchased }
            .sorted { ($0.expirationDate ?? now) < ($1.expirationDate ?? now) }
    }

    // MARK: - Purchase Management

    /// Purchase an item
    func purchaseItem(_ item: UnlockableItem) -> PurchaseResult {
        guard !item.isPurchased else {
            return .failure(.alreadyOwned)
        }

        guard chefCoinsManager.canAfford(item.price) else {
            return .failure(.insufficientFunds)
        }

        // Process purchase
        if chefCoinsManager.spendCoins(item.price, on: item.name) {
            var purchasedItem = item
            purchasedItem.isPurchased = true
            purchasedItem.purchaseDate = Date()

            // Update arrays
            if let index = allItems.firstIndex(where: { $0.id == item.id }) {
                allItems[index] = purchasedItem
            }
            purchasedItems.append(purchasedItem)

            // Auto-equip if it's the first of its type
            if !hasEquippedItem(ofType: item.type) {
                equipItem(purchasedItem)
            }

            // Save state
            savePurchasedItems()

            // Update store
            updateFeaturedItems()
            updateLimitedTimeItems()

            // Analytics
            trackPurchase(purchasedItem)

            return .success(purchasedItem)
        } else {
            return .failure(.transactionFailed)
        }
    }

    /// Check if user has equipped item of type
    func hasEquippedItem(ofType type: UnlockableType) -> Bool {
        return equippedItems[type.rawValue] != nil
    }

    /// Equip an item
    func equipItem(_ item: UnlockableItem) {
        guard item.isPurchased else { return }

        // Unequip current item of same type
        if let currentId = equippedItems[item.type.rawValue],
           let index = purchasedItems.firstIndex(where: { $0.id == currentId }) {
            purchasedItems[index].isEquipped = false
        }

        // Equip new item
        equippedItems[item.type.rawValue] = item.id
        if let index = purchasedItems.firstIndex(where: { $0.id == item.id }) {
            purchasedItems[index].isEquipped = true
        }

        // Apply theme if it's a theme item
        if item.type == .theme {
            applyTheme(item)
        }

        saveEquippedItems()
    }

    /// Unequip an item
    func unequipItem(_ item: UnlockableItem) {
        guard item.isPurchased && item.isEquipped else { return }

        equippedItems[item.type.rawValue] = nil
        if let index = purchasedItems.firstIndex(where: { $0.id == item.id }) {
            purchasedItems[index].isEquipped = false
        }

        saveEquippedItems()
    }

    // MARK: - Theme Management

    /// Apply theme
    private func applyTheme(_ theme: UnlockableItem) {
        guard theme.type == .theme else { return }

        // Store theme preference
        userDefaults.set(theme.id, forKey: "selectedTheme")

        // Notify app to update theme
        NotificationCenter.default.post(name: .themeChanged, object: theme)
    }

    /// Get current theme
    func getCurrentTheme() -> UnlockableItem? {
        guard let themeId = equippedItems[UnlockableType.theme.rawValue] else { return nil }
        return purchasedItems.first(where: { $0.id == themeId })
    }

    // MARK: - Item Queries

    /// Get items by type
    func getItems(ofType type: UnlockableType) -> [UnlockableItem] {
        return allItems.filter { $0.type == type }
    }

    /// Get purchased items by type
    func getPurchasedItems(ofType type: UnlockableType) -> [UnlockableItem] {
        return purchasedItems.filter { $0.type == type }
    }

    /// Get equipped item for type
    func getEquippedItem(ofType type: UnlockableType) -> UnlockableItem? {
        guard let itemId = equippedItems[type.rawValue] else { return nil }
        return purchasedItems.first(where: { $0.id == itemId })
    }

    /// Check if item is affordable
    func canAfford(_ item: UnlockableItem) -> Bool {
        return chefCoinsManager.canAfford(item.price)
    }

    // MARK: - Persistence

    /// Save purchased items
    private func savePurchasedItems() {
        if let encoded = try? JSONEncoder().encode(purchasedItems) {
            userDefaults.set(encoded, forKey: "purchasedUnlockables")
        }
    }

    /// Load purchased items
    private func loadPurchasedItems() {
        if let data = userDefaults.data(forKey: "purchasedUnlockables"),
           let decoded = try? JSONDecoder().decode([UnlockableItem].self, from: data) {
            purchasedItems = decoded
        }
    }

    /// Save equipped items
    private func saveEquippedItems() {
        userDefaults.set(equippedItems, forKey: "equippedUnlockables")
    }

    /// Load equipped items
    private func loadEquippedItems() {
        equippedItems = userDefaults.dictionary(forKey: "equippedUnlockables") as? [String: String] ?? [:]
    }

    // MARK: - Analytics

    /// Track purchase
    private func trackPurchase(_ item: UnlockableItem) {
        print("Item purchased: \(item.name) for \(item.price) coins")
        // Analytics implementation would go here
    }

    // MARK: - Mock Data

    private func createMockStoreItems() -> [UnlockableItem] {
        var items: [UnlockableItem] = []

        // Themes
        items.append(contentsOf: [
            UnlockableItem(
                id: "theme_midnight",
                type: .theme,
                name: "Midnight Chef",
                description: "Dark theme with purple accents",
                price: 500,
                previewImage: "theme_midnight",
                rarity: .rare,
                category: "Themes",
                isLimitedTime: false,
                expirationDate: nil
            ),
            UnlockableItem(
                id: "theme_sunset",
                type: .theme,
                name: "Sunset Kitchen",
                description: "Warm orange and pink gradients",
                price: 750,
                previewImage: "theme_sunset",
                rarity: .epic,
                category: "Themes",
                isLimitedTime: false,
                expirationDate: nil
            ),
            UnlockableItem(
                id: "theme_halloween",
                type: .theme,
                name: "Spooky Season",
                description: "Halloween special theme",
                price: 1_000,
                previewImage: "theme_halloween",
                rarity: .seasonal,
                category: "Themes",
                isLimitedTime: true,
                expirationDate: Date().addingTimeInterval(7 * 86_400)
            )
        ])

        // Badges
        items.append(contentsOf: [
            UnlockableItem(
                id: "badge_gold_chef",
                type: .badge,
                name: "Gold Chef Badge",
                description: "Show off your culinary mastery",
                price: 300,
                previewImage: "badge_gold",
                rarity: .rare,
                category: "Profile",
                isLimitedTime: false,
                expirationDate: nil
            ),
            UnlockableItem(
                id: "badge_speed_demon",
                type: .badge,
                name: "Speed Demon",
                description: "For the fastest recipe creators",
                price: 250,
                previewImage: "badge_speed",
                rarity: .common,
                category: "Profile",
                isLimitedTime: false,
                expirationDate: nil
            )
        ])

        // Titles
        items.append(contentsOf: [
            UnlockableItem(
                id: "title_master_chef",
                type: .title,
                name: "Master Chef",
                description: "The ultimate culinary title",
                price: 1_500,
                previewImage: nil,
                rarity: .legendary,
                category: "Profile",
                isLimitedTime: false,
                expirationDate: nil
            ),
            UnlockableItem(
                id: "title_recipe_wizard",
                type: .title,
                name: "Recipe Wizard",
                description: "Master of magical recipes",
                price: 800,
                previewImage: nil,
                rarity: .epic,
                category: "Profile",
                isLimitedTime: false,
                expirationDate: nil
            )
        ])

        // Sticker Packs
        items.append(contentsOf: [
            UnlockableItem(
                id: "stickers_emoji_chef",
                type: .stickerPack,
                name: "Emoji Chef Pack",
                description: "15 chef-themed emoji stickers",
                price: 200,
                previewImage: "stickers_emoji",
                rarity: .common,
                category: "Content",
                isLimitedTime: false,
                expirationDate: nil
            ),
            UnlockableItem(
                id: "stickers_halloween",
                type: .stickerPack,
                name: "Spooky Stickers",
                description: "20 Halloween stickers",
                price: 400,
                previewImage: "stickers_halloween",
                rarity: .seasonal,
                category: "Content",
                isLimitedTime: true,
                expirationDate: Date().addingTimeInterval(7 * 86_400)
            )
        ])

        // Recipe Collections
        items.append(contentsOf: [
            UnlockableItem(
                id: "recipes_italian",
                type: .recipeCollection,
                name: "Italian Classics",
                description: "25 authentic Italian recipes",
                price: 600,
                previewImage: "recipes_italian",
                rarity: .rare,
                category: "Content",
                isLimitedTime: false,
                expirationDate: nil
            ),
            UnlockableItem(
                id: "recipes_vegan",
                type: .recipeCollection,
                name: "Plant Power",
                description: "30 delicious vegan recipes",
                price: 700,
                previewImage: "recipes_vegan",
                rarity: .rare,
                category: "Content",
                isLimitedTime: false,
                expirationDate: nil
            )
        ])

        // Effects
        items.append(contentsOf: [
            UnlockableItem(
                id: "effect_rainbow",
                type: .effect,
                name: "Rainbow Sparkle",
                description: "Add rainbow effects to your photos",
                price: 350,
                previewImage: "effect_rainbow",
                rarity: .epic,
                category: "Effects",
                isLimitedTime: false,
                expirationDate: nil
            )
        ])

        // Boosters
        items.append(contentsOf: [
            UnlockableItem(
                id: "booster_2x_coins",
                type: .booster,
                name: "Double Coins (7 Days)",
                description: "Earn 2x coins for one week",
                price: 1_000,
                previewImage: "booster_coins",
                rarity: .epic,
                category: "Effects",
                isLimitedTime: false,
                expirationDate: nil
            ),
            UnlockableItem(
                id: "booster_xp",
                type: .booster,
                name: "XP Boost (3 Days)",
                description: "50% more XP for 3 days",
                price: 500,
                previewImage: "booster_xp",
                rarity: .rare,
                category: "Effects",
                isLimitedTime: false,
                expirationDate: nil
            )
        ])

        return items
    }
}

// MARK: - Purchase Result
enum PurchaseResult {
    case success(UnlockableItem)
    case failure(PurchaseError)

    enum PurchaseError: LocalizedError {
        case insufficientFunds
        case alreadyOwned
        case transactionFailed
        case itemNotFound

        var errorDescription: String? {
            switch self {
            case .insufficientFunds:
                return "Not enough Chef Coins"
            case .alreadyOwned:
                return "You already own this item"
            case .transactionFailed:
                return "Transaction failed. Please try again"
            case .itemNotFound:
                return "Item not found in store"
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let themeChanged = Notification.Name("themeChanged")
    static let itemPurchased = Notification.Name("itemPurchased")
    static let itemEquipped = Notification.Name("itemEquipped")
}
