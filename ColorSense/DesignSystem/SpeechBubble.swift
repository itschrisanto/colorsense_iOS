import SwiftUI

/// A rounded speech bubble with a tail on its bottom edge.
///
/// Drawn as a `Shape` rather than assembled from a rounded rectangle plus a triangle overlay, so
/// the whole outline is one path. That matters because it is filled with a solid colour and any
/// seam between two shapes shows as a hairline where the tail meets the body.
struct SpeechBubble: Shape {
    var cornerRadius: CGFloat = 20
    var tailWidth: CGFloat = 26
    var tailHeight: CGFloat = 15
    /// Where the tail sits along the bottom edge, 0 leading to 1 trailing.
    var tailPosition: CGFloat = 0.5

    func path(in rect: CGRect) -> Path {
        let body = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: max(rect.height - tailHeight, cornerRadius * 2)
        )
        let radius = min(cornerRadius, min(body.width, body.height) / 2)

        // Clamp so the tail cannot slide into the corner arcs, where it would produce a kink.
        let centre = body.minX + radius + tailWidth / 2
            + (body.width - 2 * radius - tailWidth) * min(max(tailPosition, 0), 1)
        let left = centre - tailWidth / 2
        let right = centre + tailWidth / 2

        var path = Path()
        path.move(to: CGPoint(x: body.minX + radius, y: body.minY))
        path.addLine(to: CGPoint(x: body.maxX - radius, y: body.minY))
        path.addArc(
            center: CGPoint(x: body.maxX - radius, y: body.minY + radius),
            radius: radius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false
        )
        path.addLine(to: CGPoint(x: body.maxX, y: body.maxY - radius))
        path.addArc(
            center: CGPoint(x: body.maxX - radius, y: body.maxY - radius),
            radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false
        )

        path.addLine(to: CGPoint(x: right, y: body.maxY))
        path.addLine(to: CGPoint(x: centre, y: body.maxY + tailHeight))
        path.addLine(to: CGPoint(x: left, y: body.maxY))

        path.addLine(to: CGPoint(x: body.minX + radius, y: body.maxY))
        path.addArc(
            center: CGPoint(x: body.minX + radius, y: body.maxY - radius),
            radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false
        )
        path.addLine(to: CGPoint(x: body.minX, y: body.minY + radius))
        path.addArc(
            center: CGPoint(x: body.minX + radius, y: body.minY + radius),
            radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
