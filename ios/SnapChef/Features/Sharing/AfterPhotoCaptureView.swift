import SwiftUI
import PhotosUI
import UIKit

struct AfterPhotoCaptureView: View {
    @Binding var afterPhoto: UIImage?
    let recipeID: String
    @Environment(\.dismiss) var dismiss
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var isUploading = false
    @State private var uploadError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                MagicalBackground()
                    .ignoresSafeArea()

                VStack(spacing: 30) {
                    // Title
                    Text("Capture Your Creation")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.top, 40)

                    Text("Show off your finished dish!")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.9))

                    // Preview area
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )

                        if let photo = afterPhoto {
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(20)
                                .padding(10)
                        } else {
                            VStack(spacing: 20) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white.opacity(0.5))

                                Text("No photo yet")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                    .frame(height: 300)
                    .padding(.horizontal, 20)

                    // Capture buttons
                    HStack(spacing: 20) {
                        MagneticButton(
                            title: "Take Photo",
                            icon: "camera.fill",
                            action: {
                                showCamera = true
                            }
                        )

                        MagneticButton(
                            title: "Choose Photo",
                            icon: "photo.fill",
                            action: {
                                showPhotoLibrary = true
                            }
                        )
                    }
                    .padding(.horizontal, 20)

                    Spacer()

                    // Save button
                    if afterPhoto != nil {
                        MagneticButton(
                            title: isUploading ? "Saving..." : "Save & Continue",
                            icon: "checkmark.circle.fill",
                            action: saveAndContinue
                        )
                        .disabled(isUploading)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.white)
            )
        }
        .sheet(isPresented: $showCamera) {
            AfterPhotoCameraCapture(image: $afterPhoto)
        }
        .sheet(isPresented: $showPhotoLibrary) {
            AfterPhotoLibraryPicker(image: $afterPhoto)
        }
        .alert("Error", isPresented: .constant(uploadError != nil)) {
            Button("OK") {
                uploadError = nil
            }
        } message: {
            Text(uploadError ?? "")
        }
    }

    private func saveAndContinue() {
        guard let photo = afterPhoto else { return }

        print("📷 AfterPhotoCapture: User captured after photo for recipe ID: \(recipeID)")
        isUploading = true

        Task {
            do {
                print("📷 AfterPhotoCapture: Starting upload to CloudKit...")
                // Save the after photo to CloudKit
                try await CloudKitRecipeManager.shared.updateAfterPhoto(for: recipeID, afterPhoto: photo)

                print("📷 AfterPhotoCapture: Upload successful, dismissing view")
                await MainActor.run {
                    isUploading = false
                    dismiss()
                }
            } catch {
                print("📷 AfterPhotoCapture: Upload failed - \(error.localizedDescription)")
                await MainActor.run {
                    isUploading = false
                    uploadError = "Failed to save photo: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Camera Capture
struct AfterPhotoCameraCapture: UIViewControllerRepresentable {
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
        let parent: AfterPhotoCameraCapture

        init(_ parent: AfterPhotoCameraCapture) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
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

// MARK: - Photo Library Picker
struct AfterPhotoLibraryPicker: UIViewControllerRepresentable {
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
        let parent: AfterPhotoLibraryPicker

        init(_ parent: AfterPhotoLibraryPicker) {
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
    AfterPhotoCaptureView(
        afterPhoto: .constant(nil),
        recipeID: "test-recipe-id"
    )
}
