import SwiftUI
import PhotosUI
import CloudKit

struct ChallengeDetailView: View {
    let challenge: Challenge
    @Environment(\.dismiss) var dismiss
    @StateObject private var gamificationManager = GamificationManager.shared
    @StateObject private var authManager = UnifiedAuthManager.shared
    @StateObject private var rewardAnimator = ChallengeRewardAnimator.shared
    
    // Join state
    @State private var isJoining = false
    @State private var joinSuccess = false
    
    // Submission state
    @State private var showSubmissionSheet = false
    @State private var selectedImage: UIImage?
    @State private var submissionDescription = ""
    @State private var isSubmitting = false
    @State private var imageSourceType: ImageSourceType? = nil
    
    enum ImageSourceType: Identifiable {
        case camera, photoLibrary
        var id: Int { hashValue }
    }
    
    // Celebration state
    @State private var showCelebration = false
    @State private var pointsEarned = 0
    @State private var coinsEarned = 0
    @State private var showSharePrompt = false
    @State private var showBrandedShare = false
    
    // Get the actual challenge from GamificationManager if it exists
    private var displayChallenge: Challenge {
        if let activeChallenge = gamificationManager.activeChallenges.first(where: {
            $0.id == challenge.id || $0.title == challenge.title
        }) {
            return activeChallenge
        }
        return challenge
    }
    
    private var isJoined: Bool {
        displayChallenge.isJoined || gamificationManager.isChallengeJoined(displayChallenge.id)
    }
    
    private var decodedRequirements: [String] {
        // Fix requirements display - decode if needed
        displayChallenge.requirements.compactMap { requirement in
            // Check if it looks like base64 or UUID
            if requirement.count > 30 && !requirement.contains(" ") {
                // Try to decode as base64
                if let data = Data(base64Encoded: requirement),
                   let decoded = String(data: data, encoding: .utf8) {
                    return decoded
                }
            }
            // Return as-is if not encoded
            return requirement
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        challengeHeader
                        
                        // Action Button (Join or Submit)
                        if !displayChallenge.isCompleted {
                            if isJoined {
                                submitChallengeButton
                            } else {
                                joinChallengeButton
                            }
                        } else {
                            completedBadge
                        }
                        
                        // Requirements
                        requirementsSection
                        
                        // Rewards
                        rewardsSection
                        
                        // Participants
                        participantsSection
                    }
                    .padding(.vertical, 40)
                    .padding(.horizontal, 20)
                }
                
                // Celebration Overlay
                if showCelebration {
                    celebrationOverlay
                }
                
                // Share Prompt Overlay
                if showSharePrompt {
                    sharePromptOverlay
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#667eea"))
                }
            }
        }
        .sheet(isPresented: $showSubmissionSheet) {
            submissionSheet
        }
        .sheet(item: $imageSourceType) { sourceType in
            switch sourceType {
            case .camera:
                ChallengeCameraView(image: $selectedImage)
            case .photoLibrary:
                ChallengeImagePicker(image: $selectedImage)
            }
        }
        .sheet(isPresented: $showBrandedShare) {
            if let shareContent = createShareContent() {
                BrandedSharePopup(content: shareContent)
                    .presentationDetents([.height(420)])
                    .presentationDragIndicator(.hidden)
            }
        }
    }
    
    // MARK: - View Components
    
    private var challengeHeader: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: iconForChallenge())
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Title
            Text(displayChallenge.title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // Description
            Text(displayChallenge.description)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }
    
    private var joinChallengeButton: some View {
        MagneticButton(
            title: joinSuccess ? "Joined!" : "Join Challenge",
            icon: joinSuccess ? "checkmark.circle.fill" : "plus.circle.fill",
            action: joinChallenge
        )
        .disabled(isJoining || joinSuccess)
    }
    
    private var submitChallengeButton: some View {
        VStack(spacing: 16) {
            // Main submit button with enhanced design
            Button(action: {
                showSubmissionSheet = true
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#667eea").opacity(0.3),
                                        Color(hex: "#764ba2").opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Submit Proof")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Complete to earn rewards")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#667eea"),
                                    Color(hex: "#764ba2")
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color(hex: "#667eea").opacity(0.4), radius: 15, y: 8)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Progress indicator (removed for now since Challenge doesn't have progress property)
            /*if displayChallenge.progress > 0 && displayChallenge.progress < 1 {
                HStack {
                    Text("Progress: \(Int(displayChallenge.progress * 100))%")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                    
                    ProgressView(value: displayChallenge.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: "#43e97b")))
                        .frame(width: 120)
                }
                .padding(.horizontal, 20)
            }*/
        }
    }
    
    private var completedBadge: some View {
        HStack {
            Image(systemName: "checkmark.seal.fill")
                .font(.title)
                .foregroundColor(.green)
            Text("Challenge Completed!")
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.5), lineWidth: 1)
                )
        )
    }
    
    private var requirementsSection: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Requirements", systemImage: "checklist")
                    .font(.headline)
                    .foregroundColor(.white)
                
                ForEach(Array(decodedRequirements.enumerated()), id: \.offset) { _, requirement in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#43e97b"))
                        
                        Text(requirement)
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                }
            }
            .padding()
        }
    }
    
    private var rewardsSection: some View {
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Rewards", systemImage: "gift.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack(spacing: 30) {
                    // Points
                    VStack(spacing: 4) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.yellow)
                        Text("\(displayChallenge.points)")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        Text("Points")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    // Coins
                    VStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(Color(hex: "#FFD700"))
                        Text("\(displayChallenge.coins)")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        Text("Coins")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .padding()
        }
    }
    
    private var participantsSection: some View {
        GlassmorphicCard {
            HStack {
                Label("\(displayChallenge.participants) participants", systemImage: "person.3.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                Text(displayChallenge.timeRemaining)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding()
        }
    }
    
    // MARK: - Submission Sheet
    
    private var submissionSheet: some View {
        NavigationStack {
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [
                        Color(hex: "#1a1a2e"),
                        Color(hex: "#16213e")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Animated particles
                GeometryReader { geometry in
                    ForEach(0..<15, id: \.self) { index in
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#667eea").opacity(0.3),
                                        Color(hex: "#764ba2").opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: CGFloat.random(in: 20...60))
                            .position(
                                x: CGFloat.random(in: 0...geometry.size.width),
                                y: CGFloat.random(in: 0...geometry.size.height)
                            )
                            .blur(radius: 10)
                            .opacity(0.3)
                    }
                }
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header with icon
                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: "#667eea").opacity(0.2),
                                                Color(hex: "#764ba2").opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                    .blur(radius: 20)
                                
                                Image(systemName: iconForChallenge())
                                    .font(.system(size: 50, weight: .semibold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: "#667eea"),
                                                Color(hex: "#764ba2")
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            
                            VStack(spacing: 8) {
                                Text("Complete Challenge")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text(displayChallenge.title)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, 20)
                        
                        // Image Selection Section
                        VStack(spacing: 20) {
                            Text("Add Your Proof")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                            
                            if let image = selectedImage {
                                // Selected image display
                                ZStack {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 280)
                                        .frame(maxWidth: .infinity)
                                        .clipped()
                                        .cornerRadius(20)
                                        .overlay(
                                            LinearGradient(
                                                colors: [
                                                    Color.black.opacity(0.3),
                                                    Color.clear
                                                ],
                                                startPoint: .top,
                                                endPoint: .center
                                            )
                                            .cornerRadius(20)
                                        )
                                    
                                    // Remove button
                                    VStack {
                                        HStack {
                                            Spacer()
                                            Button(action: { 
                                                withAnimation(.spring()) {
                                                    selectedImage = nil 
                                                }
                                            }) {
                                                ZStack {
                                                    Circle()
                                                        .fill(.ultraThinMaterial)
                                                        .frame(width: 36, height: 36)
                                                    
                                                    Image(systemName: "xmark")
                                                        .font(.system(size: 14, weight: .bold))
                                                        .foregroundColor(.white)
                                                }
                                            }
                                            .padding(12)
                                        }
                                        Spacer()
                                    }
                                }
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .scale(scale: 0.8).combined(with: .opacity)
                                ))
                            } else {
                                // Image source selection buttons
                                HStack(spacing: 16) {
                                    Button(action: { 
                                        showSubmissionSheet = false
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            imageSourceType = .camera
                                        }
                                    }) {
                                        VStack(spacing: 12) {
                                            ZStack {
                                                Circle()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [
                                                                Color(hex: "#667eea").opacity(0.2),
                                                                Color(hex: "#764ba2").opacity(0.1)
                                                            ],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                                    .frame(width: 60, height: 60)
                                                
                                                Image(systemName: "camera.fill")
                                                    .font(.system(size: 26, weight: .medium))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Text("Camera")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 140)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(.ultraThinMaterial)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 20)
                                                        .stroke(
                                                            LinearGradient(
                                                                colors: [
                                                                    Color.white.opacity(0.2),
                                                                    Color.white.opacity(0.1)
                                                                ],
                                                                startPoint: .top,
                                                                endPoint: .bottom
                                                            ),
                                                            lineWidth: 1
                                                        )
                                                )
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    
                                    Button(action: { 
                                        showSubmissionSheet = false
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            imageSourceType = .photoLibrary
                                        }
                                    }) {
                                        VStack(spacing: 12) {
                                            ZStack {
                                                Circle()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [
                                                                Color(hex: "#f093fb").opacity(0.2),
                                                                Color(hex: "#f5576c").opacity(0.1)
                                                            ],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                                    .frame(width: 60, height: 60)
                                                
                                                Image(systemName: "photo.fill")
                                                    .font(.system(size: 26, weight: .medium))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Text("Gallery")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 140)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(.ultraThinMaterial)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 20)
                                                        .stroke(
                                                            LinearGradient(
                                                                colors: [
                                                                    Color.white.opacity(0.2),
                                                                    Color.white.opacity(0.1)
                                                                ],
                                                                startPoint: .top,
                                                                endPoint: .bottom
                                                            ),
                                                            lineWidth: 1
                                                        )
                                                )
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                        }
                    
                        // Description Field with enhanced design
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "text.bubble.fill")
                                    .font(.system(size: 14))
                                Text("Add a Caption")
                                    .font(.system(size: 16, weight: .medium))
                                Text("(optional)")
                                    .font(.system(size: 14))
                                    .opacity(0.6)
                            }
                            .foregroundColor(.white.opacity(0.9))
                            
                            TextField("Share your experience...", text: $submissionDescription, axis: .vertical)
                                .textFieldStyle(.plain)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(
                                                    Color.white.opacity(0.1),
                                                    lineWidth: 1
                                                )
                                        )
                                )
                                .foregroundColor(.white)
                                .lineLimit(2...4)
                        }
                    
                    Spacer()
                    
                        // Submit Button with enhanced design
                        Button(action: submitProof) {
                            HStack(spacing: 12) {
                                if isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.9)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                    Text("Submit Proof")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: selectedImage != nil ? 
                                                [Color(hex: "#667eea"), Color(hex: "#764ba2")] : 
                                                [Color.gray.opacity(0.5), Color.gray.opacity(0.3)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .shadow(
                                        color: selectedImage != nil ? 
                                            Color(hex: "#667eea").opacity(0.4) : 
                                            Color.clear,
                                        radius: 20,
                                        y: 10
                                    )
                            )
                        }
                        .disabled(selectedImage == nil || isSubmitting)
                        .buttonStyle(ScaleButtonStyle())
                        
                        // Rewards preview
                        if selectedImage != nil && !isSubmitting {
                            HStack(spacing: 20) {
                                HStack(spacing: 6) {
                                    Image(systemName: "star.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.yellow)
                                    Text("+\(displayChallenge.points) points")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "dollarsign.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hex: "#FFD700"))
                                    Text("+\(displayChallenge.coins) coins")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showSubmissionSheet = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                            )
                    }
                }
            }
        }
        .onChange(of: selectedImage) { _ in
            // If an image was selected from camera/gallery, reopen submission sheet
            if selectedImage != nil && !showSubmissionSheet {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showSubmissionSheet = true
                }
            }
        }
    }
    
    // MARK: - Celebration Overlay
    
    private var celebrationOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Trophy Animation
                Image(systemName: "trophy.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.yellow)
                    .scaleEffect(showCelebration ? 1.2 : 0.5)
                    .animation(.spring(response: 0.6, dampingFraction: 0.5), value: showCelebration)
                
                Text("AWESOME!")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                
                // Rewards Display
                HStack(spacing: 40) {
                    VStack(spacing: 8) {
                        Text("+\(pointsEarned)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.yellow)
                        Text("POINTS")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    VStack(spacing: 8) {
                        Text("+\(coinsEarned)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(Color(hex: "#FFD700"))
                        Text("COINS")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .scaleEffect(showCelebration ? 1 : 0.8)
            .opacity(showCelebration ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showCelebration)
        }
    }
    
    // MARK: - Share Prompt Overlay
    
    private var sharePromptOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Share with Friends!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Let everyone know about your achievement")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 20) {
                    Button(action: {
                        showSharePrompt = false
                        dismiss()
                    }) {
                        Text("Skip")
                            .padding(.horizontal, 40)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                    }
                    
                    Button(action: {
                        showSharePrompt = false
                        showBrandedShare = true
                    }) {
                        Text("Share Now")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding()
        }
        .transition(.opacity)
    }
    
    // MARK: - Helper Functions
    
    private func iconForChallenge() -> String {
        switch displayChallenge.type {
        case .daily:
            return "sun.max.fill"
        case .weekly:
            return "calendar.circle.fill"
        case .special:
            return "star.circle.fill"
        case .community:
            return "person.3.fill"
        }
    }
    
    private func joinChallenge() {
        guard authManager.isAuthenticated else { return }
        
        isJoining = true
        
        Task {
            // Mark as joined locally
            gamificationManager.joinChallenge(displayChallenge)
            
            // Sync to CloudKit
            if let userID = authManager.currentUser?.id.uuidString {
                // Save join status to CloudKit
                let container = CKContainer(identifier: CloudKitConfig.containerIdentifier)
                let database = container.publicCloudDatabase
                let recordID = CKRecord.ID(recordName: "uc_\(userID)_\(displayChallenge.id)")
                let record = CKRecord(recordType: CloudKitConfig.userChallengeRecordType, recordID: recordID)
                record[CKField.UserChallenge.userID] = userID
                record[CKField.UserChallenge.challengeID] = CKRecord.Reference(
                    recordID: CKRecord.ID(recordName: displayChallenge.id),
                    action: .none
                )
                record[CKField.UserChallenge.status] = "joined"
                record[CKField.UserChallenge.startedAt] = Date()
                record[CKField.UserChallenge.progress] = 0.0
                _ = try? await database.save(record)
                print("✅ Saved challenge join to CloudKit")
            }
            
            await MainActor.run {
                isJoining = false
                joinSuccess = true
            }
        }
    }
    
    private func submitProof() {
        guard let image = selectedImage else { return }
        guard !isSubmitting else { return }
        
        isSubmitting = true
        showSubmissionSheet = false
        
        Task {
            // Calculate rewards
            pointsEarned = calculatePoints()
            coinsEarned = pointsEarned / 10
            
            // Update local state
            await MainActor.run {
                gamificationManager.markChallengeCompleted(displayChallenge.id)
                gamificationManager.awardPoints(pointsEarned, reason: "Completed \(displayChallenge.title)")
            }
            
            // Save to CloudKit
            if let userID = authManager.currentUser?.id.uuidString {
                try? await saveToCloudKit(image: image, userID: userID)
            }
            
            // Show celebration
            await MainActor.run {
                isSubmitting = false
                showCelebration = true
                
                // Play confetti animation
                rewardAnimator.playChallengeCompletion(
                    tier: displayChallenge.type == .weekly ? .gold : .silver,
                    coins: coinsEarned
                )
                
                // Transition to share prompt after celebration
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    showCelebration = false
                    showSharePrompt = true
                }
            }
        }
    }
    
    private func calculatePoints() -> Int {
        switch displayChallenge.type {
        case .daily:
            return 100
        case .weekly:
            return 500
        case .special:
            return 750
        case .community:
            return 1000
        }
    }
    
    private func saveToCloudKit(image: UIImage, userID: String) async throws {
        let container = CKContainer(identifier: CloudKitConfig.containerIdentifier)
        let database = container.publicCloudDatabase
        
        // Create UserChallenge record
        let recordID = CKRecord.ID(recordName: "uc_\(userID)_\(displayChallenge.id)")
        let record = CKRecord(recordType: CloudKitConfig.userChallengeRecordType, recordID: recordID)
        
        record[CKField.UserChallenge.userID] = userID
        record[CKField.UserChallenge.challengeID] = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: displayChallenge.id),
            action: .none
        )
        record[CKField.UserChallenge.status] = "completed"
        record[CKField.UserChallenge.progress] = 1.0
        record[CKField.UserChallenge.completedAt] = Date()
        record[CKField.UserChallenge.earnedPoints] = Int64(pointsEarned)
        record[CKField.UserChallenge.earnedCoins] = Int64(coinsEarned)
        record[CKField.UserChallenge.notes] = submissionDescription
        
        // Add image
        if let imageData = image.jpegData(compressionQuality: 0.8),
           let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("\(UUID().uuidString).jpg") {
            try imageData.write(to: url)
            record[CKField.UserChallenge.proofImage] = CKAsset(fileURL: url)
        }
        
        _ = try await database.save(record)
    }
    
    private func createShareContent() -> ShareContent? {
        // ShareContent might not have a public initializer, return nil for now
        // This would need to be fixed with proper ShareContent initialization
        return nil
    }
}

// MARK: - Supporting Views

// MARK: - Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// Custom image pickers for ChallengeDetailView to avoid conflicts

struct ChallengeImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    @MainActor
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ChallengeImagePicker
        
        init(_ parent: ChallengeImagePicker) {
            self.parent = parent
        }
        
        @MainActor
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
                    guard let self = self, let uiImage = image as? UIImage else { return }
                    Task { @MainActor in
                        self.parent.image = uiImage
                    }
                }
            }
        }
    }
}

struct ChallengeCameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ChallengeCameraView
        
        init(_ parent: ChallengeCameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}