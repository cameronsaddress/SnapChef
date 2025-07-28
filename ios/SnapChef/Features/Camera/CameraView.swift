import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var cameraModel = CameraModel()
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) var dismiss
    
    @State private var showingTestOption = false
    @State private var isProcessing = false
    @State private var showingResults = false
    @State private var generatedRecipes: [Recipe] = []
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreview(cameraModel: cameraModel)
                .ignoresSafeArea()
            
            // Gradient overlay at top and bottom
            VStack {
                LinearGradient(
                    colors: [Color.black.opacity(0.6), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 150)
                
                Spacer()
                
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 200)
            }
            .ignoresSafeArea()
            
            // UI overlay
            VStack {
                // Top bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // Camera flip button
                    Button(action: {
                        cameraModel.flipCamera()
                    }) {
                        Image(systemName: "camera.rotate")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.white.opacity(0.2)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                // Instructions
                VStack(spacing: 8) {
                    Text("Take a photo of your")
                        .font(.system(size: clampedFontSize(min: 18, preferred: 24, max: 32), weight: .medium))
                    Text("fridge or pantry")
                        .font(.system(size: clampedFontSize(min: 18, preferred: 24, max: 32), weight: .medium))
                }
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
                
                Spacer()
                
                // Bottom controls
                VStack(spacing: 20) {
                    // Capture button
                    Button(action: capturePhoto) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 80, height: 80)
                            
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 4)
                                .frame(width: 90, height: 90)
                        }
                    }
                    .disabled(isProcessing)
                    
                    // Test button
                    if showingTestOption {
                        Button(action: useTestPhoto) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text("Use Test Photo")
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
                .padding(.bottom, 50)
            }
            
            // Processing overlay
            if isProcessing {
                ProcessingOverlay()
            }
        }
        .onAppear {
            cameraModel.requestCameraPermission()
            #if DEBUG
            showingTestOption = true
            #endif
        }
        .fullScreenCover(isPresented: $showingResults) {
            RecipeResultsView(recipes: generatedRecipes)
        }
    }
    
    private func clampedFontSize(min minSize: CGFloat, preferred: CGFloat, max maxSize: CGFloat) -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let scaleFactor = screenWidth / 375.0 // Base on iPhone 11 Pro width
        let scaled = preferred * scaleFactor
        return min(max(scaled, minSize), maxSize)
    }
    
    private func capturePhoto() {
        HapticManager.impact(.medium)
        
        cameraModel.capturePhoto { image in
            processImage(image)
        }
    }
    
    private func useTestPhoto() {
        guard let testImage = UIImage(named: "test_fridge") else {
            // Try loading from file
            if let image = loadTestFridgeImage() {
                processImage(image)
            }
            return
        }
        processImage(testImage)
    }
    
    private func loadTestFridgeImage() -> UIImage? {
        // Try to load the test fridge image from the web app assets
        let paths = [
            "/Users/cameronanderson/SnapChef/snapchef/webapp-archive/assets/fridge.jpg",
            "/Users/cameronanderson/SnapChef/snapchef/assets/fridge.jpg"
        ]
        
        for path in paths {
            if let image = UIImage(contentsOfFile: path) {
                return image
            }
        }
        
        // Create a simple test image
        let size = CGSize(width: 300, height: 300)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        
        // Draw a gradient background
        let context = UIGraphicsGetCurrentContext()!
        let colors = [UIColor.systemBlue.cgColor, UIColor.systemGreen.cgColor]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
        
        // Draw some text
        let text = "Test Fridge"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let textSize = text.size(withAttributes: attributes)
        let textRect = CGRect(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2, width: textSize.width, height: textSize.height)
        text.draw(in: textRect, withAttributes: attributes)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
    
    private func processImage(_ image: UIImage) {
        isProcessing = true
        
        Task {
            do {
                // Check free uses
                if !deviceManager.hasUnlimitedAccess && deviceManager.freeUsesRemaining <= 0 {
                    authManager.promptForAuthIfNeeded(deviceManager: deviceManager)
                    isProcessing = false
                    return
                }
                
                // Consume free use if needed
                if !deviceManager.hasUnlimitedAccess {
                    let consumed = await deviceManager.consumeFreeUse()
                    if !consumed {
                        throw AppError.apiError("Unable to process image. Please try again.")
                    }
                }
                
                // Analyze image
                let response = try await NetworkManager.shared.analyzeImage(image, deviceId: deviceManager.deviceId)
                
                if response.success, let recipes = response.recipes {
                    generatedRecipes = recipes
                    
                    // Add to recent recipes
                    for recipe in recipes {
                        appState.addRecentRecipe(recipe)
                    }
                    
                    // Update free uses
                    deviceManager.freeUsesRemaining = response.creditsRemaining
                    
                    showingResults = true
                } else {
                    throw AppError.apiError(response.error ?? "Failed to generate recipes")
                }
                
            } catch {
                appState.error = error as? AppError ?? .unknown(error.localizedDescription)
            }
            
            isProcessing = false
        }
    }
}

struct ProcessingOverlay: View {
    @State private var loadingMessage = LoadingMessages.messages.randomElement() ?? "Creating magic..."
    @State private var rotation: Double = 0
    
    let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Animated loader
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 4
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(rotation))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotation)
                }
                
                Text(loadingMessage)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .animation(.easeInOut, value: loadingMessage)
            }
        }
        .onAppear {
            rotation = 360
        }
        .onReceive(timer) { _ in
            loadingMessage = LoadingMessages.messages.randomElement() ?? loadingMessage
        }
    }
}

struct LoadingMessages {
    static let messages = [
        "Analyzing your ingredients...",
        "Creating delicious recipes...",
        "Checking what's fresh...",
        "Finding perfect combinations...",
        "Calculating nutrition facts...",
        "Making kitchen magic...",
        "Discovering hidden gems...",
        "Crafting culinary delights..."
    ]
}

#Preview {
    CameraView()
        .environmentObject(AppState())
        .environmentObject(DeviceManager())
        .environmentObject(AuthenticationManager())
}