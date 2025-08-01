import SwiftUI

struct UsernameSelectionView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var username = ""
    @State private var isChecking = false
    @State private var isAvailable = false
    @State private var hasChecked = false
    @State private var suggestions: [String] = []
    
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
                                    checkUsernameAvailability()
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
                    .disabled(!isValid || !isAvailable)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func checkUsernameAvailability() {
        guard isValid else { return }
        
        isChecking = true
        
        // Simulate API call
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // In real app, check with backend
            let takenUsernames = ["chef", "master", "cooking", "snapchef", "admin"]
            isAvailable = !takenUsernames.contains(username.lowercased())
            hasChecked = true
            isChecking = false
            
            if !isAvailable {
                // Generate suggestions
                suggestions = [
                    "\(username)123",
                    "\(username)_chef",
                    "chef_\(username)",
                    "\(username)\(Int.random(in: 10...99))"
                ]
            }
        }
    }
    
    private func saveUsername() {
        // In real app, update user profile with username
        dismiss()
    }
}

#Preview {
    UsernameSelectionView()
        .environmentObject(AuthenticationManager())
}