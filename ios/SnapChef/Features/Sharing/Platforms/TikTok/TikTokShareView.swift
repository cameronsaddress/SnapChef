// REPLACE ENTIRE FILE: TikTokShareView.swift

import SwiftUI
import AVKit
import Photos

struct TikTokShareView: View {
    let content: ShareContent
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine = ViralVideoEngine()
    private let template: ViralTemplate = .kineticTextSteps
    @State private var isGenerating = false
    @State private var videoURL: URL?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.black, .black.opacity(0.9)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        header
                        hashtagChips
                        Button(action: generate) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14).fill(LinearGradient(colors: [Color(red:1,green:0,blue:0.31), Color(red:0,green:0.95,blue:0.92)], startPoint: .leading, endPoint: .trailing)).frame(height: 56)
                                if isGenerating {
                                    HStack(spacing: 10) {
                                        ProgressView()
                                        Text(getProgressText())
                                    }.foregroundColor(.white)
                                } else {
                                    Text("Generate & Share to TikTok").bold().foregroundColor(.white)
                                }
                            }
                        }
                        .disabled(isGenerating)
                        .padding(.bottom, 40)
                    }.padding(.horizontal, 20)
                }
            }
            .navigationTitle("TikTok Video")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() }.foregroundColor(.white) }
            }
        }
        .alert("Error", isPresented: .constant(error != nil)) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }

    private var hashtagChips: some View {
        let tags = ["SnapChef","FoodTok","FridgeHack","QuickDinner","30MinuteMeals","HomeChef","MealPrep"]
        return VStack(alignment: .leading, spacing: 10) {
            Text("Recommended Hashtags").font(.headline).foregroundColor(.white)
            Wrap(tags, spacing: 8) { Text("#\($0)").padding(.horizontal,10).padding(.vertical,6).background(Color.white.opacity(0.08)).cornerRadius(10).foregroundColor(.white) }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) { Image(systemName:"music.note").font(.system(size: 22, weight: .bold)); Text("TikTok Video Generator").font(.system(size: 22, weight: .bold)) }.foregroundColor(.white)
            Text("Auto-shares to TikTok after generation").foregroundColor(.gray).font(.subheadline)
        }.padding(.top, 18)
    }
    
    private func getProgressText() -> String {
        let phase = engine.currentProgress.phase.rawValue.capitalized
        if phase.contains("Rendering") {
            return "Rendering Video..."
        } else if videoURL != nil {
            return "Sharing to TikTok..."
        } else {
            return phase
        }
    }

    private func generate() {
        guard let inputs = content.toRenderInputs() else { return }
        let (recipe, media) = inputs
        isGenerating = true
        Task {
            do {
                let url = try await engine.render(template: template, recipe: recipe, media: media) { _ in }
                self.videoURL = url
                // Automatically share to TikTok after generation
                await shareToTikTokAutomatically(url: url)
            } catch { 
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isGenerating = false
                }
            }
        }
    }

    @MainActor
    private func shareToTikTokAutomatically(url: URL) async {
        // Request photo permission first
        let hasPermission = await withCheckedContinuation { continuation in
            ViralVideoExporter.requestPhotoPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        
        guard hasPermission else {
            self.error = "Photo access denied"
            self.isGenerating = false
            return
        }
        
        // Save video to Photos
        let saveResult = await withCheckedContinuation { continuation in
            ViralVideoExporter.saveToPhotos(videoURL: url) { result in
                continuation.resume(returning: result)
            }
        }
        
        switch saveResult {
        case .success(let identifier):
            // Share to TikTok with enhanced caption
            let recipeTitle = {
                if case .recipe(let recipe) = content.type {
                    return recipe.name
                }
                return "Amazing Recipe"
            }()
            let caption = "🔥 FRIDGE TO TABLE CHALLENGE 🔥\n\(recipeTitle) in 30 seconds!\n#SnapChef #FoodTok #FridgeHack #QuickMeals"
            
            let shareResult = await withCheckedContinuation { continuation in
                ViralVideoExporter.shareToTikTok(localIdentifiers: [identifier], caption: caption) { result in
                    continuation.resume(returning: result)
                }
            }
            
            switch shareResult {
            case .success:
                // Success - TikTok app should now be open
                self.isGenerating = false
                // Optionally dismiss the view since TikTok is now open
                dismiss()
            case .failure(let error):
                self.error = error.localizedDescription
                self.isGenerating = false
            }
            
        case .failure(let error):
            self.error = error.localizedDescription
            self.isGenerating = false
        }
    }
}

// Simple wrapping layout using LazyVGrid for Swift 6 compatibility
struct Wrap<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let content: (Data.Element) -> Content
    
    init(_ d: Data, spacing: CGFloat = 8, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        data = d
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: spacing)], spacing: spacing) {
            ForEach(Array(data), id: \.self) { item in
                content(item)
            }
        }
        .frame(maxHeight: 120)
    }
}