import SwiftUI

struct InfiniteCanvasView: View {
    @Bindable var store: CanvasStore

    @State private var lastPanTranslation: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1
    @State private var didCenterOnOrigin = false
    @State private var viewSize: CGSize = .zero

    private enum DragSession {
        case handle(index: Int, side: HandleSide,
                    baseHandle: CGPoint, base: VectorShape)
        case node(index: Int, base: VectorShape)
        case shape(base: VectorShape)
    }
    @State private var dragSession: DragSession?

    var body: some View {
        Canvas { context, size in
            drawDotGrid(into: &context, size: size)
            drawShapes(into: &context)
            drawTangentHandles(into: &context)
            drawSelectionHandles(into: &context)
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .contentShape(Rectangle())
        .gesture(panGesture, including: store.tool == .hand ? .all : [])
        .simultaneousGesture(zoomGesture, including: store.tool == .hand ? .all : [])
        .gesture(selectGesture, including: store.tool == .select ? .all : [])
        .ignoresSafeArea()
        .overlay(alignment: .bottom) { toolbar }
        .overlay(alignment: .topTrailing) { zoomBadge }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            viewSize = size
            guard !didCenterOnOrigin, size.width > 0 else { return }
            store.viewport.translation = CGSize(width: size.width / 2,
                                                height: size.height / 2)
            didCenterOnOrigin = true
        }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let delta = CGSize(
                    width: value.translation.width - lastPanTranslation.width,
                    height: value.translation.height - lastPanTranslation.height)
                store.viewport.pan(by: delta)
                lastPanTranslation = value.translation
            }
            .onEnded { _ in lastPanTranslation = .zero }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let factor = value.magnification / lastMagnification
                store.viewport.zoom(by: factor, around: value.startLocation)
                lastMagnification = value.magnification
            }
            .onEnded { _ in lastMagnification = 1 }
    }

    private var selectGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let scale = max(store.viewport.scale, 0.0001)
                if dragSession == nil {
                    dragSession = beginDrag(at: value.startLocation, scale: scale)
                }
                let delta = CGPoint(x: value.translation.width / scale,
                                    y: value.translation.height / scale)
                switch dragSession {
                case .handle(let index, let side, let baseHandle, let base):
                    let target = CGPoint(x: baseHandle.x + delta.x,
                                         y: baseHandle.y + delta.y)
                    store.updateSelected(base.movingHandle(index, side: side, to: target))
                case .node(let index, let base):
                    store.updateSelected(base.movingNode(index, by: delta))
                case .shape(let base):
                    store.updateSelected(base.translated(by: delta))
                case .none:
                    break
                }
            }
            .onEnded { _ in
                switch dragSession {
                case .handle(let index, let side, _, _):
                    store.snapSelectedHandle(index, side: side)
                case .node(let index, _):
                    store.snapSelectedNode(index)
                case .shape:
                    store.snapSelectedToGrid()
                case .none:
                    break
                }
                dragSession = nil
            }
    }

    // Hit priority: active node's tangent > any anchor (activates it) > body > empty.
    private func beginDrag(at screenPoint: CGPoint, scale: CGFloat) -> DragSession? {
        if let shape = store.selectedShape {
            if let active = store.activeNodeIndex,
               let hit = nearestHandle(to: screenPoint, in: shape,
                                       nodes: [active], within: 18) {
                return .handle(index: hit.index, side: hit.side,
                               baseHandle: hit.world, base: shape)
            }
            if let i = nearestAnchor(to: screenPoint, in: shape,
                                     nodes: Array(shape.nodes.indices), within: 22) {
                store.activateNode(i)
                return .node(index: i, base: shape)
            }
        }
        let world = store.viewport.screenToWorld(screenPoint)
        store.selectShape(atWorld: world, tolerance: 12 / scale)
        if let shape = store.selectedShape {
            return .shape(base: shape)
        }
        return nil
    }

    private func nearestHandle(to screenPoint: CGPoint,
                               in shape: VectorShape,
                               nodes: [Int],
                               within threshold: CGFloat)
        -> (index: Int, side: HandleSide, world: CGPoint)? {
        var best: (index: Int, side: HandleSide, world: CGPoint, distance: CGFloat)?
        for i in nodes {
            for side in [HandleSide.in, .out] {
                let world = side == .in ? shape.effectiveHandleIn(i)
                                        : shape.effectiveHandleOut(i)
                guard let w = world else { continue }
                let s = store.viewport.worldToScreen(w)
                let d = hypot(s.x - screenPoint.x, s.y - screenPoint.y)
                if d <= threshold, best == nil || d < best!.distance {
                    best = (i, side, w, d)
                }
            }
        }
        guard let best else { return nil }
        return (best.index, best.side, best.world)
    }

    private func nearestAnchor(to screenPoint: CGPoint,
                               in shape: VectorShape,
                               nodes: [Int],
                               within threshold: CGFloat) -> Int? {
        var best: (index: Int, distance: CGFloat)?
        for i in nodes {
            let s = store.viewport.worldToScreen(shape.nodes[i].anchor)
            let d = hypot(s.x - screenPoint.x, s.y - screenPoint.y)
            if d <= threshold, best == nil || d < best!.distance {
                best = (i, d)
            }
        }
        return best?.index
    }

    private func drawShapes(into context: inout GraphicsContext) {
        let transform = store.viewport.affineTransform
        for (i, shape) in store.shapes.enumerated() {
            let path = Path(shape.cgPath()).applying(transform)
            if shape.isClosed {
                context.fill(path, with: .color(.accentColor.opacity(0.15)))
            }
            let selected = i == store.selectedIndex
            context.stroke(path, with: .color(.accentColor),
                           style: StrokeStyle(lineWidth: selected ? 2.5 : 2,
                                              lineCap: .round, lineJoin: .round))
        }
    }

    private func drawTangentHandles(into context: inout GraphicsContext) {
        guard let (i, node) = store.activeNode, let shape = store.selectedShape else { return }
        let viewport = store.viewport
        let anchor = viewport.worldToScreen(node.anchor)
        for world in [shape.effectiveHandleIn(i), shape.effectiveHandleOut(i)] {
            guard let world else { continue }
            let s = viewport.worldToScreen(world)
            var arm = Path()
            arm.move(to: anchor)
            arm.addLine(to: s)
            context.stroke(arm, with: .color(.secondary.opacity(0.6)), lineWidth: 1)
            let r: CGFloat = 4
            context.fill(Path(ellipseIn: CGRect(x: s.x - r, y: s.y - r,
                                                width: r * 2, height: r * 2)),
                         with: .color(.secondary))
        }
    }

    private func drawSelectionHandles(into context: inout GraphicsContext) {
        guard let shape = store.selectedShape else { return }
        let viewport = store.viewport
        for (i, node) in shape.nodes.enumerated() {
            let s = viewport.worldToScreen(node.anchor)
            let r: CGFloat = 5
            let rect = CGRect(x: s.x - r, y: s.y - r, width: r * 2, height: r * 2)
            let isActive = i == store.activeNodeIndex
            context.fill(Path(ellipseIn: rect),
                         with: .color(isActive ? .accentColor : .white))
            context.stroke(Path(ellipseIn: rect), with: .color(.accentColor), lineWidth: 2)
        }
    }

    private func drawDotGrid(into context: inout GraphicsContext, size: CGSize) {
        let viewport = store.viewport
        let step = store.gridStep
        let screenStep = step * viewport.scale
        guard screenStep >= 8 else { return }

        let rect = viewport.visibleWorldRect(viewSize: size)
        let radius: CGFloat = 1.5
        var dots = Path()
        var x = (rect.minX / step).rounded(.down) * step
        while x <= rect.maxX {
            var y = (rect.minY / step).rounded(.down) * step
            while y <= rect.maxY {
                let s = viewport.worldToScreen(CGPoint(x: x, y: y))
                dots.addEllipse(in: CGRect(x: s.x - radius, y: s.y - radius,
                                           width: radius * 2, height: radius * 2))
                y += step
            }
            x += step
        }
        context.fill(dots, with: .color(.gray.opacity(0.45)))
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            ForEach(Tool.allCases) { option in
                Button {
                    store.tool = option
                } label: {
                    Image(systemName: option.symbolName)
                        .foregroundStyle(store.tool == option ? Color.accentColor : .secondary)
                }
            }

            Divider().frame(height: 22)

            ForEach(ShapeKind.allCases) { kind in
                Button {
                    store.insert(kind, inView: viewSize)
                } label: {
                    Image(systemName: kind.symbolName)
                }
                .foregroundStyle(.primary)
            }

            Divider().frame(height: 22)

            Button {
                store.undoLast()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(store.shapes.isEmpty)

            Button(role: .destructive) {
                store.clear()
            } label: {
                Image(systemName: "trash")
            }
            .disabled(store.shapes.isEmpty)
        }
        .font(.title3)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: .capsule)
        .padding(.bottom, 8)
    }

    private var zoomBadge: some View {
        Text("\(Int((store.viewport.scale * 100).rounded())) %")
            .font(.caption.monospacedDigit())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: .capsule)
            .padding()
    }
}

#Preview {
    InfiniteCanvasView(store: CanvasStore())
}
