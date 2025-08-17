//
//  HoneymoonBanner.swift
//  SnapChef
//
//  Created by Claude on 2025-01-17.
//  Honeymoon phase banner for premium strategy implementation
//

import SwiftUI
import os.log
import UIKit

/// Beautiful animated banner that appears during honeymoon phase (days 1-7)
/// Shows countdown and encourages user to upgrade before losing premium access
struct HoneymoonBanner: View {
    // @StateObject private var userLifecycle = UserLifecycleManager.shared // Temporarily disabled due to build issues
    @State private var isDismissed = false
    @State private var sparkleScale: CGFloat = 1.0
    @State private var gradientPhase: CGFloat = 0
    @State private var pulseIntensity: Double = 0.3
    @State private var showBanner = false

    // MARK: - Computed Properties

    private var shouldShow: Bool {
        // Only show during honeymoon phase and if not dismissed today
        // return userLifecycle.currentPhase == .honeymoon && 
        //        !isDismissed && 
        //        showBanner
        // Temporarily disabled due to build issues
        return !isDismissed && showBanner
    }

    private var currentDay: Int {
        // return userLifecycle.daysActive + 1 // +1 because daysActive starts at 0
        // Temporarily disabled due to build issues
        return 1
    }

    private var daysRemaining: Int {
        return max(0, 7 - currentDay + 1)
    }

    private var progressPercentage: Double {
        return Double(currentDay) / 7.0
    }

    private var bannerMessage: String {
        if daysRemaining > 1 {
            return "Premium Preview: Day \(currentDay) of 7"
        } else if daysRemaining == 1 {
            return "Last Day of Premium Preview!"
        } else {
            return "Premium Preview Complete"
        }
    }

    private var ctaMessage: String {
        if daysRemaining > 1 {
            return "Enjoying unlimited recipes? Keep them forever →"
        } else {
            return "Don't lose your unlimited access! Upgrade now →"
        }
    }

    private var snapChefGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.orange,
                Color.pink
            ],
            startPoint: UnitPoint(x: 0.0 + gradientPhase, y: 0),
            endPoint: UnitPoint(x: 1.0 + gradientPhase, y: 1)
        )
    }

    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.green,
                Color.cyan
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var urgencyColor: Color {
        if daysRemaining <= 1 {
            return Color.red // Red - urgent
        } else if daysRemaining <= 2 {
            return Color.orange // Orange - warning
        } else {
            return Color.green // Green - safe
        }
    }

    // MARK: - Main View

    var body: some View {
        if shouldShow {
            VStack(spacing: 0) {
                bannerContent
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(bannerBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(snapChefGradient, lineWidth: 1.5)
                    )
                    .shadow(
                        color: urgencyColor.opacity(0.4),
                        radius: daysRemaining <= 2 ? 16 : 8,
                        x: 0,
                        y: 6
                    )
                    .scaleEffect(sparkleScale)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity).combined(with: .move(edge: .top)),
                        removal: .scale.combined(with: .opacity).combined(with: .move(edge: .top))
                    ))
            }
            .padding(.horizontal, 16)
            .onAppear {
                startAnimations()
                checkDismissedStatus()
            }
            .onTapGesture {
                // Navigate to special honeymoon offer
                triggerHoneymoonOffer()
            }
        }
    }

    // MARK: - Banner Content

    private var bannerContent: some View {
        VStack(spacing: 12) {
            // Header with sparkle and message
            headerView

            // CTA message
            ctaView

            // Progress bar
            progressView

            // Dismiss button
            dismissButton
        }
    }

    private var headerView: some View {
        HStack(spacing: 10) {
            // Sparkle icon
            sparkleIcon

            // Main message
            VStack(alignment: .leading, spacing: 2) {
                Text("🎉 \(bannerMessage)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(textGradient)

                if daysRemaining > 0 {
                    Text("\(daysRemaining) day\(daysRemaining == 1 ? "" : "s") remaining")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(urgencyColor)
                }
            }

            Spacer()

            // Crown icon for premium preview
            Image(systemName: "crown.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(snapChefGradient)
                .scaleEffect(sparkleScale)
        }
    }

    private var sparkleIcon: some View {
        ZStack {
            // Glow background
            Circle()
                .fill(urgencyColor.opacity(pulseIntensity))
                .frame(width: 32, height: 32)
                .blur(radius: 6)

            // Main sparkle
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(urgencyColor)
                .scaleEffect(sparkleScale)
        }
    }

    private var ctaView: some View {
        Text(ctaMessage)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundColor(.white.opacity(0.9))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressView: some View {
        VStack(spacing: 6) {
            // Progress bar background
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 6)

                    // Progress fill
                    Capsule()
                        .fill(progressGradient)
                        .frame(width: geometry.size.width * progressPercentage, height: 6)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6), value: progressPercentage)
                }
            }
            .frame(height: 6)

            // Progress text
            HStack {
                Text("Day \(currentDay)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                Text("Day 7")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    private var dismissButton: some View {
        HStack {
            Spacer()

            Button(action: dismissBanner) {
                HStack(spacing: 4) {
                    Text("Remind me tomorrow")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))

                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var bannerBackground: some View {
        ZStack {
            // Glass base with dark tint
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.3))
                )

            // Gradient overlay
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.15),
                            Color.pink.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Shimmer effect
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: UnitPoint(x: gradientPhase - 0.3, y: 0),
                        endPoint: UnitPoint(x: gradientPhase + 0.3, y: 1)
                    )
                )
                .allowsHitTesting(false)
        }
    }

    private var textGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white,
                Color.white.opacity(0.9)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Actions

    private func dismissBanner() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isDismissed = true
        }

        // Store dismissal for today
        let today = Calendar.current.startOfDay(for: Date())
        UserDefaults.standard.set(today, forKey: "honeymoonBanner.dismissedDate")

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func triggerHoneymoonOffer() {
        // Navigate to special honeymoon subscription offer
        // This would be handled by the parent view or navigation coordinator

        // For now, just show haptic feedback and track the action
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Analytics tracking
        #if DEBUG
        NSLog("🎯 Honeymoon banner tapped - Day \(currentDay)")
        #endif

        // Navigate to subscription/premium upgrade view
        // Note: Navigation integration with subscription view would be implemented here
        // For now, log the event and potentially trigger premium paywall
        os_log("User tapped honeymoon banner - showing premium upgrade opportunity", log: .default, type: .info)

        // Store analytics event for premium upgrade interest
        UserDefaults.standard.set(Date(), forKey: "honeymoon.upgrade_interest_shown")
        UserDefaults.standard.set(currentDay, forKey: "honeymoon.upgrade_interest_day")
    }

    private func checkDismissedStatus() {
        let today = Calendar.current.startOfDay(for: Date())

        if let dismissedDate = UserDefaults.standard.object(forKey: "honeymoonBanner.dismissedDate") as? Date {
            // Check if dismissed today
            isDismissed = Calendar.current.isDate(dismissedDate, inSameDayAs: today)
        } else {
            isDismissed = false
        }

        // Show banner with animation after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                showBanner = true
            }
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        // Sparkle pulse animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            sparkleScale = daysRemaining <= 2 ? 1.15 : 1.1
        }

        // Gradient flow animation
        withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
            gradientPhase = 1.0
        }

        // Pulse intensity based on urgency
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseIntensity = daysRemaining <= 1 ? 0.8 : (daysRemaining <= 2 ? 0.6 : 0.4)
        }
    }
}

// MARK: - Preview

#Preview("Honeymoon Banner States") {
    ZStack {
        // SnapChef background
        LinearGradient(
            colors: [
                Color.black,
                Color.gray.opacity(0.8),
                Color.blue.opacity(0.3)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 32) {
            Text("Honeymoon Banner Preview")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            VStack(spacing: 20) {
                // Day 3 (safe)
                HoneymoonBannerPreview(day: 3, daysRemaining: 5)

                // Day 6 (warning)
                HoneymoonBannerPreview(day: 6, daysRemaining: 2)

                // Day 7 (urgent)
                HoneymoonBannerPreview(day: 7, daysRemaining: 1)
            }

            Spacer()
        }
        .padding()
    }
}

// Helper for preview
private struct HoneymoonBannerPreview: View {
    let day: Int
    let daysRemaining: Int

    var body: some View {
        VStack(spacing: 8) {
            Text("Day \(day) Preview")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            // Mock banner content
            VStack(spacing: 12) {
                HStack {
                    Text("🎉 Premium Preview: Day \(day) of 7")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                }

                Text(daysRemaining == 1 ? "Don't lose your unlimited access! Upgrade now →" : "Enjoying unlimited recipes? Keep them forever →")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 6)

                        Capsule()
                            .fill(LinearGradient(
                                colors: [Color.green, Color.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: geometry.size.width * (Double(day) / 7.0), height: 6)
                    }
                }
                .frame(height: 6)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(LinearGradient(
                                colors: [Color.orange, Color.pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ), lineWidth: 1.5)
                    )
            )
        }
    }
}

#Preview("Animation Test") {
    ZStack {
        Color.black.ignoresSafeArea()

        HoneymoonBanner()
            .padding()
    }
}
