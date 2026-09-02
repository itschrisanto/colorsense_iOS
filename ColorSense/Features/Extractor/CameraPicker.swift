import SwiftUI
import UIKit

/// Camera capture for the Extractor.
///
/// SwiftUI has no camera picker of its own — `PhotosPicker` only reaches the library — so this
/// wraps `UIImagePickerController`. `PHPickerViewController` superseded it for *library* access,
/// which is why the library side uses `PhotosPicker`, but camera capture is still what
/// `UIImagePickerController` is for and it is not deprecated for that use.
///
/// `isAvailable` gates the picker's camera cell, so a device without a camera never shows one.
/// Note it reports *hardware*, not permission — current simulators do provide a synthetic camera
/// and return true, and a user who has denied camera access still returns true and lands on the
/// system's own denied screen inside the capture controller.
struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker

        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // `.editedImage` is absent unless allowsEditing is set, which it deliberately is not:
            // cropping before extraction would quietly change which colors the palette is drawn
            // from, and the user has no way to know that.
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
