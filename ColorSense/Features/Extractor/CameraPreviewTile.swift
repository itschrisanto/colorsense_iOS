import AVFoundation
import SwiftUI
import UIKit

/// The live camera shown in the picker's first cell.
///
/// Deliberately only ever shown when camera access is *already* granted. Starting a capture
/// session is what triggers the permission prompt, and firing that the instant the picker opens
/// would ask for the camera before the user has expressed any interest in it — on top of the
/// photo-library prompt they are already answering. Until then the cell falls back to a glyph,
/// and the first tap prompts through the capture screen itself, where the ask has obvious cause.
struct CameraPreviewTile: UIViewRepresentable {
    func makeUIView(context: Context) -> PreviewView { PreviewView() }

    func updateUIView(_ view: PreviewView, context: Context) {}

    static func dismantleUIView(_ view: PreviewView, coordinator: ()) {
        view.stop()
    }

    /// Backed by `AVCaptureVideoPreviewLayer` as the view's own layer, which is the supported way
    /// to show a preview — adding it as a sublayer means resizing it by hand on every bounds
    /// change.
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        private var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        private let session = AVCaptureSession()
        /// Configuration and `startRunning()` both block, so they stay off the main thread.
        private let queue = DispatchQueue(label: "online.colorsense.camera-preview")

        override init(frame: CGRect) {
            super.init(frame: frame)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.session = session
            start()
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        private func start() {
            queue.async { [session] in
                session.beginConfiguration()
                session.sessionPreset = .medium  // a thumbnail needs no more than this
                if
                    let device = AVCaptureDevice.default(for: .video),
                    let input = try? AVCaptureDeviceInput(device: device),
                    session.canAddInput(input)
                {
                    session.addInput(input)
                }
                session.commitConfiguration()
                session.startRunning()
            }
        }

        func stop() {
            queue.async { [session] in
                if session.isRunning { session.stopRunning() }
            }
        }

        deinit { stop() }
    }
}
