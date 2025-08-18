import SwiftUI
import UIKit
import Foundation

// MARK: - Detective View
struct DetectiveView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var cameraModel = CameraModel()
    @StateObject private var cloudKitAuth = CloudKitAuthManager.shared
    @StateObject private var userLifecycle = UserLifecycleManager.shared
    
    @State private var showingCamera = false
    @State private var capturedImage: UIImage?
    @State private var isAnalyzing = false
    @State private var detectiveRecipe: DetectiveRecipe?
    @State private var errorMessage: String?
    @State private var showingPremiumPrompt = false
    @State private var analysisProgress: Double = 0.0
    
    // MARK: - Computed Properties for Type Inference
    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
    }
    
    private var recentRecipes: [DetectiveRecipe] {
        // Return empty array for now since detectiveRecipes is commented out in AppState
        []
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        detectiveHeader
                        
                        // Main Content
                        if let recipe = detectiveRecipe {
                            detectiveResultCard(recipe: recipe)
                        } else if isAnalyzing {
                            analysisProgressView
                        } else {
                            detectivePromptCard
                        }
                        
                        // Recent Detective Analyses (if any)
                        if !recentRecipes.isEmpty {
                            recentAnalysesSection
                        }
                        
                        Spacer(minLength: 120) // Account for tab bar
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
            }
            .navigationTitle("Recipe Detective")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingCamera) {
                CameraDetectiveView(
                    capturedImage: $capturedImage,
                    isAnalyzing: $isAnalyzing
                )
            }
            .sheet(isPresented: $showingPremiumPrompt) {
                PremiumUpgradePrompt(
                    isPresented: $showingPremiumPrompt,
                    reason: .premiumFeature("Recipe Detective")
                )
            }
            .onChange(of: capturedImage) { newImage in
                if let newImage = newImage {
                    Task {
                        await analyzeImage(newImage)
                    }
                }
            }
        }
    }
    
    // MARK: - Header
    private var detectiveHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#9b59b6"), Color(hex: "#8e44ad")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recipe Detective")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Reverse-engineer any dish from a photo")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                // Check if user doesn't have premium access
                if !cloudKitAuth.isAuthenticated || userLifecycle.currentPhase == .standard {
                    premiumBadge
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Premium Badge
    private var premiumBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "crown.fill")
                .font(.system(size: 12))
            Text("Premium")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(hex: "#9b59b6").opacity(0.8))
        )
    }
    
    // MARK: - Detective Prompt Card
    private var detectivePromptCard: some View {
        VStack(spacing: 20) {
            // Illustration
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#9b59b6").opacity(0.3), Color(hex: "#8e44ad").opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                VStack(spacing: 8) {
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(hex: "#9b59b6"))
                    
                    Image(systemName: "arrow.down")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#3498db"))
                }
            }
            
            VStack(spacing: 12) {
                Text("Snap & Solve")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Take a photo of any restaurant dish and I'll reverse-engineer the recipe for you!")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            // MARK: - TEST BUTTON (Remove in production)
            Button(action: {
                // Bypass premium check for testing
                showingCamera = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text("TEST: Bypass Premium")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.orange, Color.red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .padding(.bottom, 8)
            
            Button(action: {
                if canUseDetectiveFeature() {
                    showingCamera = true
                } else {
                    showingPremiumPrompt = true
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text(canUseDetectiveFeature() ? "Analyze Dish" : "Unlock Detective")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#9b59b6"), Color(hex: "#8e44ad")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Analysis Progress View
    private var analysisProgressView: some View {
        VStack(spacing: 20) {
            // Animated magnifying glass
            ZStack {
                Circle()
                    .fill(Color(hex: "#9b59b6").opacity(0.2))
                    .frame(width: 80, height: 80)
                    .scaleEffect(1 + sin(analysisProgress * .pi * 4) * 0.1)
                
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(Color(hex: "#9b59b6"))
                    .rotationEffect(.degrees(analysisProgress * 360))
            }
            
            VStack(spacing: 8) {
                Text("Analyzing dish...")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Our AI chef is studying the ingredients and techniques")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            // Progress bar
            ProgressView(value: analysisProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: "#9b59b6")))
                .scaleEffect(x: 1, y: 2, anchor: .center)
                .frame(height: 8)
                .background(Color.white.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .onAppear {
            startProgressAnimation()
        }
    }
    
    // MARK: - Detective Result Card
    private func detectiveResultCard(recipe: DetectiveRecipe) -> some View {
        VStack(spacing: 20) {
            // Confidence indicator
            HStack {
                Text(recipe.confidenceEmoji)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Confidence: \(Int(recipe.confidenceScore))%")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(recipe.confidenceDescription)
                        .font(.caption)
                        .foregroundColor(recipe.confidenceColor)
                }
                
                Spacer()
                
                Text("\(Int(recipe.confidenceScore))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(recipe.confidenceColor)
            }
            
            // Recipe info
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Identified Dish")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(recipe.originalDishName)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    if let style = recipe.restaurantStyle {
                        Text(style)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "#9b59b6").opacity(0.3))
                            )
                    }
                }
                
                Divider()
                    .overlay(Color.white.opacity(0.3))
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recreation Recipe")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(recipe.name)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    NavigationLink(destination: DetectiveRecipeDetailView(recipe: recipe)) {
                        HStack(spacing: 6) {
                            Text("View Recipe")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color(hex: "#9b59b6"))
                        )
                    }
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    // Save recipe
                    let baseRecipe = recipe.toBaseRecipe()
                    appState.savedRecipes.append(baseRecipe)
                    // TODO: Add detectiveRecipes support back when AppState is updated
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "heart")
                        Text("Save")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(12)
                }
                
                Button(action: {
                    // Share functionality
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(12)
                }
                
                Button(action: {
                    // Try again
                    detectiveRecipe = nil
                    capturedImage = nil
                    showingCamera = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(12)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(recipe.confidenceColor.opacity(0.5), lineWidth: 2)
                )
        )
    }
    
    // MARK: - Recent Analyses Section
    private var recentAnalysesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Analyses")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(recentRecipes, id: \.id) { recipe in
                    NavigationLink(destination: DetectiveRecipeDetailView(recipe: recipe)) {
                        detectiveHistoryCard(recipe: recipe)
                    }
                }
            }
        }
    }
    
    // MARK: - Detective History Card
    private func detectiveHistoryCard(recipe: DetectiveRecipe) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(recipe.confidenceEmoji)
                    .font(.title3)
                
                Spacer()
                
                Text("\(Int(recipe.confidenceScore))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(recipe.confidenceColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.originalDishName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(recipe.name)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
            
            Text("Analyzed \(timeAgoString(from: recipe.analyzedAt))")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Helper Functions
    private func startProgressAnimation() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false)) {
            analysisProgress = 1.0
        }
    }
    
    private func canUseDetectiveFeature() -> Bool {
        // Check if user has premium access or is in honeymoon/trial phase
        return cloudKitAuth.isAuthenticated && userLifecycle.currentPhase != .standard
    }
    
    private func analyzeImage(_ image: UIImage) async {
        isAnalyzing = true
        errorMessage = nil
        
        do {
            // Create a session ID for this analysis
            let sessionID = UUID().uuidString
            print("🔍 Starting detective analysis with session ID: \(sessionID)")
            
            // Call the actual API through SnapChefAPIManager
            let response = try await SnapChefAPIManager.shared.analyzeRestaurantMeal(
                image: image,
                sessionID: sessionID,
                llmProvider: .gemini // Using Gemini for detective analysis (default provider)
            )
            
            if response.success, let apiRecipe = response.detectiveRecipe {
                // Convert API recipe to our DetectiveRecipe model
                detectiveRecipe = SnapChefAPIManager.shared.convertAPIDetectiveRecipeToDetectiveRecipe(apiRecipe)
                
                // Save to recipes if we have a valid recipe
                if let recipe = detectiveRecipe {
                    // Convert DetectiveRecipe to regular Recipe and add to saved recipes
                    let regularRecipe = recipe.toBaseRecipe()
                    appState.savedRecipes.append(regularRecipe)
                    print("✅ Detective analysis successful: \(recipe.name)")
                    print("✅ Confidence: \(recipe.confidenceScore)%")
                }
            } else {
                errorMessage = response.error ?? "Failed to analyze the meal photo"
                print("❌ Detective analysis failed: \(errorMessage ?? "Unknown error")")
            }
        } catch {
            errorMessage = "Failed to analyze image: \(error.localizedDescription)"
            print("❌ Detective analysis error: \(error)")
        }
        
        isAnalyzing = false
    }
    
    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let days = components.day, days > 0 {
            return "\(days)d ago"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }
}

// MARK: - Detective Recipe Detail View
struct DetectiveRecipeDetailView: View {
    let recipe: DetectiveRecipe
    
    var body: some View {
        // TODO: Implement detailed recipe view
        // This would show the full recipe with confidence analysis,
        // ingredient breakdown, and step-by-step instructions
        Text("Detective Recipe Detail")
            .navigationTitle(recipe.name)
    }
}

// MARK: - Camera Detective View
struct CameraDetectiveView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Binding var isAnalyzing: Bool
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraDevice = .rear
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraDetectiveView
        
        init(_ parent: CameraDetectiveView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.capturedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview {
    DetectiveView()
        .environmentObject(AppState())
}