import CoreGraphics
import Foundation

struct CubicSegment: Equatable, Codable, Sendable {
    var start: CGPoint
    var control1: CGPoint
    var control2: CGPoint
    var end: CGPoint

    init(start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint) {
        self.start = start
        self.control1 = control1
        self.control2 = control2
        self.end = end
    }
}

struct BezierPath: Equatable, Codable, Sendable {
    var segments: [CubicSegment]
    var isClosed: Bool

    init(segments: [CubicSegment] = [], isClosed: Bool = false) {
        self.segments = segments
        self.isClosed = isClosed
    }

    var isEmpty: Bool { segments.isEmpty }

    func cgPath() -> CGPath {
        let path = CGMutablePath()
        guard let first = segments.first else { return path }
        path.move(to: first.start)
        for segment in segments {
            path.addCurve(to: segment.end,
                          control1: segment.control1,
                          control2: segment.control2)
        }
        if isClosed { path.closeSubpath() }
        return path
    }
}
