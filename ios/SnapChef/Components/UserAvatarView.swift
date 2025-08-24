import SwiftUI

/// Reusable user avatar view that displays profile photo or initials
struct UserAvatarView: View {
    let userID: String?
    let username: String?
    let displayName: String?
    let size: CGFloat
    
    @StateObject private var profilePhotoManager = ProfilePhotoManager.shared
    @State private var userPhoto: UIImage?
    
    init(userID: String? = nil, username: String? = nil, displayName: String? = nil, size: CGFloat = 40) {
        self.userID = userID
        self.username = username
        self.displayName = displayName
        self.size = size
    }
    
    private var displayText: String {
        if let username = username, !username.isEmpty {
            return username
        } else if let displayName = displayName, !displayName.isEmpty {
            return displayName
        }
        return "U"
    }
    
    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Group {
                    if let photo = userPhoto {
                        Image(uiImage: photo)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    } else {
                        Text(displayText.prefix(1).uppercased())
                            .font(.system(size: size * 0.4, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            )
            .task {
                await loadUserPhoto()
            }
    }
    
    private func loadUserPhoto() async {
        // Try to load from ProfilePhotoManager
        if let userID = userID {
            userPhoto = await profilePhotoManager.getProfilePhoto(for: userID)
        } else if userID == nil {
            // If no userID provided, try to load current user's photo
            userPhoto = profilePhotoManager.currentUserPhoto
        }
    }
}