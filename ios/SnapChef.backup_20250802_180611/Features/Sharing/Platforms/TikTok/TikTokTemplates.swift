//
//  TikTokTemplates.swift
//  SnapChef
//
//  Created on 02/03/2025
//

import SwiftUI

// MARK: - TikTok Template
enum TikTokTemplate: String, CaseIterable {
    case beforeAfterReveal = "Before/After Reveal"
    case quickRecipe = "60-Second Recipe"
    case ingredients360 = "360° Ingredients"
    case timelapse = "Cooking Timelapse"
    case splitScreen = "Split Screen"
    
    var name: String {
        return rawValue
    }
    
    var description: String {
        switch self {
        case .beforeAfterReveal:
            return "Dramatic reveal from ingredients to finished dish"
        case .quickRecipe:
            return "Fast-paced recipe tutorial with text overlay"
        case .ingredients360:
            return "Rotating view of all ingredients with recipe name"
        case .timelapse:
            return "Speed up cooking process with music sync"
        case .splitScreen:
            return "Side-by-side comparison of process and result"
        }
    }
    
    var icon: String {
        switch self {
        case .beforeAfterReveal: return "arrow.left.arrow.right"
        case .quickRecipe: return "timer"
        case .ingredients360: return "rotate.3d"
        case .timelapse: return "forward.fill"
        case .splitScreen: return "rectangle.split.2x1"
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .beforeAfterReveal:
            return [Color(hex: "#FF0050"), Color(hex: "#00F2EA")]
        case .quickRecipe:
            return [Color(hex: "#F77737"), Color(hex: "#F9A825")]
        case .ingredients360:
            return [Color(hex: "#667eea"), Color(hex: "#764ba2")]
        case .timelapse:
            return [Color(hex: "#43e97b"), Color(hex: "#38f9d7")]
        case .splitScreen:
            return [Color(hex: "#fa709a"), Color(hex: "#fee140")]
        }
    }
    
    @ViewBuilder
    func previewContent(_ content: ShareContent) -> some View {
        switch self {
        case .beforeAfterReveal:
            BeforeAfterPreview(content: content)
        case .quickRecipe:
            QuickRecipePreview(content: content)
        case .ingredients360:
            Ingredients360Preview(content: content)
        case .timelapse:
            TimelapsePreview(content: content)
        case .splitScreen:
            SplitScreenPreview(content: content)
        }
    }
}

// MARK: - Template Previews

struct BeforeAfterPreview: View {
    let content: ShareContent
    @State private var showAfter = false
    
    var body: some View {
        ZStack {
            // Before state
            if !showAfter {
                VStack(spacing: 20) {
                    Text("BEFORE")
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(.white)
                    
                    Image(systemName: "refrigerator")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.8))
                }
                .transition(.opacity)
            }
            
            // After state
            if showAfter {
                VStack(spacing: 20) {
                    Text("AFTER")
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(.white)
                    
                    if case .recipe(let recipe) = content.type {
                        Text(recipe.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1).delay(1).repeatForever(autoreverses: true)) {
                showAfter.toggle()
            }
        }
    }
}

struct QuickRecipePreview: View {
    let content: ShareContent
    @State private var currentStep = 0
    let steps = ["📸 Snap", "🤖 AI Magic", "🍳 Cook", "😋 Enjoy!"]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("60-SECOND RECIPE")
                .font(.system(size: 18, weight: .black))
                .foregroundColor(.white)
            
            Text(steps[currentStep])
                .font(.system(size: 32))
                .transition(.slide)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                withAnimation {
                    currentStep = (currentStep + 1) % steps.count
                }
            }
        }
    }
}

struct Ingredients360Preview: View {
    let content: ShareContent
    @State private var rotation: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("360° VIEW")
                .font(.system(size: 18, weight: .black))
                .foregroundColor(.white)
            
            Image(systemName: "cube.transparent")
                .font(.system(size: 60))
                .foregroundColor(.white)
                .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

struct TimelapsePreview: View {
    let content: ShareContent
    @State private var progress: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("TIMELAPSE")
                .font(.system(size: 18, weight: .black))
                .foregroundColor(.white)
            
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.white, lineWidth: 8)
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: "play.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                progress = 1
            }
        }
    }
}

struct SplitScreenPreview: View {
    let content: ShareContent
    
    var body: some View {
        HStack(spacing: 0) {
            // Left side
            VStack {
                Text("PROCESS")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Image(systemName: "hands.sparkles")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.3))
            
            Rectangle()
                .fill(Color.white)
                .frame(width: 2)
            
            // Right side
            VStack {
                Text("RESULT")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Trending Audio
struct TrendingAudio: Identifiable {
    let id = UUID()
    let name: String
    let artist: String
    let useCount: Int
    
    static let suggestions = [
        TrendingAudio(name: "Cooking Dance", artist: "TikTok Sounds", useCount: 234),
        TrendingAudio(name: "Recipe Reveal", artist: "FoodTok", useCount: 189),
        TrendingAudio(name: "Quick & Easy", artist: "Chef Vibes", useCount: 156),
        TrendingAudio(name: "Kitchen Magic", artist: "Trending Audio", useCount: 142),
        TrendingAudio(name: "Yummy Time", artist: "Food Beats", useCount: 98)
    ]
}