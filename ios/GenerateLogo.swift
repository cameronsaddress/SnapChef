#!/usr/bin/swift

import Foundation
import UIKit
import CoreGraphics
import CoreText

/// Script to generate the SnapChef logo PNG file
/// Run this with: swift GenerateLogo.swift

func createSnapChefLogo() -> UIImage? {
    let size = CGSize(width: 1200, height: 300)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 3.0 // @3x resolution
    format.opaque = false // Transparent background
    
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    
    return renderer.image { context in
        let rect = CGRect(origin: .zero, size: size)
        let cgContext = context.cgContext
        
        // Clear background (transparent)
        cgContext.setFillColor(UIColor.clear.cgColor)
        cgContext.fill(rect)
        
        // Create gradient colors matching the exact brand colors
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let pinkColor = CGColor(red: 1.0, green: 0.078, blue: 0.576, alpha: 1.0) // #FF1493
        let purpleColor = CGColor(red: 0.6, green: 0.196, blue: 0.8, alpha: 1.0) // #9932CC
        let cyanColor = CGColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1.0) // #00FFFF
        
        let colors = [pinkColor, purpleColor, cyanColor]
        let locations: [CGFloat] = [0.0, 0.5, 1.0]
        
        guard let gradient = CGGradient(colorsSpace: colorSpace,
                                       colors: colors as CFArray,
                                       locations: locations) else { return }
        
        // Create the text
        let text = "SNAPCHEF!"
        let fontSize: CGFloat = 120
        
        // Use system font with heavy weight
        let font = UIFont.systemFont(ofSize: fontSize, weight: .black)
        
        // Calculate text positioning
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let textRect = CGRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        // Create text path using Core Text for proper gradient application
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)
        
        // Save graphics state
        cgContext.saveGState()
        
        // Transform coordinate system for Core Text
        cgContext.translateBy(x: textRect.minX, y: textRect.maxY)
        cgContext.scaleBy(x: 1.0, y: -1.0)
        
        // Create clipping path from text
        let textPath = CTLineCreatePath(line)
        cgContext.addPath(textPath)
        cgContext.clip()
        
        // Draw gradient within the clipped text
        let gradientStart = CGPoint(x: 0, y: textRect.height / 2)
        let gradientEnd = CGPoint(x: textRect.width, y: textRect.height / 2)
        cgContext.drawLinearGradient(gradient, start: gradientStart, end: gradientEnd, options: [])
        
        // Restore graphics state
        cgContext.restoreGState()
        
        // Add sparkle effects
        addSparkles(to: cgContext, in: size, textRect: textRect)
    }
}

func addSparkles(to context: CGContext, in canvasSize: CGSize, textRect: CGRect) {
    // Sparkle positions around the text
    let sparklePositions: [(CGFloat, CGFloat, CGFloat, Bool)] = [
        // (x, y, size, isStarShape)
        (textRect.minX - 50, textRect.midY - 40, 25, true),
        (textRect.maxX + 20, textRect.midY - 60, 25, true),
        (textRect.minX - 30, textRect.midY + 40, 20, true),
        (textRect.maxX + 30, textRect.midY + 30, 20, true),
        (textRect.midX - 100, textRect.minY - 30, 15, false),
        (textRect.midX + 80, textRect.minY - 20, 15, false),
        (textRect.midX - 120, textRect.maxY + 20, 12, false),
        (textRect.midX + 100, textRect.maxY + 15, 12, false),
        (textRect.minX + 50, textRect.minY - 40, 18, true),
        (textRect.maxX - 80, textRect.maxY + 25, 18, true)
    ]
    
    context.setFillColor(UIColor.white.cgColor)
    context.setBlendMode(.normal)
    
    for (x, y, size, isStar) in sparklePositions {
        if isStar {
            drawStar(at: CGPoint(x: x, y: y), size: size, context: context)
        } else {
            drawCircleSparkle(at: CGPoint(x: x, y: y), radius: size / 2, context: context)
        }
    }
}

func drawStar(at center: CGPoint, size: CGFloat, context: CGContext) {
    let path = CGMutablePath()
    let outerRadius = size / 2
    let innerRadius = outerRadius * 0.4
    let points = 8 // Creates a 4-pointed star
    
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

func drawCircleSparkle(at center: CGPoint, radius: CGFloat, context: CGContext) {
    let rect = CGRect(x: center.x - radius, y: center.y - radius,
                     width: radius * 2, height: radius * 2)
    context.fillEllipse(in: rect)
}

func saveLogo() {
    guard let logoImage = createSnapChefLogo() else {
        print("❌ Failed to create logo image")
        return
    }
    
    guard let pngData = logoImage.pngData() else {
        print("❌ Failed to convert image to PNG data")
        return
    }
    
    let assetPath = "SnapChef/Design/Assets.xcassets/SnapChefLogo.imageset"
    let filePath = "\(assetPath)/SnapChefLogo@3x.png"
    
    do {
        // Ensure directory exists
        try FileManager.default.createDirectory(atPath: assetPath, withIntermediateDirectories: true)
        
        // Write PNG data
        let fileURL = URL(fileURLWithPath: filePath)
        try pngData.write(to: fileURL)
        
        print("✅ SnapChef logo successfully saved to: \(filePath)")
        print("📐 Image size: \(logoImage.size)")
        print("📊 Scale: \(logoImage.scale)x")
        print("💾 File size: \(pngData.count) bytes")
        
    } catch {
        print("❌ Error saving logo PNG: \(error)")
    }
}

// Execute the logo generation
print("🎨 Generating SnapChef logo...")
saveLogo()
print("🎉 Logo generation complete!")