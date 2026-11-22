import CoreGraphics
import Metal
@testable import MetalSprockets
import Testing

// An equal `.equatable()` element is reused without evaluating its body, also under ancestors whose environment
// writes are unchanged even when those ancestors hold closures (#598).
@MainActor
struct EquatableElementTests {
    final class Counter {
        var bodies = 0
    }

    struct Counted: Element, Equatable {
        var value: Int
        let counter: Counter

        var body: some Element {
            counter.bodies += 1
            return EmptyElement()
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.value == rhs.value
        }
    }

    struct SubmissionReader: Element, Equatable {
        @MSEnvironment(\.submissionIndex) var submissionIndex
        let counter: Counter

        var body: some Element {
            _ = submissionIndex
            counter.bodies += 1
            return EmptyElement()
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            true
        }
    }

    @Test func `the body runs only when the value changes`() throws {
        let counter = Counter()
        let system = System()
        try system.update(root: Counted(value: 1, counter: counter).equatable())
        try system.update(root: Counted(value: 1, counter: counter).equatable())
        #expect(counter.bodies == 1)
        try system.update(root: Counted(value: 2, counter: counter).equatable())
        #expect(counter.bodies == 2)
    }

    @Test func `an equal element under a closure environment writer with the same value is reused`() throws {
        let counter = Counter()
        let system = System()
        // `.environment` stores a closure, so the writer itself never compares equal.
        try system.update(root: Counted(value: 1, counter: counter).equatable().environment(\.equatableTestLabel, "same"))
        try system.update(root: Counted(value: 1, counter: counter).equatable().environment(\.equatableTestLabel, "same"))
        #expect(counter.bodies == 1)
        try system.update(root: Counted(value: 1, counter: counter).equatable().environment(\.equatableTestLabel, "changed"))
        #expect(counter.bodies == 2)
    }

    @Test func `a body that reads submissionIndex runs every update`() throws {
        let counter = Counter()
        let system = System()
        try system.update(root: SubmissionReader(counter: counter).equatable())
        try system.update(root: SubmissionReader(counter: counter).equatable())
        try system.update(root: SubmissionReader(counter: counter).equatable())
        #expect(counter.bodies == 3)
    }

    struct Triangle: Element, Equatable {
        var index: Int

        var body: some Element {
            Draw(.triangle, vertexCount: 3)
                .parameter("offset", value: SIMD4<Float>(Float(index) * 0.1, 0, 0, 0))
        }
    }

    @Test(.requiresMetal4) func `equal draws are spliced in a real render`() throws {
        let source = """
        #include <metal_stdlib>
        using namespace metal;
        struct VertexOut { float4 position [[position]]; };
        [[vertex]] VertexOut vertex_main(uint vertexID [[vertex_id]], constant float4 &offset [[buffer(0)]]) {
            VertexOut out;
            out.position = float4(float2(vertexID & 1, vertexID >> 1) * 0.1, 0, 1) + offset;
            return out;
        }
        [[fragment]] float4 fragment_main(VertexOut in [[stage_in]]) { return 1; }
        """
        let vertexShader = try VertexShader(source: source)
        let fragmentShader = try FragmentShader(source: source)
        func scene() throws -> some Element {
            try RenderPass {
                try RenderPipeline(vertexShader: vertexShader, fragmentShader: fragmentShader) {
                    ForEach(Array(0..<10), id: \.self) { index in
                        Triangle(index: index).equatable()
                    }
                }
            }
        }
        let renderer = try OffscreenRenderer(size: CGSize(width: 16, height: 16))
        _ = try renderer.render(scene())
        _ = try renderer.render(scene())
        #expect(renderer.runner.system.lastSplicedNodeCount > 0)
    }
}

private struct EquatableTestLabelKey: MSEnvironmentKey {
    static let defaultValue = ""
}

private extension MSEnvironmentValues {
    var equatableTestLabel: String {
        get { self[EquatableTestLabelKey.self] }
        set { self[EquatableTestLabelKey.self] = newValue }
    }
}
