import CoreGraphics

// Convention: screen = world * scale + translation (translation in screen points).
struct Viewport: Equatable, Codable, Sendable {

    static let defaultScaleLimits: ClosedRange<CGFloat> = 0.05...64

    var scale: CGFloat
    var translation: CGSize

    init(scale: CGFloat = 1, translation: CGSize = .zero) {
        self.scale = scale
        self.translation = translation
    }

    func worldToScreen(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x * scale + translation.width,
                y: p.y * scale + translation.height)
    }

    func screenToWorld(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x - translation.width) / scale,
                y: (p.y - translation.height) / scale)
    }

    mutating func pan(by delta: CGSize) {
        translation.width += delta.width
        translation.height += delta.height
    }

    mutating func zoom(by factor: CGFloat,
                              around anchor: CGPoint,
                              limits: ClosedRange<CGFloat> = Viewport.defaultScaleLimits) {
        let worldAnchor = screenToWorld(anchor)
        scale = min(max(scale * factor, limits.lowerBound), limits.upperBound)
        translation.width = anchor.x - worldAnchor.x * scale
        translation.height = anchor.y - worldAnchor.y * scale
    }

    var affineTransform: CGAffineTransform {
        CGAffineTransform(a: scale, b: 0, c: 0, d: scale,
                          tx: translation.width, ty: translation.height)
    }

    func visibleWorldRect(viewSize size: CGSize) -> CGRect {
        let topLeft = screenToWorld(.zero)
        let bottomRight = screenToWorld(CGPoint(x: size.width, y: size.height))
        return CGRect(x: topLeft.x,
                      y: topLeft.y,
                      width: bottomRight.x - topLeft.x,
                      height: bottomRight.y - topLeft.y)
    }
}
