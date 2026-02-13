import SwiftUI
import Combine

// MARK: - Error Handling Extensions for Views

extension View {
    /// Wraps view in an error boundary with automatic retry capability
    func withErrorBoundary(
        onError: ((SnapChefError) -> Void)? = nil,
        fallback: @escaping (SnapChefError) -> AnyView = { error in
            AnyView(DefaultErrorView(error: error))
        }
    ) -> some View {
        ErrorBoundary(
            content: { self },
            onError: onError,
            fallback: fallback
        )
    }
    
    /// Adds comprehensive error handling with retry support
    func handleErrors(
        error: Binding<SnapChefError?>,
        retryAction: (() -> Void)? = nil,
        dismissAction: (() -> Void)? = nil
    ) -> some View {
        self
            .errorBanner(error, onAction: retryAction, onDismiss: dismissAction)
            .onReceive(NotificationCenter.default.publisher(for: .snapChefRetry)) { notification in
                if let _ = notification.object as? SnapChefError {
                    retryAction?()
                }
            }
    }
    
    /// Adds loading state with error handling
    func withLoadingAndError<T>(
        state: AsyncState<T>,
        retryAction: @escaping () -> Void
    ) -> some View {
        ZStack {
            self
            
            switch state {
            case .loading:
                LoadingOverlay(message: "Loading...")
            case .error(let error):
                DefaultErrorView(error: error)
                    .background(Color.white)
            case .loaded:
                EmptyView()
            }
        }
    }
}

// MARK: - Async State Management
enum AsyncState<T> {
    case loading
    case loaded(T)
    case error(SnapChefError)
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    var error: SnapChefError? {
        if case .error(let error) = self { return error }
        return nil
    }
    
    var value: T? {
        if case .loaded(let value) = self { return value }
        return nil
    }
}

// MARK: - Async Operation Manager
@MainActor
class AsyncOperationManager<T>: ObservableObject {
    @Published private(set) var state: AsyncState<T> = .loading
    @Published var showRetryOption = false
    
    private let retryManager = RetryManager.shared
    private let operationId: String
    
    init(operationId: String) {
        self.operationId = operationId
    }
    
    func execute(
        operation: @escaping () async throws -> T,
        onSuccess: ((T) -> Void)? = nil,
        onError: ((SnapChefError) -> Void)? = nil
    ) {
        state = .loading
        showRetryOption = false
        
        retryManager.attemptRetry(
            operationId: operationId,
            operation: operation,
            onSuccess: { [weak self] result in
                self?.state = .loaded(result)
                onSuccess?(result)
            },
            onFailure: { [weak self] error in
                self?.state = .error(error)
                self?.showRetryOption = error.recovery == .retry
                onError?(error)
            }
        )
    }
    
    func retry(
        operation: @escaping () async throws -> T,
        onSuccess: ((T) -> Void)? = nil,
        onError: ((SnapChefError) -> Void)? = nil
    ) {
        execute(operation: operation, onSuccess: onSuccess, onError: onError)
    }
    
    func reset() {
        state = .loading
        showRetryOption = false
        retryManager.resetRetries(for: operationId)
    }
}

// MARK: - Error-Aware API Service
@MainActor
class ErrorAwareAPIService: ObservableObject {
    @Published var isLoading = false
    @Published var lastError: SnapChefError?
    
    private let apiManager = SnapChefAPIManager.shared
    private let globalErrorHandler = GlobalErrorHandler.shared
    
    func generateRecipes(
        from image: UIImage,
        sessionId: String = UUID().uuidString,
        preferences: RecipePreferences = RecipePreferences()
    ) async -> Result<[Recipe], SnapChefError> {
        isLoading = true
        lastError = nil
        
        return await withCheckedContinuation { continuation in
            apiManager.sendImageForRecipeGeneration(
                image: image,
                sessionId: sessionId,
                dietaryRestrictions: preferences.dietaryRestrictions,
                foodType: preferences.foodType,
                difficultyPreference: preferences.difficulty,
                healthPreference: preferences.healthPreference,
                mealType: preferences.mealType,
                cookingTimePreference: preferences.cookingTime,
                numberOfRecipes: preferences.numberOfRecipes,
                existingRecipeNames: preferences.existingRecipeNames,
                foodPreferences: preferences.foodPreferences,
                llmProvider: preferences.llmProvider
            ) { [weak self] result in
                Task { @MainActor in
                    self?.isLoading = false
                    
                    switch result {
                    case .success(let apiResponse):
                        let recipes = apiResponse.data.recipes.map { 
                            self?.apiManager.convertAPIRecipeToAppRecipe($0) ?? Recipe.placeholder
                        }
                        continuation.resume(returning: .success(recipes))
                        
                    case .failure(let error):
                        self?.lastError = error
                        self?.globalErrorHandler.handleError(error, context: "recipe_generation")
                        continuation.resume(returning: .failure(error))
                    }
                }
            }
        }
    }
}

// MARK: - Recipe Preferences Model
struct RecipePreferences {
    var dietaryRestrictions: [String] = []
    var foodType: String?
    var difficulty: String?
    var healthPreference: String?
    var mealType: String?
    var cookingTime: String?
    var numberOfRecipes: Int = 5
    var existingRecipeNames: [String] = []
    var foodPreferences: [String] = []
    var llmProvider: String?
}

// MARK: - Recipe Placeholder Extension
extension Recipe {
    static var placeholder: Recipe {
        Recipe(
            id: UUID(),
            name: "Default Recipe",
            description: "A placeholder recipe",
            ingredients: [],
            instructions: [],
            cookTime: 0,
            prepTime: 0,
            servings: 1,
            difficulty: .easy,
            nutrition: Nutrition(calories: 0, protein: 0, carbs: 0, fat: 0),
            imageURL: nil,
            createdAt: Date(),
            tags: [],
            dietaryInfo: DietaryInfo(isVegetarian: false, isVegan: false, isGlutenFree: false, isDairyFree: false)
        )
    }
}

// MARK: - Enhanced Error Handling for CloudKit Operations
// Deprecated: CloudKitRecipeManager has been superseded by CloudKitService/RecipeModule.
#if false
extension CloudKitRecipeManager {
    func safeUploadRecipe(
        _ recipe: Recipe,
        fromLLM: Bool = false,
        beforePhoto: UIImage? = nil
    ) async -> Result<String, SnapChefError> {
        do {
            let recipeId = try await uploadRecipe(recipe, fromLLM: fromLLM, beforePhoto: beforePhoto)
            return .success(recipeId)
        } catch let error as CKError {
            let snapChefError = CloudKitErrorHandler.snapChefError(from: error)
            ErrorAnalytics.logError(snapChefError, context: "cloudkit_upload_recipe")
            return .failure(snapChefError)
        } catch {
            let snapChefError = SnapChefError.storageError("Failed to upload recipe: \(error.localizedDescription)")
            ErrorAnalytics.logError(snapChefError, context: "cloudkit_upload_recipe_unknown")
            return .failure(snapChefError)
        }
    }
}
#endif

// MARK: - Error-Aware Camera Permissions
@MainActor
class CameraPermissionManager: ObservableObject {
    @Published var permissionStatus: AVAuthorizationStatus = .notDetermined
    @Published var currentError: SnapChefError?
    
    func requestPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            permissionStatus = .authorized
            return true
            
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permissionStatus = granted ? .authorized : .denied
            
            if !granted {
                currentError = .cameraError("Camera access is required to capture photos")
                ErrorAnalytics.logError(currentError!, context: "camera_permission_denied")
            }
            
            return granted
            
        case .denied, .restricted:
            permissionStatus = status
            currentError = .cameraError("Camera access is required. Please enable it in Settings.")
            ErrorAnalytics.logError(currentError!, context: "camera_permission_unavailable")
            return false
            
        @unknown default:
            permissionStatus = .denied
            currentError = .cameraError("Unknown camera permission status")
            ErrorAnalytics.logError(currentError!, context: "camera_permission_unknown")
            return false
        }
    }
}

// MARK: - Error-Safe Image Processing
struct ImageProcessor {
    static func validateImage(_ image: UIImage) -> Result<UIImage, SnapChefError> {
        // Check image size
        let maxSize: CGFloat = 4096
        if image.size.width > maxSize || image.size.height > maxSize {
            return .failure(.validationError("Image is too large. Maximum size is \(Int(maxSize))x\(Int(maxSize)) pixels.", fields: ["image"]))
        }
        
        // Check file size (estimate)
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return .failure(.imageProcessingError("Could not process image. Please try a different photo."))
        }
        
        let maxSizeBytes = 10 * 1024 * 1024 // 10MB
        if imageData.count > maxSizeBytes {
            return .failure(.validationError("Image file is too large. Please use a smaller image.", fields: ["image"]))
        }
        
        // Check image content (basic validation)
        if image.size.width < 100 || image.size.height < 100 {
            return .failure(.validationError("Image is too small. Please use a clearer photo.", fields: ["image"]))
        }
        
        return .success(image)
    }
    
    static func optimizeForUpload(_ image: UIImage) -> Result<UIImage, SnapChefError> {
        // Resize if needed
        let maxDimension: CGFloat = 2048
        let resizedImage = image.resized(withMaxDimension: maxDimension)
        
        // Validate the result
        return validateImage(resizedImage)
    }
}
