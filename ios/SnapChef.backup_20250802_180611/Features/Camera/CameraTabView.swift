import SwiftUI

struct CameraTabView: View {
    @State private var showingCamera = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Camera icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#667eea"),
                                        Color(hex: "#764ba2")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .shadow(color: Color(hex: "#667eea").opacity(0.4), radius: 20)
                        
                        Image(systemName: "camera.fill")
                            .font(.system(size: 50, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    Text("Ready to Snap?")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Take a photo of your fridge or pantry")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    MagneticButton(
                        title: "Open Camera",
                        icon: "camera.fill",
                        action: {
                            showingCamera = true
                        }
                    )
                    .padding(.horizontal, 40)
                    
                    Spacer()
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView()
        }
    }
}

#Preview {
    CameraTabView()
}