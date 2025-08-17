import SwiftUI

// MARK: - Error Types
enum SnapChefError: LocalizedError {
    case networkError(String)
    case authenticationError(String)
    case cameraError(String)
    case storageError(String)
    case apiError(String)
    case invalidInput(String)
    case subscriptionError(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return message
        case .authenticationError(let message):
            return message
        case .cameraError(let message):
            return message
        case .storageError(let message):
            return message
        case .apiError(let message):
            return message
        case .invalidInput(let message):
            return message
        case .subscriptionError(let message):
            return message
        case .unknown(let message):
            return message
        }
    }

    var userFriendlyMessage: String {
        switch self {
        case .networkError:
            return "We're having trouble connecting. Please check your internet and try again."
        case .authenticationError:
            return "Please sign in again to continue."
        case .cameraError:
            return "Camera access is needed to snap your fridge. Please enable it in Settings."
        case .storageError:
            return "We're having trouble saving your recipes. Please try again."
        case .apiError:
            return "Our chef is taking a break. Please try again in a moment."
        case .invalidInput:
            return "Please check your input and try again."
        case .subscriptionError:
            return "There was an issue with your subscription. Please try again."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }

    var actionTitle: String {
        switch self {
        case .networkError:
            return "Retry"
        case .authenticationError:
            return "Sign In"
        case .cameraError:
            return "Open Settings"
        case .storageError:
            return "Try Again"
        case .apiError:
            return "Retry"
        case .invalidInput:
            return "OK"
        case .subscriptionError:
            return "Manage Subscription"
        case .unknown:
            return "OK"
        }
    }

    var icon: String {
        switch self {
        case .networkError:
            return "wifi.slash"
        case .authenticationError:
            return "person.crop.circle.badge.exclamationmark"
        case .cameraError:
            return "camera.badge.exclamationmark"
        case .storageError:
            return "externaldrive.badge.exclamationmark"
        case .apiError:
            return "exclamationmark.icloud"
        case .invalidInput:
            return "exclamationmark.triangle"
        case .subscriptionError:
            return "creditcard"
        case .unknown:
            return "exclamationmark.circle"
        }
    }
}

// MARK: - Error Alert Modifier
struct ErrorAlertModifier: ViewModifier {
    @Binding var error: SnapChefError?
    let onAction: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .alert("Oops!", isPresented: .constant(error != nil), presenting: error) { error in
                Button(error.actionTitle) {
                    handleAction(for: error)
                    self.error = nil
                }

                if error.actionTitle != "OK" {
                    Button("Cancel", role: .cancel) {
                        self.error = nil
                    }
                }
            } message: { error in
                Text(error.userFriendlyMessage)
            }
    }

    private func handleAction(for error: SnapChefError) {
        switch error {
        case .cameraError:
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        case .authenticationError:
            // Navigate to sign in
            onAction?()
        case .subscriptionError:
            // Open subscription management
            onAction?()
        default:
            onAction?()
        }
    }
}

extension View {
    func errorAlert(_ error: Binding<SnapChefError?>, onAction: (() -> Void)? = nil) -> some View {
        modifier(ErrorAlertModifier(error: error, onAction: onAction))
    }
}

// MARK: - Error Banner View
struct ErrorBannerView: View {
    let error: SnapChefError
    let onDismiss: () -> Void
    let onAction: (() -> Void)?

    @State private var isVisible = false

    var body: some View {
        VStack {
            if isVisible {
                HStack(spacing: 16) {
                    Image(systemName: error.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Error")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)

                        Text(error.userFriendlyMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(2)
                    }

                    Spacer()

                    if let onAction = onAction {
                        Button(action: onAction) {
                            Text(error.actionTitle)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.2))
                                )
                        }
                    }

                    Button(action: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isVisible = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDismiss()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#f5576c"),
                                    Color(hex: "#f093fb")
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: Color(hex: "#f5576c").opacity(0.5), radius: 20, y: 10)
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

            // Auto dismiss after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if isVisible {
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
