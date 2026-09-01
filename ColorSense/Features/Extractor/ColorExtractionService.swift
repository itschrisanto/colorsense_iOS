import UIKit

/// Extracts the dominant colors from an image via k-means clustering on downsampled pixels.
/// Runs entirely on-device, no network call, so the extractor stays free/unlimited/no-signup
/// per the web app's positioning (vault: Claude Skill.md section 2).
enum ColorExtractionService {
    /// - Parameters:
    ///   - image: source image.
    ///   - count: number of dominant colors to return (default 5, matching the web extractor).
    ///   - sampleDimension: the image is downsampled to roughly this many pixels per side before
    ///     clustering, trading accuracy for speed. 100 is a good balance on-device.
    static func extractPalette(
        from image: UIImage,
        count: Int = 5,
        sampleDimension: Int = 100
    ) -> ExtractedPalette {
        let pixels = samplePixels(from: image, targetDimension: sampleDimension)
        let clusters = kMeans(pixels: pixels, k: count, iterations: 12)
        let total = Double(pixels.count)
        let colors = clusters
            .map { cluster in
                PaletteColor(
                    red: cluster.centroid.0,
                    green: cluster.centroid.1,
                    blue: cluster.centroid.2,
                    dominance: total > 0 ? Double(cluster.memberCount) / total : 0
                )
            }
            .sorted { $0.dominance > $1.dominance }
        return ExtractedPalette(colors: colors, createdAt: Date())
    }

    // MARK: - Pixel sampling

    private static func samplePixels(from image: UIImage, targetDimension: Int) -> [(Double, Double, Double)] {
        guard let cgImage = image.cgImage else { return [] }

        let scale = Double(targetDimension) / Double(max(cgImage.width, cgImage.height))
        let width = max(1, Int(Double(cgImage.width) * scale))
        let height = max(1, Int(Double(cgImage.height) * scale))

        var rawData = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var pixels: [(Double, Double, Double)] = []
        pixels.reserveCapacity(width * height)
        for i in stride(from: 0, to: rawData.count, by: 4) {
            let alpha = rawData[i + 3]
            guard alpha > 10 else { continue } // skip near-transparent pixels
            let r = Double(rawData[i]) / 255
            let g = Double(rawData[i + 1]) / 255
            let b = Double(rawData[i + 2]) / 255
            pixels.append((r, g, b))
        }
        return pixels
    }

    // MARK: - k-means

    private struct Cluster {
        var centroid: (Double, Double, Double)
        var memberCount: Int
    }

    private static func kMeans(
        pixels: [(Double, Double, Double)],
        k: Int,
        iterations: Int
    ) -> [Cluster] {
        guard !pixels.isEmpty, k > 0 else { return [] }
        let k = min(k, pixels.count)

        // k-means++ style seeding: spread initial centroids apart instead of picking randomly,
        // which avoids empty clusters and gives more stable results run to run.
        var centroids: [(Double, Double, Double)] = [pixels[Int.random(in: 0..<pixels.count)]]
        while centroids.count < k {
            let distances = pixels.map { pixel in
                centroids.map { squaredDistance(pixel, $0) }.min() ?? 0
            }
            let totalDistance = distances.reduce(0, +)
            guard totalDistance > 0 else {
                centroids.append(pixels[Int.random(in: 0..<pixels.count)])
                continue
            }
            var target = Double.random(in: 0..<totalDistance)
            var chosenIndex = 0
            for (index, distance) in distances.enumerated() {
                if target < distance { chosenIndex = index; break }
                target -= distance
                chosenIndex = index
            }
            centroids.append(pixels[chosenIndex])
        }

        var assignments = [Int](repeating: 0, count: pixels.count)

        for _ in 0..<iterations {
            // Assign each pixel to its nearest centroid.
            for (index, pixel) in pixels.enumerated() {
                var bestCluster = 0
                var bestDistance = Double.greatestFiniteMagnitude
                for (clusterIndex, centroid) in centroids.enumerated() {
                    let distance = squaredDistance(pixel, centroid)
                    if distance < bestDistance {
                        bestDistance = distance
                        bestCluster = clusterIndex
                    }
                }
                assignments[index] = bestCluster
            }

            // Recompute centroids as the mean of their assigned pixels.
            var sums = [(r: Double, g: Double, b: Double, count: Int)](repeating: (0, 0, 0, 0), count: k)
            for (index, pixel) in pixels.enumerated() {
                let cluster = assignments[index]
                sums[cluster].r += pixel.0
                sums[cluster].g += pixel.1
                sums[cluster].b += pixel.2
                sums[cluster].count += 1
            }
            for clusterIndex in 0..<k where sums[clusterIndex].count > 0 {
                let sum = sums[clusterIndex]
                centroids[clusterIndex] = (
                    sum.r / Double(sum.count),
                    sum.g / Double(sum.count),
                    sum.b / Double(sum.count)
                )
            }
        }

        var memberCounts = [Int](repeating: 0, count: k)
        for cluster in assignments { memberCounts[cluster] += 1 }

        return (0..<k).map { Cluster(centroid: centroids[$0], memberCount: memberCounts[$0]) }
    }

    private static func squaredDistance(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
        let dr = a.0 - b.0
        let dg = a.1 - b.1
        let db = a.2 - b.2
        return dr * dr + dg * dg + db * db
    }
}
