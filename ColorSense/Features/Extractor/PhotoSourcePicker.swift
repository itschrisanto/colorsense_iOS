import AVFoundation
import Photos
import PhotosUI
import SwiftUI

/// One screen for both extraction sources: the user's recent photos as a grid, with the camera
/// as its first cell.
///
/// This is a custom picker rather than `PhotosPicker` because `PHPickerViewController` — which
/// `PhotosPicker` wraps — runs out of process precisely so an app never touches the library, and
/// so cannot host a camera cell or any other chrome. Putting the camera in the grid therefore
/// costs read access to the library, which is the trade this screen exists to make.
///
/// Nothing here leaves the device: a chosen image is downsampled and clustered on-device by
/// `ColorExtractionService`, and the asset itself is never copied, uploaded or retained.
struct PhotoSourcePicker: View {
    let onImage: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var assets: [PHAsset] = []
    @State private var status: PHAuthorizationStatus = .notDetermined
    @State private var cameraIsPresented = false
    @State private var isLoadingSelection = false
    /// Used only from the denied state: `PhotosPicker` runs out of process, so it still works
    /// when this screen has no library access of its own.
    @State private var fallbackItem: PhotosPickerItem?
    @State private var loadFailed = false
    /// Created once and owned by this screen, not by the tile view — see CameraPreviewSession.
    @State private var preview = CameraPreviewSession()
    /// Read once into state rather than called in `body`. Evaluating it inline made the branch
    /// around the preview re-decide on every render, which is part of what let SwiftUI rebuild
    /// the representable repeatedly.
    @State private var cameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized

    /// Three across, hairline gutters — the grid is the content, so it runs edge to edge rather
    /// than sitting inside the app's usual card padding.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        NavigationStack {
            Group {
                switch status {
                case .authorized, .limited:
                    grid
                case .denied, .restricted:
                    deniedState
                default:
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Recents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                }
                // Limited access hides most of the library, and without a way back to the system
                // sheet the grid just looks broken to anyone who granted it by accident.
                if status == .limited {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Manage") { presentLimitedPicker() }
                    }
                }
            }
            .alert("Couldn't read that photo", isPresented: $loadFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("It may still be downloading from iCloud, or be in a format ColorSense can't open. Try another one.")
            }
            .overlay {
                if isLoadingSelection {
                    ZStack {
                        Color.black.opacity(0.35)
                        ProgressView().tint(.white)
                    }
                    .ignoresSafeArea()
                }
            }
        }
        .task { await requestAccess() }
        // Drives the exact tail of a successful selection without a finger: onImage then
        // dismiss, which is what choose(_:), loadFallback(_:) and the camera callback all do.
        // osascript has no assistive access here, so this is the only way to reproduce the
        // re-present headlessly and, more importantly, to test a fix for it.
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-auto-pick") else { return }
            try? await Task.sleep(for: .seconds(6))
            guard let image = UIImage(named: "LaumaWelcome") else {
                diagLog("auto-pick: no image asset, aborting")
                return
            }
            diagLog("auto-pick: calling onImage then dismiss")
            onImage(image)
            dismiss()
            diagLog("auto-pick: dismiss returned")
        }
        .task {
            diagLog("picker task, args=\(ProcessInfo.processInfo.arguments)")
            guard ProcessInfo.processInfo.arguments.contains("-auto-camera") else { return }
            try? await Task.sleep(for: .seconds(8))
            diagLog("auto firing camera tap, status=\(status.rawValue) authorized=\(cameraAuthorized)")
            preview.stop {
                diagLog("auto stop completed")
                cameraIsPresented = true
                diagLog("auto cameraIsPresented set")
            }
        }
        .onAppear {
            diagLog("picker onAppear: cameraCellRendered=\(CameraPicker.isAvailable) authorized=\(cameraAuthorized) assets=\(assets.count) status=\(status.rawValue)")
            preview.start()
        }
        .onDisappear {
            diagLog("picker onDisappear")
            preview.stop()
        }
        .onChange(of: fallbackItem) { _, item in
            guard let item else { return }
            Task { await loadFallback(item) }
        }
        .fullScreenCover(isPresented: $cameraIsPresented, onDismiss: {
            diagLog("camera cover dismissed")
            preview.start()
        }) {
            CameraPicker { image in
                AnalyticsService.capture(.paletteExtracted, ["source": "camera"])
                diagLog("image delivered \(Int(image.size.width))x\(Int(image.size.height)), calling onImage")
                onImage(image)
                diagLog("onImage returned, dismissing picker")
                dismiss()
            }
            .ignoresSafeArea()
        }
    }

    private var grid: some View {
        GeometryReader { proxy in
            let side = (proxy.size.width - 4) / 3
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    // Hardware check, not a permission one — a device with no camera should not
                    // show the cell at all.
                    if CameraPicker.isAvailable {
                        cameraCell(side: side)
                    }
                    ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { position, asset in
                        Button {
                            diagLog("photo button at grid position \(position) activated")
                            choose(asset)
                        } label: {
                            AssetThumbnail(asset: asset, side: side)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Photo taken \(asset.creationDate.map(Self.dateText) ?? "at an unknown time")")
                    }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onEnded { value in
                        diagLog("finger down at \(value.startLocation), up at \(value.location)")
                    }
            )
        }
    }

    private func cameraCell(side: CGFloat) -> some View {
        // Stops the preview and waits for the camera to actually be released before opening the
        // capture screen. Presenting first would leave two things reaching for one camera.
        Button {
            diagLog("camera cell TAPPED")
            preview.stop {
                diagLog("stop done, presenting camera")
                cameraIsPresented = true
            }
        } label: {
            ZStack {
                Color.black
                // Live only when the camera is already permitted — starting a session is what
                // triggers that prompt, and the picker should not ask before the user shows any
                // interest in the camera.
                if cameraAuthorized {
                    // A UIView has isUserInteractionEnabled on by default, so a representable
                    // inside a Button's label can take the touch that belongs to the button.
                    CameraPreviewTile(session: preview.session)
                        .allowsHitTesting(false)
                }
                Image(systemName: "camera.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(radius: 3)
            }
            .frame(width: side, height: side)
            .clipped()
            // `.clipped()` clips drawing, not hit testing. Without an explicit shape the cell's
            // tappable area is whatever its contents happen to claim.
            .contentShape(.rect)
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear {
                        diagLog("camera cell frame in global space = \(geo.frame(in: .global))")
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Take a photo")
    }

    private var deniedState: some View {
        // UNSURE rather than SAD: a refused permission is a shrug, not a failure, and the three
        // routes below mean the reader is not actually stuck.
        LaumaNotice(
            pose: .unsure,
            title: "ColorSense can't see your photos",
            message: "Allow photo access to pull a palette from a picture you already have. You can still take a new photo."
        ) {
            VStack(spacing: 12) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Take a photo instead") { cameraIsPresented = true }
                // Still works with access denied: PhotosPicker runs out of process, so the system
                // hands back the one chosen image without this app ever seeing the library.
                PhotosPicker(selection: $fallbackItem, matching: .images) {
                    Text("Choose a photo instead")
                        .font(BrandFont.ui(15, weight: .medium))
                }
            }
        }
    }

    // MARK: - Photos

    private func requestAccess() async {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        let granted = current == .notDetermined
            ? await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            : current
        status = granted
        if granted == .authorized || granted == .limited {
            loadAssets()
        } else if granted == .denied || granted == .restricted {
            // Explains the drop between opening the picker and producing a palette.
            AnalyticsService.capture(.permissionDenied, ["permission": "photos"])
        }
    }

    private func loadAssets() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        // A cap rather than the whole library: the grid is for reaching a recent picture, and
        // fetching tens of thousands of assets to show the first screenful is wasted work.
        options.fetchLimit = 300
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var found: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in found.append(asset) }
        assets = found
    }

    private func choose(_ asset: PHAsset) {
        diagLog("photo chosen, requesting image")
        isLoadingSelection = true
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true   // the asset may live in iCloud, not on the device
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact

        // Far smaller than the original: ColorExtractionService downsamples to ~100px a side
        // anyway, so requesting full resolution would only cost time and memory.
        let target = CGSize(width: 800, height: 800)
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: target,
            contentMode: .aspectFit,
            options: options
        ) { image, info in
            // Opportunistic delivery can call back more than once; only the final, non-degraded
            // image should be used, and a nil image means the load failed outright.
            let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            guard !degraded else { return }
            Task { @MainActor in
                isLoadingSelection = false
                guard let image else {
                    // Reachable for real: an iCloud asset that cannot be fetched, or one whose
                    // format will not decode. Saying nothing here would repeat the bug this
                    // screen's predecessor had.
                    AnalyticsService.capture(.extractionFailed, ["source": "library"])
                    loadFailed = true
                    return
                }
                onImage(image)
                dismiss()
            }
        }
    }

    private func loadFallback(_ item: PhotosPickerItem) async {
        isLoadingSelection = true
        defer { isLoadingSelection = false; fallbackItem = nil }
        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
        else {
            AnalyticsService.capture(.extractionFailed, ["source": "library_fallback"])
            loadFailed = true
            return
        }
        onImage(image)
        dismiss()
    }

    private func presentLimitedPicker() {
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let root = scene.keyWindow?.rootViewController
        else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: root)
    }

    private static func dateText(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

/// One photo in the grid. Thumbnails load individually and asynchronously so the grid can paint
/// immediately rather than waiting on the whole fetch.
private struct AssetThumbnail: View {
    let asset: PHAsset
    let side: CGFloat

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: side, height: side)
        .clipped()
        // `.clipped()` clips drawing, not hit testing, and `scaledToFill` deliberately overflows:
        // a portrait photo in a square cell is far taller than the cell. Without an explicit
        // shape that overflow stays tappable, so a thumbnail steals touches from its neighbours —
        // including the camera cell above it, which is later in the grid and therefore underneath.
        .contentShape(.rect)
        .onAppear(perform: load)
    }

    private func load() {
        guard image == nil else { return }
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        let scale = UIScreen.main.scale
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: side * scale, height: side * scale),
            contentMode: .aspectFill,
            options: options
        ) { result, _ in
            // Assigned on every callback rather than only the last: opportunistic delivery hands
            // back a fast low-quality image first, and showing that immediately is the point.
            guard let result else { return }
            Task { @MainActor in image = result }
        }
    }
}
