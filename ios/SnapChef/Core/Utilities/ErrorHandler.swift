import SwiftUI
import os.log
import CloudKit

// MARK: - Comprehensive Error Types
enum SnapChefError: LocalizedError, Equatable {
    // Network & API errors
    case networkError(String, recovery: ErrorRecoveryStrategy = .retry)
    case apiError(String, statusCode: Int? = nil, recovery: ErrorRecoveryStrategy = .retry)
    case timeoutError(String, recovery: ErrorRecoveryStrategy = .retry)
    case rateLimitError(String, retryAfter: TimeInterval? = nil)
    
    // Authentication & Authorization
    case authenticationError(String, recovery: ErrorRecoveryStrategy = .reauthenticate)
    case unauthorizedError(String, recovery: ErrorRecoveryStrategy = .reauthenticate)
    case subscriptionError(String, recovery: ErrorRecoveryStrategy = .manageSubscription)
    
    // Device & Permissions
    case cameraError(String, recovery: ErrorRecoveryStrategy = .openSettings)
    case photoLibraryError(String, recovery: ErrorRecoveryStrategy = .openSettings)
    case microphoneError(String, recovery: ErrorRecoveryStrategy = .openSettings)
    
    // Data & Storage
    case storageError(String, recovery: ErrorRecoveryStrategy = .retry)
    case cloudKitError(CKError, recovery: ErrorRecoveryStrategy = .retry)
    case dataCorruptionError(String, recovery: ErrorRecoveryStrategy = .clearData)
    case syncError(String, recovery: ErrorRecoveryStrategy = .forcSync)
    
    // Input & Validation
    case invalidInput(String, field: String? = nil)
    case validationError(String, fields: [String] = [])
    case imageProcessingError(String, recovery: ErrorRecoveryStrategy = .retry)
    
    // Feature-specific
    case recipeGenerationError(String, recovery: ErrorRecoveryStrategy = .retry)
    case videoGenerationError(String, recovery: ErrorRecoveryStrategy = .retry)
    case sharingError(String, platform: String? = nil, recovery: ErrorRecoveryStrategy = .retry)
    case challengeError(String, recovery: ErrorRecoveryStrategy = .retry)
    
    // System & Unknown
    case lowMemoryError(String, recovery: ErrorRecoveryStrategy = .closeApp)
    case deviceUnsupportedError(String, recovery: ErrorRecoveryStrategy = .none)
    case unknown(String, recovery: ErrorRecoveryStrategy = .retry)
    
    static func == (lhs: SnapChefError, rhs: SnapChefError) -> Bool {
        switch (lhs, rhs) {
        case (.networkError(let l, _), .networkError(let r, _)): return l == r
        case (.apiError(let l, _, _), .apiError(let r, _, _)): return l == r
        case (.authenticationError(let l, _), .authenticationError(let r, _)): return l == r
        case (.cameraError(let l, _), .cameraError(let r, _)): return l == r
        case (.storageError(let l, _), .storageError(let r, _)): return l == r
        case (.invalidInput(let l, _), .invalidInput(let r, _)): return l == r
        case (.subscriptionError(let l, _), .subscriptionError(let r, _)): return l == r
        case (.unknown(let l, _), .unknown(let r, _)): return l == r
        default: return false
        }
    }
    
    var recovery: ErrorRecoveryStrategy {
        switch self {
        case .networkError(_, let recovery),
             .apiError(_, _, let recovery),
             .timeoutError(_, let recovery),
             .authenticationError(_, let recovery),
             .unauthorizedError(_, let recovery),
             .subscriptionError(_, let recovery),
             .cameraError(_, let recovery),
             .photoLibraryError(_, let recovery),
             .microphoneError(_, let recovery),
             .storageError(_, let recovery),
             .cloudKitError(_, let recovery),
             .dataCorruptionError(_, let recovery),
             .syncError(_, let recovery),
             .imageProcessingError(_, let recovery),
             .recipeGenerationError(_, let recovery),
             .videoGenerationError(_, let recovery),
             .sharingError(_, _, let recovery),
             .challengeError(_, let recovery),
             .lowMemoryError(_, let recovery),
             .deviceUnsupportedError(_, let recovery),
             .unknown(_, let recovery):
            return recovery
        case .rateLimitError(_, let retryAfter):
            return .retryAfter(retryAfter ?? 60)
        case .invalidInput(_, _), .validationError(_, _):
            return .none
        }
    }

    var errorDescription: String? {
        switch self {
        case .networkError(let message, _): return message
        case .apiError(let message, _, _): return message
        case .timeoutError(let message, _): return message
        case .rateLimitError(let message, _): return message
        case .authenticationError(let message, _): return message
        case .unauthorizedError(let message, _): return message
        case .subscriptionError(let message, _): return message
        case .cameraError(let message, _): return message
        case .photoLibraryError(let message, _): return message
        case .microphoneError(let message, _): return message
        case .storageError(let message, _): return message
        case .cloudKitError(let error, _): return error.localizedDescription
        case .dataCorruptionError(let message, _): return message
        case .syncError(let message, _): return message
        case .invalidInput(let message, _): return message
        case .validationError(let message, _): return message
        case .imageProcessingError(let message, _): return message
        case .recipeGenerationError(let message, _): return message
        case .videoGenerationError(let message, _): return message
        case .sharingError(let message, _, _): return message
        case .challengeError(let message, _): return message
        case .lowMemoryError(let message, _): return message
        case .deviceUnsupportedError(let message, _): return message
        case .unknown(let message, _): return message
        }
    }

    var userFriendlyMessage: String {
        switch self {
        case .networkError(_, _):
            return "We're having trouble connecting. Please check your internet and try again."
        case .apiError(_, let statusCode, _):
            if let code = statusCode {
                switch code {
                case 429: return "Too many requests. Please wait a moment and try again."
                case 500...599: return "Our servers are having issues. Please try again in a few minutes."
                case 401, 403: return "Authentication expired. Please sign in again."
                default: return "Our chef is taking a break. Please try again in a moment."
                }
            }
            return "Our chef is taking a break. Please try again in a moment."
        case .timeoutError(_, _):
            return "The request took too long. Please check your connection and try again."
        case .rateLimitError(_, let retryAfter):
            if let delay = retryAfter {
                let minutes = Int(delay / 60)
                return "You've reached the rate limit. Please wait \(minutes > 0 ? "\(minutes) minutes" : "a moment") and try again."
            }
            return "You've made too many requests. Please wait a moment and try again."
        case .authenticationError(_, _), .unauthorizedError(_, _):
            return "Please sign in again to continue."
        case .subscriptionError(_, _):
            return "There was an issue with your subscription. Please check your account."
        case .cameraError(_, _):
            return "Camera access is needed to snap your fridge. Please enable it in Settings."
        case .photoLibraryError(_, _):
            return "Photo library access is needed to save images. Please enable it in Settings."
        case .microphoneError(_, _):
            return "Microphone access is needed for this feature. Please enable it in Settings."
        case .storageError(_, _):
            return "We're having trouble saving your data. Please try again."
        case .cloudKitError(let error, _):
            return CloudKitErrorHandler.userFriendlyMessage(for: error)
        case .dataCorruptionError(_, _):
            return "Some data appears corrupted. We'll try to fix this automatically."
        case .syncError(_, _):
            return "We're having trouble syncing your data. Please try again."
        case .invalidInput(_, let field):
            if let field = field {
                return "Please check your \(field) and try again."
            }
            return "Please check your input and try again."
        case .validationError(let message, _):
            return message
        case .imageProcessingError(_, _):
            return "We couldn't process your image. Please try with a different photo."
        case .recipeGenerationError(_, _):
            return "We couldn't generate recipes from your photo. Please try with a clearer image of your fridge or pantry ingredients."
        case .videoGenerationError(_, _):
            return "We couldn't create your video. Please try again."
        case .sharingError(_, let platform, _):
            if let platform = platform {
                return "We couldn't share to \(platform). Please try again."
            }
            return "We couldn't complete the sharing. Please try again."
        case .challengeError(_, _):
            return "We're having trouble with challenges. Please try again."
        case .lowMemoryError(_, _):
            return "Your device is running low on memory. Please close some apps and try again."
        case .deviceUnsupportedError(_, _):
            return "This feature isn't supported on your device."
        case .unknown(_, _):
            return "Something unexpected happened. Please try again."
        }
    }

    var actionTitle: String {
        switch recovery {
        case .retry: return "Retry"
        case .retryAfter(_): return "Retry Later"
        case .reauthenticate: return "Sign In"
        case .openSettings: return "Open Settings"
        case .manageSubscription: return "Manage Subscription"
        case .clearData: return "Clear Data"
        case .forcSync: return "Force Sync"
        case .closeApp: return "Close App"
        case .contactSupport: return "Contact Support"
        case .none: return "OK"
        }
    }

    var icon: String {
        switch self {
        case .networkError(_, _), .timeoutError(_, _): return "wifi.slash"
        case .apiError(_, _, _): return "exclamationmark.icloud"
        case .rateLimitError(_, _): return "clock.badge.exclamationmark"
        case .authenticationError(_, _), .unauthorizedError(_, _): return "person.crop.circle.badge.exclamationmark"
        case .subscriptionError(_, _): return "creditcard"
        case .cameraError(_, _): return "camera.badge.exclamationmark"
        case .photoLibraryError(_, _): return "photo.badge.exclamationmark"
        case .microphoneError(_, _): return "mic.badge.exclamationmark"
        case .storageError(_, _), .dataCorruptionError(_, _): return "externaldrive.badge.exclamationmark"
        case .cloudKitError(_, _), .syncError(_, _): return "icloud.slash"
        case .invalidInput(_, _), .validationError(_, _): return "exclamationmark.triangle"
        case .imageProcessingError(_, _): return "photo.badge.exclamationmark"
        case .recipeGenerationError(_, _): return "fork.knife.circle.fill"
        case .videoGenerationError(_, _): return "video.badge.exclamationmark"
        case .sharingError(_, _, _): return "square.and.arrow.up.trianglebadge.exclamationmark"
        case .challengeError(_, _): return "target"
        case .lowMemoryError(_, _): return "memorychip.fill"
        case .deviceUnsupportedError(_, _): return "iphone.slash"
        case .unknown(_, _): return "exclamationmark.circle"
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .lowMemoryError(_, _), .deviceUnsupportedError(_, _), .dataCorruptionError(_, _):
            return .critical
        case .authenticationError(_, _), .unauthorizedError(_, _), .subscriptionError(_, _):
            return .high
        case .networkError(_, _), .apiError(_, _, _), .timeoutError(_, _), .cloudKitError(_, _):
            return .medium
        case .invalidInput(_, _), .validationError(_, _):
            return .low
        default:
            return .medium
        }
    }
    
    var category: ErrorCategory {
        switch self {
        case .networkError(_, _), .apiError(_, _, _), .timeoutError(_, _), .rateLimitError(_, _):
            return .network
        case .authenticationError(_, _), .unauthorizedError(_, _), .subscriptionError(_, _):
            return .authentication
        case .cameraError(_, _), .photoLibraryError(_, _), .microphoneError(_, _):
            return .permissions
        case .storageError(_, _), .cloudKitError(_, _), .dataCorruptionError(_, _), .syncError(_, _):
            return .storage
        case .invalidInput(_, _), .validationError(_, _):
            return .validation
        case .imageProcessingError(_, _), .recipeGenerationError(_, _), .videoGenerationError(_, _):
            return .processing
        case .sharingError(_, _, _):
            return .sharing
        case .challengeError(_, _):
            return .gamification
        case .lowMemoryError(_, _), .deviceUnsupportedError(_, _):
            return .system
        case .unknown(_, _):
            return .unknown
        }
    }
}

// MARK: - Error Recovery Strategies
enum ErrorRecoveryStrategy: Equatable {
    case none
    case retry
    case retryAfter(TimeInterval)
    case reauthenticate
    case openSettings
    case manageSubscription
    case clearData
    case forcSync
    case closeApp
    case contactSupport
}

// MARK: - Error Severity & Categories
enum ErrorSeverity {
    case low
    case medium
    case high
    case critical
}

enum ErrorCategory {
    case network
    case authentication
    case permissions
    case storage
    case validation
    case processing
    case sharing
    case gamification
    case system
    case unknown
}

// MARK: - CloudKit Error Handler
struct CloudKitErrorHandler {
    static func userFriendlyMessage(for error: CKError) -> String {
        switch error.code {
        case .networkUnavailable, .networkFailure:
            return "Please check your internet connection and try again."
        case .notAuthenticated:
            return "Please sign in to iCloud to sync your data."
        case .quotaExceeded:
            return "Your iCloud storage is full. Please free up space."
        case .zoneBusy, .serviceUnavailable:
            return "iCloud is temporarily unavailable. Please try again."
        case .requestRateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .accountTemporarilyUnavailable:
            return "Your iCloud account is temporarily unavailable."
        case .serverResponseLost:
            return "Lost connection to iCloud. Please try again."
        default:
            return "iCloud sync encountered an issue. Please try again."
        }
    }
    
    static func snapChefError(from ckError: CKError) -> SnapChefError {
        switch ckError.code {
        case .networkUnavailable, .networkFailure:
            return .networkError(userFriendlyMessage(for: ckError))
        case .notAuthenticated:
            return .authenticationError(userFriendlyMessage(for: ckError))
        case .quotaExceeded:
            return .storageError(userFriendlyMessage(for: ckError), recovery: .manageSubscription)
        case .requestRateLimited:
            return .rateLimitError(userFriendlyMessage(for: ckError), retryAfter: 60)
        default:
            return .cloudKitError(ckError)
        }
    }
}

// MARK: - Error Analytics
struct ErrorAnalytics {
    private static let logger = Logger(subsystem: "com.snapchef.app", category: "errors")
    
    @MainActor
    static func logError(_ error: SnapChefError, context: String = "", userId: String? = nil) {
        let errorData = [
            "error_type": String(describing: error),
            "severity": String(describing: error.severity),
            "category": String(describing: error.category),
            "context": context,
            "user_id": userId ?? "anonymous",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "build_number": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        ]
        
        // Log to system logger
        logger.error("SnapChef Error: \(error.errorDescription ?? "Unknown") - Context: \(context)")
        
        // Log to analytics (if available)
        AnalyticsManager.shared.logEvent("error_occurred", parameters: errorData)
        
        // Critical errors should be reported immediately
        if error.severity == .critical {
            reportCriticalError(error, context: context, userId: userId)
        }
    }
    
    private static func reportCriticalError(_ error: SnapChefError, context: String, userId: String?) {
        // Send critical errors to monitoring service
        Task {
            do {
                let crashData: [String: String] = await MainActor.run {
                    let appState = getCurrentAppState()
                    return [
                        "error": String(describing: error),
                        "context": context,
                        "user_id": userId ?? "anonymous",
                        "timestamp": String(Date().timeIntervalSince1970),
                        "app_state": String(describing: appState)
                    ]
                }
                
                // Send to crash reporting service
                await CrashReportingService.shared.reportCriticalError(crashData)
            } catch {
                logger.error("Failed to report critical error: \(error)")
            }
        }
    }
    
    @MainActor
    private static func getCurrentAppState() -> [String: Any] {
        return [
            "memory_usage": ProcessInfo.processInfo.physicalMemory,
            "available_storage": getAvailableStorage(),
            "network_reachable": NetworkMonitor.shared.isReachable,
            "authenticated": UnifiedAuthManager.shared.isAuthenticated
        ]
    }
    
    private static func getAvailableStorage() -> Int64 {
        do {
            guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return 0
            }
            let values = try documentDirectory.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            return Int64(values.volumeAvailableCapacity ?? 0)
        } catch {
            return 0
        }
    }
}

// MARK: - Network Monitor
@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    @Published var isReachable = true
    
    private init() {
        // Initialize network monitoring
    }
}

// MARK: - Crash Reporting Service
actor CrashReportingService {
    static let shared = CrashReportingService()
    
    private init() {}
    
    func reportCriticalError(_ data: [String: String]) async {
        // Implementation for crash reporting
        print("Critical error reported: \(data)")
    }
}

// MARK: - Enhanced Error Alert Modifier
struct ErrorAlertModifier: ViewModifier {
    @Binding var error: SnapChefError?
    let onAction: (() -> Void)?
    let onRetry: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: .constant(error != nil), presenting: error) { error in
                Button(error.actionTitle) {
                    handleAction(for: error)
                    self.error = nil
                }

                if error.recovery != .none && error.actionTitle != "OK" {
                    Button("Cancel", role: .cancel) {
                        // Log dismissal
                        ErrorAnalytics.logError(error, context: "user_dismissed_alert")
                        self.error = nil
                    }
                }
                
                // Add secondary action for contact support on critical errors
                if error.severity == .critical {
                    Button("Contact Support") {
                        handleContactSupport(for: error)
                        self.error = nil
                    }
                }
            } message: { error in
                Text(error.userFriendlyMessage)
            }
            .onAppear {
                if let error = error {
                    // Log error when alert appears
                    ErrorAnalytics.logError(error, context: "alert_shown")
                }
            }
    }

    private func handleAction(for error: SnapChefError) {
        // Log action taken
        ErrorAnalytics.logError(error, context: "user_action_\(error.recovery)")
        
        switch error.recovery {
        case .retry:
            onRetry?() ?? onAction?()
        case .retryAfter(let delay):
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                onRetry?() ?? onAction?()
            }
        case .reauthenticate:
            // Navigate to authentication
            onAction?()
        case .openSettings:
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        case .manageSubscription:
            // Open subscription management
            onAction?()
        case .clearData:
            // Handle data clearing
            onAction?()
        case .forcSync:
            // Handle force sync
            onAction?()
        case .closeApp:
            // Close the app (extreme case)
            exit(0)
        case .contactSupport:
            handleContactSupport(for: error)
        case .none:
            // No action needed
            break
        }
    }
    
    private func handleContactSupport(for error: SnapChefError) {
        let subject = "SnapChef Error Report - \(error.category)"
        let body = """
        Error Details:
        - Type: \(error.category)
        - Severity: \(error.severity)
        - Description: \(error.errorDescription ?? "Unknown")
        - App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
        
        Please describe what you were doing when this error occurred:
        """
        
        if let url = URL(string: "mailto:support@snapchef.app?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            UIApplication.shared.open(url)
        }
    }
}

extension View {
    func errorAlert(_ error: Binding<SnapChefError?>, onAction: (() -> Void)? = nil, onRetry: (() -> Void)? = nil) -> some View {
        modifier(ErrorAlertModifier(error: error, onAction: onAction, onRetry: onRetry))
    }
    
    func errorBanner(_ error: Binding<SnapChefError?>, onAction: (() -> Void)? = nil, onDismiss: (() -> Void)? = nil) -> some View {
        modifier(ErrorBannerModifier(error: error, onAction: onAction, onDismiss: onDismiss))
    }
}

// MARK: - Error Banner Modifier
struct ErrorBannerModifier: ViewModifier {
    @Binding var error: SnapChefError?
    let onAction: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            VStack {
                if let error = error {
                    ErrorBannerView(
                        error: error,
                        onDismiss: {
                            self.error = nil
                            onDismiss?()
                        },
                        onAction: onAction
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }
                
                Spacer()
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: error != nil)
        }
    }
}

// MARK: - Enhanced Error Banner View
struct ErrorBannerView: View {
    let error: SnapChefError
    let onDismiss: () -> Void
    let onAction: (() -> Void)?

    @State private var isVisible = false
    @State private var progress: Double = 1.0

    var body: some View {
        VStack {
            if isVisible {
                HStack(spacing: 16) {
                    // Error icon with severity color
                    Image(systemName: error.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(severityTitle)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            
                            if error.severity == .critical {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.yellow)
                            }
                        }

                        Text(error.userFriendlyMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    // Action buttons
                    VStack(spacing: 8) {
                        if error.recovery != .none {
                            Button(action: {
                                ErrorAnalytics.logError(error, context: "banner_action_tapped")
                                onAction?()
                                dismissBanner()
                            }) {
                                Text(error.actionTitle)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.2))
                                    )
                            }
                        }

                        Button(action: dismissBanner) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                .padding()
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(backgroundGradient)
                        
                        // Progress bar for auto-dismiss
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 2)
                                .mask(
                                    HStack {
                                        Rectangle()
                                            .frame(width: UIScreen.main.bounds.width * 0.8 * progress)
                                        Spacer()
                                    }
                                )
                        }
                    }
                )
                .shadow(color: shadowColor.opacity(0.5), radius: 20, y: 10)
                .padding(.horizontal)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isVisible = true
            }
            
            // Log banner appearance
            ErrorAnalytics.logError(error, context: "banner_shown")

            // Auto dismiss with progress animation
            startAutoDismissTimer()
        }
    }
    
    private var severityTitle: String {
        switch error.severity {
        case .low: return "Notice"
        case .medium: return "Warning"
        case .high: return "Error"
        case .critical: return "Critical Error"
        }
    }
    
    private var backgroundGradient: LinearGradient {
        switch error.severity {
        case .low:
            return LinearGradient(colors: [Color.blue, Color.purple], startPoint: .leading, endPoint: .trailing)
        case .medium:
            return LinearGradient(colors: [Color.orange, Color.red], startPoint: .leading, endPoint: .trailing)
        case .high:
            return LinearGradient(colors: [Color(hex: "#f5576c"), Color(hex: "#f093fb")], startPoint: .leading, endPoint: .trailing)
        case .critical:
            return LinearGradient(colors: [Color.red, Color(hex: "#8B0000")], startPoint: .leading, endPoint: .trailing)
        }
    }
    
    private var shadowColor: Color {
        switch error.severity {
        case .low: return Color.blue
        case .medium: return Color.orange
        case .high: return Color(hex: "#f5576c")
        case .critical: return Color.red
        }
    }
    
    private func dismissBanner() {
        withAnimation(.easeOut(duration: 0.3)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
    
    private func startAutoDismissTimer() {
        let duration: TimeInterval = error.severity == .critical ? 10.0 : 5.0
        
        withAnimation(.linear(duration: duration)) {
            progress = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            if isVisible {
                dismissBanner()
            }
        }
    }
}

// MARK: - Loading Overlay
struct LoadingOverlay: View {
    let message: String
    @State private var rotation = 0.0

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#667eea"),
                                    Color(hex: "#764ba2"),
                                    Color(hex: "#f093fb")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 4
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(rotation))

                    Image(systemName: "sparkles")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundColor(.white)
                }

                Text(message)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
            )
            .shadow(radius: 20)
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Retry Mechanism
@MainActor
class RetryManager: ObservableObject {
    static let shared = RetryManager()
    
    @Published private var retryAttempts: [String: Int] = [:]
    private let maxRetries = 3
    private let retryDelays: [TimeInterval] = [1.0, 2.0, 5.0] // Exponential backoff
    
    private init() {}
    
    func canRetry(for operationId: String) -> Bool {
        let attempts = retryAttempts[operationId] ?? 0
        return attempts < maxRetries
    }
    
    func attemptRetry<T: Sendable>(
        operationId: String,
        operation: @escaping () async throws -> T,
        onSuccess: @escaping (T) -> Void,
        onFailure: @escaping (SnapChefError) -> Void
    ) {
        let currentAttempt = retryAttempts[operationId] ?? 0
        
        guard currentAttempt < maxRetries else {
            onFailure(.unknown("Maximum retry attempts exceeded", recovery: .contactSupport))
            return
        }
        
        retryAttempts[operationId] = currentAttempt + 1
        
        let delay = currentAttempt < retryDelays.count ? retryDelays[currentAttempt] : (retryDelays.last ?? 5.0)
        
        Task {
            if currentAttempt > 0 {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            
            do {
                let result = try await operation()
                await MainActor.run {
                    retryAttempts.removeValue(forKey: operationId)
                    onSuccess(result)
                }
            } catch {
                await MainActor.run {
                    let snapChefError = error as? SnapChefError ?? .unknown(error.localizedDescription)
                    
                    // Log retry attempt
                    ErrorAnalytics.logError(snapChefError, context: "retry_attempt_\(currentAttempt + 1)")
                    
                    if canRetry(for: operationId) && snapChefError.recovery == .retry {
                        // Schedule another retry
                        attemptRetry(
                            operationId: operationId,
                            operation: operation,
                            onSuccess: onSuccess,
                            onFailure: onFailure
                        )
                    } else {
                        retryAttempts.removeValue(forKey: operationId)
                        onFailure(snapChefError)
                    }
                }
            }
        }
    }
    
    func resetRetries(for operationId: String) {
        retryAttempts.removeValue(forKey: operationId)
    }
}

// MARK: - Error Boundary Component
struct ErrorBoundary<Content: View>: View {
    let content: Content
    let fallback: (SnapChefError) -> AnyView
    let onError: ((SnapChefError) -> Void)?
    
    @State private var error: SnapChefError?
    
    init(
        @ViewBuilder content: () -> Content,
        onError: ((SnapChefError) -> Void)? = nil,
        @ViewBuilder fallback: @escaping (SnapChefError) -> AnyView = { error in
            AnyView(DefaultErrorView(error: error))
        }
    ) {
        self.content = content()
        self.onError = onError
        self.fallback = fallback
    }
    
    var body: some View {
        Group {
            if let error = error {
                fallback(error)
            } else {
                content
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .snapChefError)) { notification in
            if let error = notification.object as? SnapChefError {
                self.error = error
                onError?(error)
                ErrorAnalytics.logError(error, context: "error_boundary_caught")
            }
        }
    }
}

// MARK: - Default Error View
struct DefaultErrorView: View {
    let error: SnapChefError
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: error.icon)
                .font(.system(size: 60, weight: .light))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("Oops!")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(error.userFriendlyMessage)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            if error.recovery != .none {
                Button(error.actionTitle) {
                    // Handle action based on recovery strategy
                    handleRecoveryAction()
                }
                .buttonStyle(.borderedProminent)
            }
            
            if error.severity != .low {
                Button("Show Details") {
                    showDetails.toggle()
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
            }
            
            if showDetails {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Error Details:")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Text("Type: \(error.category)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Severity: \(error.severity)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let description = error.errorDescription {
                        Text("Description: \(description)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .transition(.opacity)
            }
        }
        .padding()
        .animation(.easeInOut, value: showDetails)
    }
    
    private func handleRecoveryAction() {
        switch error.recovery {
        case .retry:
            // Post retry notification
            NotificationCenter.default.post(name: .snapChefRetry, object: error)
        case .openSettings:
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        case .contactSupport:
            // Open support email
            if let url = URL(string: "mailto:support@snapchef.app") {
                UIApplication.shared.open(url)
            }
        default:
            break
        }
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let snapChefError = Notification.Name("SnapChefError")
    static let snapChefRetry = Notification.Name("SnapChefRetry")
}

// MARK: - Global Error Handler
@MainActor
class GlobalErrorHandler: ObservableObject {
    static let shared = GlobalErrorHandler()
    
    @Published var currentError: SnapChefError?
    @Published var errorHistory: [SnapChefError] = []
    
    private init() {
        setupErrorHandling()
    }
    
    private func setupErrorHandling() {
        // Handle uncaught exceptions
        NSSetUncaughtExceptionHandler { exception in
            let error = SnapChefError.unknown(
                "Uncaught exception: \(exception.description)",
                recovery: .contactSupport
            )
            Task { @MainActor in
                GlobalErrorHandler.shared.handleError(error, context: "uncaught_exception")
            }
        }
    }
    
    func handleError(_ error: SnapChefError, context: String = "") {
        currentError = error
        errorHistory.append(error)
        
        // Keep only last 50 errors
        if errorHistory.count > 50 {
            errorHistory.removeFirst()
        }
        
        // Log error
        ErrorAnalytics.logError(error, context: context)
        
        // Post notification for error boundaries
        NotificationCenter.default.post(name: .snapChefError, object: error)
        
        // Handle critical errors immediately
        if error.severity == .critical {
            handleCriticalError(error, context: context)
        }
    }
    
    private func handleCriticalError(_ error: SnapChefError, context: String) {
        // Send crash report immediately
        Task {
            await CrashReportingService.shared.reportCriticalError([
                "error": String(describing: error),
                "context": context,
                "timestamp": String(Date().timeIntervalSince1970)
            ])
        }
        
        // Show critical error alert
        DispatchQueue.main.async {
            // Force show alert even if another error is showing
            self.currentError = error
        }
    }
    
    func clearError() {
        currentError = nil
    }
    
    func clearHistory() {
        errorHistory.removeAll()
    }
}

// MARK: - Success Toast
struct SuccessToast: View {
    let message: String
    @State private var isVisible = false
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            if isVisible {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(Color(hex: "#43e97b"))

                    Text(message)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)

                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(hex: "#43e97b").opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: Color(hex: "#43e97b").opacity(0.3), radius: 10)
                .padding(.horizontal)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isVisible = true
            }

            // Auto dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isVisible = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }
        }
    }
}
