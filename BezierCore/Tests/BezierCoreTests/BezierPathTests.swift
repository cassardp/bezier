import Testing
import CoreGraphics
@testable import BezierCore

@Suite("BezierPath & CubicSegment")
struct BezierPathTests {

    @Test("isEmpty / cgPath() d'un tracé vide reste vide et ne plante pas")
    func empty() {
        let empty = BezierPath()
        #expect(empty.isEmpty)
        #expect(empty.cgPath().isEmpty)
    }

    @Test("cgPath() reflète le nombre d'éléments du tracé")
    func cgPathBuilt() {
        let seg = CubicSegment(start: .zero,
                               control1: CGPoint(x: 3, y: 0),
                               control2: CGPoint(x: 6, y: 0),
                               end: CGPoint(x: 9, y: 0))
        let path = BezierPath(segments: [seg], isClosed: true)
        var count = 0
        path.cgPath().applyWithBlock { _ in count += 1 }
        #expect(count == 3)
        #expect(!path.isEmpty)
    }
}
