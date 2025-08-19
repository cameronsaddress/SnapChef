import SwiftUI
import PhotosUI
import CloudKit

struct UsernameSetupView: View {
    @StateObject private var cloudKitAuth = CloudKitAuthManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var username = ""
    @State private var isCheckingUsername = false
    @State private var usernameStatus: UsernameStatus = .unchecked
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""

    // Animation states
    @State private var contentVisible = false
    @State private var buttonScale: CGFloat = 1.0

    enum UsernameStatus {
        case unchecked
        case checking
        case available
        case taken
        case invalid
        case profanity

        var color: Color {
            switch self {
            case .unchecked, .checking: return .gray
            case .available: return .green
            case .taken, .invalid, .profanity: return .red
            }
        }

        var message: String {
            switch self {
            case .unchecked: return ""
            case .checking: return "Checking availability..."
            case .available: return "Username available!"
            case .taken: return "Username already taken"
            case .invalid: return "Username must be 3-20 characters, alphanumeric only"
            case .profanity: return "Username contains inappropriate content"
            }
        }

        var icon: String? {
            switch self {
            case .available: return "checkmark.circle.fill"
            case .taken, .invalid, .profanity: return "xmark.circle.fill"
            default: return nil
            }
        }
    }

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color(hex: "#667eea"),
                    Color(hex: "#764ba2")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 12) {
                        Text("Complete Your Profile")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Choose a unique username and profile photo")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 20)

                    // Profile Photo Section
                    VStack(spacing: 20) {
                        // Photo picker
                        Button(action: { showImagePicker = true }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 150, height: 150)

                                if let selectedImage = selectedImage {
                                    Image(uiImage: selectedImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 150, height: 150)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 3)
                                        )
                                } else {
                                    VStack(spacing: 8) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.white)
                                        Text("Add Photo")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                }

                                // Edit overlay for existing photo
                                if selectedImage != nil {
                                    Circle()
                                        .fill(Color.black.opacity(0.5))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 18))
                                                .foregroundColor(.white)
                                        )
                                        .offset(x: 55, y: 55)
                                }
                            }
                        }
                        .scaleEffect(buttonScale)
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                buttonScale = hovering ? 1.05 : 1.0
                            }
                        }
                    }
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.2), value: contentVisible)

                    // Username Input Section
                    VStack(spacing: 16) {
                        // Username field
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                TextField("Choose username", text: $username)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .onChange(of: username) { newValue in
                                        validateUsername(newValue)
                                    }

                                if isCheckingUsername {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else if let icon = usernameStatus.icon {
                                    Image(systemName: icon)
                                        .foregroundColor(usernameStatus.color)
                                        .font(.system(size: 20))
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(usernameStatus.color.opacity(0.5), lineWidth: 2)
                            )

                            // Status message
                            if !usernameStatus.message.isEmpty {
                                HStack {
                                    Text(usernameStatus.message)
                                        .font(.system(size: 14))
                                        .foregroundColor(usernameStatus.color)
                                    Spacer()
                                }
                                .padding(.horizontal, 4)
                            }
                        }

                        // Username requirements
                        VStack(alignment: .leading, spacing: 4) {
                            Label("3-20 characters", systemImage: "textformat.123")
                            Label("Letters, numbers, underscore only", systemImage: "textformat.abc")
                            Label("Must be unique", systemImage: "person.badge.shield.checkmark")
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.4), value: contentVisible)

                    // Continue Button
                    Button(action: saveProfile) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                            } else {
                                Text("Continue")
                                    .font(.system(size: 18, weight: .bold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                        .foregroundColor(canContinue ? .white : .white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(canContinue ? Color.white.opacity(0.3) : Color.white.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .disabled(!canContinue || isLoading)
                    .padding(.horizontal)
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.6), value: contentVisible)

                    // Skip for now (optional)
                    Button(action: skipSetup) {
                        Text("Skip for now")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                            .underline()
                    }
                    .opacity(contentVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.8), value: contentVisible)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal)
            }
        }
        .photosPicker(isPresented: $showImagePicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            print("🔍 DEBUG: UsernameSetupView appeared")
            withAnimation(.easeOut(duration: 0.5)) {
                contentVisible = true
            }
        }
    }

    private var canContinue: Bool {
        usernameStatus == .available && !username.isEmpty
    }

    private func validateUsername(_ username: String) {
        // Reset if empty
        guard !username.isEmpty else {
            usernameStatus = .unchecked
            return
        }

        // Check format
        let usernameRegex = "^[a-zA-Z0-9_]{3,20}$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)

        guard usernamePredicate.evaluate(with: username) else {
            usernameStatus = .invalid
            return
        }

        // Check for profanity
        if ProfanityFilter.shared.containsProfanity(username) {
            usernameStatus = .profanity
            return
        }

        // Check availability in CloudKit
        checkUsernameAvailability(username)
    }

    private func checkUsernameAvailability(_ username: String) {
        isCheckingUsername = true
        usernameStatus = .checking

        Task {
            do {
                let isAvailable = try await cloudKitAuth.checkUsernameAvailability(username)

                await MainActor.run {
                    isCheckingUsername = false
                    usernameStatus = isAvailable ? .available : .taken
                }
            } catch {
                await MainActor.run {
                    isCheckingUsername = false
                    usernameStatus = .unchecked
                    errorMessage = "Failed to check username availability"
                    showError = true
                }
            }
        }
    }

    private func saveProfile() {
        guard canContinue else { return }

        isLoading = true

        Task {
            do {
                // Save username using CloudKitAuthManager
                try await cloudKitAuth.setUsername(username)

                // Save profile image to CloudKit if provided
                if let image = selectedImage {
                    try await CloudKitUserManager.shared.updateProfileImage(image)
                }

                await MainActor.run {
                    cloudKitAuth.showUsernameSelection = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to save profile. Please try again."
                    showError = true
                }
            }
        }
    }

    private func skipSetup() {
        // Generate a temporary username and save it
        let tempUsername = "Chef\(Int.random(in: 10_000...99_999))"

        Task {
            do {
                try await cloudKitAuth.setUsername(tempUsername)
                await MainActor.run {
                    cloudKitAuth.showUsernameSelection = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to set temporary username"
                    showError = true
                }
            }
        }
    }
}

#Preview {
    UsernameSetupView()
}
