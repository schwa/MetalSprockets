import Metal
@testable import MetalSprockets
import Testing

@Suite("Submission index")
struct SubmissionIndexTests {
    private final class Recorder {
        var values: [(UInt64, Int)] = []

        func record(_ index: UInt64, _ limit: Int) -> EmptyElement {
            values.append((index, limit))
            return EmptyElement()
        }
    }

    @Test("Each recording sees its own submission index and the in-flight limit", .requiresMetal4)
    func indexAdvancesPerSubmission() throws {
        let runner = try Runner(maximumInFlightSubmissions: 2)
        let recorder = Recorder()
        for _ in 0..<5 {
            let element = EnvironmentReader(keyPath: \.submissionIndex) { index in
                EnvironmentReader(keyPath: \.maximumInFlightSubmissions) { limit in
                    recorder.record(index, limit)
                }
            }
            _ = try runner.submit(element)
        }
        #expect(recorder.values.map(\.0) == [1, 2, 3, 4, 5])
        #expect(recorder.values.allSatisfy { $0.1 == 2 })
    }

    @Test("Outside a recording the defaults apply")
    func defaults() {
        let values = MSEnvironmentValues()
        #expect(values.submissionIndex == 0)
        #expect(values.maximumInFlightSubmissions == 1)
    }
}
