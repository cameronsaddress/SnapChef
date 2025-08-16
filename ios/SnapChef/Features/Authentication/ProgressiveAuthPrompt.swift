//
//  ProgressiveAuthPrompt.swift
//  SnapChef
//
//  Created by Claude on 2025-01-16.
//  Progressive Authentication UI Component
//

import SwiftUI
import AuthenticationServices

/// Beautiful slide-up authentication prompt that appears at strategic moments
/// Integrates with AuthPromptTrigger for context-aware messaging
struct ProgressiveAuthPrompt: View {
    // MARK: - Environment & Dependencies
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authTrigger = AuthPromptTrigger.shared
    @StateObject private var authManager = CloudKitAuthManager.shared
    @StateObject private var tikTokAuthManager = TikTokAuthManager.shared
    
    // MARK: - State
    
    @State private var dragOffset: CGFloat = 0
    @State private var isVisible = false
    @State private var isAnimating = false
    @State private var shimmerPhase: CGFloat = 0
    @State private var particleScale: CGFloat = 0
    @State private var showSuccess = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // MARK: - Constants
    
    private let cardHeight: CGFloat = 420
    private let dismissThreshold: CGFloat = 150
    private let snapBackThreshold: CGFloat = 50
    
    // MARK: - Computed Properties
    
    private var currentContext: AuthPromptTrigger.TriggerContext {
        authTrigger.currentContext ?? .firstRecipeSuccess
    }
    
    private var contextIcon: String {
        switch currentContext {
        case .firstRecipeSuccess: return "heart.fill"
        case .viralContentCreated: return "flame.fill"
        case .dailyLimitReached: return "infinity"
        case .socialFeatureExplored: return "person.3.fill"
        case .challengeInterest: return "trophy.fill"
        case .shareAttempt: return "square.and.arrow.up"
        case .weeklyHighEngagement: return "star.fill"
        case .returningUser: return "hand.wave.fill"
        }
    }
    
    private var contextGradient: [Color] {
        switch currentContext {
        case .firstRecipeSuccess: 
            return [Color(hex: "#f093fb"), Color(hex: "#f5576c")]
        case .viralContentCreated: 
            return [Color(hex: "#ff6b35"), Color(hex: "#ff1493")]
        case .dailyLimitReached: 
            return [Color(hex: "#667eea"), Color(hex: "#764ba2")]
        case .socialFeatureExplored: 
            return [Color(hex: "#43e97b"), Color(hex: "#38f9d7")]
        case .challengeInterest: 
            return [Color(hex: "#ffa726"), Color(hex: "#ff7043")]
        case .shareAttempt: 
            return [Color(hex: "#4facfe"), Color(hex: "#00f2fe")]
        case .weeklyHighEngagement: 
            return [Color(hex: "#f093fb"), Color(hex: "#f5576c")]
        case .returningUser: 
            return [Color(hex: "#667eea"), Color(hex: "#764ba2")]
        }
    }
    
    private var benefits: [(icon: String, title: String)] {
        switch currentContext {
        case .firstRecipeSuccess:
            return [
                ("bookmark.fill", "Save your recipes"),
                ("icloud.fill", "Sync across devices"),
                ("sparkles", "Unlock premium features")
            ]
        case .viralContentCreated:
            return [
                ("chart.line.uptrend.xyaxis", "Track viral stats"),
                ("trophy.fill", "Compete with chefs"),
                ("flame.fill", "Show off your skills")
            ]
        case .dailyLimitReached:
            return [
                ("infinity", "Unlimited recipes"),
                ("heart.fill", "Save favorites"),
                ("star.fill", "Premium features")
            ]
        case .socialFeatureExplored:
            return [
                ("person.3.fill", "Follow other chefs"),
                ("message.fill", "Share with friends"),
                ("globe", "Join the community")
            ]
        case .challengeInterest:
            return [
                ("trophy.fill", "Win challenges"),
                ("flame.fill", "Build streaks"),
                ("gift.fill", "Earn rewards")
            ]
        case .shareAttempt:
            return [
                ("square.and.arrow.up", "Easy sharing"),
                ("link", "Custom links"),
                ("photo.fill", "Beautiful cards")
            ]
        case .weeklyHighEngagement:
            return [
                ("crown.fill", "VIP features"),
                ("star.fill", "Exclusive content"),
                ("sparkles", "Special rewards")
            ]
        case .returningUser:
            return [
                ("arrow.clockwise", "Resume progress"),
                ("icloud.fill", "Sync recipes"),
                ("heart.fill", "Keep favorites")
            ]
        }
    }
    
    // MARK: - Body
    
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
            VStack(spacing: 0) {
                Spacer()
                
                GlassmorphicCard(content: {
                    VStack(spacing: 0) {
                        // Drag handle
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 40, height: 6)
                            .padding(.top, 12)
                            .padding(.bottom, 20)
                        
                        // Header section
                        VStack(spacing: 16) {
                            // Context icon with animation
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: contextGradient,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                                    .shadow(color: contextGradient.first?.opacity(0.5) ?? .clear, radius: 20)
                                
                                Image(systemName: contextIcon)
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                                
                                // Particle burst effect
                                Circle()
                                    .stroke(Color.white.opacity(0.6), lineWidth: 2)
                                    .frame(width: 80, height: 80)
                                    .scaleEffect(particleScale)
                                    .opacity(particleScale > 0 ? 0 : 1)
                            }
                            
                            // Title and message
                            VStack(spacing: 8) {
                                Text(currentContext.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                Text(currentContext.message)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                    .padding(.horizontal, 20)
                            }
                        }
                        .padding(.bottom, 24)
                        
                        // Benefits section
                        VStack(spacing: 12) {
                            ForEach(Array(benefits.enumerated()), id: \.offset) { index, benefit in
                                HStack(spacing: 12) {
                                    Image(systemName: benefit.icon)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: contextGradient,
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: 24)
                                    
                                    Text(benefit.title)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                    
                                    Spacer()
                                    
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(contextGradient.first ?? .blue)
                                }
                                .padding(.horizontal, 20)
                                .opacity(isVisible ? 1 : 0)
                                .offset(x: isVisible ? 0 : 50)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.1), value: isVisible)
                            }
                        }
                        .padding(.bottom, 32)
                        
                        // Sign in buttons
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
                            .disabled(isLoading)
                            
                            // Sign in with TikTok
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
                                    
                                    Text(isLoading ? "Signing in..." : "Continue with TikTok")
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
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        
                        // Action buttons
                        HStack(spacing: 16) {
                            // Maybe Later
                            Button(action: {
                                authTrigger.recordPromptAction("dismissed", for: currentContext)
                                dismissPrompt()
                            }) {
                                Text("Maybe Later")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 24)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            
                            // Don't Ask Again
                            Button(action: {
                                authTrigger.recordPromptAction("never", for: currentContext)
                                dismissPrompt()
                            }) {
                                Text("Don't Ask Again")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 24)
                            }
                        }
                        .padding(.bottom, 20)
                        
                        // Error message
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 16)
                        }
                    }
                }, cornerRadius: 24, glowColor: contextGradient.first ?? Color(hex: "#667eea"))
                .frame(height: cardHeight)
                .offset(y: dragOffset)
                .offset(y: isVisible ? 0 : cardHeight)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isVisible)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.height > 0 {
                                dragOffset = value.translation.height
                            }
                        }
                        .onEnded { value in
                            if value.translation.height > dismissThreshold {
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
            
            // Trigger animations
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
                
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    shimmerPhase = 1.0
                }
            }
            
            // Trigger particle effect
            triggerParticleEffect()
        }
    }
    
    // MARK: - Action Handlers
    
    private func handleSignInWithApple(_ result: Result<ASAuthorization, Error>) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                switch result {
                case .success(let authorization):
                    try await authManager.signInWithApple(authorization: authorization)
                case .failure(let error):
                    throw error
                }
                await MainActor.run {
                    authTrigger.recordPromptAction("completed", for: currentContext)
                    showSuccessAndDismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Sign in failed. Please try again."
                    triggerErrorFeedback()
                }
            }
        }
    }
    
    private func handleTikTokSignIn() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // TikTok authentication using the shared manager
                _ = try await tikTokAuthManager.authenticate()
                await MainActor.run {
                    authTrigger.recordPromptAction("completed", for: currentContext)
                    showSuccessAndDismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "TikTok sign in failed. Please try again."
                    triggerErrorFeedback()
                }
            }
        }
    }
    
    private func showSuccessAndDismiss() {
        isLoading = false
        showSuccess = true
        
        // Trigger success haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Show success animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            particleScale = 3
        }
        
        // Dismiss after success animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            dismissPrompt()
        }
    }
    
    private func dismissPrompt() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isVisible = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
    
    private func triggerParticleEffect() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 1.2)) {
                particleScale = 2.5
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                particleScale = 0
            }
        }
    }
    
    private func triggerErrorFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        
        // Shake animation
        withAnimation(.easeInOut(duration: 0.1).repeatCount(3, autoreverses: true)) {
            dragOffset = 10
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                dragOffset = 0
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        MagicalBackground()
            .ignoresSafeArea()
        
        ProgressiveAuthPrompt()
    }
}

// MARK: - Usage Examples

extension ProgressiveAuthPrompt {
    /// Show prompt for first recipe success
    static func showForFirstRecipe() -> some View {
        ProgressiveAuthPrompt()
            .onAppear {
                AuthPromptTrigger.shared.triggerPrompt(for: .firstRecipeSuccess)
            }
    }
    
    /// Show prompt for viral content
    static func showForViralContent() -> some View {
        ProgressiveAuthPrompt()
            .onAppear {
                AuthPromptTrigger.shared.triggerPrompt(for: .viralContentCreated)
            }
    }
    
    /// Show prompt for social features
    static func showForSocial() -> some View {
        ProgressiveAuthPrompt()
            .onAppear {
                AuthPromptTrigger.shared.triggerPrompt(for: .socialFeatureExplored)
            }
    }
    
    /// Show prompt for challenges
    static func showForChallenges() -> some View {
        ProgressiveAuthPrompt()
            .onAppear {
                AuthPromptTrigger.shared.triggerPrompt(for: .challengeInterest)
            }
    }
}