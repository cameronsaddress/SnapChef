import Foundation
import SwiftUI
import CloudKit

// Import the UserProfile model from DiscoverUsersView
// Since we can't import from another Swift file directly, we'll need to define a method that returns the data

// MARK: - Fake User Data Service
@MainActor
class FakeUserDataService {
    static let shared = FakeUserDataService()
    
    private init() {}
    
    // MARK: - Name Data
    private let firstNames = [
        "Emma", "Liam", "Olivia", "Noah", "Ava", "Ethan", "Sophia", "Mason", "Isabella", "William",
        "Mia", "James", "Charlotte", "Benjamin", "Amelia", "Lucas", "Harper", "Henry", "Evelyn", "Alexander",
        "Michael", "Sarah", "David", "Jessica", "Daniel", "Emily", "Matthew", "Madison", "Joseph", "Elizabeth",
        "Jackson", "Avery", "Samuel", "Ella", "Sebastian", "Scarlett", "Jack", "Grace", "Aiden", "Chloe",
        "Owen", "Victoria", "Dylan", "Riley", "Luke", "Aria", "Gabriel", "Lily", "Anthony", "Aubrey",
        "Isaac", "Zoey", "Grayson", "Penelope", "Julian", "Lillian", "Wyatt", "Addison", "Leo", "Layla",
        "Jayden", "Natalie", "Levi", "Camila", "Isaiah", "Hannah", "Thomas", "Hazel", "Charles", "Violet",
        "Caleb", "Aurora", "Christopher", "Savannah", "Joshua", "Audrey", "Andrew", "Brooklyn", "Nathan", "Bella",
        "Claire", "Skylar", "Lucy", "Paisley", "Everly", "Anna", "Caroline", "Nova", "Genesis", "Kennedy",
        "Maya", "Willow", "Kinsley", "Naomi", "Elena", "Sarah", "Ariana", "Allison", "Gabriella", "Alice"
    ]
    
    private let lastNames = [
        "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez",
        "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin",
        "Lee", "Perez", "Thompson", "White", "Harris", "Sanchez", "Clark", "Ramirez", "Lewis", "Robinson",
        "Walker", "Young", "Allen", "King", "Wright", "Scott", "Torres", "Nguyen", "Hill", "Flores",
        "Green", "Adams", "Nelson", "Baker", "Hall", "Rivera", "Campbell", "Mitchell", "Carter", "Roberts",
        "Phillips", "Evans", "Turner", "Diaz", "Parker", "Cruz", "Edwards", "Collins", "Reyes", "Stewart",
        "Morris", "Morales", "Murphy", "Cook", "Rogers", "Gutierrez", "Ortiz", "Morgan", "Cooper", "Peterson",
        "Bailey", "Reed", "Kelly", "Howard", "Ramos", "Kim", "Cox", "Ward", "Richardson", "Watson",
        "Brooks", "Chavez", "Wood", "James", "Bennett", "Gray", "Mendoza", "Ruiz", "Hughes", "Price",
        "Alvarez", "Castillo", "Sanders", "Patel", "Myers", "Long", "Ross", "Foster", "Jimenez", "Chen"
    ]
    
    private let cuisineTypes = [
        "Italian", "French", "Japanese", "Mexican", "Thai", "Indian", "Chinese", "Mediterranean", 
        "American", "Korean", "Vietnamese", "Greek", "Spanish", "Middle Eastern", "Brazilian",
        "Moroccan", "Ethiopian", "Peruvian", "Turkish", "Lebanese", "Fusion", "Vegan", "Vegetarian",
        "BBQ", "Seafood", "Desserts", "Baking", "Comfort Food", "Street Food", "Farm-to-Table"
    ]
    
    private let bioTemplates = [
        "🍳 [Cuisine] enthusiast | [Experience] years in the kitchen | Sharing my culinary journey",
        "👨‍🍳 Professional chef specializing in [Cuisine] | [Experience]+ years experience",
        "🌱 Plant-based recipes that don't compromise on flavor | [Cuisine] inspired",
        "Home cook passionate about [Cuisine] food | Learning every day 📚",
        "Food blogger | [Cuisine] recipes | Making cooking accessible for everyone",
        "[Experience] years of culinary adventures | [Cuisine] is my love language ❤️",
        "Michelin-trained chef bringing [Cuisine] to your home kitchen",
        "Weekend warrior in the kitchen | [Cuisine] obsessed | [Experience] years cooking",
        "Culinary student exploring [Cuisine] cuisine | Follow my journey 🎓",
        "Food is art 🎨 | Specializing in [Cuisine] | [Experience] years creating magic",
        "From grandma's recipes to modern [Cuisine] | Keeping traditions alive",
        "Self-taught chef | [Cuisine] fusion experiments | [Experience] years of practice",
        "[Cuisine] street food expert | Bringing authentic flavors to your kitchen",
        "Recipe developer | [Cuisine] specialist | [Experience]+ years in the industry",
        "Making [Cuisine] cooking simple and delicious | Home cook with [Experience] years experience"
    ]
    
    // MARK: - Generate Fake Users
    func generateFakeUsers() -> [(
        id: String,
        username: String,
        displayName: String,
        profileImageURL: String?,
        profileImage: UIImage?,
        followerCount: Int,
        followingCount: Int,
        recipesShared: Int,
        isVerified: Bool,
        isFollowing: Bool,
        bio: String?,
        isLocal: Bool,
        joinedDate: Date?,
        lastActive: Date?,
        cuisineSpecialty: String?,
        cookingLevel: String?
    )] {
        var users: [(
            id: String,
            username: String,
            displayName: String,
            profileImageURL: String?,
            profileImage: UIImage?,
            followerCount: Int,
            followingCount: Int,
            recipesShared: Int,
            isVerified: Bool,
            isFollowing: Bool,
            bio: String?,
            isLocal: Bool,
            joinedDate: Date?,
            lastActive: Date?,
            cuisineSpecialty: String?,
            cookingLevel: String?
        )] = []
        var usedUsernames = Set<String>()
        
        for i in 1...200 {
            let firstName = firstNames.randomElement()!
            let lastName = lastNames.randomElement()!
            let displayName = "\(firstName) \(lastName)"
            
            // Generate unique username
            var username = generateUsername(firstName: firstName, lastName: lastName)
            var attempt = 0
            while usedUsernames.contains(username) {
                attempt += 1
                username = "\(username)\(attempt)"
            }
            usedUsernames.insert(username)
            
            // Generate realistic follower counts with power law distribution
            let followerCount = generateFollowerCount(userIndex: i)
            // Ensure followingCount range is valid (upper bound must be >= lower bound)
            let maxFollowing = max(10, min(followerCount/2, 5000))
            let followingCount = Int.random(in: 10...maxFollowing)
            let recipesShared = generateRecipeCount(followerCount: followerCount)
            
            // Top 10% are verified
            let isVerified = i <= 20 || (i <= 50 && Bool.random())
            
            // Generate bio
            let cuisine = cuisineTypes.randomElement()!
            let experience = Int.random(in: 1...25)
            let bio = generateBio(cuisine: cuisine, experience: experience)
            
            let user = (
                id: "fake_user_\(i)",
                username: username,
                displayName: displayName,
                profileImageURL: nil as String?,
                profileImage: nil as UIImage?,
                followerCount: followerCount,
                followingCount: followingCount,
                recipesShared: recipesShared,
                isVerified: isVerified,
                isFollowing: Bool.random() && i > 50, // Some mid-tier users are already followed
                bio: bio as String?,
                isLocal: true, // Mark as local user
                joinedDate: Date().addingTimeInterval(-Double.random(in: 86400...31536000)) as Date?, // Random date in past year
                lastActive: Date().addingTimeInterval(-Double.random(in: 3600...604800)) as Date?, // Active in past week
                cuisineSpecialty: cuisine as String?,
                cookingLevel: generateCookingLevel(experience: experience) as String?
            )
            
            users.append(user)
        }
        
        // Sort by follower count (descending) to show popular users first
        return users.sorted { $0.followerCount > $1.followerCount }
    }
    
    // MARK: - Helper Functions
    private func generateUsername(firstName: String, lastName: String) -> String {
        let strategies = [
            { "\(firstName.lowercased())\(lastName.lowercased())" },
            { "\(firstName.lowercased())_\(lastName.lowercased())" },
            { "\(firstName.lowercased()).\(lastName.lowercased())" },
            { "chef\(firstName.lowercased())" },
            { "\(firstName.lowercased())cooks" },
            { "\(lastName.lowercased())kitchen" },
            { "\(firstName.prefix(1).lowercased())\(lastName.lowercased())" },
            { "\(firstName.lowercased())\(Int.random(in: 1...99))" },
            { "the\(firstName.lowercased())chef" },
            { "\(firstName.lowercased())_recipes" }
        ]
        
        return strategies.randomElement()!()
    }
    
    private func generateFollowerCount(userIndex: Int) -> Int {
        // Power law distribution for realistic social media follower counts
        if userIndex <= 5 {
            // Top influencers
            return Int.random(in: 100000...5000000)
        } else if userIndex <= 20 {
            // Popular chefs
            return Int.random(in: 10000...100000)
        } else if userIndex <= 50 {
            // Rising stars
            return Int.random(in: 1000...10000)
        } else if userIndex <= 100 {
            // Active community members
            return Int.random(in: 100...1000)
        } else {
            // Regular users
            return Int.random(in: 0...100)
        }
    }
    
    private func generateRecipeCount(followerCount: Int) -> Int {
        // More followers typically means more recipes shared
        if followerCount > 100000 {
            return Int.random(in: 200...2000)
        } else if followerCount > 10000 {
            return Int.random(in: 50...200)
        } else if followerCount > 1000 {
            return Int.random(in: 20...50)
        } else if followerCount > 100 {
            return Int.random(in: 5...20)
        } else {
            return Int.random(in: 0...5)
        }
    }
    
    private func generateBio(cuisine: String, experience: Int) -> String {
        let template = bioTemplates.randomElement()!
        return template
            .replacingOccurrences(of: "[Cuisine]", with: cuisine)
            .replacingOccurrences(of: "[Experience]", with: "\(experience)")
    }
    
    private func generateCookingLevel(experience: Int) -> String {
        if experience >= 15 {
            return "Master Chef"
        } else if experience >= 10 {
            return "Professional"
        } else if experience >= 5 {
            return "Advanced"
        } else if experience >= 2 {
            return "Intermediate"
        } else {
            return "Beginner"
        }
    }
}