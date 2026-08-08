import Observation
import Testing

@testable import MetalSprockets

@Observable
private final class EqualityTestModel {
    var value = 0
}

private final class PlainEqualityTestModel {
    var value = 0
}

@Suite("Observable-holding element equality (#352)")
struct ObservableElementEqualityTests {
    @Test("Element holding the same @Observable instance compares equal")
    func sameObservableInstanceIsEqual() {
        struct ModelElement {
            let model: EqualityTestModel
        }
        let model = EqualityTestModel()
        #expect(isEqual(ModelElement(model: model), ModelElement(model: model)))
    }

    @Test("Element holding different @Observable instances compares unequal")
    func differentObservableInstancesAreNotEqual() {
        struct ModelElement {
            let model: EqualityTestModel
        }
        #expect(!isEqual(ModelElement(model: EqualityTestModel()), ModelElement(model: EqualityTestModel())))
    }

    @Test("Mutating the observed model does not change identity-based equality")
    func mutationDoesNotAffectEquality() {
        struct ModelElement {
            let model: EqualityTestModel
        }
        let model = EqualityTestModel()
        let before = ModelElement(model: model)
        model.value = 42
        #expect(isEqual(before, ModelElement(model: model)))
    }

    @Test("Optional model property compares by identity")
    func optionalModelProperty() {
        struct ModelElement {
            let model: EqualityTestModel?
        }
        let model = EqualityTestModel()
        #expect(isEqual(ModelElement(model: model), ModelElement(model: model)))
        #expect(isEqual(ModelElement(model: nil), ModelElement(model: nil)))
        #expect(!isEqual(ModelElement(model: model), ModelElement(model: nil)))
        #expect(!isEqual(ModelElement(model: model), ModelElement(model: EqualityTestModel())))
    }

    @Test("A class element is never equal, even to itself")
    func classElementsAreNeverEqual() {
        // System relies on this: a class element's mutable properties are invisible to reflection.
        let model = EqualityTestModel()
        #expect(!isEqual(model, model))
    }

    @Test("Same reference for a plain class property compares equal")
    func samePlainClassInstanceIsEqual() {
        struct ModelElement {
            let model: PlainEqualityTestModel
            let count: Int
        }
        let model = PlainEqualityTestModel()
        #expect(isEqual(ModelElement(model: model, count: 1), ModelElement(model: model, count: 1)))
        #expect(!isEqual(ModelElement(model: model, count: 1), ModelElement(model: model, count: 2)))
    }
}
