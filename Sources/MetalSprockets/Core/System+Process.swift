package extension System {
    // Signposted as Setup and Workload by `render(root:)`. `PhaseRunner` does the traversal (#390).
    func processSetup() throws {
        try withCurrentSystem {
            try PhaseRunner(events: traversalEvents, traversalContext: traversalContext).runSetup()
        }
    }

    func processWorkload() throws {
        try withCurrentSystem {
            try PhaseRunner(events: traversalEvents, traversalContext: traversalContext).runWorkload()
        }
    }
}
