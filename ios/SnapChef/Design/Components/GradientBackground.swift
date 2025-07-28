import SwiftUI

struct FridgeFlyThroughBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            colors: [
                Color(hex: "#4ECDC4"), // Teal
                Color(hex: "#45B7D1"), // Light Blue
                Color(hex: "#3A7CA5"), // Ocean Blue
                Color(hex: "#2E5266")  // Steel Blue
            ],
            startPoint: animateGradient ? .topLeading : .bottomTrailing,
            endPoint: animateGradient ? .bottomTrailing : .topLeading
        )
        .hueRotation(.degrees(animateGradient ? 30 : 0))
        .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: animateGradient)
        .onAppear {
            animateGradient = true
        }
    }
}

struct GradientBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: "#4ECDC4"), // Teal
                Color(hex: "#45B7D1"), // Light Blue
                Color(hex: "#3FA9C4"), // Medium Blue
                Color(hex: "#52D3D8") // Cyan
            ]),
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .animation(
            Animation.easeInOut(duration: 8.0)
                .repeatForever(autoreverses: true),
            value: animateGradient
        )
        .onAppear {
            animateGradient = true
        }
    }
}

// Color extension for hex support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    FridgeFlyThroughBackground()
}