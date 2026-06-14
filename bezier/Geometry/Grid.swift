import CoreGraphics
import Foundation

struct Grid: Equatable, Sendable {

    var step: CGFloat
    var origin: CGPoint

    init(step: CGFloat, origin: CGPoint = .zero) {
        self.step = max(step, 1e-6)
        self.origin = origin
    }

    func snap(_ p: CGPoint) -> CGPoint {
        CGPoint(x: snap(p.x, base: origin.x),
                y: snap(p.y, base: origin.y))
    }

    private func snap(_ value: CGFloat, base: CGFloat) -> CGFloat {
        base + ((value - base) / step).rounded() * step
    }
}
