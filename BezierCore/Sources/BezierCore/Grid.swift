import CoreGraphics
import Foundation

public struct Grid: Equatable, Sendable {

    public var step: CGFloat
    public var origin: CGPoint

    public init(step: CGFloat, origin: CGPoint = .zero) {
        self.step = max(step, 1e-6)
        self.origin = origin
    }

    public func snap(_ p: CGPoint) -> CGPoint {
        CGPoint(x: snap(p.x, base: origin.x),
                y: snap(p.y, base: origin.y))
    }

    private func snap(_ value: CGFloat, base: CGFloat) -> CGFloat {
        base + ((value - base) / step).rounded() * step
    }
}
