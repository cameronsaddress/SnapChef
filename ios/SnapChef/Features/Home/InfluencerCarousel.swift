import SwiftUI

struct InfluencerCarousel: View {
    @State private var currentIndex = 0
    @State private var selectedInfluencer: InfluencerRecipe?
    @State private var timer: Timer?
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    let influencers = InfluencerRecipe.mockInfluencers
    let autoScrollInterval: TimeInterval = 5.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Celebrity Kitchens")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("See what your favorite stars are cooking")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<influencers.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentIndex ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentIndex ? 1 : 0.8)
                            .animation(.spring(response: 0.3), value: currentIndex)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // Carousel
            GeometryReader { geometry in
                HStack(spacing: 20) {
                    ForEach(0..<influencers.count, id: \.self) { index in
                        InfluencerShowcaseCard(
                            influencer: influencers[index],
                            onTap: {
                                selectedInfluencer = influencers[index]
                            }
                        )
                        .frame(width: geometry.size.width - 40)
                        .scaleEffect(index == currentIndex ? 1 : 0.95)
                        .opacity(index == currentIndex ? 1 : 0.7)
                        .animation(.spring(response: 0.3), value: currentIndex)
                    }
                }
                .padding(.horizontal, 20)
                .offset(x: -CGFloat(currentIndex) * (geometry.size.width - 20) + dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            dragOffset = value.translation.width
                            stopAutoScroll()
                        }
                        .onEnded { value in
                            isDragging = false
                            let threshold: CGFloat = 50
                            
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if value.translation.width > threshold && currentIndex > 0 {
                                    currentIndex -= 1
                                } else if value.translation.width < -threshold && currentIndex < influencers.count - 1 {
                                    currentIndex += 1
                                }
                                dragOffset = 0
                            }
                            
                            startAutoScroll()
                        }
                )
            }
            .frame(height: 480)
        }
        .onAppear {
            startAutoScroll()
        }
        .onDisappear {
            stopAutoScroll()
        }
        .sheet(item: $selectedInfluencer) { influencer in
            InfluencerDetailView(influencer: influencer)
        }
    }
    
    private func startAutoScroll() {
        stopAutoScroll()
        timer = Timer.scheduledTimer(withTimeInterval: autoScrollInterval, repeats: true) { _ in
            if !isDragging {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    currentIndex = (currentIndex + 1) % influencers.count
                }
            }
        }
    }
    
    private func stopAutoScroll() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    ZStack {
        MagicalBackground()
            .ignoresSafeArea()
        
        InfluencerCarousel()
    }
}