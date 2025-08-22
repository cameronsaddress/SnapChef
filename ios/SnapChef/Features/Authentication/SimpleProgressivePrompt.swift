//
//  SimpleProgressivePrompt.swift
//  SnapChef
//
//  Simplified progressive authentication prompt
//  Cleaner, more focused than the original ProgressiveAuthPrompt
//

import SwiftUI
import AuthenticationServices

struct SimpleProgressivePrompt: View {
    @StateObject private var authManager = UnifiedAuthManager.shared
    @Environment(\.dismiss) private var dismiss
    
    let context: PromptContext
    
    @State private var dragOffset: CGFloat = 0
    @State private var isVisible = false
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    enum PromptContext {
        case firstRecipe
        case viralContent
        case socialFeature
        case challenge
        
        var title: String {
            switch self {
            case .firstRecipe: return "Love your first recipe?"
            case .viralContent: return "Ready to go viral?"
            case .socialFeature: return "Connect with chefs"
            case .challenge: return "Join the challenge"
            }
        }
        
        var message: String {
            switch self {
            case .firstRecipe: return "Save your recipes and unlock premium features"
            case .viralContent: return "Track your viral videos and compete with others"
            case .socialFeature: return "Follow chefs and share your creations"
            case .challenge: return "Participate in daily challenges and earn rewards"
            }
        }
        
        var icon: String {
            switch self {
            case .firstRecipe: return "heart.fill"
            case .viralContent: return "flame.fill"
            case .socialFeature: return "person.3.fill"
            case .challenge: return "trophy.fill"
            }
        }
        
        var gradient: [Color] {
            switch self {
            case .firstRecipe: return [Color(hex: "#f093fb"), Color(hex: "#f5576c")]
            case .viralContent: return [Color(hex: "#ff6b35"), Color(hex: "#ff1493")]
            case .socialFeature: return [Color(hex: "#43e97b"), Color(hex: "#38f9d7")]
            case .challenge: return [Color(hex: "#ffa726"), Color(hex: "#ff7043")]
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black
                .opacity(isVisible ? 0.3 : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPrompt()
                }
            
            // Main card
            VStack {
                Spacer()
                
                VStack(spacing: 0) {
                    // Drag handle
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 40, height: 6)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    
                    // Content
                    VStack(spacing: 24) {
                        // Icon and header
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: context.gradient,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 60, height: 60)
                                    .shadow(color: context.gradient.first?.opacity(0.3) ?? .clear, radius: 10)
                                
                                Image(systemName: context.icon)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(spacing: 8) {
                                Text(context.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text(context.message)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                        }
                        
                        // Sign in buttons
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
                            .frame(height: 44)
                            .cornerRadius(22)
                            .disabled(isLoading)
                            
                            // TikTok Sign In
                            Button(action: handleTikTokSignIn) {
                                HStack(spacing: 8) {
                                    if isLoading {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "music.note")
                                            .font(.title3)
                                    }
                                    
                                    Text(isLoading ? "Signing in..." : "Continue with TikTok")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    LinearGradient(
                                        colors: [Color.black, Color(hex: "#FF0050")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(22)
                            }
                            .disabled(isLoading)
                        }
                        
                        // Action buttons
                        HStack(spacing: 16) {
                            Button("Maybe Later") {
                                dismissPrompt()
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            
                            Button("Don't Ask Again") {
                                neverAskAgain()
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        }
                        
                        // Error message
                        if showError {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.8),
                                    Color.black.opacity(0.9)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .offset(y: dragOffset)
                .offset(y: isVisible ? 0 : 300)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isVisible)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.height > 0 {
                                dragOffset = value.translation.height
                            }
                        }
                        .onEnded { value in
                            if value.translation.height > 100 {
                                dismissPrompt()
                            } else {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        Task {
            do {
                isLoading = true
                
                switch result {
                case .success(let authorization):
                    try await authManager.signInWithApple(authorization: authorization)
                    
                    await MainActor.run {
                        // Success - prompt will be dismissed via onChange
                        recordSuccess()
                    }
                    
                case .failure(let error):
                    let nsError = error as NSError
                    if nsError.code != 1001 { // Not user cancellation
                        throw error
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Sign in failed. Please try again."
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
                
                // TikTok sign-in not available with CloudKitAuthManager
                throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "TikTok sign-in requires UnifiedAuthManager"])
                
                await MainActor.run {
                    recordSuccess()
                    dismissPrompt()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "TikTok sign in failed. Please try again."
                    showError = true
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func dismissPrompt() {
        recordDismissal()
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isVisible = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
    
    private func neverAskAgain() {
        recordNeverAsk()
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isVisible = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
    
    private func recordSuccess() {
        // Track successful authentication from progressive prompt
        UserDefaults.standard.set(Date(), forKey: "lastProgressiveAuthSuccess")
    }
    
    private func recordDismissal() {
        // Track dismissal to avoid showing too frequently
        let key = "progressiveAuthDismissal_\(context.title.replacingOccurrences(of: " ", with: "_"))"
        UserDefaults.standard.set(Date(), forKey: key)
    }
    
    private func recordNeverAsk() {
        // Mark that user doesn't want progressive prompts
        UserDefaults.standard.set(true, forKey: "neverShowProgressiveAuth")
    }
}

// MARK: - Convenience Initializers

extension SimpleProgressivePrompt {
    static func forFirstRecipe() -> SimpleProgressivePrompt {
        SimpleProgressivePrompt(context: .firstRecipe)
    }
    
    static func forViralContent() -> SimpleProgressivePrompt {
        SimpleProgressivePrompt(context: .viralContent)
    }
    
    static func forSocialFeature() -> SimpleProgressivePrompt {
        SimpleProgressivePrompt(context: .socialFeature)
    }
    
    static func forChallenge() -> SimpleProgressivePrompt {
        SimpleProgressivePrompt(context: .challenge)
    }
}

#Preview {
    ZStack {
        MagicalBackground()
            .ignoresSafeArea()
        
        SimpleProgressivePrompt(context: .firstRecipe)
    }
}
