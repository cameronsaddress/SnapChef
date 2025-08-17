//
//  PolishUIComponents.swift
//  SnapChef
//
//  Created on 12/01/2025
//  Enhanced UI components with polish features: progress indicators, haptic feedback, smooth transitions
//

import UIKit
import SwiftUI
import Combine

// MARK: - Enhanced Progress View with Haptic Feedback

/// Enhanced progress view with smooth animations and haptic feedback
@available(iOS 14.0, *)
public struct EnhancedProgressView: View {
    @Binding var progress: RenderProgress
    @State private var isAnimating = false
    @State private var lastPhase: RenderPhase = .planning
    @State private var smoothProgress: Double = 0.0

    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let selectionFeedback = UISelectionFeedbackGenerator()

    public init(progress: Binding<RenderProgress>) {
        self._progress = progress
    }

    public var body: some View {
        VStack(spacing: 24) {
            // Phase indicator with smooth transitions
            Text(progress.phase.rawValue)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(progress.phase.rawValue)

            // Enhanced progress ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: smoothProgress)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: smoothProgress)

                VStack {
                    Text("\(Int(smoothProgress * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)

                    if let memoryUsage = progress.memoryUsage {
                        let memoryMB = Double(memoryUsage) / 1_024.0 / 1_024.0
                        Text("\(String(format: "%.1f", memoryMB)) MB")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Phase timeline
            PhaseTimelineView(currentPhase: progress.phase)

            // Performance indicators
            if let memoryUsage = progress.memoryUsage {
                PerformanceIndicatorsView(memoryUsage: memoryUsage)
            }
        }
        .padding()
        .onChange(of: progress.progress) { newProgress in
            withAnimation(.easeInOut(duration: 0.3)) {
                smoothProgress = newProgress
            }
        }
        .onChange(of: progress.phase) { newPhase in
            if newPhase != lastPhase {
                triggerPhaseHaptic(newPhase)
                lastPhase = newPhase
            }
        }
        .onAppear {
            prepareHapticFeedback()
        }
    }

    private func triggerPhaseHaptic(_ phase: RenderPhase) {
        switch phase {
        case .planning:
            selectionFeedback.selectionChanged()
        case .preparingAssets:
            impactFeedback.impactOccurred(intensity: 0.5)
        case .renderingFrames:
            impactFeedback.impactOccurred(intensity: 0.7)
        case .compositing:
            impactFeedback.impactOccurred(intensity: 0.6)
        case .addingOverlays:
            impactFeedback.impactOccurred(intensity: 0.8)
        case .encoding:
            impactFeedback.impactOccurred(intensity: 0.9)
        case .finalizing:
            impactFeedback.impactOccurred(intensity: 1.0)
        case .complete:
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
        }
    }

    private func prepareHapticFeedback() {
        impactFeedback.prepare()
        selectionFeedback.prepare()
    }
}

// MARK: - Phase Timeline View

@available(iOS 14.0, *)
struct PhaseTimelineView: View {
    let currentPhase: RenderPhase
    private let phases = RenderPhase.allCases

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                ZStack {
                    Circle()
                        .fill(phaseColor(for: phase))
                        .frame(width: 12, height: 12)

                    if phase == currentPhase {
                        Circle()
                            .stroke(Color.blue, lineWidth: 2)
                            .frame(width: 16, height: 16)
                            .scaleEffect(isCurrentPhase(phase) ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: currentPhase)
                    }
                }

                if index < phases.count - 1 {
                    Rectangle()
                        .fill(index < phaseIndex(currentPhase) ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 20, height: 2)
                        .animation(.easeInOut(duration: 0.3), value: currentPhase)
                }
            }
        }
        .padding(.horizontal)
    }

    private func phaseColor(for phase: RenderPhase) -> Color {
        let currentIndex = phaseIndex(currentPhase)
        let phaseIdx = phaseIndex(phase)

        if phaseIdx < currentIndex {
            return .blue
        } else if phaseIdx == currentIndex {
            return .blue
        } else {
            return .gray.opacity(0.3)
        }
    }

    private func isCurrentPhase(_ phase: RenderPhase) -> Bool {
        return phase == currentPhase
    }

    private func phaseIndex(_ phase: RenderPhase) -> Int {
        return phases.firstIndex(of: phase) ?? 0
    }
}

// MARK: - Performance Indicators View

@available(iOS 14.0, *)
struct PerformanceIndicatorsView: View {
    let memoryUsage: UInt64

    private var memoryMB: Double {
        return Double(memoryUsage) / 1_024.0 / 1_024.0
    }

    private var memoryPercentage: Double {
        return min(Double(memoryUsage) / Double(ExportSettings.maxMemoryUsage), 1.0)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "memorychip")
                    .foregroundColor(memoryColor)
                Text("Memory")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(String(format: "%.1f", memoryMB)) MB")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(memoryColor)
            }

            ProgressView(value: memoryPercentage)
                .progressViewStyle(LinearProgressViewStyle(tint: memoryColor))
                .animation(.easeInOut(duration: 0.3), value: memoryPercentage)
        }
        .padding(.horizontal)
    }

    private var memoryColor: Color {
        if memoryPercentage > 0.9 {
            return .red
        } else if memoryPercentage > 0.7 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - Loading States View

@available(iOS 14.0, *)
public struct LoadingStatesView: View {
    @State private var isAnimating = false
    @State private var animationOffset: CGFloat = 0

    let message: String
    let style: LoadingStyle

    public enum LoadingStyle {
        case subtle
        case prominent
        case minimal
    }

    public init(message: String = "Processing...", style: LoadingStyle = .prominent) {
        self.message = message
        self.style = style
    }

    public var body: some View {
        VStack(spacing: 16) {
            switch style {
            case .subtle:
                subtleLoader
            case .prominent:
                prominentLoader
            case .minimal:
                minimalLoader
            }

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .onAppear {
            startAnimation()
        }
    }

    private var subtleLoader: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
    }

    private var prominentLoader: some View {
        ZStack {
            Circle()
                .stroke(Color.blue.opacity(0.3), lineWidth: 4)
                .frame(width: 60, height: 60)

            Circle()
                .trim(from: 0, to: 0.3)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 60, height: 60)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(
                    Animation.linear(duration: 1.0).repeatForever(autoreverses: false),
                    value: isAnimating
                )
        }
    }

    private var minimalLoader: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            .scaleEffect(0.8)
    }

    private func startAnimation() {
        isAnimating = true
    }
}

// MARK: - Smooth Transition Container

@available(iOS 14.0, *)
public struct SmoothTransitionContainer<Content: View>: View {
    @State private var isVisible = false

    let content: Content
    let transitionStyle: TransitionStyle

    public enum TransitionStyle {
        case fade
        case slide
        case scale
        case spring
    }

    public init(transitionStyle: TransitionStyle = .spring, @ViewBuilder content: () -> Content) {
        self.transitionStyle = transitionStyle
        self.content = content()
    }

    public var body: some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : (transitionStyle == .scale ? 0.8 : 1))
            .offset(y: isVisible ? 0 : (transitionStyle == .slide ? 20 : 0))
            .animation(animationForStyle(), value: isVisible)
            .onAppear {
                withAnimation {
                    isVisible = true
                }
            }
    }

    private func animationForStyle() -> Animation {
        switch transitionStyle {
        case .fade:
            return .easeInOut(duration: 0.3)
        case .slide:
            return .easeOut(duration: 0.4)
        case .scale:
            return .easeInOut(duration: 0.3)
        case .spring:
            return .spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)
        }
    }
}

// MARK: - Error Recovery View

@available(iOS 14.0, *)
public struct ErrorRecoveryView: View {
    let error: Error
    let retryAction: () -> Void
    let cancelAction: () -> Void

    @State private var isRetrying = false

    public init(
        error: Error,
        retryAction: @escaping () -> Void,
        cancelAction: @escaping () -> Void
    ) {
        self.error = error
        self.retryAction = retryAction
        self.cancelAction = cancelAction
    }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Something went wrong")
                .font(.headline)
                .fontWeight(.semibold)

            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 16) {
                Button("Cancel") {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    cancelAction()
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("Retry") {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()

                    isRetrying = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        retryAction()
                        isRetrying = false
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isRetrying)
            }
        }
        .padding()
    }
}

// MARK: - Button Styles

@available(iOS 14.0, *)
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

@available(iOS 14.0, *)
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.2))
            .foregroundColor(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Haptic Feedback Manager

public final class HapticFeedbackManager: @unchecked Sendable {
    public static let shared = HapticFeedbackManager()

    private var impactLight: UIImpactFeedbackGenerator?
    private var impactMedium: UIImpactFeedbackGenerator?
    private var impactHeavy: UIImpactFeedbackGenerator?
    private var selection: UISelectionFeedbackGenerator?
    private var notification: UINotificationFeedbackGenerator?

    private init() {
        // Initialize on first use to avoid MainActor issues
    }

    @MainActor
    private func ensureGeneratorsInitialized() {
        if impactLight == nil {
            impactLight = UIImpactFeedbackGenerator(style: .light)
            impactMedium = UIImpactFeedbackGenerator(style: .medium)
            impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
            selection = UISelectionFeedbackGenerator()
            notification = UINotificationFeedbackGenerator()
        }
    }

    @MainActor
    public func prepareHaptics() {
        ensureGeneratorsInitialized()
        impactLight?.prepare()
        impactMedium?.prepare()
        impactHeavy?.prepare()
        selection?.prepare()
    }

    @MainActor
    public func impact(_ intensity: UIImpactFeedbackGenerator.FeedbackStyle) {
        ensureGeneratorsInitialized()
        switch intensity {
        case .light:
            impactLight?.impactOccurred()
        case .medium:
            impactMedium?.impactOccurred()
        case .heavy:
            impactHeavy?.impactOccurred()
        @unknown default:
            impactMedium?.impactOccurred()
        }
    }

    @MainActor
    public func selectionFeedback() {
        ensureGeneratorsInitialized()
        selection?.selectionChanged()
    }

    @MainActor
    public func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        ensureGeneratorsInitialized()
        notification?.notificationOccurred(type)
    }

    @MainActor
    public func renderPhaseTransition(_ phase: RenderPhase) {
        switch phase {
        case .planning:
            selectionFeedback()
        case .preparingAssets:
            impact(.light)
        case .renderingFrames:
            impact(.medium)
        case .compositing:
            impact(.medium)
        case .addingOverlays:
            impact(.medium)
        case .encoding:
            impact(.heavy)
        case .finalizing:
            impact(.heavy)
        case .complete:
            notification(.success)
        }
    }
}
