import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss

    let requiredFor: AuthRequiredFeature?

    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

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

                        Text("Sign In to SnapChef")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        if let feature = requiredFor {
                            Text("Sign in required for \(feature.title)")
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
                        FeatureItem(icon: "trophy.fill", title: "Join Challenges", description: "Compete with other chefs")
                        FeatureItem(icon: "flame.fill", title: "Track Streaks", description: "Build your cooking habits")
                        FeatureItem(icon: "person.3.fill", title: "Create Teams", description: "Cook together with friends")
                        FeatureItem(icon: "square.and.arrow.up", title: "Share Recipes", description: "Show off your creations")
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

                        // Sign in with Google
                        Button(action: signInWithGoogle) {
                            HStack {
                                Image("google-icon") // Add this to Assets
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                Text("Sign in with Google")
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(25)
                        }

                        // Sign in with Facebook
                        Button(action: signInWithFacebook) {
                            HStack {
                                Image(systemName: "f.square.fill")
                                    .font(.title2)
                                Text("Sign in with Facebook")
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(hex: "#1877F2"))
                            .cornerRadius(25)
                        }
                    }
                    .padding(.horizontal, 24)
                    .disabled(isLoading)

                    // Skip for now
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
        .onAppear {
            print("🔍 DEBUG: [AuthenticationView] appeared")
        }
        .overlay(
            isLoading ? LoadingOverlay() : nil
        )
    }

    // MARK: - Sign In Methods

    private func handleSignInWithApple(_ result: Result<ASAuthorization, Error>) {
        isLoading = true

        Task {
            do {
                switch result {
                case .success(let authorization):
                    try await authManager.signInWithApple(authorization: authorization)
                    dismiss()
                case .failure(let error):
                    throw error
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }

    private func signInWithGoogle() {
        isLoading = true

        Task {
            do {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let rootViewController = windowScene.windows.first?.rootViewController else {
                    throw AuthError.unknown
                }

                try await authManager.signInWithGoogle(presentingViewController: rootViewController)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }

    private func signInWithFacebook() {
        isLoading = true

        Task {
            do {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let rootViewController = windowScene.windows.first?.rootViewController else {
                    throw AuthError.unknown
                }

                try await authManager.signInWithFacebook(presentingViewController: rootViewController)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
}

struct FeatureItem: View {
    let icon: String
    let title: String
    let description: String

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
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()
        }
    }
}

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
        }
    }
}

#Preview {
    AuthenticationView(requiredFor: .challenges)
        .environmentObject(AuthenticationManager())
}
