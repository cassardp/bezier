import CoreGraphics
import Foundation

public struct CubicSegment: Equatable, Codable, Sendable {
    public var start: CGPoint
    public var control1: CGPoint
    public var control2: CGPoint
    public var end: CGPoint

    public init(start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint) {
        self.start = start
        self.control1 = control1
        self.control2 = control2
        self.end = end
    }
}

public struct BezierPath: Equatable, Codable, Sendable {
    public var segments: [CubicSegment]
    public var isClosed: Bool

    public init(segments: [CubicSegment] = [], isClosed: Bool = false) {
        self.segments = segments
        self.isClosed = isClosed
    }

    public var isEmpty: Bool { segments.isEmpty }

    public func cgPath() -> CGPath {
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
