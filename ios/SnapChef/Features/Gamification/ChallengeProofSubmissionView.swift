import SwiftUI
import PhotosUI
import CloudKit

struct ChallengeProofSubmissionView: View {
    let challenge: Challenge
    @Environment(\.dismiss) var dismiss
    @StateObject private var cloudKitSync = CloudKitSyncService.shared
    @StateObject private var gamificationManager = GamificationManager.shared
    
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var notes = ""
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var submissionSuccess = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 60))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Text("Submit Your Proof")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text(challenge.title)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.top, 20)
                        
                        // Image Selection
                        VStack(spacing: 16) {
                            if let image = selectedImage {
                                // Show selected image
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 300)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 10)
                                
                                Button(action: {
                                    withAnimation(.spring()) {
                                        selectedImage = nil
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "xmark.circle.fill")
                                        Text("Remove Photo")
                                    }
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.red.opacity(0.2))
                                    .cornerRadius(8)
                                }
                            } else {
                                // Photo selection buttons
                                VStack(spacing: 12) {
                                    Button(action: {
                                        showCamera = true
                                    }) {
                                        HStack {
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 20))
                                            Text("Take Photo")
                                                .font(.system(size: 18, weight: .semibold))
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(
                                            LinearGradient(
                                                colors: [
                                                    Color(hex: "#4facfe"),
                                                    Color(hex: "#00f2fe")
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(12)
                                    }
                                    
                                    Button(action: {
                                        showImagePicker = true
                                    }) {
                                        HStack {
                                            Image(systemName: "photo.on.rectangle")
                                                .font(.system(size: 20))
                                            Text("Choose from Library")
                                                .font(.system(size: 18, weight: .semibold))
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color.white.opacity(0.2))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Notes Section
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Add Notes (Optional)", systemImage: "note.text")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            TextEditor(text: $notes)
                                .frame(height: 100)
                                .padding(8)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                                .scrollContentBackground(.hidden)
                        }
                        .padding(.horizontal, 20)
                        
                        // Challenge Requirements Reminder
                        GlassmorphicCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Challenge Requirements", systemImage: "checklist")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                ForEach(challenge.requirements, id: \.self) { requirement in
                                    HStack {
                                        Image(systemName: "checkmark.circle")
                                            .foregroundColor(Color(hex: "#43e97b"))
                                            .font(.system(size: 14))
                                        Text(requirement)
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.8))
                                        Spacer()
                                    }
                                }
                            }
                            .padding(16)
                        }
                        .padding(.horizontal, 20)
                        
                        // Submit Button
                        Button(action: submitProof) {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.9)
                                } else {
                                    Image(systemName: submissionSuccess ? "checkmark.circle.fill" : "paperplane.fill")
                                        .font(.system(size: 18))
                                    Text(submissionSuccess ? "Submitted!" : "Submit Completed Challenge")
                                        .font(.system(size: 18, weight: .bold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: submissionSuccess ? [Color.green, Color.green.opacity(0.8)] : [
                                        Color(hex: "#667eea"),
                                        Color(hex: "#764ba2")
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: Color(hex: "#667eea").opacity(0.3), radius: 10)
                        }
                        .padding(.horizontal, 20)
                        .disabled(selectedImage == nil || isSubmitting || submissionSuccess)
                        .opacity(selectedImage == nil ? 0.5 : 1.0)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ProofImagePicker(image: $selectedImage)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker(image: $selectedImage)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: submissionSuccess) { success in
            if success {
                // Dismiss after successful submission
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            }
        }
    }
    
    private func submitProof() {
        guard let image = selectedImage else { return }
        
        isSubmitting = true
        
        Task {
            do {
                // Upload proof to CloudKit
                try await cloudKitSync.submitChallengeProof(
                    challengeID: challenge.id,
                    proofImage: image,
                    notes: notes.isEmpty ? nil : notes
                )
                
                // Update progress
                await MainActor.run {
                    gamificationManager.updateChallengeProgress(challenge.id, progress: 1.0)
                    
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    isSubmitting = false
                    submissionSuccess = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to submit proof: \(error.localizedDescription)"
                    showError = true
                    isSubmitting = false
                }
            }
        }
    }
}

// MARK: - Camera Image Picker
struct CameraImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraImagePicker
        
        init(_ parent: CameraImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
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
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ProofImagePicker
        
        init(_ parent: ProofImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    if let uiImage = image as? UIImage {
                        Task { @MainActor in
                            self.parent.image = uiImage
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ChallengeProofSubmissionView(challenge: Challenge(
        title: "Pasta Master",
        description: "Create 5 different pasta dishes",
        type: .weekly,
        endDate: Date().addingTimeInterval(5 * 24 * 60 * 60),
        requirements: ["Cook 5 pasta recipes", "Share with friends"],
        currentProgress: 0.4,
        participants: 234
    ))
}