import SwiftUI

/// Styles a small floating readout that sits on top of rendered content.
///
/// Rendered output is arbitrary — it can be any colour, and it changes every frame — so overlays need their own
/// backing to stay legible. This applies the standard treatment: a material backing, rounded corners, and enough
/// padding to keep the badge off the edge of the drawable.
///
/// ```swift
/// RenderView { context, size in
///     // ...
/// }
/// .overlay(alignment: .bottomTrailing) {
///     Text("MSAA 4x")
///         .modifier(OverlayBadgeModifier())
/// }
/// ```
public struct OverlayBadgeModifier: ViewModifier {
    /// Not derived from anything in the environment: it is the badge's own corner rounding, matched to the system's
    /// small-control radius.
    private let cornerRadius: CGFloat = 8

    public init() {
        // This line intentionally left blank.
    }

    public func body(content: Content) -> some View {
        content
            .padding()
            .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
            .padding()
    }
}

#Preview {
    Color.orange
        .overlay(alignment: .bottomTrailing) {
            Text("MSAA 4x")
                .modifier(OverlayBadgeModifier())
        }
}
