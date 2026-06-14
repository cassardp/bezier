import Testing
import CoreGraphics
@testable import BezierCore

@Suite("Viewport — conversions monde ↔ écran")
struct ViewportTests {

    @Test("Identité : monde == écran à scale 1 sans translation")
    func identity() {
        let vp = Viewport()
        #expect(vp.worldToScreen(CGPoint(x: 10, y: 20)) == CGPoint(x: 10, y: 20))
        #expect(vp.screenToWorld(CGPoint(x: 10, y: 20)) == CGPoint(x: 10, y: 20))
    }

    @Test("Roundtrip world → screen → world préserve le point")
    func roundtrip() {
        let vp = Viewport(scale: 2.5, translation: CGSize(width: 30, height: -15))
        let p = CGPoint(x: 12.3, y: -45.6)
        let back = vp.screenToWorld(vp.worldToScreen(p))
        #expect(approx(back.x, p.x))
        #expect(approx(back.y, p.y))
    }

    @Test("worldToScreen applique scale puis translation")
    func forwardTransform() {
        let vp = Viewport(scale: 2, translation: CGSize(width: 100, height: 50))
        #expect(vp.worldToScreen(CGPoint(x: 10, y: 10)) == CGPoint(x: 120, y: 70))
    }

    @Test("pan décale la translation en points écran")
    func pan() {
        var vp = Viewport(translation: CGSize(width: 10, height: 10))
        vp.pan(by: CGSize(width: 5, height: -3))
        #expect(vp.translation == CGSize(width: 15, height: 7))
    }

    @Test("zoom garde le point d'ancrage écran immobile")
    func zoomKeepsAnchorFixed() {
        var vp = Viewport(scale: 1, translation: CGSize(width: 100, height: 50))
        let anchor = CGPoint(x: 200, y: 300)
        let worldBefore = vp.screenToWorld(anchor)
        vp.zoom(by: 2.0, around: anchor)
        let worldAfter = vp.screenToWorld(anchor)
        #expect(approx(worldAfter.x, worldBefore.x))
        #expect(approx(worldAfter.y, worldBefore.y))
        #expect(approx(vp.scale, 2.0))
    }

    @Test("zoom est borné par les limites fournies")
    func zoomRespectsLimits() {
        var vp = Viewport()
        vp.zoom(by: 1000, around: .zero, limits: 0.5...4)
        #expect(vp.scale == 4)
        vp.zoom(by: 0.0001, around: .zero, limits: 0.5...4)
        #expect(vp.scale == 0.5)
    }

    @Test("affineTransform équivaut à worldToScreen")
    func affineMatchesForward() {
        let vp = Viewport(scale: 1.75, translation: CGSize(width: -20, height: 40))
        let p = CGPoint(x: 7, y: -11)
        let viaAffine = p.applying(vp.affineTransform)
        let viaMethod = vp.worldToScreen(p)
        #expect(approx(viaAffine.x, viaMethod.x))
        #expect(approx(viaAffine.y, viaMethod.y))
    }

    @Test("visibleWorldRect couvre la zone affichée")
    func visibleRect() {
        let vp = Viewport(scale: 2, translation: .zero)
        let rect = vp.visibleWorldRect(viewSize: CGSize(width: 200, height: 100))
        #expect(approx(rect.minX, 0))
        #expect(approx(rect.minY, 0))
        #expect(approx(rect.width, 100))
        #expect(approx(rect.height, 50))
    }
}

func approx(_ a: CGFloat, _ b: CGFloat, _ eps: CGFloat = 1e-9) -> Bool {
    abs(a - b) < eps
}
