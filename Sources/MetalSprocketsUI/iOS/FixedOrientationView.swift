#if os(iOS)
import SwiftUI
import UIKit

/// A container whose content stays physically still while the interface rotates around it, the way the Camera app's
/// preview does.
///
/// When the interface rotates, the content is turned back by the same amount inside the system's rotation animation,
/// and keeps its width and height, so on screen it doesn't move. SwiftUI can't do this itself: a `rotationEffect`
/// change lands after the system has already animated the window round.
///
/// Use it around content whose own orientation is tied to the device rather than the interface, such as a camera
/// feed. For AR, pair it with `arkit(session:frame:frameData:orientation:)` and `.fixed`, which keeps the camera
/// matrices at the angle the content started at.
///
/// The content is hosted separately, so it doesn't inherit the environment from outside this view; apply any
/// environment it needs inside the closure.
public struct FixedOrientationView<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        FixedOrientationHost(content: content)
    }
}

private struct FixedOrientationHost<Content: View>: UIViewControllerRepresentable {
    let content: Content

    func makeUIViewController(context: Context) -> FixedOrientationViewController<Content> {
        FixedOrientationViewController(rootView: content)
    }

    func updateUIViewController(_ viewController: FixedOrientationViewController<Content>, context: Context) {
        viewController.hostingController.rootView = content
    }
}

private final class FixedOrientationViewController<Content: View>: UIViewController {
    let hostingController: UIHostingController<Content>

    /// The rotation the content is turned by, in radians: the opposite of every interface rotation since it appeared.
    /// Updated as soon as a rotation is announced; decides the content's size.
    private var counterRotation: CGFloat = 0

    /// The rotation in the content's transform, which catches up with `counterRotation` inside the system's rotation
    /// animation.
    private var appliedRotation: CGFloat = 0

    /// The content's size for the duration of a rotation. UIKit resizes the container a layout pass before the
    /// rotation animation starts; holding the size keeps the content from being laid out at the wrong shape, which
    /// left the render view stuck at it.
    private var transitionContentSize: CGSize?

    init(rootView: Content) {
        hostingController = UIHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.clipsToBounds = true
        // The content fills its turned frame edge to edge; the container's safe area doesn't apply to it.
        hostingController.safeAreaRegions = []
        hostingController.view.backgroundColor = .clear
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = transitionContentSize ?? Self.contentSize(containerSize: view.bounds.size, counterRotation: counterRotation)
        hostingController.view.bounds = CGRect(origin: .zero, size: size)
        hostingController.view.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        hostingController.view.transform = CGAffineTransform(rotationAngle: appliedRotation)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        // `targetTransform` is the rotation the interface is about to animate through.
        let rotation = atan2(coordinator.targetTransform.b, coordinator.targetTransform.a)
        guard abs(rotation) > 0.001 else {
            return
        }
        counterRotation = Self.normalized(counterRotation - rotation)
        transitionContentSize = Self.contentSize(containerSize: size, counterRotation: counterRotation)
        coordinator.animate(alongsideTransition: { [self] _ in
            appliedRotation = counterRotation
            view.setNeedsLayout()
            view.layoutIfNeeded()
        }, completion: { [self] _ in
            transitionContentSize = nil
            view.setNeedsLayout()
        })
    }

    /// The content's size in a container of `containerSize`: the same, or with width and height swapped while the
    /// content is turned a quarter turn away from the interface.
    private static func contentSize(containerSize: CGSize, counterRotation: CGFloat) -> CGSize {
        let isQuarterTurned = Int((counterRotation / (.pi / 2)).rounded()).isMultiple(of: 2) == false
        return isQuarterTurned ? CGSize(width: containerSize.height, height: containerSize.width) : containerSize
    }

    /// The angle in `(-π, π]`.
    private static func normalized(_ angle: CGFloat) -> CGFloat {
        let wrapped = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if wrapped > .pi {
            return wrapped - 2 * .pi
        }
        if wrapped <= -.pi {
            return wrapped + 2 * .pi
        }
        return wrapped
    }
}
#endif
