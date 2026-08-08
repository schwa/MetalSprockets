import GeometryLite3D
import Metal
@testable import MetalSprockets
import MetalSprocketsSupport
import simd
import Testing

@Suite
struct ParametersTests {
    @Test
    func testParameterValueDebugDescription() {
        let textureValue = ParameterValue<Float>.texture(nil)
        #expect(textureValue.debugDescription == "Texture()")

        let samplerValue = ParameterValue<Float>.samplerState(nil)
        #expect(samplerValue.debugDescription == "SamplerState()")

        let bufferValue = ParameterValue<Float>.buffer(nil, 16)
        #expect(bufferValue.debugDescription == "Buffer(nil, offset: 16")

        let arrayValue = ParameterValue<Float>.array([1.0, 2.0, 3.0])
        #expect(arrayValue.debugDescription == "Array")

        let scalarValue = ParameterValue<Float>.value(42.0)
        #expect(scalarValue.debugDescription == "42.0")
    }

    @Test
    func testParameterInitialization() {
        let param = Parameter(name: "testParam", functionTypes: .vertex, value: ParameterValue<Float>.value(3.14))
        #expect(param.name == "testParam")
        #expect(param.functionTypes == .vertex)

        let param2 = Parameter(name: "testParam2", value: ParameterValue<Int>.value(42))
        #expect(param2.name == "testParam2")
        #expect(param2.functionTypes.isEmpty)
    }

    @Test
    func testAnyParameterValue() {
        let floatValue = ParameterValue<Float>.value(3.14)
        let anyValue = AnyParameterValue(floatValue)
        #expect(anyValue.debugDescription == "3.14")

        let textureValue = ParameterValue<Float>.texture(nil)
        let anyTexture = AnyParameterValue(textureValue)
        #expect(anyTexture.debugDescription == "Texture()")
    }

    @Test
    @MainActor
    func testParameterElementModifier() {
        struct TestElement: Element {
            var body: some Element {
                EmptyElement()
            }
        }

        let element = TestElement()
        let modifier = ParameterElementModifier(
            functionTypes: .fragment,
            name: "color",
            value: ParameterValue<SIMD4<Float>>.value(SIMD4<Float>(1, 0, 0, 1)),
            content: element
        )

        #expect(modifier.parameters.count == 1)
        #expect(modifier.parameters[name: "color"] != nil)
        #expect(modifier.parameters[name: "color"]?.name == "color")
        #expect(modifier.parameters[name: "color"]?.functionTypes == .fragment)
    }

    @Test
    @MainActor
    func testElementParameterExtensions() {
        struct TestElement: Element {
            var body: some Element {
                EmptyElement()
            }
        }

        let element = TestElement()

        let withSimd = element.parameter("position", value: SIMD4<Float>(1, 2, 3, 4))
        #expect(withSimd is ParameterElementModifier<TestElement>)

        let withMatrix = element.parameter("transform", value: simd_float4x4.identity)
        #expect(withMatrix is ParameterElementModifier<TestElement>)

        let withTexture = element.parameter("diffuseTexture", texture: nil)
        #expect(withTexture is ParameterElementModifier<TestElement>)

        let device = MTLCreateSystemDefaultDevice()
        if let device {
            let buffer = device.makeBuffer(length: 256)
            if let buffer {
                let withBuffer = element.parameter("vertexBuffer", buffer: buffer, offset: 0)
                #expect(withBuffer is ParameterElementModifier<TestElement>)
            }
        }

        let withArray = element.parameter("weights", values: [1.0, 2.0, 3.0, 4.0])
        #expect(withArray is ParameterElementModifier<TestElement>)

        let withValue = element.parameter("scale", value: Float(2.0))
        #expect(withValue is ParameterElementModifier<TestElement>)
    }

    @Test
    func testStringQuoted() {
        let string = "test"
        #expect(string.quoted == "\"test\"")

        let optional: String? = "optional"
        #expect(optional.quoted == "\"optional\"")

        let nilString: String? = nil
        #expect(nilString.quoted == "nil")
    }

    @Test
    @MainActor
    func testParameterWorkloadEnter() throws {
        struct TestElement: Element {
            var body: some Element {
                EmptyElement()
                    .parameter("testParam", functionType: .vertex, value: Float(1.0))
            }
        }

        let element = TestElement()
        let system = System()

        try system.update(root: element)

        try system.processSetup()

        let modifiedElement = element.body
        #expect(modifiedElement is ParameterElementModifier<EmptyElement>)

        if let modifier = modifiedElement as? ParameterElementModifier<EmptyElement> {
            #expect(modifier.parameters.count == 1)
            if let param = modifier.parameters[name: "testParam"] {
                #expect(param.name == "testParam")
                #expect(param.functionTypes == .vertex)
            }
        }
    }

    @Test
    @MainActor
    func testMultipleParameters() {
        struct TestElement: Element {
            var body: some Element {
                EmptyElement()
                    .parameter("param1", value: Float(1.0))
                    .parameter("param2", value: SIMD4<Float>(1, 2, 3, 4))
                    .parameter("param3", functionType: .fragment, value: simd_float4x4.identity)
            }
        }

        _ = TestElement()
    }

    @Test
    @MainActor
    func testParameterWithDifferentFunctionTypes() {
        struct TestElement: Element {
            var body: some Element {
                EmptyElement()
            }
        }

        let element = TestElement()

        let vertexParam = element.parameter("vertexPos", functionType: .vertex, value: SIMD4<Float>(0, 0, 0, 1))
        #expect(vertexParam is ParameterElementModifier<TestElement>)

        let fragmentParam = element.parameter("fragmentColor", functionType: .fragment, value: SIMD4<Float>(1, 1, 1, 1))
        #expect(fragmentParam is ParameterElementModifier<TestElement>)

        let kernelParam = element.parameter("kernelSize", functionType: .kernel, value: Int32(256))
        #expect(kernelParam is ParameterElementModifier<TestElement>)

        let autoParam = element.parameter("autoDetect", functionType: nil, value: Float(1.0))
        #expect(autoParam is ParameterElementModifier<TestElement>)
    }

    @Test
    func testParameterValueVariants() {
        let device = MTLCreateSystemDefaultDevice()

        if let device {
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm,
                width: 256,
                height: 256,
                mipmapped: false
            )
            let texture = device.makeTexture(descriptor: textureDescriptor)
            let textureParam = ParameterValue<Float>.texture(texture)
            #expect(textureParam.debugDescription == "Texture()")
        }

        if let device {
            let samplerDescriptor = MTLSamplerDescriptor()
            samplerDescriptor.minFilter = .linear
            samplerDescriptor.magFilter = .linear
            let samplerState = device.makeSamplerState(descriptor: samplerDescriptor)
            let samplerParam = ParameterValue<Float>.samplerState(samplerState)
            #expect(samplerParam.debugDescription == "SamplerState()")
        }

        if let device {
            let buffer = device.makeBuffer(length: 1_024)
            buffer?.label = "TestBuffer"
            let bufferParam = ParameterValue<Float>.buffer(buffer, 128)
            #expect(bufferParam.debugDescription.contains("TestBuffer"))
            #expect(bufferParam.debugDescription.contains("128"))
        }

        let arrayParam = ParameterValue<Float>.array([1.0, 2.0, 3.0, 4.0, 5.0])
        #expect(arrayParam.debugDescription == "Array")

        let floatParam = ParameterValue<Float>.value(3.14159)
        #expect(floatParam.debugDescription == "3.14159")

        let intParam = ParameterValue<Int32>.value(42)
        #expect(intParam.debugDescription == "42")

        let simdParam = ParameterValue<SIMD4<Float>>.value(SIMD4<Float>(1, 2, 3, 4))
        #expect(simdParam.debugDescription.contains("1.0"))
    }
}
