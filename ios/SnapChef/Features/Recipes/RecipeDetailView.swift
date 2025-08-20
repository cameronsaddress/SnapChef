import SwiftUI
import CloudKit
import UIKit

struct RecipeDetailView: View {
    let recipe: Recipe
    var cloudKitRecipe: CloudKitRecipe?
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var showingPrintView = false
    @State private var showingComments = false
    @State private var isLiked = false
    @State private var likeCount = 0
    @State private var isLoadingLike = false
    @State private var showingUserProfile = false
    @State private var authorName = ""
    @State private var newCommentText = ""
    @State private var isSubmittingComment = false
    @State private var showingAllComments = false
    @State private var selectedUserID = ""
    @State private var selectedUserName = ""
    @State private var showingDeleteAlert = false
    @StateObject private var cloudKitSync = CloudKitSyncService.shared
    @StateObject private var cloudKitAuth = CloudKitAuthManager.shared
    @StateObject private var cloudKitRecipeManager = CloudKitRecipeManager.shared
    @StateObject private var commentsViewModel = RecipeCommentsViewModel()

    // New states for branded share
    @State private var showBrandedShare = false
    @State private var shareContent: ShareContent?
    
    // MARK: - ViewBuilder Helper Functions
    
    @ViewBuilder
    private var headerSection: some View {
        DetectiveCard {
            VStack(alignment: .leading, spacing: 16) {
                // Recipe title with like and share buttons
                HStack(alignment: .top, spacing: 12) {
                    Text(recipe.name)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                    
                    shareButton
                    likeButton
                }
                
                authorInfo
                
                Text(recipe.description)
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.9))
                
                HStack(spacing: 20) {
                    Label("\(recipe.prepTime + recipe.cookTime)m", systemImage: "clock")
                        .foregroundColor(Color(hex: "#9b59b6"))
                    Label("\(recipe.servings) servings", systemImage: "person.2")
                        .foregroundColor(Color(hex: "#9b59b6"))
                    Label(recipe.difficulty.rawValue, systemImage: "star.fill")
                        .foregroundColor(Color(hex: "#9b59b6"))
                }
                .font(.system(size: 16, weight: .medium))
            }
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var shareButton: some View {
        Button(action: {
            shareContent = ShareContent(
                type: .recipe(recipe),
                beforeImage: nil,
                afterImage: nil
            )
            showBrandedShare = true
        }) {
            VStack(spacing: 4) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#9b59b6"), Color(hex: "#8e44ad")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
    }
    
    @ViewBuilder
    private var likeButton: some View {
        Button(action: toggleLike) {
            VStack(spacing: 4) {
                ZStack {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(Color(hex: "#9b59b6"))
                        .scaleEffect(isLiked ? 1.1 : 0)
                        .opacity(isLiked ? 1 : 0)
                    
                    Image(systemName: "heart")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .scaleEffect(isLiked ? 0 : 1.0)
                        .opacity(isLiked ? 0 : 1)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: isLiked)
                
                if likeCount > 0 {
                    Text("\(likeCount)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isLiked ? Color(hex: "#9b59b6") : .white.opacity(0.6))
                        .animation(.easeInOut(duration: 0.2), value: isLiked)
                }
            }
        }
        .disabled(isLoadingLike)
        .opacity(isLoadingLike ? 0.6 : 1.0)
    }
    
    @ViewBuilder
    private var authorInfo: some View {
        if let cloudKitRecipe = cloudKitRecipe, !cloudKitRecipe.ownerID.isEmpty {
            Button(action: { showingUserProfile = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#9b59b6"))
                    Text("by \(authorName.isEmpty ? "Chef" : authorName)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#9b59b6"))
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    @ViewBuilder
    private var ingredientsSection: some View {
        DetectiveCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "list.bullet.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "#9b59b6"))
                    
                    Text("Ingredients")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                if recipe.ingredients.isEmpty {
                    Text("No ingredients listed")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                        .italic()
                        .padding(.vertical, 8)
                } else {
                    ForEach(recipe.ingredients) { ingredient in
                        HStack {
                            Image(systemName: ingredient.isAvailable ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(ingredient.isAvailable ? Color(hex: "#9b59b6") : .white.opacity(0.5))
                            Text("\(ingredient.quantity) \(ingredient.unit ?? "") \(ingredient.name)")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var instructionsSection: some View {
        DetectiveCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "#9b59b6"))
                    
                    Text("Instructions")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                if recipe.instructions.isEmpty {
                    Text("No instructions provided")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                        .italic()
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, instruction in
                        HStack(alignment: .top) {
                            Text("\(index + 1).")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color(hex: "#9b59b6"))
                                .frame(width: 30)
                            Text(instruction)
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private var optionalSections: some View {
        Group {
            cookingTechniquesSection
            flavorProfileSection
            secretIngredientsSection
            proTipsSection
            visualCluesSection
        }
    }
    
    @ViewBuilder
    private var cookingTechniquesSection: some View {
        if !recipe.cookingTechniques.isEmpty {
            DetectiveCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(hex: "#9b59b6"))
                        
                        Text("Cooking Techniques")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    
                    ForEach(recipe.cookingTechniques, id: \.self) { technique in
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#9b59b6"))
                            Text(technique)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    private var flavorProfileSection: some View {
        if let flavorProfile = recipe.flavorProfile,
           (flavorProfile.sweet > 0 || flavorProfile.salty > 0 || flavorProfile.sour > 0 || 
            flavorProfile.bitter > 0 || flavorProfile.umami > 0) {
            DetectiveCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(hex: "#9b59b6"))
                        
                        Text("Flavor Profile")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    
                    VStack(spacing: 12) {
                        FlavorBar(label: "Sweet", value: flavorProfile.sweet, color: Color(hex: "#ff6b6b"))
                        FlavorBar(label: "Salty", value: flavorProfile.salty, color: Color(hex: "#4ecdc4"))
                        FlavorBar(label: "Sour", value: flavorProfile.sour, color: Color(hex: "#ffe66d"))
                        FlavorBar(label: "Bitter", value: flavorProfile.bitter, color: Color(hex: "#95e77e"))
                        FlavorBar(label: "Umami", value: flavorProfile.umami, color: Color(hex: "#a8e6cf"))
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    private var secretIngredientsSection: some View {
        if !recipe.secretIngredients.isEmpty {
            DetectiveCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(hex: "#9b59b6"))
                        
                        Text("Secret Ingredients")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    
                    ForEach(recipe.secretIngredients, id: \.self) { secret in
                        HStack {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#9b59b6"))
                            Text(secret)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    private var proTipsSection: some View {
        if !recipe.proTips.isEmpty {
            DetectiveCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(hex: "#9b59b6"))
                        
                        Text("Pro Tips")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    
                    ForEach(Array(recipe.proTips.enumerated()), id: \.offset) { index, tip in
                        HStack(alignment: .top) {
                            Text("\(index + 1).")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(hex: "#9b59b6"))
                                .frame(width: 25)
                            Text(tip)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    private var visualCluesSection: some View {
        if !recipe.visualClues.isEmpty {
            DetectiveCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(hex: "#9b59b6"))
                        
                        Text("Visual Clues")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    
                    ForEach(recipe.visualClues, id: \.self) { clue in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#43e97b"))
                            Text(clue)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    private var nutritionSection: some View {
        DetectiveCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "#9b59b6"))
                    
                    Text("Nutrition Facts")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                HStack(spacing: 16) {
                    RecipeDetailNutritionItem(label: "Calories", value: "\(recipe.nutrition.calories)")
                    RecipeDetailNutritionItem(label: "Protein", value: "\(recipe.nutrition.protein)g")
                    RecipeDetailNutritionItem(label: "Carbs", value: "\(recipe.nutrition.carbs)g")
                    RecipeDetailNutritionItem(label: "Fat", value: "\(recipe.nutrition.fat)g")
                }
            }
        }
        .padding(.horizontal, 20)
    }

    var body: some View {
        ZStack {
            // Dark detective background
            LinearGradient(
                colors: [
                    Color(hex: "#0f0625"),
                    Color(hex: "#1a0033"),
                    Color(hex: "#0a051a")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    // Header with close button
                    HStack {
                        Button(action: { showingPrintView = true }) {
                            Image(systemName: "printer")
                                .font(.system(size: 28))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "#9b59b6"), Color(hex: "#8e44ad")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        
                        Spacer()
                        
                        Button("Done") {
                            dismiss()
                        }
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Recipe before/after photos
                    RecipePhotoView(
                        recipe: recipe,
                        width: UIScreen.main.bounds.width - 40,
                        height: 250,
                        showLabels: true
                    )
                    .padding(.horizontal, 20)

                    // Recipe Info
                    headerSection

                    // Ingredients
                    ingredientsSection

                    // Instructions
                    instructionsSection
                    
                    // Optional sections (cooking techniques, flavor profile, etc.)
                    optionalSections

                    // Nutrition
                    nutritionSection

                    // Delete Recipe Button
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .font(.system(size: 18, weight: .medium))
                            Text("Delete Recipe")
                                .font(.system(size: 18, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)

                    // Comments Section
                    commentsSection
                    
                    Spacer(minLength: 50)
                }
            }
        }
        .navigationBarHidden(true)
            .sheet(isPresented: $showingPrintView) {
                RecipePrintView(recipe: recipe)
            }
            .sheet(isPresented: $showingUserProfile) {
                if !selectedUserID.isEmpty {
                    UserProfileView(userID: selectedUserID, userName: selectedUserName)
                        .onDisappear {
                            selectedUserID = ""
                            selectedUserName = ""
                        }
                } else if let cloudKitRecipe = cloudKitRecipe {
                    UserProfileView(userID: cloudKitRecipe.ownerID, userName: authorName)
                }
            }
            .sheet(isPresented: $showingAllComments) {
                RecipeCommentsView(recipe: recipe)
            }
            // Add branded share popup
            .sheet(isPresented: $showBrandedShare) {
                if let content = shareContent {
                    BrandedSharePopup(content: content)
                }
            }
            .alert("Delete Recipe?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteRecipe()
                }
            } message: {
                Text("Are you sure you want to delete \"\(recipe.name)\"? This action cannot be undone.")
            }
            .onAppear {
                print("🔍 DEBUG: RecipeDetailView appeared for recipe: \(recipe.name)")
                print("🔍 RECIPE ENHANCED FIELDS IN UI:")
                print("🔍   - cookingTechniques: \(recipe.cookingTechniques.isEmpty ? "EMPTY" : "\(recipe.cookingTechniques)")")
                print("🔍   - flavorProfile: \(recipe.flavorProfile != nil ? "PRESENT" : "NIL")")
                if let fp = recipe.flavorProfile {
                    print("🔍     • sweet: \(fp.sweet), salty: \(fp.salty), sour: \(fp.sour), bitter: \(fp.bitter), umami: \(fp.umami)")
                }
                print("🔍   - secretIngredients: \(recipe.secretIngredients.isEmpty ? "EMPTY" : "\(recipe.secretIngredients)")")
                print("🔍   - proTips: \(recipe.proTips.isEmpty ? "EMPTY" : "\(recipe.proTips)")")
                print("🔍   - visualClues: \(recipe.visualClues.isEmpty ? "EMPTY" : "\(recipe.visualClues)")")
                print("🔍   - shareCaption: \(recipe.shareCaption.isEmpty ? "EMPTY" : "\"\(recipe.shareCaption)\"")")
                print("🔍   - isDetectiveRecipe: \(recipe.isDetectiveRecipe)")
                print("🔍 UI SECTIONS VISIBILITY:")
                print("🔍   - cookingTechniquesSection will show: \(!recipe.cookingTechniques.isEmpty)")
                print("🔍   - secretIngredientsSection will show: \(!recipe.secretIngredients.isEmpty)")
                print("🔍   - proTipsSection will show: \(!recipe.proTips.isEmpty)")
                print("🔍   - visualCluesSection will show: \(!recipe.visualClues.isEmpty)")
            }
            .task {
                await loadLikeStatus()
                await loadAuthorInfo()
                
                print("🔍 RecipeDetailView: Loading comments for recipe: \(recipe.name) (ID: \(recipe.id.uuidString))")
                print("🔍 Authentication status: \(cloudKitAuth.isAuthenticated)")
                if let user = cloudKitAuth.currentUser {
                    print("🔍 Current user: \(user.displayName) (ID: \(user.recordID))")
                } else {
                    print("🔍 No current user found")
                }
                
                await commentsViewModel.loadComments(for: recipe.id.uuidString)
            }
        }

    // MARK: - Delete Recipe
    private func deleteRecipe() {
        withAnimation(.spring()) {
            appState.deleteRecipe(recipe)

            // Also remove from CloudKit if it's a CloudKit recipe
            if cloudKitAuth.isAuthenticated {
                Task {
                    do {
                        // Remove from saved recipes in CloudKit
                        try await cloudKitRecipeManager.removeRecipeFromUserProfile(
                            recipe.id.uuidString,
                            type: .saved
                        )
                        // Also remove from created if it was created by user
                        try await cloudKitRecipeManager.removeRecipeFromUserProfile(
                            recipe.id.uuidString,
                            type: .created
                        )
                        print("✅ Removed recipe from CloudKit")
                    } catch {
                        print("❌ Failed to remove recipe from CloudKit: \(error)")
                    }
                }
            }

            // Dismiss the detail view after deletion
            dismiss()
        }
    }

    private func toggleLike() {
        guard !isLoadingLike else { return }

        // Haptic feedback
        let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        impactGenerator.impactOccurred()

        Task {
            isLoadingLike = true
            defer { isLoadingLike = false }

            do {
                if isLiked {
                    try await cloudKitSync.unlikeRecipe(recipe.id.uuidString)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isLiked = false
                        likeCount = max(0, likeCount - 1)
                    }
                } else {
                    // For demo purposes, use current user ID as owner ID
                    let ownerID = CloudKitAuthManager.shared.currentUser?.recordID ?? "anonymous"
                    try await cloudKitSync.likeRecipe(recipe.id.uuidString, recipeOwnerID: ownerID)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isLiked = true
                        likeCount += 1
                    }

                    // Success haptic for like
                    let successGenerator = UINotificationFeedbackGenerator()
                    successGenerator.notificationOccurred(.success)
                }
            } catch {
                print("Failed to toggle like: \(error)")
                // Error haptic
                let errorGenerator = UINotificationFeedbackGenerator()
                errorGenerator.notificationOccurred(.error)
            }
        }
    }

    private func loadLikeStatus() async {
        do {
            isLiked = try await cloudKitSync.isRecipeLiked(recipe.id.uuidString)
            likeCount = try await cloudKitSync.getRecipeLikeCount(recipe.id.uuidString)
        } catch {
            print("Failed to load like status: \(error)")
        }
    }

    private func loadAuthorInfo() async {
        guard let cloudKitRecipe = cloudKitRecipe, !cloudKitRecipe.ownerID.isEmpty else { return }

        do {
            let database = CKContainer(identifier: CloudKitConfig.containerIdentifier).publicCloudDatabase
            let record = try await database.record(for: CKRecord.ID(recordName: cloudKitRecipe.ownerID))
            let user = CloudKitUser(from: record)
            await MainActor.run {
                authorName = user.displayName
            }
        } catch {
            print("Failed to load author info: \(error)")
        }
    }

    private func submitComment() {
        let trimmedText = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        // Check if user is authenticated
        guard cloudKitAuth.isAuthenticated else {
            print("❌ Cannot submit comment: User not authenticated")
            // TODO: Show authentication prompt
            return
        }

        Task {
            isSubmittingComment = true
            defer { isSubmittingComment = false }

            print("🔍 Submitting comment for recipe: \(recipe.id.uuidString)")
            print("📝 Comment content: \(trimmedText)")

            await commentsViewModel.addComment(
                to: recipe.id.uuidString,
                content: trimmedText
            )

            await MainActor.run {
                newCommentText = ""
            }
        }
    }

    // MARK: - Share Functions
    // shareVia function removed - now using branded popup directly

    private func shareRecipe() {
        let recipeText = """
        \(recipe.name)

        \(recipe.description)

        ⏱ Cooking time: \(recipe.prepTime + recipe.cookTime) minutes
        🍽 Servings: \(recipe.servings)
        📊 Difficulty: \(recipe.difficulty.rawValue)

        Created with SnapChef - Turn your fridge into amazing recipes!
        """

        let activityVC = UIActivityViewController(activityItems: [recipeText], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            // For iPad
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
            }
            rootVC.present(activityVC, animated: true)
        }
    }
}

struct RecipeDetailNutritionItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "#9b59b6"))
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Detective Comment Row
struct DetectiveCommentRow: View {
    let comment: CommentItem
    let onUserTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // User Avatar
                Button(action: onUserTap) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#9b59b6"), Color(hex: "#8e44ad")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(comment.userName.prefix(1).uppercased())
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(hex: "#2d1b69"))
                        )
                }
                .buttonStyle(PlainButtonStyle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Button(action: onUserTap) {
                            Text(comment.userName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "#9b59b6"))
                        }
                        .buttonStyle(PlainButtonStyle())

                        Text("• \(comment.timeAgoText)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))

                        Spacer()
                    }

                    Text(comment.content)
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Recipe Comment Row (kept for compatibility)
struct RecipeCommentRow: View {
    let comment: CommentItem
    let onUserTap: () -> Void

    var body: some View {
        DetectiveCommentRow(comment: comment, onUserTap: onUserTap)
    }
}

// MARK: - Recipe Print View
struct RecipePrintView: View {
    let recipe: Recipe
    @Environment(\.dismiss) var dismiss
    @State private var isPrinting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .center, spacing: 12) {
                        Text("SnapChef Recipe")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)

                        Text(recipe.name)
                            .font(.system(size: 28, weight: .bold))
                            .multilineTextAlignment(.center)

                        HStack(spacing: 20) {
                            Label("\(recipe.prepTime + recipe.cookTime) min", systemImage: "clock")
                            Label("\(recipe.servings) servings", systemImage: "person.2")
                            Label(recipe.difficulty.rawValue, systemImage: "star")
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 10)

                    Divider()

                    // Ingredients
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ingredients")
                            .font(.system(size: 20, weight: .bold))

                        ForEach(recipe.ingredients) { ingredient in
                            HStack {
                                Text("•")
                                    .font(.system(size: 16))
                                Text("\(ingredient.quantity) \(ingredient.unit ?? "") \(ingredient.name)")
                                    .font(.system(size: 16))
                            }
                        }
                    }
                    .padding(.bottom, 10)

                    Divider()

                    // Instructions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Instructions")
                            .font(.system(size: 20, weight: .bold))

                        ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, instruction in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1).")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(width: 25, alignment: .trailing)
                                Text(instruction)
                                    .font(.system(size: 16))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.bottom, 8)
                        }
                    }
                    .padding(.bottom, 10)

                    Divider()

                    // Nutrition
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nutrition Facts (per serving)")
                            .font(.system(size: 16, weight: .bold))

                        HStack(spacing: 20) {
                            Text("Calories: \(recipe.nutrition.calories)")
                            Text("Protein: \(recipe.nutrition.protein)g")
                            Text("Carbs: \(recipe.nutrition.carbs)g")
                            Text("Fat: \(recipe.nutrition.fat)g")
                        }
                        .font(.system(size: 14))
                    }

                    Spacer(minLength: 40)

                    // Footer
                    Text("Created with SnapChef • \(Date().formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(30)
                .background(Color.white)
                .cornerRadius(0)
            }
            .background(Color.gray.opacity(0.1))
            .navigationTitle("Print Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: printRecipe) {
                        Label("Print", systemImage: "printer.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .disabled(isPrinting)
                }
            }
        }
    }

    private func printRecipe() {
        isPrinting = true

        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = "SnapChef Recipe - \(recipe.name)"
        printInfo.outputType = .general

        let printController = UIPrintInteractionController.shared
        printController.printInfo = printInfo

        // Create a text representation of the recipe
        let formatter = UISimpleTextPrintFormatter(text: createPrintableText())
        formatter.perPageContentInsets = UIEdgeInsets(top: 72, left: 72, bottom: 72, right: 72)

        printController.printFormatter = formatter

        printController.present(animated: true) { _, completed, error in
            isPrinting = false
            if completed {
                dismiss()
            } else if let error = error {
                print("Print error: \(error.localizedDescription)")
            }
        }
    }

    private func createPrintableText() -> String {
        var text = "SNAPCHEF RECIPE\n\n"
        text += "\(recipe.name.uppercased())\n\n"
        text += "Prep Time: \(recipe.prepTime) min | Cook Time: \(recipe.cookTime) min\n"
        text += "Servings: \(recipe.servings) | Difficulty: \(recipe.difficulty.rawValue)\n\n"

        text += "INGREDIENTS\n"
        text += String(repeating: "-", count: 40) + "\n"
        for ingredient in recipe.ingredients {
            text += "• \(ingredient.quantity) \(ingredient.unit ?? "") \(ingredient.name)\n"
        }

        text += "\nINSTRUCTIONS\n"
        text += String(repeating: "-", count: 40) + "\n"
        for (index, instruction) in recipe.instructions.enumerated() {
            text += "\(index + 1). \(instruction)\n\n"
        }

        text += "\nNUTRITION FACTS (per serving)\n"
        text += String(repeating: "-", count: 40) + "\n"
        text += "Calories: \(recipe.nutrition.calories) | "
        text += "Protein: \(recipe.nutrition.protein)g | "
        text += "Carbs: \(recipe.nutrition.carbs)g | "
        text += "Fat: \(recipe.nutrition.fat)g\n\n"

        text += "\nCreated with SnapChef • \(Date().formatted(date: .abbreviated, time: .omitted))"

        return text
    }
}

// MARK: - Comments Section
extension RecipeDetailView {
    @ViewBuilder
    private var commentsSection: some View {
        DetectiveCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "#9b59b6"))
                    
                    Text("Comments")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if !commentsViewModel.comments.isEmpty {
                        Text("\(commentsViewModel.comments.count)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                // Comment Input
                if cloudKitAuth.isAuthenticated {
                    HStack(spacing: 12) {
                        TextField("Add a comment...", text: $newCommentText)
                            .textFieldStyle(DetectiveTextFieldStyle())

                        Button(action: submitComment) {
                            if isSubmittingComment {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(Color(hex: "#9b59b6"))
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(newCommentText.isEmpty ? .white.opacity(0.5) : Color(hex: "#9b59b6"))
                            }
                        }
                        .disabled(newCommentText.isEmpty || isSubmittingComment)
                    }
                } else {
                    HStack(spacing: 12) {
                        Text("Sign in to comment")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        
                        Button(action: {
                            cloudKitAuth.showAuthSheet = true
                        }) {
                            Image(systemName: "person.circle")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "#9b59b6"))
                        }
                    }
                }

                // Comments List
                if commentsViewModel.isLoading && commentsViewModel.comments.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(Color(hex: "#9b59b6"))
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else if commentsViewModel.comments.isEmpty {
                    Text("Be the first to comment!")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.vertical, 20)
                } else {
                    ForEach(commentsViewModel.comments.prefix(5)) { comment in
                        DetectiveCommentRow(comment: comment, onUserTap: {
                            selectedUserID = comment.userID
                            selectedUserName = comment.userName
                            showingUserProfile = true
                        })
                        .padding(.vertical, 8)
                    }

                    if commentsViewModel.comments.count > 5 {
                        Button(action: { showingAllComments = true }) {
                            Text("View all \(commentsViewModel.comments.count) comments")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: "#9b59b6"))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Supporting Views

struct DetectiveTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .foregroundColor(.white)
    }
}

#Preview {
    RecipeDetailView(recipe: MockDataProvider.shared.mockRecipe())
        .environmentObject(AppState())
}
