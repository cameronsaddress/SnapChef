import SwiftUI
import AuthenticationServices
import GoogleSignIn

struct CloudKitAuthView: View {
    @StateObject private var authManager = CloudKitAuthManager.shared
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
                        
                        // Google Sign-In
                        Button(action: handleSignInWithGoogle) {
                            HStack {
                                Image(systemName: "globe")
                                    .font(.system(size: 18))
                                Text("Sign in with Google")
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(25)
                        }
                        
                        // Facebook Sign-In (placeholder for now)
                        Button(action: handleSignInWithFacebook) {
                            HStack {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 18))
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
            isLoading ? LoadingOverlay(message: "Signing in...") : nil
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
                    if nsError.code == 1001 {
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
    
    private func handleSignInWithGoogle() {
        isLoading = true
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Unable to get root view controller"
            showError = true
            isLoading = false
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak authManager] result, error in
            Task { @MainActor in
                if let error = error {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                    return
                }
                
                guard let result = result else {
                    errorMessage = "No result from Google Sign-In"
                    showError = true
                    isLoading = false
                    return
                }
                
                do {
                    try await authManager?.signInWithGoogle(user: result.user)
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                }
            }
        }
    }
    
    private func handleSignInWithFacebook() {
        // Facebook sign-in not yet implemented
        errorMessage = "Facebook sign-in coming soon"
        showError = true
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