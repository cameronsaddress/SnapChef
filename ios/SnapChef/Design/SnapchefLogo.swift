import SwiftUI

struct SnapchefLogo: View {
    @State private var animate = false

    var body: some View {
        Text("SNAPCHEF!")
            .font(.system(size: 48, weight: .heavy, design: .rounded))
            .foregroundStyle(
                LinearGradient(colors: [Color.pink, Color.purple, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .shadow(color: .purple.opacity(0.4), radius: 5, x: 2, y: 2)
            .scaleEffect(animate ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animate)
            .onAppear {
                animate = true
            }
    }
}

#Preview {
    SnapchefLogo()
}