//
//  AuthPromptCard.swift
//  SnapChef
//
//  Legacy compatibility wrappers.
//  Auth UI now routes through ProgressiveAuthPrompt for a single prompt stack.
//

import SwiftUI

@available(*, deprecated, message: "Use ProgressiveAuthPrompt directly.")
struct AuthPromptCard: View {
    @Binding var isPresented: Bool
    let prompt: AuthPromptManager.AuthPrompt
    let onSignIn: () -> Void
    let onDismiss: (AuthPromptManager.DismissAction) -> Void

    var body: some View {
        ProgressiveAuthPrompt(overrideContext: mappedContext)
            .onDisappear {
                isPresented = false
            }
    }

    private var mappedContext: AuthPromptTrigger.TriggerContext {
        legacyTriggerContext(from: prompt.context)
    }
}

@available(*, deprecated, message: "Use ProgressiveAuthPrompt directly.")
struct AuthPromptOverlay: View {
    @StateObject private var authPromptManager = AuthPromptManager.shared
    @State private var isPresented = true

    var body: some View {
        Group {
            if let prompt = authPromptManager.currentPrompt {
                AuthPromptCard(
                    isPresented: $isPresented,
                    prompt: prompt,
                    onSignIn: { },
                    onDismiss: { _ in }
                )
                .id(prompt.id)
                .onDisappear {
                    authPromptManager.currentPrompt = nil
                    authPromptManager.isShowingPrompt = false
                    authPromptManager.shouldShowPrompt = false
                }
            } else {
                EmptyView()
            }
        }
        .onAppear {
            isPresented = true
        }
    }
}

private func legacyTriggerContext(from context: AuthPromptManager.PromptContext) -> AuthPromptTrigger.TriggerContext {
    switch context {
    case .firstRecipeSuccess:
        return .firstRecipeSuccess
    case .viralContentCreated:
        return .viralContentCreated
    case .dailyLimitReached:
        return .dailyLimitReached
    case .challengeInterest:
        return .challengeInterest
    case .socialExploration:
        return .socialFeatureExplored
    case .shareIntent:
        return .shareAttempt
    case .reengagement:
        return .returningUser
    case .featureDiscovery, .iCloudSetup:
        return .socialFeatureExplored
    }
}
