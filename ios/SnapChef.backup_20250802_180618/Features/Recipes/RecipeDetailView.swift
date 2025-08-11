import SwiftUI
import CloudKit
import UIKit

struct RecipeDetailView: View {
    let recipe: Recipe
    var cloudKitRecipe: CloudKitRecipe?
    @Environment(\.dismiss) var dismiss
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
    @StateObject private var cloudKitSync = CloudKitSyncService.shared
    @StateObject private var cloudKitAuth = CloudKitAuthManager.shared
    @StateObject private var commentsViewModel = RecipeCommentsViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Recipe Image Placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#667eea"),
                                        Color(hex: "#764ba2")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 250)
                        
                        Text(recipe.difficulty.emoji)
                            .font(.system(size: 80))
                    }
                    
                    // Recipe Info
                    VStack(alignment: .leading, spacing: 16) {
                        // Recipe title with like and share buttons
                        HStack(alignment: .top, spacing: 12) {
                            Text(recipe.name)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer()
                            
                            // Share button
                            Menu {
                                Button(action: { shareVia("instagram") }) {
                                    Label("Instagram", systemImage: "camera")
                                }
                                Button(action: { shareVia("tiktok") }) {
                                    Label("TikTok", systemImage: "music.note")
                                }
                                Button(action: { shareVia("twitter") }) {
                                    Label("X (Twitter)", systemImage: "bubble.left")
                                }
                                Button(action: { shareVia("whatsapp") }) {
                                    Label("WhatsApp", systemImage: "message")
                                }
                                Divider()
                                Button(action: { shareRecipe() }) {
                                    Label("More Options", systemImage: "ellipsis")
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            // Like button
                            Button(action: toggleLike) {
                                VStack(spacing: 4) {
                                    ZStack {
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 24, weight: .medium))
                                            .foregroundColor(.pink)
                                            .scaleEffect(isLiked ? 1.1 : 0)
                                            .opacity(isLiked ? 1 : 0)
                                        
                                        Image(systemName: "heart")
                                            .font(.system(size: 24, weight: .medium))
                                            .foregroundColor(.gray)
                                            .scaleEffect(isLiked ? 0 : 1.0)
                                            .opacity(isLiked ? 0 : 1)
                                    }
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: isLiked)
                                    
                                    if likeCount > 0 {
                                        Text("\(likeCount)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(isLiked ? .pink : .gray)
                                            .animation(.easeInOut(duration: 0.2), value: isLiked)
                                    }
                                }
                            }
                            .disabled(isLoadingLike)
                            .opacity(isLoadingLike ? 0.6 : 1.0)
                        }
                        
                        // Author info (if available)
                        if let cloudKitRecipe = cloudKitRecipe, !cloudKitRecipe.ownerID.isEmpty {
                            Button(action: { showingUserProfile = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.blue)
                                    Text("by \(authorName.isEmpty ? "Chef" : authorName)")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.blue)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Text(recipe.description)
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 20) {
                            Label("\(recipe.prepTime + recipe.cookTime)m", systemImage: "clock")
                            Label("\(recipe.servings) servings", systemImage: "person.2")
                            Label(recipe.difficulty.rawValue, systemImage: "star.fill")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    }
                    
                    // Ingredients
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ingredients")
                            .font(.system(size: 24, weight: .bold))
                        
                        ForEach(recipe.ingredients) { ingredient in
                            HStack {
                                Image(systemName: ingredient.isAvailable ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(ingredient.isAvailable ? .green : .gray)
                                Text("\(ingredient.quantity) \(ingredient.unit ?? "") \(ingredient.name)")
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Instructions")
                            .font(.system(size: 24, weight: .bold))
                        
                        ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, instruction in
                            HStack(alignment: .top) {
                                Text("\(index + 1).")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.blue)
                                    .frame(width: 30)
                                Text(instruction)
                                    .font(.system(size: 16))
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    
                    // Nutrition
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Nutrition Facts")
                            .font(.system(size: 24, weight: .bold))
                        
                        HStack(spacing: 16) {
                            RecipeDetailNutritionItem(label: "Calories", value: "\(recipe.nutrition.calories)")
                            RecipeDetailNutritionItem(label: "Protein", value: "\(recipe.nutrition.protein)g")
                            RecipeDetailNutritionItem(label: "Carbs", value: "\(recipe.nutrition.carbs)g")
                            RecipeDetailNutritionItem(label: "Fat", value: "\(recipe.nutrition.fat)g")
                        }
                    }
                    
                    // Comments Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Comments")
                                .font(.system(size: 24, weight: .bold))
                            Spacer()
                            if commentsViewModel.comments.count > 0 {
                                Text("\(commentsViewModel.comments.count)")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Comment Input
                        HStack(spacing: 12) {
                            TextField("Add a comment...", text: $newCommentText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button(action: submitComment) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(newCommentText.isEmpty ? .gray : .blue)
                            }
                            .disabled(newCommentText.isEmpty || isSubmittingComment)
                        }
                        
                        // Comments List
                        if commentsViewModel.isLoading && commentsViewModel.comments.isEmpty {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .tint(.gray)
                                Spacer()
                            }
                            .padding(.vertical, 20)
                        } else if commentsViewModel.comments.isEmpty {
                            Text("Be the first to comment!")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                                .padding(.vertical, 20)
                        } else {
                            ForEach(commentsViewModel.comments.prefix(5)) { comment in
                                RecipeCommentRow(comment: comment, onUserTap: {
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
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingPrintView = true }) {
                        Image(systemName: "printer")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
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
            .task {
                await loadLikeStatus()
                await loadAuthorInfo()
                await commentsViewModel.loadComments(for: recipe.id.uuidString)
            }
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
        guard !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        Task {
            isSubmittingComment = true
            defer { isSubmittingComment = false }
            
            await commentsViewModel.addComment(
                to: recipe.id.uuidString,
                content: newCommentText
            )
            
            await MainActor.run {
                newCommentText = ""
            }
        }
    }
    
    // MARK: - Share Functions
    
    private func shareVia(_ platform: String) {
        let recipeText = """
        Check out this amazing \(recipe.name) recipe I found on SnapChef! 
        
        ⏱ \(recipe.prepTime + recipe.cookTime) minutes
        🍽 \(recipe.servings) servings
        \(recipe.difficulty.emoji) \(recipe.difficulty.rawValue) difficulty
        
        #SnapChef #HomeCooking #FoodLove
        """
        
        // For now, just use the system share sheet
        shareRecipe()
    }
    
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
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Recipe Comment Row
struct RecipeCommentRow: View {
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
                                colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(comment.userName.prefix(1).uppercased())
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Button(action: onUserTap) {
                            Text(comment.userName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Text("• \(comment.timeAgoText)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    Text(comment.content)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 4)
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

#Preview {
    RecipeDetailView(recipe: MockDataProvider.shared.mockRecipe())
}