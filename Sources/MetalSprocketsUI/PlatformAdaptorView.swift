import SwiftUI

#if os(macOS)
internal struct PlatformAdaptorView<ViewType>: View where ViewType: NSView {
    let make: () -> ViewType
    let update: (ViewType) -> Void
    let dismantle: (ViewType) -> Void

    init(make: @escaping () -> ViewType, update: @escaping (ViewType) -> Void, dismantle: @escaping (ViewType) -> Void = { _ in /* no teardown */ }) {
        self.make = make
        self.update = update
        self.dismantle = dismantle
    }

    var body: some View {
        Representation(make: make, update: update, dismantle: dismantle)
    }

    struct Representation: NSViewRepresentable {
        let make: () -> ViewType
        let update: (ViewType) -> Void
        let dismantle: (ViewType) -> Void

        func makeCoordinator() -> PlatformAdaptorCoordinator<ViewType> {
            PlatformAdaptorCoordinator(dismantle: dismantle)
        }

        func makeNSView(context: Context) -> ViewType {
            make()
        }

        func updateNSView(_ nsView: ViewType, context: Context) {
            update(nsView)
        }

        static func dismantleNSView(_ nsView: ViewType, coordinator: PlatformAdaptorCoordinator<ViewType>) {
            coordinator.dismantle(nsView)
        }
    }
}

#elseif os(iOS) || os(tvOS) || os(visionOS)
internal struct PlatformAdaptorView<ViewType>: View where ViewType: UIView {
    let make: () -> ViewType
    let update: (ViewType) -> Void
    let dismantle: (ViewType) -> Void

    init(make: @escaping () -> ViewType, update: @escaping (ViewType) -> Void, dismantle: @escaping (ViewType) -> Void = { _ in /* no teardown */ }) {
        self.make = make
        self.update = update
        self.dismantle = dismantle
    }

    var body: some View {
        Representation(make: make, update: update, dismantle: dismantle)
    }

    struct Representation: UIViewRepresentable {
        let make: () -> ViewType
        let update: (ViewType) -> Void
        let dismantle: (ViewType) -> Void

        func makeCoordinator() -> PlatformAdaptorCoordinator<ViewType> {
            PlatformAdaptorCoordinator(dismantle: dismantle)
        }

        func makeUIView(context: Context) -> ViewType {
            make()
        }

        func updateUIView(_ uiView: ViewType, context: Context) {
            update(uiView)
        }

        static func dismantleUIView(_ uiView: ViewType, coordinator: PlatformAdaptorCoordinator<ViewType>) {
            coordinator.dismantle(uiView)
        }
    }
}

#else
// Without this the failure on a new platform is a confusing "cannot find PlatformAdaptorView in scope" at every use
// site rather than a statement of what is actually missing.
#error("MetalSprocketsUI has no platform view representable for this platform.")
#endif

/// Carries the teardown action to the static `dismantle` entry points, which cannot see the representable's own
/// properties. See #301.
internal final class PlatformAdaptorCoordinator<ViewType> {
    let dismantle: (ViewType) -> Void

    init(dismantle: @escaping (ViewType) -> Void) {
        self.dismantle = dismantle
    }
}
