import SwiftUI

struct FloatingFoodAnimation: View {
    let foodEmojis = ["🍎", "🥕", "🍅", "🥦", "🍗", "🧀", "🥚", "🍞", "🥛", "🍋"]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<8) { index in
                    FloatingFood(
                        emoji: foodEmojis[index % foodEmojis.count],
                        screenSize: geometry.size,
                        index: index
                    )
                }
            }
        }
    }
}

struct FloatingFood: View {
    let emoji: String
    let screenSize: CGSize
    let index: Int
    
    @State private var position: CGPoint
    @State private var opacity: Double = 0
    
    init(emoji: String, screenSize: CGSize, index: Int) {
        self.emoji = emoji
        self.screenSize = screenSize
        self.index = index
        
        // Random starting position - ensure food starts fully off-screen
        let startX = CGFloat.random(in: 50...(screenSize.width - 50))
        let startY: CGFloat = -100 // Always start above the screen
        self._position = State(initialValue: CGPoint(x: startX, y: startY))
    }
    
    var body: some View {
        Text(emoji)
            .font(.system(size: CGFloat.random(in: 30...50)))
            .position(position)
            .opacity(opacity)
            .onAppear {
                startAnimation()
            }
    }
    
    private func startAnimation() {
        withAnimation(.easeIn(duration: 0.5)) {
            opacity = 0.3 // More translucent
        }
        
        animateFloat()
    }
    
    private func animateFloat() {
        let duration = Double.random(in: 15...25)
        let delay = Double(index) * 0.5
        
        withAnimation(
            Animation.linear(duration: duration)
                .delay(delay)
                .repeatForever(autoreverses: false)
        ) {
            position.y = screenSize.height + 100
        }
        
        // Slight horizontal movement
        withAnimation(
            Animation.easeInOut(duration: 3)
                .delay(delay)
                .repeatForever(autoreverses: true)
        ) {
            position.x += CGFloat.random(in: -30...30)
        }
    }
}

#Preview {
    ZStack {
        GradientBackground()
        FloatingFoodAnimation()
    }
}