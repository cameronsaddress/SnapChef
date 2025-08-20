import Foundation
import SwiftUI
import Combine

/// ChallengeProgressTracker monitors and updates challenge progress in real-time
@MainActor
class ChallengeProgressTracker: ObservableObject {
    // MARK: - Properties
    static let shared = ChallengeProgressTracker()

    @Published var activeTracking: [String: TrackingSession] = [:]
    @Published var recentActions: [ChallengeAction] = []
    @Published var milestoneReached: MilestoneNotification?

    private let gamificationManager = GamificationManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var trackingTimers: [String: Timer] = [:]

    // Action types that can trigger progress
    enum ActionType: String {
        case recipeCreated = "recipe_created"
        case recipeRated = "recipe_rated"
        case recipeShared = "recipe_shared"
        case ingredientScanned = "ingredient_scanned"
        case timeCompleted = "time_completed"
        case streakMaintained = "streak_maintained"
        case perfectScore = "perfect_score"
        case cuisineExplored = "cuisine_explored"
        case calorieTarget = "calorie_target"
        case proteinTarget = "protein_target"
        case mealPrepCompleted = "meal_prep"
    }

    // MARK: - Initialization
    private init() {
        setupObservers()
    }

    // MARK: - Setup
    private func setupObservers() {
        // Observe recipe creation
        NotificationCenter.default.publisher(for: Notification.Name("RecipeCreated"))
            .sink { [weak self] notification in
                if let recipe = notification.object as? Recipe {
                    self?.handleRecipeCreated(recipe)
                }
            }
            .store(in: &cancellables)

        // Observe recipe rating
        NotificationCenter.default.publisher(for: Notification.Name("RecipeRated"))
            .sink { [weak self] notification in
                if let info = notification.userInfo,
                   let rating = info["rating"] as? Int {
                    self?.handleRecipeRated(rating: rating)
                }
            }
            .store(in: &cancellables)

        // Observe recipe sharing
        NotificationCenter.default.publisher(for: Notification.Name("RecipeShared"))
            .sink { [weak self] _ in
                self?.handleRecipeShared()
            }
            .store(in: &cancellables)
    }

    // MARK: - Progress Tracking

    /// Start tracking a specific challenge
    func startTracking(challenge: Challenge) {
        let session = TrackingSession(
            challengeId: challenge.id,
            startTime: Date(),
            targetValue: extractTargetValue(from: challenge),
            currentValue: 0
        )

        activeTracking[challenge.id] = session

        // Start timer-based tracking if needed
        if challenge.title.lowercased().contains("speed") || challenge.title.lowercased().contains("minute") {
            startTimerTracking(for: challenge)
        }
    }

    /// Stop tracking a specific challenge
    func stopTracking(challengeId: String) {
        activeTracking.removeValue(forKey: challengeId)

        // Stop timer if exists
        trackingTimers[challengeId]?.invalidate()
        trackingTimers.removeValue(forKey: challengeId)
    }

    /// Track a specific action
    func trackAction(_ action: ActionType, metadata: [String: Any] = [:]) {
        let challengeAction = ChallengeAction(
            type: action,
            timestamp: Date(),
            metadata: metadata
        )

        recentActions.append(challengeAction)

        // Keep only recent actions (last 100)
        if recentActions.count > 100 {
            recentActions.removeFirst()
        }

        // Update relevant challenges
        updateChallengesForAction(action, metadata: metadata)
    }

    // MARK: - Action Handlers

    func handleRecipeCreated(_ recipe: Recipe) {
        trackAction(.recipeCreated, metadata: [
            "recipeId": recipe.id,
            "calories": recipe.nutrition.calories,
            "protein": recipe.nutrition.protein,
            "cuisine": recipe.tags.first ?? "",
            "ingredientCount": recipe.ingredients.count,
            "prepTime": recipe.prepTime
        ])

        // Update recipe count for relevant challenges
        for challenge in gamificationManager.activeChallenges {
            if shouldUpdateForRecipeCreation(challenge: challenge, recipe: recipe) {
                incrementProgress(for: challenge)
            }
        }
    }

    private func handleRecipeRated(rating: Int) {
        trackAction(.recipeRated, metadata: ["rating": rating])

        if rating == 5 {
            trackAction(.perfectScore)

            // Update perfect recipe challenges
            for challenge in gamificationManager.activeChallenges {
                if challenge.title.lowercased().contains("perfect") {
                    incrementProgress(for: challenge)
                }
            }
        }
    }

    private func handleRecipeShared() {
        trackAction(.recipeShared)

        // Update sharing challenges
        for challenge in gamificationManager.activeChallenges {
            if challenge.title.lowercased().contains("share") || challenge.title.lowercased().contains("social") {
                incrementProgress(for: challenge)
            }
        }
    }

    // MARK: - Progress Updates

    private func updateChallengesForAction(_ action: ActionType, metadata: [String: Any]) {
        for challenge in gamificationManager.activeChallenges {
            var shouldUpdate = false
            var progressIncrement: Double = 0

            switch action {
            case .recipeCreated:
                if challenge.requirements.first?.contains("recipe") ?? false {
                    shouldUpdate = true
                    progressIncrement = 1.0 / Double(extractTargetValue(from: challenge))
                }

            case .cuisineExplored:
                if challenge.title.lowercased().contains("cuisine") || challenge.title.lowercased().contains("international") {
                    shouldUpdate = true
                    progressIncrement = 1.0 / Double(extractTargetValue(from: challenge))
                }

            case .calorieTarget:
                if challenge.title.lowercased().contains("calorie") || challenge.title.lowercased().contains("healthy") {
                    shouldUpdate = true
                    progressIncrement = 1.0 / Double(extractTargetValue(from: challenge))
                }

            case .proteinTarget:
                if challenge.title.lowercased().contains("protein") {
                    shouldUpdate = true
                    progressIncrement = 1.0 / Double(extractTargetValue(from: challenge))
                }

            case .timeCompleted:
                if challenge.title.lowercased().contains("speed") || challenge.title.lowercased().contains("quick") {
                    shouldUpdate = true
                    progressIncrement = 1.0 / Double(extractTargetValue(from: challenge))
                }

            case .mealPrepCompleted:
                if challenge.title.lowercased().contains("meal prep") {
                    shouldUpdate = true
                    progressIncrement = 1.0 / Double(extractTargetValue(from: challenge))
                }

            default:
                break
            }

            if shouldUpdate {
                let newProgress = min(challenge.currentProgress + progressIncrement, 1.0)
                updateProgress(for: challenge, to: newProgress)

                // Save progress to Core Data
                gamificationManager.saveChallengeProgress(
                    challengeId: challenge.id,
                    action: action.rawValue,
                    value: newProgress
                )
            }
        }
    }

    private func incrementProgress(for challenge: Challenge) {
        if var session = activeTracking[challenge.id] {
            session.currentValue += 1
            activeTracking[challenge.id] = session
            let progress = Double(session.currentValue) / Double(session.targetValue)
            updateProgress(for: challenge, to: min(progress, 1.0))
        } else {
            // Calculate increment based on requirement
            let target = extractTargetValue(from: challenge)
            let increment = 1.0 / Double(target)
            let newProgress = min(challenge.currentProgress + increment, 1.0)
            updateProgress(for: challenge, to: newProgress)
        }
    }

    private func updateProgress(for challenge: Challenge, to newProgress: Double) {
        let oldProgress = challenge.currentProgress
        gamificationManager.updateChallengeProgress(challenge.id, progress: newProgress)

        // Check for milestones
        checkMilestone(challenge: challenge, oldProgress: oldProgress, newProgress: newProgress)

        // Complete challenge if progress reaches 100%
        if newProgress >= 1.0 && oldProgress < 1.0 {
            completeChallenge(challenge)
        }
    }

    // MARK: - Timer-based Tracking

    private func startTimerTracking(for challenge: Challenge) {
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTimerProgress(for: challenge)
            }
        }

        trackingTimers[challenge.id] = timer
    }

    private func updateTimerProgress(for challenge: Challenge) {
        guard let session = activeTracking[challenge.id] else { return }

        let elapsedTime = Date().timeIntervalSince(session.startTime)
        let targetTime = Double(extractTargetValue(from: challenge) * 60) // Convert minutes to seconds

        if elapsedTime >= targetTime {
            // Timer completed
            trackAction(.timeCompleted, metadata: ["challengeId": challenge.id])
            stopTracking(challengeId: challenge.id)
        }
    }

    // MARK: - Helper Methods

    private func shouldUpdateForRecipeCreation(challenge: Challenge, recipe: Recipe) -> Bool {
        let title = challenge.title.lowercased()
        let description = challenge.description.lowercased()

        // Check various conditions
        if title.contains("recipe") || description.contains("recipe") {
            // Check specific constraints
            if title.contains("calorie") || description.contains("calorie") {
                let calories = recipe.nutrition.calories
                if let targetCalories = extractCalorieTarget(from: challenge) {
                    return calories <= targetCalories
                }
            }

            if title.contains("ingredient") {
                if let targetIngredients = extractIngredientTarget(from: challenge) {
                    return recipe.ingredients.count <= targetIngredients
                }
            }

            if title.contains("protein") {
                let protein = recipe.nutrition.protein
                if let targetProtein = extractProteinTarget(from: challenge) {
                    return protein >= targetProtein
                }
            }

            if title.contains("vegetarian") || title.contains("vegan") || title.contains("plant-based") {
                return recipe.dietaryInfo.isVegetarian || recipe.dietaryInfo.isVegan
            }

            // Check for cuisine matches in tags
            for tag in recipe.tags {
                if title.contains(tag.lowercased()) || description.contains(tag.lowercased()) {
                    return true
                }
            }

            // Default: any recipe counts
            return true
        }

        return false
    }

    private func extractTargetValue(from challenge: Challenge) -> Int {
        // Extract number from requirement string (e.g., "0/10 recipes" -> 10)
        let requirementText = challenge.requirements.first ?? ""
        let components = requirementText.split(separator: "/")
        if components.count >= 2 {
            let targetString = components[1].split(separator: " ")[0]
            return Int(targetString) ?? 1
        }
        return 1
    }

    private func extractCalorieTarget(from challenge: Challenge) -> Int? {
        // Extract calorie target from title or description
        let text = challenge.title + " " + challenge.description
        let pattern = #"(\d+)\s*calories?"#

        if let match = text.range(of: pattern, options: .regularExpression) {
            let numberString = text[match].split(separator: " ")[0]
            return Int(numberString)
        }

        return nil
    }

    private func extractIngredientTarget(from challenge: Challenge) -> Int? {
        // Extract ingredient count from title or description
        let text = challenge.title + " " + challenge.description
        let pattern = #"(\d+)\s*ingredients?"#

        if let match = text.range(of: pattern, options: .regularExpression) {
            let numberString = text[match].split(separator: " ")[0]
            return Int(numberString)
        }

        return nil
    }

    private func extractProteinTarget(from challenge: Challenge) -> Int? {
        // Extract protein target from title or description
        let text = challenge.title + " " + challenge.description
        let pattern = #"(\d+)g?\s*protein"#

        if let match = text.range(of: pattern, options: .regularExpression) {
            let matchedString = String(text[match])
            let numbers = matchedString.filter { $0.isNumber }
            return Int(numbers)
        }

        return nil
    }

    // MARK: - Milestones & Completion

    private func checkMilestone(challenge: Challenge, oldProgress: Double, newProgress: Double) {
        let milestones: [Double] = [0.25, 0.5, 0.75, 1.0]

        for milestone in milestones {
            if oldProgress < milestone && newProgress >= milestone {
                // Milestone reached
                let notification = MilestoneNotification(
                    challengeId: challenge.id,
                    challengeTitle: challenge.title,
                    milestone: milestone,
                    reward: milestone == 1.0 ? challenge.points : Int(Double(challenge.points) * milestone * 0.2)
                )

                milestoneReached = notification

                // Clear notification after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if self.milestoneReached?.challengeId == challenge.id {
                        self.milestoneReached = nil
                    }
                }

                break
            }
        }
    }

    private func completeChallenge(_ challenge: Challenge) {
        // Calculate final score based on completion time and other factors
        var score = challenge.points

        if let session = activeTracking[challenge.id] {
            let completionTime = Date().timeIntervalSince(session.startTime)
            let expectedTime = Double(extractTargetValue(from: challenge) * 60)

            if completionTime < expectedTime * 0.8 {
                // Bonus for fast completion
                score = Int(Double(score) * 1.2)
            }
        }

        // Complete the challenge
        gamificationManager.completeChallengeWithPersistence(challenge, score: score)

        // Create activity for challenge completion
        Task {
            if CloudKitAuthManager.shared.isAuthenticated,
               let userID = CloudKitAuthManager.shared.currentUser?.recordID {
                do {
                    try await CloudKitSyncService.shared.createActivity(
                        type: "challengeCompleted",
                        actorID: userID,
                        challengeID: challenge.id,
                        challengeName: challenge.title
                    )
                } catch {
                    print("Failed to create challenge completion activity: \(error)")
                }
            }
            
            // Track challenge completion streak
            await StreakManager.shared.recordActivity(for: .challengeCompletion)
        }

        // Stop tracking
        stopTracking(challengeId: challenge.id)

        // Show completion notification
        showCompletionNotification(for: challenge, score: score)
    }

    private func showCompletionNotification(for challenge: Challenge, score: Int) {
        // This would trigger a UI notification
        NotificationCenter.default.post(
            name: Notification.Name("ChallengeCompleted"),
            object: nil,
            userInfo: [
                "challengeId": challenge.id,
                "title": challenge.title,
                "score": score,
                "reward": challenge
            ]
        )
    }
}

// MARK: - Supporting Types

struct TrackingSession {
    let challengeId: String
    let startTime: Date
    let targetValue: Int
    var currentValue: Int
}

struct ChallengeAction {
    let id = UUID()
    let type: ChallengeProgressTracker.ActionType
    let timestamp: Date
    let metadata: [String: Any]
}

struct MilestoneNotification: Identifiable {
    let id = UUID()
    let challengeId: String
    let challengeTitle: String
    let milestone: Double
    let reward: Int

    var message: String {
        let percentage = Int(milestone * 100)
        return "\(percentage)% complete! +\(reward) points"
    }
}

// MARK: - Progress Analytics
extension ChallengeProgressTracker {
    /// Get progress analytics for a specific challenge
    func getAnalytics(for challengeId: String) -> ChallengeAnalytics? {
        guard let session = activeTracking[challengeId] else { return nil }

        let elapsedTime = Date().timeIntervalSince(session.startTime)
        let progressRate = Double(session.currentValue) / elapsedTime
        let estimatedCompletion = session.targetValue > session.currentValue ?
            Date().addingTimeInterval(Double(session.targetValue - session.currentValue) / progressRate) : nil

        return ChallengeAnalytics(
            challengeId: challengeId,
            startTime: session.startTime,
            elapsedTime: elapsedTime,
            progressRate: progressRate,
            estimatedCompletion: estimatedCompletion,
            actionsPerformed: recentActions.filter { action in
                if let actionChallengeId = action.metadata["challengeId"] as? String {
                    return actionChallengeId == challengeId
                }
                return false
            }.count
        )
    }
}

struct ChallengeAnalytics {
    let challengeId: String
    let startTime: Date
    let elapsedTime: TimeInterval
    let progressRate: Double
    let estimatedCompletion: Date?
    let actionsPerformed: Int
}
