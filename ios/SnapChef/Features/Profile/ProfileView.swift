import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var deviceManager: DeviceManager
    @State private var showingSubscriptionView = false
    
    var body: some View {
        NavigationView {
            ZStack {
                GradientBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // User info
                        if let user = appState.currentUser {
                            AuthenticatedProfileView(user: user)
                        } else {
                            GuestProfileView(freeUses: deviceManager.freeUsesRemaining)
                        }
                        
                        // Stats
                        StatsSection(recipesCreated: appState.recentRecipes.count)
                        
                        // Subscription
                        SubscriptionCard(
                            currentTier: appState.currentUser?.subscription.tier ?? .free,
                            onUpgrade: { showingSubscriptionView = true }
                        )
                        
                        // Settings
                        SettingsSection()
                        
                        // Sign out button
                        if authManager.isAuthenticated {
                            Button(action: {
                                authManager.signOut()
                            }) {
                                Text("Sign Out")
                                    .foregroundColor(.white.opacity(0.8))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.red.opacity(0.2))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 20)
                }
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.large)
            }
        }
        .sheet(isPresented: $showingSubscriptionView) {
            SubscriptionView()
        }
    }
}

struct AuthenticatedProfileView: View {
    let user: User
    
    var body: some View {
        VStack(spacing: 16) {
            // Profile image
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#FF6B6B"), Color(hex: "#4ECDC4")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .overlay(
                    Text(user.name?.first?.uppercased() ?? "U")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                )
            
            Text(user.name ?? "SnapChef User")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
            
            if let email = user.email {
                Text(email)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Credits
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text("\(user.credits) credits")
            }
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

struct GuestProfileView: View {
    let freeUses: Int
    
    var body: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.5))
                )
            
            Text("Guest User")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
            
            Text("\(freeUses) free snaps remaining")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
            
            Button(action: {
                // Trigger auth
            }) {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text("Sign In for More")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#FF6B6B"), Color(hex: "#4ECDC4")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
        }
    }
}

struct StatsSection: View {
    let recipesCreated: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Stats")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
            
            HStack(spacing: 16) {
                StatCard(title: "Recipes", value: "\(recipesCreated)", icon: "book.fill")
                StatCard(title: "Streak", value: "0", icon: "flame.fill")
                StatCard(title: "Shared", value: "0", icon: "square.and.arrow.up")
            }
            .padding(.horizontal, 20)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.8))
            
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct SubscriptionCard: View {
    let currentTier: Subscription.SubscriptionTier
    let onUpgrade: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Plan")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(currentTier.displayName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                if currentTier != .premium {
                    Button(action: onUpgrade) {
                        Text("Upgrade")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.white)
                            )
                    }
                }
            }
            
            // Features
            VStack(alignment: .leading, spacing: 8) {
                ForEach(currentTier.features, id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                        
                        Text(feature)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
}

struct SettingsSection: View {
    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(icon: "bell", title: "Notifications", action: {})
            SettingsRow(icon: "questionmark.circle", title: "Help & Support", action: {})
            SettingsRow(icon: "doc.text", title: "Terms & Privacy", action: {})
            SettingsRow(icon: "star", title: "Rate SnapChef", action: {})
        }
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 30)
                
                Text(title)
                    .font(.system(size: 17))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
        .environmentObject(AuthenticationManager())
        .environmentObject(DeviceManager())
}