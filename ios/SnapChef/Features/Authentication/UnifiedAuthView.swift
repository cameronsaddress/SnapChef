//
//  UnifiedAuthView.swift
//  SnapChef
//
//  Simplified authentication view that handles all auth flows
//  Replaces CloudKitAuthView and AuthenticationView with cleaner UX
//

import SwiftUI
import AuthenticationServices

struct UnifiedAuthView: View {
    @StateObject private var authManager = UnifiedAuthManager.shared
    @Environment(\.dismiss) private var dismiss
    
    let requiredFor: AuthRequiredFeature?
    let showAsSheet: Bool
    
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var loadingMessage = "Signing in..."
    
    init(requiredFor: AuthRequiredFeature? = nil, showAsSheet: Bool = true) {
        self.requiredFor = requiredFor
        self.showAsSheet = showAsSheet
    }
    
    var body: some View {
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
                        .foregroundColor(.white)
                    
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
                    AuthBenefitRow(icon: "bookmark.fill", title: "Save Recipes", subtitle: "Never lose your favorites")
                    AuthBenefitRow(icon: "icloud.fill", title: "Sync Everywhere", subtitle: "Access on all your devices")
                    AuthBenefitRow(icon: "trophy.fill", title: "Join Challenges", subtitle: "Compete with other chefs")
                    AuthBenefitRow(icon: "square.and.arrow.up", title: "Share Creations", subtitle: "Show off your cooking")
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Sign In Options
                VStack(spacing: 12) {
                    // Apple Sign In
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                    )
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(25)
                    .disabled(isLoading)
                    
                    // TikTok Sign In
                    Button(action: {
                        handleTikTokSignIn()
                    }) {
                        HStack(spacing: 12) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "music.note")
                                    .font(.title2)
                            }
                            
                            Text(isLoading ? loadingMessage : "Continue with TikTok")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
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
                
                // Skip option (only for non-required features)
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
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(showAsSheet)
        .toolbar {
            if showAsSheet {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $authManager.showUsernameSetup) {
            UsernameSetupView()
                .interactiveDismissDisabled()
        }
        .onAppear {
            print("🔍 DEBUG: [UnifiedAuthView] appeared")
        }
        .onChange(of: authManager.isAuthenticated) { isAuth in
            if isAuth {
                dismiss()
            }
        }
    }
    
    // MARK: - Action Handlers
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        Task {
            do {
                isLoading = true
                loadingMessage = "Signing in with Apple..."
                
                switch result {
                case .success(let authorization):
                    try await authManager.signInWithApple(authorization: authorization)
                case .failure(let error):
                    // Handle user cancellation gracefully
                    let nsError = error as NSError
                    if nsError.code == 1001 {
                        // User cancelled - just stop loading
                        return
                    }
                    throw error
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Sign in failed: \(error.localizedDescription)"
                    showError = true
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func handleTikTokSignIn() {
        Task {
            do {
                isLoading = true
                loadingMessage = "Connecting to TikTok..."
                
                try await authManager.signInWithTikTok()
                
                // If successful, dismiss
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "TikTok sign in failed: \(error.localizedDescription)"
                    showError = true
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct AuthBenefitRow: View {
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
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#667eea"))
        }
    }
}

#Preview {
    NavigationStack {
        UnifiedAuthView(requiredFor: .challenges)
    }
}
