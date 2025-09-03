import SwiftUI
import RealityKit
import simd

fileprivate let bandStep: Float = 0.5
fileprivate let bandCount: Int = 12
fileprivate let cycleDistances: [Float] = [0.5, 1.5, 3.0]

struct DepthImmersiveView: View {
    @State private var scene = DepthScene()

    var body: some View {
        RealityView { content in
            await scene.setup(in: content)
        } update: { content in
            scene.update()
        }
        // Single tap: place a marker (cycles 0.5m → 1.5m → 3.0m)
        .gesture(SpatialTapGesture().onEnded { _ in
            scene.placeNextDepthMarker()
        })
        // Double tap: toggle ruler placement A/B
        .gesture(SpatialTapGesture(count: 2).onEnded { _ in
            scene.toggleRulerMode()
        })
    }
}

@MainActor
final class DepthScene {
    private var root = Entity()
    private var camera = PerspectiveCamera()
    private var markersRoot = Entity()
    private var bandsRoot = Entity()

    private var distanceIndex = 0
    private var rulerPlacingA = true
    private var rulerA: Entity?
    private var rulerB: Entity?
    private var rulerLabel: Entity?

    func setup(in content: RealityViewContent) async {
        let camAnchor = AnchorEntity(.head)
        camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 55
        camAnchor.addChild(camera)

        root = Entity()
        camAnchor.addChild(root)

        markersRoot = Entity()
        bandsRoot = Entity()
        root.addChild(markersRoot)
        root.addChild(bandsRoot)

        spawnDepthBands()
        content.add(camAnchor)
    }

    func update() { updateRulerLabel() }

    // MARK: - Bands
    private func spawnDepthBands() {
        bandsRoot.children.removeAll()
        for i in 1...bandCount {
            let z = Float(i) * bandStep
            let ring = makeRing(radius: 0.75 + 0.05 * Float(i), thickness: 0.005, zMeters: z)
            ring.components.set(OpacityComponent(opacity: 0.18))
            bandsRoot.addChild(ring)

            let label = makeTextEntity(String(format: "%.1fm", z), fontSize: 0.05)
            label.position = [0.9, 0.0, -z]
            label.components.set(BillboardComponent())
            label.components.set(OpacityComponent(opacity: 0.6))
            bandsRoot.addChild(label)
        }
    }

    private func makeRing(radius: Float, thickness: Float, zMeters: Float) -> Entity {
        let segments = 64
        let parent = Entity()
        for s in 0..<segments {
            let theta0 = (Float(s) / Float(segments)) * 2 * .pi
            let theta1 = (Float(s+1) / Float(segments)) * 2 * .pi
            let mid = (theta0 + theta1) * 0.5
            let dx = cosf(mid) * radius
            let dy = sinf(mid) * radius
            let seg = ModelEntity(
                mesh: .generateBox(size: [thickness, thickness, radius*(theta1-theta0)]),
                materials: [SimpleMaterial(color: .white, roughness: 0.9, isMetallic: false)]
            )
            seg.position = [dx, dy, -zMeters]
            seg.orientation = simd_quatf(angle: mid, axis: [0,0,1])
            parent.addChild(seg)
        }
        return parent
    }

    // MARK: - Markers
    func placeNextDepthMarker() {
        let d = cycleDistances[distanceIndex % cycleDistances.count]
        distanceIndex += 1
        let marker = makeDepthMarker(distance: d)
        markersRoot.addChild(marker)

        if !rulerModeActive {
            addDistanceLabel(near: marker, text: String(format: "%.2fm", d))
        } else {
            if rulerPlacingA {
                clearRuler()
                rulerA = marker
            } else {
                rulerB = marker
                makeOrUpdateRulerLabel()
            }
            rulerPlacingA.toggle()
        }
    }

    private func colorForDistance(_ d: Float) -> UIColor {
        if d < 1.0 { return UIColor(red: 1, green: 0, blue: 0, alpha: 1) }          // near → red
        if d < 2.0 { return UIColor(red: 1, green: 0.5, blue: 0, alpha: 1) }        // mid → orange
        return UIColor(red: 0, green: 0.75, blue: 0, alpha: 1)                      // far → green
    }

    private func makeDepthMarker(distance d: Float) -> Entity {
        let sphere = ModelEntity(
            mesh: .generateSphere(radius: 0.05),
            materials: [SimpleMaterial(color: colorForDistance(d), roughness: 0.4, isMetallic: false)]
        )
        sphere.position = [0, 0, -d]   // along camera forward in head space
        sphere.components.set(BillboardComponent())
        return sphere
    }

    private func addDistanceLabel(near entity: Entity, text: String) {
        let label = makeTextEntity(text, fontSize: 0.07)
        label.position = entity.position
        label.position.y += 0.12
        label.components.set(BillboardComponent())
        markersRoot.addChild(label)
    }

    private func makeTextEntity(_ s: String, fontSize: Float) -> Entity {
        let mesh = MeshResource.generateText(
            s, extrusionDepth: 0.001,
            font: .systemFont(ofSize: CGFloat(fontSize)),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        let mat = SimpleMaterial(color: .white, roughness: 0.8, isMetallic: false)
        return ModelEntity(mesh: mesh, materials: [mat])
    }

    // MARK: - Ruler
    private var rulerModeActive: Bool { true }

    func toggleRulerMode() { rulerPlacingA = true }

    private func clearRuler() {
        rulerA?.removeFromParent()
        rulerB?.removeFromParent()
        rulerLabel?.removeFromParent()
        rulerA = nil; rulerB = nil; rulerLabel = nil
    }

    private func makeOrUpdateRulerLabel() {
        guard let a = rulerA, let b = rulerB else { return }
        let dist = simd_distance(a.position, b.position)
        let mid = (a.position + b.position) / 2

        if rulerLabel == nil {
            let l = makeTextEntity(String(format: "Δ = %.2fm", dist), fontSize: 0.08)
            l.position = mid
            l.position.y += 0.15
            l.components.set(BillboardComponent())
            markersRoot.addChild(l)
            rulerLabel = l
        } else if let model = rulerLabel as? ModelEntity {
            let newMesh = MeshResource.generateText(
                String(format: "Δ = %.2fm", dist),
                extrusionDepth: 0.001,
                font: .systemFont(ofSize: 14),
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byWordWrapping
            )
            model.model?.mesh = newMesh
            rulerLabel?.position = mid
            rulerLabel?.position.y += 0.15
        }
    }

    private func updateRulerLabel() {
        guard let a = rulerA, let b = rulerB, let label = rulerLabel else { return }
        let mid = (a.position + b.position) / 2
        label.position = mid
        label.position.y += 0.15
        makeOrUpdateRulerLabel()
    }
}

