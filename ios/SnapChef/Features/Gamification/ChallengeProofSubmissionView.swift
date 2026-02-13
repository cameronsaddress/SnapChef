import SwiftUI
import PhotosUI
import CloudKit

struct ChallengeProofSubmissionView: View {
    let challenge: Challenge
    @Environment(\.dismiss) var dismiss
    @StateObject private var gamificationManager = GamificationManager.shared
    
    // Image selection
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showCamera = false
    
    // Submission state
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Rewards
    @State private var pointsEarned = 0
    @State private var coinsEarned = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Image section
                    imageSection
                    
                    // Submit button
                    submitButton
                }
                .padding()
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Complete Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ProofImagePicker(image: $selectedImage)
        }
        .sheet(isPresented: $showCamera) {
            ProofCameraView(image: $selectedImage)
        }
        .alert("Success!", isPresented: $showSuccess) {
            Button("Share") {
                shareToSocial()
            }
            Button("Done") {
                dismiss()
            }
        } message: {
            Text("You earned \(pointsEarned) points and \(coinsEarned) coins!")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Challenge icon
            Image(systemName: iconForChallenge())
                .font(.system(size: 50))
                .foregroundColor(.accentColor)
            
            // Challenge title
            Text(challenge.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Challenge description
            Text(challenge.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Requirements
            if let requirement = challenge.requirements.first {
                Label(requirement, systemImage: "checkmark.circle")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
    
    private var imageSection: some View {
        VStack(spacing: 16) {
            Text("Upload Proof")
                .font(.headline)
            
            if let image = selectedImage {
                // Show selected image
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                    .overlay(
                        Button(action: { selectedImage = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding(8),
                        alignment: .topTrailing
                    )
            } else {
                // Image selection buttons
                HStack(spacing: 16) {
                    Button(action: { showCamera = true }) {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 40))
                            Text("Camera")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    Button(action: { showImagePicker = true }) {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 40))
                            Text("Gallery")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    private var submitButton: some View {
        Button(action: submitProof) {
            if isSubmitting {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Text("Submit Proof")
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(selectedImage != nil ? Color.accentColor : Color.gray)
        .foregroundColor(.white)
        .cornerRadius(12)
        .disabled(selectedImage == nil || isSubmitting)
    }
    
    // MARK: - Helper Functions
    
    private func iconForChallenge() -> String {
        switch challenge.type {
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
    
    private func submitProof() {
        guard let image = selectedImage else { return }
        guard !isSubmitting else { return }
        
        isSubmitting = true
        
        Task {
            do {
                // Calculate rewards
                pointsEarned = calculatePoints()
                coinsEarned = pointsEarned / 10
                
                // Update local state immediately
                await MainActor.run {
                    // Mark challenge as completed
                    gamificationManager.markChallengeCompleted(challenge.id)
                    
                    // Award points
                    gamificationManager.awardPoints(pointsEarned, reason: "Completed \(challenge.title)")
                }
                
                // Save to CloudKit
                try await saveToCloudKit(image: image)
                
                // Show success
                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                }
                
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "Failed to submit proof. Please try again."
                    showError = true
                }
            }
        }
    }
    
    private func calculatePoints() -> Int {
        switch challenge.type {
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
    
    private func saveToCloudKit(image: UIImage) async throws {
        guard let userID = UnifiedAuthManager.shared.currentUser?.id.uuidString else {
            throw NSError(domain: "ChallengeProof", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        guard let container = CloudKitRuntimeSupport.makeContainer() else {
            throw SnapChefError.syncError("CloudKit unavailable in this runtime")
        }
        let database = container.publicCloudDatabase
        
        // Create UserChallenge record
        let recordID = CKRecord.ID(recordName: "uc_\(userID)_\(challenge.id)")
        let record = CKRecord(recordType: CloudKitConfig.userChallengeRecordType, recordID: recordID)
        
        record[CKField.UserChallenge.userID] = userID
        record[CKField.UserChallenge.challengeID] = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: challenge.id),
            action: .none
        )
        record[CKField.UserChallenge.status] = "completed"
        record[CKField.UserChallenge.progress] = 1.0
        record[CKField.UserChallenge.completedAt] = Date()
        record[CKField.UserChallenge.earnedPoints] = Int64(pointsEarned)
        record[CKField.UserChallenge.earnedCoins] = Int64(coinsEarned)
        
        // Add image if available
        if let imageData = image.jpegData(compressionQuality: 0.8),
           let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("\(UUID().uuidString).jpg") {
            try imageData.write(to: url)
            record[CKField.UserChallenge.proofImage] = CKAsset(fileURL: url)
        }
        
        // Save record
        _ = try await database.save(record)
        
        // Update user stats
        try await updateUserStats(userID: userID, database: database)
        
        // Create activity
        try await createActivity(userID: userID, database: database)
    }
    
    private func updateUserStats(userID: String, database: CKDatabase) async throws {
        let userRecordID = CKRecord.ID(recordName: "user_\(userID)")
        
        do {
            let userRecord = try await database.record(for: userRecordID)
            
            // Update points
            let currentPoints = userRecord[CKField.User.totalPoints] as? Int64 ?? 0
            userRecord[CKField.User.totalPoints] = currentPoints + Int64(pointsEarned)
            
            // Update challenges completed
            let currentCompleted = userRecord[CKField.User.challengesCompleted] as? Int64 ?? 0
            userRecord[CKField.User.challengesCompleted] = currentCompleted + 1
            
            // Update last active
            userRecord[CKField.User.lastActivityAt] = Date()
            
            _ = try await database.save(userRecord)
        } catch {
            // If user record doesn't exist, that's ok - just log it
            print("Could not update user stats: \(error)")
        }
    }
    
    private func createActivity(userID: String, database: CKDatabase) async throws {
        let activity = CKRecord(recordType: CloudKitConfig.activityRecordType)
        
        activity[CKField.Activity.id] = UUID().uuidString
        activity[CKField.Activity.type] = "challengeCompleted"
        activity[CKField.Activity.actorID] = userID
        activity[CKField.Activity.timestamp] = Date()
        activity["title"] = "Completed \(challenge.title)"
        activity["subtitle"] = "+\(pointsEarned) points"
        activity[CKField.Activity.challengeID] = challenge.id
        activity[CKField.Activity.challengeName] = challenge.title
        
        _ = try await database.save(activity)
    }
    
    private func shareToSocial() {
        // Open share sheet
        if let image = selectedImage {
            let text = "I just completed the \(challenge.title) challenge on SnapChef! 🎉"
            let activityVC = UIActivityViewController(activityItems: [text, image], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }
        
        // Dismiss after sharing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}

// MARK: - Image Picker
struct ProofImagePicker: UIViewControllerRepresentable {
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
        let parent: ProofImagePicker
        
        init(_ parent: ProofImagePicker) {
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

// MARK: - Camera Picker View
struct ProofCameraView: UIViewControllerRepresentable {
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
        let parent: ProofCameraView
        
        init(_ parent: ProofCameraView) {
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
