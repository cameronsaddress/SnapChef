//
//  AuthPromptCard.swift
//  SnapChef
//
//  Created on August 27, 2025
//  Slide-up authentication prompt card with swipe-to-dismiss
//

import SwiftUI
import AuthenticationServices

struct AuthPromptCard: View {
    @Binding var isPresented: Bool
    let prompt: AuthPromptManager.AuthPrompt
    let onSignIn: () -> Void
    let onDismiss: (AuthPromptManager.DismissAction) -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var showBenefits = false
    @State private var benefitIndex = 0
    @State private var scale: CGFloat = 0.95
    @State private var opacity: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)
            
            // Content
            VStack(alignment: .center, spacing: 20) {
                // Icon with animation
                if let iconName = prompt.content.icon {
                    Image(systemName: iconName)
                        .font(.system(size: 50))
                        .foregroundColor(iconColor(for: prompt.content.visualStyle))
                        .scaleEffect(scale)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: scale)
                }
                
                // Title with animation
                Text(prompt.content.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Message
                Text(prompt.content.message)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Animated benefits
                if showBenefits {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(prompt.content.benefits.prefix(benefitIndex + 1).enumerated()), id: \.offset) { index, benefit in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 20))
                                Text(benefit)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                    }
                    .padding(.horizontal)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: benefitIndex)
                }
                
                // Sign in button
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        switch result {
                        case .success:
                            onSignIn()
                            onDismiss(.completed)
                        case .failure(let error):
                            print("Sign in failed: \(error)")
                        }
                    }
                )
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .cornerRadius(25)
                .padding(.horizontal)
                
                // Secondary actions
                HStack(spacing: 40) {
                    Button(action: {
                        withAnimation(.spring()) {
                            onDismiss(.later)
                            isPresented = false
                        }
                    }) {
                        Text(prompt.content.secondaryAction)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Button(action: {
                        withAnimation(.spring()) {
                            onDismiss(.never)
                            isPresented = false
                        }
                    }) {
                        Text("Don't Ask Again")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(
                    LinearGradient(
                        colors: gradientColors(for: prompt.content.visualStyle),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .offset(y: dragOffset)
        .scaleEffect(scale)
        .opacity(opacity)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 150 {
                        withAnimation(.spring()) {
                            dragOffset = UIScreen.main.bounds.height
                            opacity = 0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDismiss(.swipedAway)
                            isPresented = false
                        }
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // Stagger benefit animations
            withAnimation(.easeOut(duration: 0.3).delay(0.5)) {
                showBenefits = true
            }
            
            for i in 0..<prompt.content.benefits.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7 + Double(i) * 0.2) {
                    withAnimation {
                        benefitIndex = i
                    }
                }
            }
            
            // Haptic feedback
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
    
    private func iconColor(for style: AuthPromptManager.PromptContent.VisualStyle) -> Color {
        switch style {
        case .celebration:
            return .yellow
        case .exciting:
            return .pink
        case .informative:
            return .blue
        case .urgent:
            return .orange
        case .friendly:
            return .green
        }
    }
    
    private func gradientColors(for style: AuthPromptManager.PromptContent.VisualStyle) -> [Color] {
        switch style {
        case .celebration:
            return [Color(hex: "#667eea"), Color(hex: "#764ba2")]
        case .exciting:
            return [Color(hex: "#f093fb"), Color(hex: "#f5576c")]
        case .informative:
            return [Color(hex: "#4facfe"), Color(hex: "#00f2fe")]
        case .urgent:
            return [Color(hex: "#fa709a"), Color(hex: "#fee140")]
        case .friendly:
            return [Color(hex: "#30cfd0"), Color(hex: "#330867")]
        }
    }
}

// MARK: - Auth Prompt Overlay

struct AuthPromptOverlay: View {
    @StateObject private var authPromptManager = AuthPromptManager.shared
    @State private var showCard = false
    
    var body: some View {
        ZStack {
            // Background dimming
            Color.black.opacity(showCard ? 0.4 : 0)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.3), value: showCard)
                .onTapGesture {
                    // Allow tapping background to dismiss
                    withAnimation(.spring()) {
                        authPromptManager.dismissPrompt(action: .swipedAway)
                        showCard = false
                    }
                }
            
            // Card
            if let prompt = authPromptManager.currentPrompt {
                VStack {
                    Spacer()
                    
                    AuthPromptCard(
                        isPresented: $showCard,
                        prompt: prompt,
                        onSignIn: {
                            // Handled in onCompletion of SignInWithAppleButton
                        },
                        onDismiss: { action in
                            authPromptManager.dismissPrompt(action: action)
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showCard = true
            }
        }
    }
}