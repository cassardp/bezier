import CoreGraphics
import Foundation

public enum NodeType: String, Codable, Sendable {
    case corner
    case smooth
}

public struct Node: Equatable, Codable, Sendable {
    public var anchor: CGPoint
    // Handles are absolute control points; nil means a straight side.
    public var handleIn: CGPoint?
    public var handleOut: CGPoint?
    public var type: NodeType

    public init(anchor: CGPoint,
                handleIn: CGPoint? = nil,
                handleOut: CGPoint? = nil,
                type: NodeType = .corner) {
        self.anchor = anchor
        self.handleIn = handleIn
        self.handleOut = handleOut
        self.type = type
    }

    public init(corner anchor: CGPoint) {
        self.init(anchor: anchor, type: .corner)
    }

    public init(smooth anchor: CGPoint, handleOut: CGPoint) {
        self.init(anchor: anchor,
                  handleIn: anchor * 2 - handleOut,
                  handleOut: handleOut,
                  type: .smooth)
    }

    public func mapped(_ transform: (CGPoint) -> CGPoint) -> Node {
        Node(anchor: transform(anchor),
             handleIn: handleIn.map(transform),
             handleOut: handleOut.map(transform),
             type: type)
    }

    public func translated(by delta: CGPoint) -> Node {
        mapped { $0 + delta }
    }
}

public enum HandleSide: Sendable {
    case `in`
    case out
}

public struct Shape: Equatable, Codable, Sendable {
    public var nodes: [Node]
    public var isClosed: Bool

    public init(nodes: [Node] = [], isClosed: Bool = false) {
        self.nodes = nodes
        self.isClosed = isClosed
    }

    public var isEmpty: Bool { nodes.count < 2 }

    // Missing handles default to the segment thirds, so a side stays straight.
    private static func segment(from a: Node, to b: Node) -> CubicSegment {
        let line = b.anchor - a.anchor
        let c1 = a.handleOut ?? a.anchor + line * (1.0 / 3.0)
        let c2 = b.handleIn ?? a.anchor + line * (2.0 / 3.0)
        return CubicSegment(start: a.anchor, control1: c1, control2: c2, end: b.anchor)
    }

    public func bezierPath() -> BezierPath {
        guard nodes.count >= 2 else { return BezierPath() }
        var segments: [CubicSegment] = []
        for i in 0..<(nodes.count - 1) {
            segments.append(Shape.segment(from: nodes[i], to: nodes[i + 1]))
        }
        if isClosed, let first = nodes.first, let last = nodes.last {
            segments.append(Shape.segment(from: last, to: first))
        }
        return BezierPath(segments: segments, isClosed: isClosed)
    }

    public func cgPath() -> CGPath { bezierPath().cgPath() }

    public func mapped(_ transform: (CGPoint) -> CGPoint) -> Shape {
        Shape(nodes: nodes.map { $0.mapped(transform) }, isClosed: isClosed)
    }

    public func translated(by delta: CGPoint) -> Shape {
        mapped { $0 + delta }
    }

    public func snappingAnchors(to grid: Grid) -> Shape {
        Shape(nodes: nodes.map { node in
            node.translated(by: grid.snap(node.anchor) - node.anchor)
        }, isClosed: isClosed)
    }

    public func movingNode(_ index: Int, by delta: CGPoint) -> Shape {
        guard nodes.indices.contains(index) else { return self }
        var copy = self
        copy.nodes[index] = nodes[index].translated(by: delta)
        return copy
    }

    public func snappingNode(_ index: Int, to grid: Grid) -> Shape {
        guard nodes.indices.contains(index) else { return self }
        let node = nodes[index]
        var copy = self
        copy.nodes[index] = node.translated(by: grid.snap(node.anchor) - node.anchor)
        return copy
    }

    private func neighbor(of index: Int, after: Bool) -> Int? {
        guard nodes.indices.contains(index) else { return nil }
        if after {
            if index < nodes.count - 1 { return index + 1 }
            return isClosed ? 0 : nil
        } else {
            if index > 0 { return index - 1 }
            return isClosed ? nodes.count - 1 : nil
        }
    }

    public func effectiveHandleOut(_ index: Int) -> CGPoint? {
        guard nodes.indices.contains(index) else { return nil }
        if let h = nodes[index].handleOut { return h }
        guard let next = neighbor(of: index, after: true) else { return nil }
        let a = nodes[index].anchor
        return a + (nodes[next].anchor - a) * (1.0 / 3.0)
    }

    public func effectiveHandleIn(_ index: Int) -> CGPoint? {
        guard nodes.indices.contains(index) else { return nil }
        if let h = nodes[index].handleIn { return h }
        guard let prev = neighbor(of: index, after: false) else { return nil }
        let a = nodes[index].anchor
        return a + (nodes[prev].anchor - a) * (1.0 / 3.0)
    }

    public func movingHandle(_ index: Int, side: HandleSide, to point: CGPoint) -> Shape {
        guard nodes.indices.contains(index) else { return self }
        var node = nodes[index]
        switch side {
        case .out: node.handleOut = point
        case .in:  node.handleIn = point
        }
        if node.type == .smooth {
            let mirror = node.anchor * 2 - point
            switch side {
            case .out: node.handleIn = mirror
            case .in:  node.handleOut = mirror
            }
        }
        var copy = self
        copy.nodes[index] = node
        return copy
    }

    public func snappingHandle(_ index: Int, side: HandleSide, to grid: Grid) -> Shape {
        let current = side == .in ? effectiveHandleIn(index) : effectiveHandleOut(index)
        guard let current else { return self }
        return movingHandle(index, side: side, to: grid.snap(current))
    }

    public var anchorBounds: CGRect {
        guard let first = nodes.first?.anchor else { return .zero }
        var minX = first.x, minY = first.y, maxX = first.x, maxY = first.y
        for node in nodes.dropFirst() {
            minX = min(minX, node.anchor.x); maxX = max(maxX, node.anchor.x)
            minY = min(minY, node.anchor.y); maxY = max(maxY, node.anchor.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    // Kappa: cubic Bézier approximation of a quarter circle (max error ~0.02%).
    static let kappa: CGFloat = 0.5522847498307936

    public static func rectangle(center: CGPoint, width: CGFloat, height: CGFloat) -> Shape {
        let hw = width / 2, hh = height / 2
        let corners = [
            CGPoint(x: center.x - hw, y: center.y - hh),
            CGPoint(x: center.x + hw, y: center.y - hh),
            CGPoint(x: center.x + hw, y: center.y + hh),
            CGPoint(x: center.x - hw, y: center.y + hh),
        ]
        return Shape(nodes: corners.map(Node.init(corner:)), isClosed: true)
    }

    public static func square(center: CGPoint, side: CGFloat) -> Shape {
        rectangle(center: center, width: side, height: side)
    }

    public static func ellipse(center: CGPoint, semiMajor a: CGFloat, semiMinor b: CGFloat) -> Shape {
        let k = Shape.kappa
        let specs: [(CGPoint, CGPoint)] = [
            (CGPoint(x: a, y: 0),  CGPoint(x: a, y: k * b)),
            (CGPoint(x: 0, y: b),  CGPoint(x: -k * a, y: b)),
            (CGPoint(x: -a, y: 0), CGPoint(x: -a, y: -k * b)),
            (CGPoint(x: 0, y: -b), CGPoint(x: k * a, y: -b)),
        ]
        let nodes = specs.map { anchor, handleOut in
            Node(smooth: anchor + center, handleOut: handleOut + center)
        }
        return Shape(nodes: nodes, isClosed: true)
    }

    public static func circle(center: CGPoint, radius: CGFloat) -> Shape {
        ellipse(center: center, semiMajor: radius, semiMinor: radius)
    }

    public static func regularPolygon(center: CGPoint,
                                      circumradius r: CGFloat,
                                      sides: Int,
                                      rotation: CGFloat = 0) -> Shape {
        guard sides >= 3 else { return Shape() }
        let nodes = (0..<sides).map { i -> Node in
            let angle = rotation + 2 * .pi * CGFloat(i) / CGFloat(sides)
            return Node(corner: CGPoint(x: center.x + r * Foundation.cos(angle),
                                        y: center.y + r * Foundation.sin(angle)))
        }
        return Shape(nodes: nodes, isClosed: true)
    }

    public static func triangle(center: CGPoint, size: CGFloat) -> Shape {
        regularPolygon(center: center, circumradius: size, sides: 3, rotation: -.pi / 2)
    }
}
