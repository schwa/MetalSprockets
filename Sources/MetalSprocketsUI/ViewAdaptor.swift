import SwiftUI

#if os(macOS)
internal struct ViewAdaptor<ViewType>: View where ViewType: NSView {
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

        func makeCoordinator() -> ViewAdaptorCoordinator<ViewType> {
            ViewAdaptorCoordinator(dismantle: dismantle)
        }

        func makeNSView(context: Context) -> ViewType {
            make()
        }

        func updateNSView(_ nsView: ViewType, context: Context) {
            update(nsView)
        }

        static func dismantleNSView(_ nsView: ViewType, coordinator: ViewAdaptorCoordinator<ViewType>) {
            coordinator.dismantle(nsView)
        }
    }
}

#elseif os(iOS) || os(tvOS) || os(visionOS)
internal struct ViewAdaptor<ViewType>: View where ViewType: UIView {
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

        func makeCoordinator() -> ViewAdaptorCoordinator<ViewType> {
            ViewAdaptorCoordinator(dismantle: dismantle)
        }

        func makeUIView(context: Context) -> ViewType {
            make()
        }

        func updateUIView(_ uiView: ViewType, context: Context) {
            update(uiView)
        }

        static func dismantleUIView(_ uiView: ViewType, coordinator: ViewAdaptorCoordinator<ViewType>) {
            coordinator.dismantle(uiView)
        }
    }
}
#endif

/// Carries the teardown action to the static `dismantle` entry points, which cannot see the representable's own
/// properties. See #301.
internal final class ViewAdaptorCoordinator<ViewType> {
    let dismantle: (ViewType) -> Void

    init(dismantle: @escaping (ViewType) -> Void) {
        self.dismantle = dismantle
    }
}
