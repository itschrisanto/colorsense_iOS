import SwiftUI
import UIKit

/// Diagnostic only. Appends to a file in the app container so a reproduction does not depend on a
/// console session staying attached — backgrounding the app ends the console, which was swallowing
/// every trace. Pulled afterwards with `devicectl device copy from --domain-type appDataContainer`.
func diagLog(_ message: String) {
    let line = "\(Date().formatted(date: .omitted, time: .standard))  \(message)  mem=\(diagFootprintMB())MB\n"
    FileHandle.standardError.write(line.data(using: .utf8)!)
    guard let dir = try? FileManager.default.url(
        for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
    ) else { return }
    let url = dir.appending(path: "diag.log")
    if let handle = try? FileHandle(forWritingTo: url) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        try? handle.close()
    } else {
        try? line.data(using: .utf8)!.write(to: url)
    }
}

func diagFootprintMB() -> Int {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    guard result == KERN_SUCCESS else { return -1 }
    return Int(info.phys_footprint / (1024 * 1024))
}

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
        diagLog("CameraPicker.makeUIViewController")
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
