import CoreGraphics
import Foundation

enum NodeType: String, Codable, Sendable {
    case corner
    case smooth
}

struct Node: Equatable, Codable, Sendable {
    var anchor: CGPoint
    // Handles are absolute control points; nil means a straight side.
    var handleIn: CGPoint?
    var handleOut: CGPoint?
    var type: NodeType

    init(anchor: CGPoint,
                handleIn: CGPoint? = nil,
                handleOut: CGPoint? = nil,
                type: NodeType = .corner) {
        self.anchor = anchor
        self.handleIn = handleIn
        self.handleOut = handleOut
        self.type = type
    }

    init(corner anchor: CGPoint) {
        self.init(anchor: anchor, type: .corner)
    }

    init(smooth anchor: CGPoint, handleOut: CGPoint) {
        self.init(anchor: anchor,
                  handleIn: anchor * 2 - handleOut,
                  handleOut: handleOut,
                  type: .smooth)
    }

    func mapped(_ transform: (CGPoint) -> CGPoint) -> Node {
        Node(anchor: transform(anchor),
             handleIn: handleIn.map(transform),
             handleOut: handleOut.map(transform),
             type: type)
    }

    func translated(by delta: CGPoint) -> Node {
        mapped { $0 + delta }
    }
}

enum HandleSide: Sendable {
    case `in`
    case out
}

struct VectorShape: Equatable, Codable, Sendable {
    var nodes: [Node]
    var isClosed: Bool

    init(nodes: [Node] = [], isClosed: Bool = false) {
        self.nodes = nodes
        self.isClosed = isClosed
    }

    var isEmpty: Bool { nodes.count < 2 }

    // Missing handles default to the segment thirds, so a side stays straight.
    private static func segment(from a: Node, to b: Node) -> CubicSegment {
        let line = b.anchor - a.anchor
        let c1 = a.handleOut ?? a.anchor + line * (1.0 / 3.0)
        let c2 = b.handleIn ?? a.anchor + line * (2.0 / 3.0)
        return CubicSegment(start: a.anchor, control1: c1, control2: c2, end: b.anchor)
    }

    func bezierPath() -> BezierPath {
        guard nodes.count >= 2 else { return BezierPath() }
        var segments: [CubicSegment] = []
        for i in 0..<(nodes.count - 1) {
            segments.append(VectorShape.segment(from: nodes[i], to: nodes[i + 1]))
        }
        if isClosed, let first = nodes.first, let last = nodes.last {
            segments.append(VectorShape.segment(from: last, to: first))
        }
        return BezierPath(segments: segments, isClosed: isClosed)
    }

    func cgPath() -> CGPath { bezierPath().cgPath() }

    func mapped(_ transform: (CGPoint) -> CGPoint) -> VectorShape {
        VectorShape(nodes: nodes.map { $0.mapped(transform) }, isClosed: isClosed)
    }

    func translated(by delta: CGPoint) -> VectorShape {
        mapped { $0 + delta }
    }

    func snappingAnchors(to grid: Grid) -> VectorShape {
        VectorShape(nodes: nodes.map { node in
            node.translated(by: grid.snap(node.anchor) - node.anchor)
        }, isClosed: isClosed)
    }

    func movingNode(_ index: Int, by delta: CGPoint) -> VectorShape {
        guard nodes.indices.contains(index) else { return self }
        var copy = self
        copy.nodes[index] = nodes[index].translated(by: delta)
        return copy
    }

    func snappingNode(_ index: Int, to grid: Grid) -> VectorShape {
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

    func effectiveHandleOut(_ index: Int) -> CGPoint? {
        guard nodes.indices.contains(index) else { return nil }
        if let h = nodes[index].handleOut { return h }
        guard let next = neighbor(of: index, after: true) else { return nil }
        let a = nodes[index].anchor
        return a + (nodes[next].anchor - a) * (1.0 / 3.0)
    }

    func effectiveHandleIn(_ index: Int) -> CGPoint? {
        guard nodes.indices.contains(index) else { return nil }
        if let h = nodes[index].handleIn { return h }
        guard let prev = neighbor(of: index, after: false) else { return nil }
        let a = nodes[index].anchor
        return a + (nodes[prev].anchor - a) * (1.0 / 3.0)
    }

    func movingHandle(_ index: Int, side: HandleSide, to point: CGPoint) -> VectorShape {
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

    func snappingHandle(_ index: Int, side: HandleSide, to grid: Grid) -> VectorShape {
        let current = side == .in ? effectiveHandleIn(index) : effectiveHandleOut(index)
        guard let current else { return self }
        return movingHandle(index, side: side, to: grid.snap(current))
    }

    var anchorBounds: CGRect {
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

    static func rectangle(center: CGPoint, width: CGFloat, height: CGFloat) -> VectorShape {
        let hw = width / 2, hh = height / 2
        let corners = [
            CGPoint(x: center.x - hw, y: center.y - hh),
            CGPoint(x: center.x + hw, y: center.y - hh),
            CGPoint(x: center.x + hw, y: center.y + hh),
            CGPoint(x: center.x - hw, y: center.y + hh),
        ]
        return VectorShape(nodes: corners.map(Node.init(corner:)), isClosed: true)
    }

    static func square(center: CGPoint, side: CGFloat) -> VectorShape {
        rectangle(center: center, width: side, height: side)
    }

    static func ellipse(center: CGPoint, semiMajor a: CGFloat, semiMinor b: CGFloat) -> VectorShape {
        let k = VectorShape.kappa
        let specs: [(CGPoint, CGPoint)] = [
            (CGPoint(x: a, y: 0),  CGPoint(x: a, y: k * b)),
            (CGPoint(x: 0, y: b),  CGPoint(x: -k * a, y: b)),
            (CGPoint(x: -a, y: 0), CGPoint(x: -a, y: -k * b)),
            (CGPoint(x: 0, y: -b), CGPoint(x: k * a, y: -b)),
        ]
        let nodes = specs.map { anchor, handleOut in
            Node(smooth: anchor + center, handleOut: handleOut + center)
        }
        return VectorShape(nodes: nodes, isClosed: true)
    }

    static func circle(center: CGPoint, radius: CGFloat) -> VectorShape {
        ellipse(center: center, semiMajor: radius, semiMinor: radius)
    }

    static func regularPolygon(center: CGPoint,
                                      circumradius r: CGFloat,
                                      sides: Int,
                                      rotation: CGFloat = 0) -> VectorShape {
        guard sides >= 3 else { return VectorShape() }
        let nodes = (0..<sides).map { i -> Node in
            let angle = rotation + 2 * .pi * CGFloat(i) / CGFloat(sides)
            return Node(corner: CGPoint(x: center.x + r * Foundation.cos(angle),
                                        y: center.y + r * Foundation.sin(angle)))
        }
        return VectorShape(nodes: nodes, isClosed: true)
    }

    static func triangle(center: CGPoint, size: CGFloat) -> VectorShape {
        regularPolygon(center: center, circumradius: size, sides: 3, rotation: -.pi / 2)
    }
}
