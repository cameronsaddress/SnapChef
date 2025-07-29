import SwiftUI

struct AfterPhotoCaptureView: View {
    @Binding var afterPhoto: UIImage?
    @Binding var showingCamera: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Text("After Photo")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            
            Button(action: { showingCamera = true }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: "#43e97b").opacity(0.5),
                                            Color(hex: "#38f9d7").opacity(0.5)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .frame(height: 200)
                    
                    if let photo = afterPhoto {
                        Image(uiImage: photo)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Image(systemName: "camera.rotate.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.white)
                                            .padding(10)
                                            .background(Color.black.opacity(0.5))
                                            .clipShape(Circle())
                                            .padding(12)
                                    }
                                }
                            )
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text("Take a photo of your finished dish!")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Text("Show off your culinary creation! 📸")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}