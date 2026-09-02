@preconcurrency import AVFoundation
import os
import SwiftUI

/// Owns the capture session behind the picker's live camera tile.
///
/// It exists as a separate object because the session's life must *not* be tied to the view's.
/// The tile was originally a `UIViewRepresentable` that built an `AVCaptureSession` in its `init`
/// and tore it down in `deinit`, which meant SwiftUI rebuilding that view rebuilt the session —
/// and SwiftUI rebuilds views constantly. Tapping any cell in the grid changes state, re-renders,
/// and churned a new session each time. On device that crashed; the simulator only logged it:
///
///     _stopFigCaptureSession: Timed out waiting for session to stop
///     _postRuntimeError: AVFoundationErrorDomain Code=-11819 "Cannot Complete Action"
///     AVCaptureSession dealloc
///
/// Held in `@State` by the picker, this is created once and lives as long as the screen does.
/// The view attaches to it and never controls it.
@MainActor
final class CameraPreviewSession {
    let session = AVCaptureSession()

    /// Configuration and start/stop all block, so none of them run on the main thread.
    private let queue = DispatchQueue(label: "online.colorsense.camera-preview")
    private var isConfigured = false

    /// Safe to call repeatedly — configuration happens once, and starting a running session is a
    /// no-op. That matters because SwiftUI can re-run `onAppear` more than once.
    func start() {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        let session = session
        let configureIfNeeded = !isConfigured
        isConfigured = true
        queue.async {
            if configureIfNeeded {
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
            }
            if !session.isRunning { session.startRunning() }
        }
    }

    /// Stops, then calls back on the main actor once the camera is actually released.
    ///
    /// The completion is the point. `stopRunning()` is synchronous on the session queue but
    /// asynchronous from the caller's view, so presenting the capture screen immediately after
    /// asking to stop races it — and two things reaching for one camera is its own failure. The
    /// picker therefore waits for this before opening the camera.
    func stop(then completion: (@MainActor () -> Void)? = nil) {
        let session = session
        guard let completion else {
            queue.async { if session.isRunning { session.stopRunning() } }
            return
        }

        // The completion runs when the stop finishes *or* when a short deadline passes,
        // whichever comes first, and exactly once either way.
        //
        // Gating purely on the stop was a 9-second stall: `stopRunning()` can block that long
        // when the session is wedged — measured in the simulator as "Timed out waiting for
        // session to stop", 9.0s, with the capture screen not appearing until it returned. A UI
        // action must not inherit AVFoundation's worst case. Releasing the camera first is still
        // worth attempting, so the deadline is a floor on responsiveness rather than a
        // replacement for waiting.
        let hasResumed = OSAllocatedUnfairLock(initialState: false)
        func resumeOnce() {
            let alreadyRan = hasResumed.withLock { ran -> Bool in
                defer { ran = true }
                return ran
            }
            guard !alreadyRan else { return }
            Task { @MainActor in completion() }
        }

        queue.async {
            if session.isRunning { session.stopRunning() }
            resumeOnce()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { resumeOnce() }
    }
}

/// Shows a session that something else owns. Deliberately holds no lifecycle of its own: it
/// attaches the layer and nothing more, so SwiftUI rebuilding it costs nothing.
struct CameraPreviewTile: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.session = session
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        view.session = session
    }

    /// Backed by `AVCaptureVideoPreviewLayer` as the view's own layer, which is the supported way
    /// to show a preview — a sublayer would need resizing by hand on every bounds change.
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var session: AVCaptureSession? {
            didSet { scheduleLayerUpdate() }
        }

        private var layerUpdateGeneration = 0

        private var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            scheduleLayerUpdate()
        }

        private func scheduleLayerUpdate() {
            // AVFoundation mutates capture-session state when this property changes. Doing that
            // synchronously inside make/updateUIView re-enters SwiftUI while its AttributeGraph
            // transaction is still open. Defer one run-loop turn, and invalidate stale work when
            // a lazy cell is discarded before it ever reaches a window.
            layerUpdateGeneration += 1
            let generation = layerUpdateGeneration
            DispatchQueue.main.async { [weak self] in
                guard let self, generation == self.layerUpdateGeneration else { return }
                self.applyLayerState()
            }
        }

        private func applyLayerState() {
            previewLayer.videoGravity = .resizeAspectFill
            let visibleSession = window == nil ? nil : session
            if previewLayer.session !== visibleSession {
                previewLayer.session = visibleSession
            }
        }
    }
}
