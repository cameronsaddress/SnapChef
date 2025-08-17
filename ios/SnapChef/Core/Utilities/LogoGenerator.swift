import SwiftUI
import UIKit

struct LogoGenerator {
    static func generateSnapChefLogo() -> UIImage? {
        let size = CGSize(width: 1_200, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let cgContext = context.cgContext

            // Clear background
            cgContext.setFillColor(UIColor.clear.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: size))

            // Create gradient colors
            let pinkColor = UIColor(red: 1.0, green: 0.078, blue: 0.576, alpha: 1.0) // #FF1493
            let purpleColor = UIColor(red: 0.6, green: 0.196, blue: 0.8, alpha: 1.0) // #9932CC
            let cyanColor = UIColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1.0) // #00FFFF

            // Create gradient
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [pinkColor.cgColor, purpleColor.cgColor, cyanColor.cgColor]
            let locations: [CGFloat] = [0.0, 0.5, 1.0]

            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) else {
                return
            }

            // Create text path
            let text = "SNAPCHEF!"
            let font = UIFont.systemFont(ofSize: 120, weight: .black)

            // Calculate text size and position
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font
            ]

            let textSize = (text as NSString).size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )

            // Create text path
            let path = CGMutablePath()
            let attributedString = NSAttributedString(string: text, attributes: attributes)
            let line = CTLineCreateWithAttributedString(attributedString)
            let runs = CTLineGetGlyphRuns(line)

            for i in 0..<CFArrayGetCount(runs) {
                let run = CFArrayGetValueAtIndex(runs, i) as! CTRun
                let glyphCount = CTRunGetGlyphCount(run)

                if glyphCount > 0 {
                    var glyphs = [CGGlyph](repeating: 0, count: glyphCount)
                    var positions = [CGPoint](repeating: .zero, count: glyphCount)

                    CTRunGetGlyphs(run, CFRangeMake(0, 0), &glyphs)
                    CTRunGetPositions(run, CFRangeMake(0, 0), &positions)

                    let runFont = CTRunGetAttributes(run)[kCTFontAttributeName] as! CTFont

                    for j in 0..<glyphCount {
                        let glyphPath = CTFontCreatePathForGlyph(runFont, glyphs[j], nil)
                        if let glyphPath = glyphPath {
                            let transform = CGAffineTransform(translationX: textRect.minX + positions[j].x, y: textRect.minY + positions[j].y)
                            path.addPath(glyphPath, transform: transform)
                        }
                    }
                }
            }

            // Apply gradient to text
            cgContext.saveGState()
            cgContext.addPath(path)
            cgContext.clip()

            let startPoint = CGPoint(x: 0, y: size.height / 2)
            let endPoint = CGPoint(x: size.width, y: size.height / 2)
            cgContext.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])

            cgContext.restoreGState()

            // Add sparkle effect
            addSparkles(to: cgContext, in: size)
        }
    }

    private static func addSparkles(to context: CGContext, in size: CGSize) {
        // Add sparkle points around the text
        let sparklePositions: [(CGFloat, CGFloat)] = [
            (200, 80), (1_000, 100), (150, 220), (1_050, 180),
            (300, 50), (900, 250), (100, 150), (1_100, 120),
            (250, 270), (950, 40), (180, 60), (1_020, 240)
        ]

        context.setFillColor(UIColor.white.cgColor)

        for (x, y) in sparklePositions {
            // Draw a 4-pointed star
            drawStar(at: CGPoint(x: x, y: y), size: 20, context: context)
        }
    }

    private static func drawStar(at center: CGPoint, size: CGFloat, context: CGContext) {
        let path = CGMutablePath()

        // Create a 4-pointed star
        let innerRadius = size * 0.3
        let outerRadius = size * 0.8

        let points: [CGFloat] = [0, 45, 90, 135, 180, 225, 270, 315]

        for (index, angle) in points.enumerated() {
            let radius = index % 2 == 0 ? outerRadius : innerRadius
            let radians = angle * .pi / 180
            let x = center.x + radius * cos(radians)
            let y = center.y + radius * sin(radians)

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        path.closeSubpath()
        context.addPath(path)
        context.fillPath()
    }

    static func saveLogoToAssets() -> Bool {
        guard let logo = generateSnapChefLogo() else { return false }

        // Create the imageset directory
        let assetPath = "/Users/cameronanderson/SnapChef/snapchef/ios/SnapChef/Design/Assets.xcassets/SnapChefLogo.imageset"

        do {
            try FileManager.default.createDirectory(atPath: assetPath, withIntermediateDirectories: true)

            // Save the @3x image
            let imageData = logo.pngData()
            let imagePath = assetPath + "/SnapChefLogo@3x.png"
            try imageData?.write(to: URL(fileURLWithPath: imagePath))

            // Create Contents.json
            let contentsJSON = """
            {
              "images" : [
                {
                  "filename" : "SnapChefLogo@3x.png",
                  "idiom" : "universal",
                  "scale" : "3x"
                }
              ],
              "info" : {
                "author" : "xcode",
                "version" : 1
              }
            }
            """

            let contentsPath = assetPath + "/Contents.json"
            try contentsJSON.write(to: URL(fileURLWithPath: contentsPath), atomically: true, encoding: .utf8)

            return true
        } catch {
            print("Error saving logo: \(error)")
            return false
        }
    }
}

// SwiftUI Preview for the logo
struct SnapChefLogoView: View {
    var body: some View {
        if let logoImage = LogoGenerator.generateSnapChefLogo() {
            Image(uiImage: logoImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Text("Failed to generate logo")
        }
    }
}

#Preview {
    SnapChefLogoView()
        .frame(width: 400, height: 100)
        .background(Color.black)
}
