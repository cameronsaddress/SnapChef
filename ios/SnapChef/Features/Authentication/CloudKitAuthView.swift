import SwiftUI
import AuthenticationServices

struct CloudKitAuthView: View {
    @StateObject private var authManager = CloudKitAuthManager.shared
    @StateObject private var tikTokAuthManager = TikTokAuthManager.shared
    @Environment(\.dismiss) private var dismiss

    let requiredFor: AuthRequiredFeature?

    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var loadingMessage = "Signing in..."

    init(requiredFor: AuthRequiredFeature? = nil) {
        self.requiredFor = requiredFor
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()

                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("Welcome to SnapChef")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        if let feature = requiredFor {
                            Text("Sign in to access \(feature.title)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        } else {
                            Text("Join our community of food lovers")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.top, 40)

                    // Benefits
                    VStack(alignment: .leading, spacing: 16) {
                        CloudKitBenefitRow(icon: "trophy.fill", title: "Join Challenges", subtitle: "Compete with other chefs")
                        CloudKitBenefitRow(icon: "flame.fill", title: "Track Streaks", subtitle: "Build your cooking habits")
                        CloudKitBenefitRow(icon: "person.3.fill", title: "Create Teams", subtitle: "Cook together with friends")
                        CloudKitBenefitRow(icon: "square.and.arrow.up", title: "Share Recipes", subtitle: "Show off your creations")
                    }
                    .padding(.horizontal, 32)

                    Spacer()

                    // Sign In Buttons
                    VStack(spacing: 12) {
                        // Sign in with Apple
                        SignInWithAppleButton(
                            .signIn,
                            onRequest: { request in
                                request.requestedScopes = [.fullName, .email]
                            },
                            onCompletion: { result in
                                handleSignInWithApple(result)
                            }
                        )
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 50)
                        .cornerRadius(25)

                        // Sign in with TikTok
                        Button(action: {
                            handleTikTokSignIn()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "music.note")
                                    .font(.title2)
                                    .foregroundColor(.white)

                                Text("Continue with TikTok")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    colors: [Color.black, Color(hex: "#FF0050")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(25)
                        }
                        .disabled(isLoading)
                    }
                    .padding(.horizontal, 24)
                    .disabled(isLoading)

                    // Skip for now (only for non-required features)
                    if requiredFor == nil || requiredFor == .basicRecipes {
                        Button(action: { dismiss() }) {
                            Text("Skip for now")
                                .foregroundColor(.white.opacity(0.6))
                                .underline()
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarItems(
                trailing: Button("Cancel") { dismiss() }
                    .foregroundColor(.white)
            )
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .overlay(
            isLoading ? LoadingOverlay(message: loadingMessage) : nil
        )
        .sheet(isPresented: $authManager.showUsernameSelection) {
            UsernameSetupView()
                .interactiveDismissDisabled()
        }
    }

    private func handleSignInWithApple(_ result: Result<ASAuthorization, Error>) {
        Task {
            do {
                switch result {
                case .success(let authorization):
                    isLoading = true
                    loadingMessage = "Signing in with Apple..."
                    try await authManager.signInWithApple(authorization: authorization)

                    // Check if we need username setup
                    if authManager.showUsernameSelection {
                        // Username selection will be shown via sheet
                        isLoading = false
                    } else {
                        dismiss()
                    }
                case .failure(let error):
                    // Handle specific error codes
                    let nsError = error as NSError
                    if nsError.code == 1_001 {
                        // User cancelled - just dismiss loading
                        print("User cancelled Sign in with Apple")
                    } else {
                        errorMessage = "Sign in failed: \(error.localizedDescription)"
                        showError = true
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Authentication failed: \(error.localizedDescription)"
                    showError = true
                    isLoading = false
                }
            }
        }
    }

    private func handleTikTokSignIn() {
        Task {
            do {
                isLoading = true
                loadingMessage = "Connecting to TikTok..."
                let tikTokUser = try await tikTokAuthManager.authenticate()

                // Create SnapChef account integration if TikTok auth succeeds
                // For now, just dismiss the auth view
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "TikTok sign in failed: \(error.localizedDescription)"
                    showError = true
                    isLoading = false
                }
            }
        }
    }
}

struct CloudKitBenefitRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color(hex: "#667eea"))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()
        }
    }
}

#Preview {
    CloudKitAuthView(requiredFor: .challenges)
}
