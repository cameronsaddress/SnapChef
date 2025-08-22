import SwiftUI
import AVFoundation

struct RecipeDetectiveView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var deviceManager: DeviceManager
    @StateObject private var cameraModel = CameraModel()
    @State private var capturedImage: UIImage?
    @State private var isProcessing = false
    @State private var showingResults = false
    @State private var detectedRecipe: DetectedRecipe?
    @State private var processingMessage = "Analyzing flavors..."
    @State private var usagesRemaining = 8 // Mock usage counter
    @State private var showingUpgrade = false
    @State private var animateCapture = false
    @State private var mysteryGlow = false
    @State private var sparkleAnimation = false
    
    // Detective-themed processing messages
    private let processingMessages = [
        "Analyzing flavors...",
        "Identifying ingredients...",
        "Reconstructing recipe...",
        "Case almost solved...",
        "Investigating cooking methods...",
        "Decoding culinary secrets..."
    ]
    
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
            
            if isProcessing {
                DetectiveProcessingOverlay(
                    message: processingMessage,
                    onComplete: {
                        // Simulate analysis complete
                        showingResults = true
                        isProcessing = false
                    }
                )
            } else {
                ScrollView {
                    VStack(spacing: 30) {
                        // Header with close button
                        HStack {
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color(hex: "#ffd700"), Color(hex: "#ffed4e")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            
                            Spacer()
                            
                            // Premium badge
                            if !deviceManager.hasUnlimitedAccess {
                                HStack(spacing: 6) {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Color(hex: "#ffd700"))
                                    
                                    Text("PREMIUM")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "#2d1b69"))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color(hex: "#ffd700"), lineWidth: 1)
                                        )
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        // Title Section with Detective Aesthetic
                        VStack(spacing: 16) {
                            // Animated magnifying glass with sparkles
                            ZStack {
                                // Mystery glow effect
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                Color(hex: "#ffd700").opacity(mysteryGlow ? 0.3 : 0.1),
                                                Color.clear
                                            ],
                                            center: .center,
                                            startRadius: 0,
                                            endRadius: 100
                                        )
                                    )
                                    .frame(width: 200, height: 200)
                                    .scaleEffect(mysteryGlow ? 1.2 : 1)
                                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: mysteryGlow)
                                
                                Text("🔍")
                                    .font(.system(size: 80))
                                    .scaleEffect(animateCapture ? 1.1 : 1)
                                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animateCapture)
                                
                                // Floating sparkles
                                ForEach(0..<5, id: \.self) { index in
                                    Image(systemName: "sparkle")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "#ffd700"))
                                        .offset(
                                            x: cos(Double(index) * .pi * 2 / 5) * (sparkleAnimation ? 60 : 40),
                                            y: sin(Double(index) * .pi * 2 / 5) * (sparkleAnimation ? 60 : 40)
                                        )
                                        .opacity(sparkleAnimation ? 1 : 0.5)
                                        .animation(
                                            .easeInOut(duration: 2)
                                                .repeatForever(autoreverses: true)
                                                .delay(Double(index) * 0.2),
                                            value: sparkleAnimation
                                        )
                                }
                            }
                            
                            VStack(spacing: 8) {
                                Text("Recipe Detective 🔍")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: "#ffd700"),
                                                Color(hex: "#ffed4e")
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .multilineTextAlignment(.center)
                                
                                Text("Take a photo of any dish to recreate it at home")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                        }
                        
                        // Usage Counter
                        if !deviceManager.hasUnlimitedAccess {
                            UsageCounterCard(remaining: usagesRemaining, total: 10)
                        }
                        
                        // Camera Preview or Captured Image
                        VStack(spacing: 20) {
                            if let capturedImage = capturedImage {
                                // Show captured image with detective styling
                                VStack(spacing: 16) {
                                    Text("Evidence Captured!")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(Color(hex: "#ffd700"))
                                    
                                    Image(uiImage: capturedImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 300)
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [Color(hex: "#ffd700"), Color(hex: "#ffed4e")],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 3
                                                )
                                        )
                                        .shadow(color: Color(hex: "#ffd700").opacity(0.4), radius: 15, y: 8)
                                }
                            } else {
                                // Camera preview with detective frame
                                DetectiveCameraPreview(cameraModel: cameraModel)
                                    .frame(height: 300)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [
                                                        Color(hex: "#ffd700").opacity(0.8),
                                                        Color(hex: "#2d1b69").opacity(0.6)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 2
                                            )
                                    )
                                    .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Action Button
                        VStack(spacing: 16) {
                            if capturedImage != nil {
                                // Analyze Button
                                DetectiveAnalyzeButton(
                                    action: {
                                        startAnalysis()
                                    }
                                )
                            } else {
                                // Capture Button
                                DetectiveCaptureButton(
                                    action: {
                                        capturePhoto()
                                    }
                                )
                            }
                            
                            // Retake button if image captured
                            if capturedImage != nil {
                                Button(action: {
                                    capturedImage = nil
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "camera.rotate")
                                            .font(.system(size: 16, weight: .medium))
                                        Text("Retake Photo")
                                            .font(.system(size: 16, weight: .medium))
                                    }
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 24)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 50)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            print("🔍 DEBUG: RecipeDetectiveView appeared")
            setupAnimations()
            cameraModel.requestCameraPermission()
        }
        .onDisappear {
            cameraModel.stopSession()
        }
        .fullScreenCover(isPresented: $showingResults) {
            if let recipe = detectedRecipe {
                DetectiveResultsView(detectedRecipe: recipe)
            }
        }
        .fullScreenCover(isPresented: $showingUpgrade) {
            SubscriptionView()
                .environmentObject(deviceManager)
        }
    }
    
    private func setupAnimations() {
        mysteryGlow = true
        animateCapture = true
        sparkleAnimation = true
    }
    
    private func capturePhoto() {
        // Check usage limits
        if !deviceManager.hasUnlimitedAccess && usagesRemaining <= 0 {
            showingUpgrade = true
            return
        }
        
        cameraModel.capturePhoto { image in
            self.capturedImage = image
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
    
    private func startAnalysis() {
        guard let image = capturedImage else { return }
        
        isProcessing = true
        
        // Cycle through detective messages
        var messageIndex = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { timer in
            if messageIndex < processingMessages.count {
                Task { @MainActor in
                    processingMessage = processingMessages[messageIndex]
                }
                messageIndex += 1
            } else {
                timer.invalidate()
                // Create mock detected recipe
                Task { @MainActor in
                    detectedRecipe = DetectedRecipe(
                        originalImage: image,
                        dishName: "Classic Chicken Parmesan",
                        confidenceScore: 87,
                        estimatedIngredients: [
                            "Chicken breast",
                            "Parmesan cheese",
                            "Breadcrumbs",
                            "Marinara sauce",
                            "Mozzarella cheese",
                            "Italian seasoning"
                        ],
                        reconstructedRecipe: Recipe(
                            id: UUID(),
                            ownerID: nil,
                            name: "Classic Chicken Parmesan",
                            description: "Crispy breaded chicken breast topped with marinara sauce and melted cheese",
                            ingredients: [
                                Ingredient(id: UUID(), name: "Chicken breast", quantity: "2", unit: "pieces", isAvailable: true),
                                Ingredient(id: UUID(), name: "Panko breadcrumbs", quantity: "1", unit: "cup", isAvailable: true),
                                Ingredient(id: UUID(), name: "Parmesan cheese", quantity: "1/2", unit: "cup", isAvailable: true),
                                Ingredient(id: UUID(), name: "Marinara sauce", quantity: "1", unit: "cup", isAvailable: true),
                                Ingredient(id: UUID(), name: "Mozzarella cheese", quantity: "1", unit: "cup", isAvailable: true),
                                Ingredient(id: UUID(), name: "Eggs", quantity: "2", unit: "pieces", isAvailable: true),
                                Ingredient(id: UUID(), name: "Flour", quantity: "1/2", unit: "cup", isAvailable: true),
                                Ingredient(id: UUID(), name: "Salt and pepper", quantity: "To taste", unit: nil, isAvailable: true),
                                Ingredient(id: UUID(), name: "Italian seasoning", quantity: "1", unit: "tsp", isAvailable: true)
                            ],
                            instructions: [
                                "Preheat oven to 425°F",
                                "Set up breading station with flour, beaten eggs, and breadcrumb mixture",
                                "Season chicken with salt and pepper",
                                "Dredge chicken in flour, then egg, then breadcrumb mixture",
                                "Place on baking sheet and bake for 20 minutes",
                                "Top with marinara sauce and mozzarella cheese",
                                "Bake for additional 5-10 minutes until cheese melts",
                                "Let rest for 5 minutes before serving"
                            ],
                            cookTime: 35,
                            prepTime: 15,
                            servings: 4,
                            difficulty: .medium,
                            nutrition: Nutrition(
                                calories: 485,
                                protein: 42,
                                carbs: 28,
                                fat: 22,
                                fiber: 3,
                                sugar: 8,
                                sodium: 850
                            ),
                            imageURL: nil,
                            createdAt: Date(),
                            tags: ["Italian", "Main Course", "Comfort Food"],
                            dietaryInfo: DietaryInfo(
                                isVegetarian: false,
                                isVegan: false,
                                isGlutenFree: false,
                                isDairyFree: false
                            ),
                            isDetectiveRecipe: true,
                            cookingTechniques: ["breading", "baking"],
                            flavorProfile: FlavorProfile(sweet: 3, salty: 7, sour: 2, bitter: 1, umami: 6),
                            secretIngredients: ["Italian seasoning blend"],
                            proTips: ["Pound chicken evenly for consistent cooking"],
                            visualClues: ["Golden brown crust", "Melted cheese topping"],
                            shareCaption: "Homemade Chicken Parmesan! 🍗🧀 #ChickenParmesan #Homemade"
                        )
                    )
                    
                    // Decrease usage count
                    if !deviceManager.hasUnlimitedAccess {
                        usagesRemaining = max(0, usagesRemaining - 1)
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        isProcessing = false
                        showingResults = true
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct DetectedRecipe {
    let originalImage: UIImage
    let dishName: String
    let confidenceScore: Int
    let estimatedIngredients: [String]
    let reconstructedRecipe: Recipe
}

struct UsageCounterCard: View {
    let remaining: Int
    let total: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "#ffd700"))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(remaining)/\(total) free analyses used")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)
                            .cornerRadius(2)
                        
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#ffd700"), Color(hex: "#ffed4e")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geometry.size.width * (Double(remaining) / Double(total)),
                                height: 4
                            )
                            .cornerRadius(2)
                    }
                }
                .frame(height: 4)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "#ffd700").opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
}

struct DetectiveCameraPreview: View {
    @ObservedObject var cameraModel: CameraModel
    
    var body: some View {
        ZStack {
            if cameraModel.isCameraAuthorized {
                CameraPreview(cameraModel: cameraModel)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("Camera Access Required")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Enable camera access to analyze dishes")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                    
                    Button("Open Settings") {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                    .foregroundColor(Color(hex: "#ffd700"))
                    .font(.system(size: 16, weight: .semibold))
                }
                .padding(40)
            }
            
            // Detective viewfinder overlay
            VStack {
                HStack {
                    DetectiveCorner()
                    Spacer()
                    DetectiveCorner()
                        .rotationEffect(.degrees(90))
                }
                Spacer()
                HStack {
                    DetectiveCorner()
                        .rotationEffect(.degrees(-90))
                    Spacer()
                    DetectiveCorner()
                        .rotationEffect(.degrees(180))
                }
            }
            .padding(20)
        }
    }
}

struct DetectiveCorner: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(hex: "#ffd700"))
                .frame(width: 20, height: 3)
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color(hex: "#ffd700"))
                    .frame(width: 3, height: 20)
                Spacer()
            }
        }
        .frame(width: 20, height: 20)
    }
}

struct DetectiveCaptureButton: View {
    let action: () -> Void
    @State private var isPressed = false
    @State private var pulseAnimation = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#ffd700"))
                        .frame(width: 24, height: 24)
                        .scaleEffect(pulseAnimation ? 1.2 : 1)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulseAnimation)
                    
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#2d1b69"))
                }
                
                Text("Capture Dish")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#2d1b69"),
                                Color(hex: "#11052c")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "#ffd700"), Color(hex: "#ffed4e")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1)
            .shadow(color: Color(hex: "#ffd700").opacity(0.4), radius: 15, y: 8)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .onAppear {
            pulseAnimation = true
        }
    }
}

struct DetectiveAnalyzeButton: View {
    let action: () -> Void
    @State private var isPressed = false
    @State private var sparkleAnimation = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: "sparkle")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#ffd700"))
                            .offset(
                                x: cos(Double(index) * .pi * 2 / 3) * (sparkleAnimation ? 15 : 8),
                                y: sin(Double(index) * .pi * 2 / 3) * (sparkleAnimation ? 15 : 8)
                            )
                            .opacity(sparkleAnimation ? 1 : 0.5)
                            .animation(
                                .easeInOut(duration: 1.5)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                value: sparkleAnimation
                            )
                    }
                    
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text("Analyze Dish")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#ffd700"),
                                Color(hex: "#ffb347")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1)
            .shadow(color: Color(hex: "#ffd700").opacity(0.6), radius: 20, y: 10)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .onAppear {
            sparkleAnimation = true
        }
    }
}

struct DetectiveProcessingOverlay: View {
    let message: String
    let onComplete: () -> Void
    @State private var rotation = 0.0
    @State private var sparkleAnimation = false
    @State private var progress: Double = 0
    
    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.9)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Animated magnifying glass
                ZStack {
                    // Rotating investigation circles
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(
                                Color(hex: "#ffd700").opacity(0.3),
                                lineWidth: 2
                            )
                            .frame(width: CGFloat(80 + index * 40))
                            .rotationEffect(.degrees(rotation + Double(index * 60)))
                    }
                    
                    // Center magnifying glass
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(hex: "#ffd700").opacity(0.4),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 50
                                )
                            )
                            .frame(width: 100, height: 100)
                            .scaleEffect(sparkleAnimation ? 1.2 : 1)
                        
                        Text("🔍")
                            .font(.system(size: 60))
                            .scaleEffect(sparkleAnimation ? 1.1 : 1)
                    }
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: sparkleAnimation)
                }
                
                VStack(spacing: 16) {
                    Text(message)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: "#ffd700"))
                        .multilineTextAlignment(.center)
                    
                    Text("Our AI detective is on the case...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 4)
                                .cornerRadius(2)
                            
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#ffd700"), Color(hex: "#ffed4e")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * progress, height: 4)
                                .cornerRadius(2)
                        }
                    }
                    .frame(height: 4)
                    .padding(.horizontal, 40)
                }
            }
        }
        .onAppear {
            startAnimations()
            startProgressSimulation()
        }
    }
    
    private func startAnimations() {
        sparkleAnimation = true
        
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }
    
    private func startProgressSimulation() {
        // Simulate analysis progress
        withAnimation(.easeInOut(duration: 8)) {
            progress = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            onComplete()
        }
    }
}

#Preview {
    RecipeDetectiveView()
        .environmentObject(AppState())
        .environmentObject(DeviceManager())
}