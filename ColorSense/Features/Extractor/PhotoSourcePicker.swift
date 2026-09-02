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
        .onChange(of: fallbackItem) { _, item in
            guard let item else { return }
            Task { await loadFallback(item) }
        }
        .fullScreenCover(isPresented: $cameraIsPresented) {
            CameraPicker { image in
                onImage(image)
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
                    ForEach(assets, id: \.localIdentifier) { asset in
                        Button { choose(asset) } label: {
                            AssetThumbnail(asset: asset, side: side)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Photo taken \(asset.creationDate.map(Self.dateText) ?? "at an unknown time")")
                    }
                }
            }
        }
    }

    private func cameraCell(side: CGFloat) -> some View {
        Button { cameraIsPresented = true } label: {
            ZStack {
                Color.black
                // Live only when the camera is already permitted — see CameraPreviewTile.
                if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
                    CameraPreviewTile()
                }
                Image(systemName: "camera.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(radius: 3)
            }
            .frame(width: side, height: side)
            .clipped()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Take a photo")
    }

    private var deniedState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 34))
                .foregroundStyle(BrandColor.coral)
            Text("ColorSense can't see your photos")
                .font(BrandFont.ui(17, weight: .bold))
            Text("Allow photo access to pull a palette from a picture you already have. You can still take a new photo.")
                .font(BrandFont.ui(14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(BrandFont.ui(15, weight: .medium))
            Button("Take a photo instead") { cameraIsPresented = true }
                .font(BrandFont.ui(15, weight: .medium))
            // Still works with access denied: PhotosPicker runs out of process, so the system
            // hands back the one chosen image without this app ever seeing the library.
            PhotosPicker(selection: $fallbackItem, matching: .images) {
                Text("Choose a photo instead")
                    .font(BrandFont.ui(15, weight: .medium))
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Photos

    private func requestAccess() async {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        let granted = current == .notDetermined
            ? await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            : current
        status = granted
        if granted == .authorized || granted == .limited { loadAssets() }
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
