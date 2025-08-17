//
//  UnifiedAuthIntegrationExample.swift
//  SnapChef
//
//  Example showing how to integrate UnifiedAuthManager into existing views
//  This demonstrates the migration from multiple auth systems to the unified approach
//

import SwiftUI

// MARK: - Example: Migrating CameraView Integration

/// Example showing how to migrate CameraView to use UnifiedAuthManager
struct CameraViewUnifiedAuthExample: View {
    @StateObject private var unifiedAuth = UnifiedAuthManager.shared
    @EnvironmentObject var appState: AppState
    
    @State private var showingResults = false
    @State private var generatedRecipes: [Recipe] = []
    @State private var showProgressivePrompt = false
    @State private var progressiveContext: SimpleProgressivePrompt.PromptContext = .firstRecipe
    
    var body: some View {
        VStack {
            // Camera UI here...
            
            Button("Capture Recipe") {
                captureAndGenerateRecipe()
            }
            .disabled(!canCreateRecipe())
            
            if !canCreateRecipe() {
                Button("Upgrade for More Recipes") {
                    showAuthForPremium()
                }
            }
        }
        .sheet(isPresented: $unifiedAuth.showAuthSheet) {
            UnifiedAuthView(requiredFor: .premiumFeatures)
        }
        .sheet(isPresented: $showProgressivePrompt) {
            SimpleProgressivePrompt(context: progressiveContext)
        }
        .onChange(of: unifiedAuth.shouldShowProgressivePrompt) { shouldShow in
            if shouldShow {
                showProgressivePrompt = true
                // Reset the trigger
                unifiedAuth.shouldShowProgressivePrompt = false
            }
        }
    }
    
    private func captureAndGenerateRecipe() {
        // Simulate recipe generation
        let newRecipe = Recipe.example
        generatedRecipes.append(newRecipe)
        
        // Track the recipe creation for progressive auth
        unifiedAuth.trackAnonymousAction(.recipeCreated)
        
        // Show results
        showingResults = true
    }
    
    private func canCreateRecipe() -> Bool {
        // Check if user has reached limits
        return appState.getRemainingRecipes() > 0
    }
    
    private func showAuthForPremium() {
        unifiedAuth.promptAuthForFeature(.premiumFeatures) {
            // Completion handler - user authenticated
            print("User authenticated for premium features")
        }
    }
}

// MARK: - Example: Challenge Hub Integration

/// Example showing how to integrate challenges with unified auth
struct ChallengeHubUnifiedAuthExample: View {
    @StateObject private var unifiedAuth = UnifiedAuthManager.shared
    
    var body: some View {
        VStack {
            if unifiedAuth.isAuthenticated {
                // Show authenticated challenge content
                Text("Welcome, \(unifiedAuth.currentUser?.displayName ?? "Chef")!")
                // Challenge list here...
            } else {
                // Show unauthenticated state
                VStack(spacing: 16) {
                    Text("Join Challenges")
                        .font(.title)
                    
                    Text("Sign in to participate in cooking challenges")
                        .foregroundColor(.secondary)
                    
                    Button("Sign In") {
                        showAuthForChallenges()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .sheet(isPresented: $unifiedAuth.showAuthSheet) {
            UnifiedAuthView(requiredFor: .challenges)
        }
        .onAppear {
            // Track that user explored challenges
            unifiedAuth.trackAnonymousAction(.challengeViewed)
        }
    }
    
    private func showAuthForChallenges() {
        unifiedAuth.promptAuthForFeature(.challenges) {
            // User authenticated - can now join challenges
            print("User can now join challenges")
        }
    }
}

// MARK: - Example: Social Features Integration

/// Example showing social features with unified auth
struct SocialFeaturesUnifiedAuthExample: View {
    @StateObject private var unifiedAuth = UnifiedAuthManager.shared
    
    var body: some View {
        VStack {
            if unifiedAuth.isAuthenticated {
                // Show authenticated social content
                HStack {
                    if let user = unifiedAuth.currentUser {
                        VStack(alignment: .leading) {
                            Text(user.displayName)
                                .font(.headline)
                            
                            HStack {
                                Text("\(user.followerCount) followers")
                                Text("\(user.followingCount) following")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if let tikTokUser = unifiedAuth.tikTokUser {
                        VStack {
                            Text("TikTok Connected")
                                .font(.caption)
                            Text("@\(tikTokUser.displayName)")
                                .font(.caption2)
                        }
                    }
                }
                
                // Social content here...
                
            } else {
                // Unauthenticated social preview
                VStack(spacing: 20) {
                    Text("Connect with Chefs")
                        .font(.title)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "person.3.fill")
                            Text("Follow your favorite chefs")
                        }
                        
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share your recipe creations")
                        }
                        
                        HStack {
                            Image(systemName: "music.note")
                            Text("Connect your TikTok")
                        }
                    }
                    
                    Button("Join the Community") {
                        showAuthForSocial()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .sheet(isPresented: $unifiedAuth.showAuthSheet) {
            UnifiedAuthView(requiredFor: .socialSharing)
        }
        .onAppear {
            // Track social exploration
            unifiedAuth.trackAnonymousAction(.socialExplored)
        }
    }
    
    private func showAuthForSocial() {
        unifiedAuth.promptAuthForFeature(.socialSharing) {
            print("User authenticated for social features")
        }
    }
}

// MARK: - Example: Video Sharing Integration

/// Example showing TikTok video sharing with unified auth
struct VideoSharingUnifiedAuthExample: View {
    @StateObject private var unifiedAuth = UnifiedAuthManager.shared
    
    @State private var showingVideoGenerator = false
    @State private var showingTikTokAuth = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Share Your Recipe Video")
                .font(.title)
            
            if unifiedAuth.tikTokUser != nil {
                // TikTok connected
                VStack {
                    Text("✅ TikTok Connected")
                        .foregroundColor(.green)
                    
                    Button("Create & Share Video") {
                        generateAndShareVideo()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                // TikTok not connected
                VStack {
                    Text("Connect TikTok to share videos")
                        .foregroundColor(.secondary)
                    
                    Button("Connect TikTok") {
                        connectTikTok()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .sheet(isPresented: $showingVideoGenerator) {
            // Video generator view here
            Text("Video Generator")
        }
    }
    
    private func connectTikTok() {
        Task {
            do {
                try await unifiedAuth.signInWithTikTok()
                print("TikTok connected successfully")
            } catch {
                print("TikTok connection failed: \(error)")
            }
        }
    }
    
    private func generateAndShareVideo() {
        // Track video generation
        unifiedAuth.trackAnonymousAction(.videoGenerated)
        
        // Show video generator
        showingVideoGenerator = true
    }
}

// MARK: - Example: Migration Helper Extension

extension View {
    /// Helper to easily migrate from CloudKitAuthManager to UnifiedAuthManager
    func withUnifiedAuth() -> some View {
        self.environmentObject(UnifiedAuthManager.shared)
    }
    
    /// Helper to show auth for a specific feature
    func requireAuth(for feature: AuthRequiredFeature, 
                    showSheet: Binding<Bool>,
                    completion: (() -> Void)? = nil) -> some View {
        self.modifier(AuthRequiredModifier(feature: feature, showSheet: showSheet, completion: completion))
    }
}

struct AuthRequiredModifier: ViewModifier {
    let feature: AuthRequiredFeature
    @Binding var showSheet: Bool
    let completion: (() -> Void)?
    
    @StateObject private var unifiedAuth = UnifiedAuthManager.shared
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showSheet) {
                UnifiedAuthView(requiredFor: feature)
            }
            .onAppear {
                if unifiedAuth.isAuthRequiredFor(feature: feature) {
                    unifiedAuth.authCompletionHandler = completion
                }
            }
    }
}

#Preview {
    VStack(spacing: 20) {
        CameraViewUnifiedAuthExample()
        ChallengeHubUnifiedAuthExample()
        SocialFeaturesUnifiedAuthExample()
        VideoSharingUnifiedAuthExample()
    }
    .environmentObject(AppState())
}
