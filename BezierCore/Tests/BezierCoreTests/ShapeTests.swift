import Testing
import CoreGraphics
@testable import BezierCore

@Suite("Shape (modèle éditable centré sur les nœuds)")
struct ShapeTests {

    @Test("rectangle : 4 coins francs, fermé, boîte centrée")
    func rectangleBasics() {
        let r = Shape.rectangle(center: CGPoint(x: 100, y: 50), width: 40, height: 20)
        #expect(r.nodes.count == 4)
        #expect(r.isClosed)
        #expect(r.nodes.allSatisfy { $0.type == .corner && $0.handleIn == nil && $0.handleOut == nil })
        let b = r.anchorBounds
        #expect(approx(b.minX, 80) && approx(b.maxX, 120))
        #expect(approx(b.minY, 40) && approx(b.maxY, 60))
    }

    @Test("carré : côtés égaux")
    func squareIsSquare() {
        let s = Shape.square(center: .zero, side: 30)
        let b = s.anchorBounds
        #expect(approx(b.width, 30) && approx(b.height, 30))
    }

    @Test("un côté sans poignée s'aplatit en segment droit (contrôles aux tiers)")
    func straightSideThirds() {
        let s = Shape.square(center: .zero, side: 60)
        let seg = s.bezierPath().segments[0]
        let dx = seg.end.x - seg.start.x, dy = seg.end.y - seg.start.y
        #expect(approx(seg.control1.x, seg.start.x + dx / 3))
        #expect(approx(seg.control1.y, seg.start.y + dy / 3))
        #expect(approx(seg.control2.x, seg.start.x + 2 * dx / 3))
        #expect(approx(seg.control2.y, seg.start.y + 2 * dy / 3))
    }

    @Test("cercle : 4 nœuds smooth, boîte = ±r")
    func circleNodes() {
        let c = Shape.circle(center: .zero, radius: 25)
        #expect(c.nodes.count == 4)
        #expect(c.isClosed)
        #expect(c.nodes.allSatisfy { $0.type == .smooth })
        let b = c.anchorBounds
        #expect(approx(b.minX, -25) && approx(b.maxX, 25))
        #expect(approx(b.minY, -25) && approx(b.maxY, 25))
    }

    @Test("cercle : poignées symétriques autour de l'ancre")
    func circleHandlesSymmetric() {
        let c = Shape.circle(center: .zero, radius: 25)
        for node in c.nodes {
            guard let hIn = node.handleIn, let hOut = node.handleOut else {
                Issue.record("smooth node without handles"); continue
            }
            #expect(approx((hIn.x + hOut.x) / 2, node.anchor.x))
            #expect(approx((hIn.y + hOut.y) / 2, node.anchor.y))
        }
    }

    @Test("cercle : poignées à la distance kappa·r de l'ancre")
    func circleHandleMagnitude() {
        let r: CGFloat = 40
        let c = Shape.circle(center: .zero, radius: r)
        let node = c.nodes[0]
        let dx = node.handleOut!.x - node.anchor.x
        let dy = node.handleOut!.y - node.anchor.y
        #expect(approx(dx, 0))
        #expect(approx(dy, Shape.kappa * r))
    }

    @Test("triangle : 3 coins, pointe en haut")
    func triangleBasics() {
        let t = Shape.triangle(center: .zero, size: 50)
        #expect(t.nodes.count == 3)
        #expect(t.isClosed)
        let top = t.nodes.min { $0.anchor.y < $1.anchor.y }!
        #expect(approx(top.anchor.x, 0))
        #expect(approx(top.anchor.y, -50))
    }

    @Test("regularPolygon refuse moins de 3 côtés")
    func degeneratePolygon() {
        #expect(Shape.regularPolygon(center: .zero, circumradius: 10, sides: 2).isEmpty)
    }

    @Test("translated déplace ancres et poignées en bloc")
    func translatePreservesShape() {
        let c = Shape.circle(center: .zero, radius: 10)
        let moved = c.translated(by: CGPoint(x: 5, y: -3))
        for (a, b) in zip(c.nodes, moved.nodes) {
            #expect(approx(b.anchor.x, a.anchor.x + 5))
            #expect(approx(b.anchor.y, a.anchor.y - 3))
            #expect(approx(b.handleOut!.x, a.handleOut!.x + 5))
            #expect(approx(b.handleOut!.y, a.handleOut!.y - 3))
        }
    }

    @Test("snappingAnchors cale les ancres sur la grille, poignées solidaires")
    func snapAnchors() {
        let grid = Grid(step: 50)
        let c = Shape.circle(center: CGPoint(x: 12, y: 12), radius: 40)
        let snapped = c.snappingAnchors(to: grid)
        for node in snapped.nodes {
            #expect(approx(node.anchor.x.truncatingRemainder(dividingBy: 50), 0)
                    || approx(abs(node.anchor.x.truncatingRemainder(dividingBy: 50)), 50))
            #expect(approx(node.anchor.y.truncatingRemainder(dividingBy: 50), 0)
                    || approx(abs(node.anchor.y.truncatingRemainder(dividingBy: 50)), 50))
        }
        for (a, b) in zip(c.nodes, snapped.nodes) {
            let before = a.handleOut! - a.anchor
            let after = b.handleOut! - b.anchor
            #expect(approx(before.x, after.x) && approx(before.y, after.y))
        }
    }

    @Test("movingNode translate un seul nœud, laisse les autres en place")
    func moveSingleNode() {
        let sq = Shape.square(center: .zero, side: 100)
        let moved = sq.movingNode(0, by: CGPoint(x: 10, y: -7))
        #expect(approx(moved.nodes[0].anchor.x, sq.nodes[0].anchor.x + 10))
        #expect(approx(moved.nodes[0].anchor.y, sq.nodes[0].anchor.y - 7))
        for i in 1..<4 {
            #expect(moved.nodes[i].anchor == sq.nodes[i].anchor)
        }
    }

    @Test("movingNode déplace aussi les poignées du nœud (cercle)")
    func moveNodeCarriesHandles() {
        let c = Shape.circle(center: .zero, radius: 30)
        let moved = c.movingNode(0, by: CGPoint(x: 5, y: 5))
        let before = c.nodes[0]
        let after = moved.nodes[0]
        #expect(approx(after.handleOut!.x, before.handleOut!.x + 5))
        #expect(approx(after.handleIn!.y, before.handleIn!.y + 5))
    }

    @Test("snappingNode n'aimante que le nœud visé")
    func snapSingleNode() {
        let grid = Grid(step: 50)
        let sq = Shape.square(center: CGPoint(x: 12, y: 0), side: 100)
        let snapped = sq.snappingNode(0, to: grid)
        #expect(snapped.nodes[0].anchor == grid.snap(sq.nodes[0].anchor))
        #expect(snapped.nodes[1].anchor == sq.nodes[1].anchor)
    }

    @Test("movingNode / snappingNode hors borne : forme inchangée")
    func nodeOutOfBounds() {
        let sq = Shape.square(center: .zero, side: 10)
        #expect(sq.movingNode(9, by: CGPoint(x: 1, y: 1)) == sq)
        #expect(sq.snappingNode(-1, to: Grid(step: 50)) == sq)
    }

    @Test("poignée effective d'un coin droit : au tiers du côté")
    func effectiveHandleOnCorner() {
        let sq = Shape.square(center: .zero, side: 90)
        let out = sq.effectiveHandleOut(0)!
        #expect(approx(out.x, -15) && approx(out.y, -45))
        let inp = sq.effectiveHandleIn(0)!
        #expect(approx(inp.x, -45) && approx(inp.y, -15))
    }

    @Test("poignée effective d'un nœud smooth : la poignée explicite")
    func effectiveHandleOnSmooth() {
        let c = Shape.circle(center: .zero, radius: 20)
        #expect(c.effectiveHandleOut(0) == c.nodes[0].handleOut)
    }

    @Test("movingHandle sur un coin : un seul côté change, type inchangé")
    func moveHandleCorner() {
        let sq = Shape.square(center: .zero, side: 90)
        let curved = sq.movingHandle(0, side: .out, to: CGPoint(x: 0, y: -80))
        #expect(curved.nodes[0].handleOut == CGPoint(x: 0, y: -80))
        #expect(curved.nodes[0].handleIn == nil)
        #expect(curved.nodes[0].type == .corner)
    }

    @Test("movingHandle sur un nœud smooth : poignée opposée en miroir")
    func moveHandleSmoothMirrors() {
        let c = Shape.circle(center: .zero, radius: 20)
        let p = CGPoint(x: 20, y: 12)
        let moved = c.movingHandle(0, side: .out, to: p)
        let anchor = c.nodes[0].anchor
        let expectedMirror = anchor * 2 - p
        #expect(moved.nodes[0].handleOut == p)
        #expect(approx(moved.nodes[0].handleIn!.x, expectedMirror.x))
        #expect(approx(moved.nodes[0].handleIn!.y, expectedMirror.y))
    }

    @Test("snappingHandle aimante le bout de la tangente sur la grille")
    func snapHandleTip() {
        let grid = Grid(step: 50)
        let sq = Shape.square(center: .zero, side: 200)
        let curved = sq.movingHandle(0, side: .out, to: CGPoint(x: 12, y: -88))
        let snapped = curved.snappingHandle(0, side: .out, to: grid)
        #expect(snapped.nodes[0].handleOut == grid.snap(CGPoint(x: 12, y: -88)))
        #expect(snapped.nodes[0].handleOut == CGPoint(x: 0, y: -100))
    }

    @Test("mapped applique la transformation aux ancres et poignées")
    func mappedScales() {
        let sq = Shape.square(center: .zero, side: 10)
        let scaled = sq.mapped { CGPoint(x: $0.x * 2, y: $0.y * 2) }
        #expect(approx(scaled.anchorBounds.width, 20))
    }

    @Test("forme à moins de 2 nœuds : vide, bezierPath vide")
    func emptyShape() {
        #expect(Shape().isEmpty)
        #expect(Shape(nodes: [Node(corner: .zero)]).bezierPath().isEmpty)
    }
}
