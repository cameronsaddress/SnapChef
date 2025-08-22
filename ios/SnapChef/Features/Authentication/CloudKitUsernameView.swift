import SwiftUI

struct CloudKitUsernameView: View {
    @StateObject private var authManager = UnifiedAuthManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var isChecking = false
    @State private var isAvailable = false
    @State private var hasChecked = false
    @State private var suggestions: [String] = []
    @State private var showError = false
    @State private var errorMessage = ""

    var isValid: Bool {
        username.count >= 3 && username.count <= 20 && username.range(of: "^[a-zA-Z0-9_]+$", options: .regularExpression) != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()

                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "at.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("Choose Your Username")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("This is how other chefs will know you")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.top, 40)

                    // Username Input
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "at")
                                .foregroundColor(.white.opacity(0.6))

                            TextField("username", text: $username)
                                .textContentType(.username)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .foregroundColor(.white)
                                .onChange(of: username) { _ in
                                    hasChecked = false
                                    if isValid {
                                        checkUsernameAvailability()
                                    }
                                }

                            if isChecking {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else if hasChecked {
                                Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(isAvailable ? .green : .red)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            isValid ? (isAvailable ? Color.green : Color.red) : Color.white.opacity(0.3),
                                            lineWidth: 1
                                        )
                                )
                        )

                        // Validation message
                        if !username.isEmpty {
                            if !isValid {
                                Label("3-20 characters, letters, numbers, and underscores only", systemImage: "info.circle")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            } else if hasChecked && !isAvailable {
                                Label("Username already taken", systemImage: "xmark.circle")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            } else if hasChecked && isAvailable {
                                Label("Username available!", systemImage: "checkmark.circle")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Suggestions
                    if !suggestions.isEmpty && !isAvailable {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Try these:")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(suggestions, id: \.self) { suggestion in
                                        Button(action: {
                                            username = suggestion
                                            checkUsernameAvailability()
                                        }) {
                                            Text("@\(suggestion)")
                                                .font(.subheadline)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.white.opacity(0.1))
                                                        .overlay(
                                                            Capsule()
                                                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                                        )
                                                )
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    Spacer()

                    // Continue Button
                    Button(action: saveUsername) {
                        Text("Continue")
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                isValid && isAvailable ? Color.white : Color.white.opacity(0.3)
                            )
                            .cornerRadius(25)
                            .animation(.easeInOut, value: isValid && isAvailable)
                    }
                    .disabled(!isValid || !isAvailable || isChecking)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled() // Can't dismiss without choosing username
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func checkUsernameAvailability() {
        guard isValid else { return }

        isChecking = true

        Task {
            do {
                isAvailable = try await authManager.checkUsernameAvailability(username)
                hasChecked = true

                if !isAvailable {
                    // Generate suggestions based on current username
                    suggestions = [
                        "\(username)123",
                        "\(username)_chef",
                        "chef_\(username)",
                        "\(username)\(Int.random(in: 10...99))",
                        "\(username)_\(Int.random(in: 100...999))"
                    ].prefix(4).map { $0 }
                } else {
                    suggestions = []
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }

            isChecking = false
        }
    }

    private func saveUsername() {
        Task {
            do {
                try await authManager.setUsername(username)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    CloudKitUsernameView()
}
