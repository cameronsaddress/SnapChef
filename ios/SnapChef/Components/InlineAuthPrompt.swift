//
//  InlineAuthPrompt.swift
//  SnapChef
//
//  Created on August 27, 2025
//  Inline authentication prompt for locked features
//

import SwiftUI
import AuthenticationServices

struct InlineAuthPrompt: View {
    let context: String
    let benefits: [String]
    var onAuthenticated: (() -> Void)? = nil
    
    @State private var isExpanded = false
    @State private var showingFullPrompt = false
    @State private var bounceAnimation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with lock icon
            HStack {
                Image(systemName: isExpanded ? "lock.open.fill" : "lock.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 20))
                    .rotationEffect(.degrees(bounceAnimation ? -10 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.5).repeatCount(3, autoreverses: true), value: bounceAnimation)
                
                Text(context)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Expand/collapse button
                Button(action: {
                    withAnimation(.spring()) {
                        isExpanded.toggle()
                        if isExpanded {
                            bounceAnimation = true
                        }
                    }
                }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            
            // Expandable benefits
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(benefits, id: \.self) { benefit in
                        HStack(spacing: 10) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow)
                            Text(benefit)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
                .padding(.vertical, 8)
                
                // Sign in button
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        switch result {
                        case .success:
                            // Authentication handled in SignInWithAppleButton
                            onAuthenticated?()
                        case .failure(let error):
                            AppLog.warning(AppLog.auth, "Inline sign-in failed: \(error.localizedDescription)")
                        }
                    }
                )
                .signInWithAppleButtonStyle(.white)
                .frame(height: 44)
                .cornerRadius(22)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.3),
                            Color.purple.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
    }
}

// MARK: - Locked Content View

struct LockedContentView<Content: View>: View {
    let isLocked: Bool
    let lockReason: String
    let benefits: [String]
    @ViewBuilder let content: () -> Content
    
    @State private var showAuthPrompt = false
    
    var body: some View {
        ZStack {
            if isLocked {
                // Blurred locked content
                content()
                    .blur(radius: 8)
                    .overlay(
                        Color.black.opacity(0.3)
                    )
                    .disabled(true)
                
                // Lock overlay
                VStack(spacing: 20) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(lockReason)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        showAuthPrompt = true
                    }) {
                        Text("Unlock Feature")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    }
                }
            } else {
                // Unlocked content
                content()
            }
        }
        .sheet(isPresented: $showAuthPrompt) {
            AuthenticationSheet(benefits: benefits)
        }
    }
}

// MARK: - Authentication Sheet

struct AuthenticationSheet: View {
    let benefits: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var isAuthenticating = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: "#667eea"),
                        Color(hex: "#764ba2")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Icon
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                        .padding(.top, 40)
                    
                    // Title
                    Text("Sign In to Unlock")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Benefits list
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(benefits, id: \.self) { benefit in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.green)
                                Text(benefit)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                    
                    // Sign in button
                    if isAuthenticating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    } else {
                        SignInWithAppleButton(
                            .signIn,
                            onRequest: { request in
                                request.requestedScopes = [.fullName, .email]
                            },
                            onCompletion: { result in
                                isAuthenticating = true
                                switch result {
                                case .success:
                                    // Authentication handled in SignInWithAppleButton
                                    dismiss()
                                case .failure(let error):
                                    AppLog.warning(AppLog.auth, "Inline sign-in failed: \(error.localizedDescription)")
                                    isAuthenticating = false
                                }
                            }
                        )
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 56)
                        .cornerRadius(28)
                        .padding(.horizontal, 40)
                    }
                    
                    // Skip button
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Continue as Guest")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
    }
}

// MARK: - Feature Lock Badge

struct FeatureLockBadge: View {
    let isLocked: Bool
    
    var body: some View {
        if isLocked {
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundColor(.white)
                .padding(4)
                .background(
                    Circle()
                        .fill(Color.red)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
        }
    }
}
