import SwiftUI

struct CapturedImageView: View {
    let image: UIImage
    let onRetake: () -> Void
    let onConfirm: () -> Void
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            // Full screen image
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()
            
            // Dark overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            // UI Overlay
            VStack {
                // Top bar
                HStack {
                    Text("Review Photo")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                Spacer()
                
                // Bottom controls
                VStack(spacing: 20) {
                    Text("Looking good?")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(showContent ? 1 : 0)
                        .scaleEffect(showContent ? 1 : 0.8)
                    
                    HStack(spacing: 40) {
                        // Retake button
                        Button(action: onRetake) {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 70, height: 70)
                                    
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 28, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                
                                Text("Retake")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .opacity(showContent ? 1 : 0)
                        .scaleEffect(showContent ? 1 : 0.8)
                        
                        // Confirm button
                        Button(action: onConfirm) {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(hex: "#43e97b"),
                                                    Color(hex: "#38f9d7")
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 90, height: 90)
                                        .shadow(
                                            color: Color(hex: "#43e97b").opacity(0.5),
                                            radius: 20,
                                            y: 10
                                        )
                                    
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                
                                Text("Use Photo")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .opacity(showContent ? 1 : 0)
                        .scaleEffect(showContent ? 1 : 0.8)
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                showContent = true
            }
        }
    }
}

#Preview {
    CapturedImageView(
        image: UIImage(systemName: "photo")!,
        onRetake: {},
        onConfirm: {}
    )
}