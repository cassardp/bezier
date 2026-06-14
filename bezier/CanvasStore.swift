import CoreGraphics
import Observation

enum Tool: String, CaseIterable, Identifiable {
    case hand
    case select

    var id: String { rawValue }
    var symbolName: String {
        switch self {
        case .hand: "hand.draw"
        case .select: "cursorarrow"
        }
    }
}

enum ShapeKind: String, CaseIterable, Identifiable {
    case square
    case circle
    case triangle

    var id: String { rawValue }
    var symbolName: String {
        switch self {
        case .square: "square"
        case .circle: "circle"
        case .triangle: "triangle"
        }
    }

    func makeShape(center: CGPoint, span: CGFloat) -> VectorShape {
        switch self {
        case .square:   VectorShape.square(center: center, side: span)
        case .circle:   VectorShape.circle(center: center, radius: span / 2)
        case .triangle: VectorShape.triangle(center: center, size: span / 2)
        }
    }
}

@MainActor
@Observable
final class CanvasStore {
    var viewport = Viewport()
    var tool: Tool = .select
    var shapes: [VectorShape] = []
    var selectedIndex: Int?
    var activeNodeIndex: Int?
    var gridStep: CGFloat = 50
    var grid: Grid { Grid(step: gridStep) }

    var selectedShape: VectorShape? {
        guard let i = selectedIndex, shapes.indices.contains(i) else { return nil }
        return shapes[i]
    }

    var activeNode: (index: Int, node: Node)? {
        guard let shape = selectedShape, let n = activeNodeIndex,
              shape.nodes.indices.contains(n) else { return nil }
        return (n, shape.nodes[n])
    }

    func insert(_ kind: ShapeKind, inView size: CGSize) {
        let screenCenter = CGPoint(x: size.width / 2, y: size.height / 2)
        let center = grid.snap(viewport.screenToWorld(screenCenter))
        let shape = kind.makeShape(center: center, span: gridStep * 4)
                        .snappingAnchors(to: grid)
        shapes.append(shape)
        selectedIndex = shapes.count - 1
        activeNodeIndex = nil
    }

    func activateNode(_ index: Int?) {
        activeNodeIndex = index
    }

    func selectShape(atWorld worldPoint: CGPoint, tolerance: CGFloat) {
        activeNodeIndex = nil
        for i in shapes.indices.reversed() {
            if shapes[i].anchorBounds.insetBy(dx: -tolerance, dy: -tolerance)
                .contains(worldPoint) {
                selectedIndex = i
                return
            }
        }
        selectedIndex = nil
    }

    func updateSelected(_ shape: VectorShape) {
        guard let i = selectedIndex, shapes.indices.contains(i) else { return }
        shapes[i] = shape
    }

    func snapSelectedToGrid() {
        guard let i = selectedIndex, shapes.indices.contains(i) else { return }
        shapes[i] = shapes[i].snappingAnchors(to: grid)
    }

    func snapSelectedNode(_ nodeIndex: Int) {
        guard let i = selectedIndex, shapes.indices.contains(i) else { return }
        shapes[i] = shapes[i].snappingNode(nodeIndex, to: grid)
    }

    func snapSelectedHandle(_ nodeIndex: Int, side: HandleSide) {
        guard let i = selectedIndex, shapes.indices.contains(i) else { return }
        shapes[i] = shapes[i].snappingHandle(nodeIndex, side: side, to: grid)
    }

    func clear() {
        shapes.removeAll()
        selectedIndex = nil
        activeNodeIndex = nil
    }

    func undoLast() {
        guard !shapes.isEmpty else { return }
        shapes.removeLast()
        selectedIndex = nil
        activeNodeIndex = nil
    }
}
