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
    @State private var showPreview = false
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
                                        Text(engine.currentProgress.phase.rawValue.capitalized)
                                    }.foregroundColor(.white)
                                } else {
                                    Text("Generate TikTok Video").bold().foregroundColor(.white)
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    if videoURL != nil { Button("Share") { share() }.foregroundColor(.pink) }
                }
            }
        }
        .sheet(isPresented: $showPreview) { if let url = videoURL { VideoPlayer(player: AVPlayer(url: url)).ignoresSafeArea() } }
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
            Text("Beat-synced, safe-zone text, gentle motion").foregroundColor(.gray).font(.subheadline)
        }.padding(.top, 18)
    }

    private func generate() {
        guard let inputs = content.toRenderInputs() else { return }
        let (recipe, media) = inputs
        isGenerating = true
        Task {
            do {
                let url = try await engine.render(template: template, recipe: recipe, media: media) { _ in }
                self.videoURL = url; self.showPreview = true
            } catch { self.error = error.localizedDescription }
            self.isGenerating = false
        }
    }

    private func share() {
        guard let url = videoURL else { return }
        ViralVideoExporter.requestPhotoPermission { ok in
            Task { @MainActor in
                guard ok else { self.error = "Photo access denied"; return }
                ViralVideoExporter.saveToPhotos(videoURL: url) { result in
                    Task { @MainActor in
                        switch result {
                        case .success(let identifier):
                            let caption = "What's in my fridge → dinner. ✨🔥 #SnapChef #FoodTok"
                            ViralVideoExporter.shareToTikTok(localIdentifiers: [identifier], caption: caption) { share in
                                Task { @MainActor in
                                    if case .failure(let e) = share { self.error = e.localizedDescription }
                                }
                            }
                        case .failure(let e): self.error = e.localizedDescription
                        }
                    }
                }
            }
        }
    }
}

// simple wrapping layout
struct Wrap<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    var data: Data; var spacing: CGFloat; var content: (Data.Element)->Content
    init(_ d: Data, spacing: CGFloat = 8, @ViewBuilder content: @escaping (Data.Element)->Content) {
        data = d; self.spacing = spacing; self.content = content
    }
    var body: some View {
        let dataArray = Array(data)
        var width: CGFloat = 0, height: CGFloat = 0
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(dataArray, id: \.self) { item in
                    content(item)
                        .alignmentGuide(.leading) { d in
                            if (abs(width - d.width) > geo.size.width) { width = 0; height -= d.height + spacing }
                            let result = width; if item == dataArray.last { width = 0 }; width -= d.width + spacing; return result
                        }
                        .alignmentGuide(.top) { _ in let result = height; if item == dataArray.last { height = 0 }; return result }
                }
            }
        }.frame(height: 120)
    }
}