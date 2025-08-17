import SwiftUI
import UIKit

/// Utility to generate the SnapChef logo as a PNG image file
struct LogoImageGenerator {
    /// Generates and saves the SnapChef logo PNG to the Assets folder
    static func generateAndSaveLogo() {
        let logoImage = createLogoImage()
        saveToPNGFile(image: logoImage)
    }

    /// Creates the SnapChef logo as UIImage
    private static func createLogoImage() -> UIImage {
        let size = CGSize(width: 1_200, height: 300)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3.0 // @3x resolution
        format.opaque = false // Transparent background

        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)

            // Clear background (transparent)
            UIColor.clear.setFill()
            context.fill(rect)

            // Draw the main text with gradient
            drawGradientText(in: rect, context: context.cgContext)

            // Add sparkle decorations
            drawSparkles(in: rect, context: context.cgContext)
        }
    }

    private static func drawGradientText(in rect: CGRect, context: CGContext) {
        let text = "SNAPCHEF!"

        // Create the font
        guard let font = UIFont(name: "HelveticaNeue-Black", size: 120) ??
                        UIFont.systemFont(ofSize: 120, weight: .black) as UIFont? else { return }

        // Calculate text positioning
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let textRect = CGRect(
            x: (rect.width - textSize.width) / 2,
            y: (rect.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )

        // Create gradient colors
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let pinkColor = CGColor(red: 1.0, green: 0.078, blue: 0.576, alpha: 1.0) // #FF1493
        let purpleColor = CGColor(red: 0.6, green: 0.196, blue: 0.8, alpha: 1.0) // #9932CC
        let cyanColor = CGColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1.0) // #00FFFF

        let colors = [pinkColor, purpleColor, cyanColor]
        let locations: [CGFloat] = [0.0, 0.5, 1.0]

        guard let gradient = CGGradient(colorsSpace: colorSpace,
                                       colors: colors as CFArray,
                                       locations: locations) else { return }

        // Create text path using Core Text
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)

        context.saveGState()
        context.translateBy(x: textRect.minX, y: textRect.minY)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: 0, y: -textRect.height)

        // Create clipping path from text
        let textPath = CTLineCreatePath(line)
        context.addPath(textPath)
        context.clip()

        // Draw gradient
        let startPoint = CGPoint(x: 0, y: textRect.height / 2)
        let endPoint = CGPoint(x: textRect.width, y: textRect.height / 2)
        context.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])

        context.restoreGState()
    }

    private static func drawSparkles(in rect: CGRect, context: CGContext) {
        // Sparkle positions around the text
        let sparkleData: [(CGPoint, CGFloat, Bool)] = [
            // (position, size, isStarShape)
            (CGPoint(x: 200, y: 80), 25, true),
            (CGPoint(x: 1_000, y: 100), 25, true),
            (CGPoint(x: 150, y: 220), 25, true),
            (CGPoint(x: 1_050, y: 180), 25, true),
            (CGPoint(x: 300, y: 50), 15, false),
            (CGPoint(x: 900, y: 250), 15, false),
            (CGPoint(x: 100, y: 150), 15, false),
            (CGPoint(x: 1_100, y: 120), 15, false),
            (CGPoint(x: 250, y: 270), 12, false),
            (CGPoint(x: 950, y: 40), 12, false),
            (CGPoint(x: 180, y: 60), 18, true),
            (CGPoint(x: 1_020, y: 240), 18, true)
        ]

        context.setFillColor(UIColor.white.cgColor)
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)

        for (position, size, isStar) in sparkleData {
            if isStar {
                drawStar(at: position, size: size, context: context)
            } else {
                drawCircleSparkle(at: position, radius: size / 2, context: context)
            }
        }
    }

    private static func drawStar(at center: CGPoint, size: CGFloat, context: CGContext) {
        let path = CGMutablePath()
        let outerRadius = size / 2
        let innerRadius = outerRadius * 0.4
        let points = 8 // 4-pointed star with intermediate points

        for i in 0..<points {
            let angle = (Double(i) * .pi) / Double(points / 2) - .pi / 2
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()

        context.addPath(path)
        context.fillPath()
    }

    private static func drawCircleSparkle(at center: CGPoint, radius: CGFloat, context: CGContext) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius,
                         width: radius * 2, height: radius * 2)
        context.fillEllipse(in: rect)
    }

    /// Saves the generated image as PNG
    private static func saveToPNGFile(image: UIImage) {
        guard let pngData = image.pngData() else {
            print("❌ Failed to convert image to PNG data")
            return
        }

        let assetPath = "/Users/cameronanderson/SnapChef/snapchef/ios/SnapChef/Design/Assets.xcassets/SnapChefLogo.imageset"
        let filePath = "\(assetPath)/SnapChefLogo@3x.png"

        do {
            // Ensure directory exists
            try FileManager.default.createDirectory(at: URL(fileURLWithPath: assetPath),
                                                  withIntermediateDirectories: true)

            // Write PNG data
            try pngData.write(to: URL(fileURLWithPath: filePath))

            print("✅ SnapChef logo successfully saved to: \(filePath)")
            print("📐 Image size: \(image.size)")
            print("📊 Scale: \(image.scale)x")
        } catch {
            print("❌ Error saving logo PNG: \(error)")
        }
    }
}

// MARK: - SwiftUI Preview Helper
struct LogoPreview: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("SnapChef Logo Generator")
                .font(.title2)
                .padding()

            if let image = createPreviewImage() {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 400, maxHeight: 100)
                    .background(Color.black.opacity(0.1))
                    .cornerRadius(8)
            }

            Button("Generate & Save Logo PNG") {
                LogoImageGenerator.generateAndSaveLogo()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .padding()
    }

    private func createPreviewImage() -> UIImage? {
        let size = CGSize(width: 600, height: 150) // Smaller for preview
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // Simple preview version
            let rect = CGRect(origin: .zero, size: size)

            // Clear background
            UIColor.clear.setFill()
            context.fill(rect)

            // Draw text with simple gradient
            let text = "SNAPCHEF!"
            let font = UIFont.systemFont(ofSize: 60, weight: .black)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.systemPink
            ]

            let textSize = (text as NSString).size(withAttributes: attributes)
            let textRect = CGRect(
                x: (rect.width - textSize.width) / 2,
                y: (rect.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )

            (text as NSString).draw(in: textRect, withAttributes: attributes)
        }
    }
}

#Preview {
    LogoPreview()
}
