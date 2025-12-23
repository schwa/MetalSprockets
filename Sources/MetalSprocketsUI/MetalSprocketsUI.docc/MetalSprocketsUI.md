# ``MetalSprocketsUI``

SwiftUI integration for MetalSprockets—render to views, ARKit sessions, and visionOS immersive spaces.

## Overview

MetalSprocketsUI bridges MetalSprockets with SwiftUI, providing views and modifiers that let you embed GPU rendering in your app's UI.

```swift
import SwiftUI
import MetalSprockets
import MetalSprocketsUI

struct ContentView: View {
    var body: some View {
        RenderView { context, size in
            try MyRenderPipeline()
        }
    }
}
```

### Platforms

MetalSprocketsUI supports multiple rendering targets:

| Platform | Integration |
|----------|-------------|
| macOS / iOS | ``RenderView`` embeds Metal in SwiftUI |
| iOS + ARKit | Camera passthrough with AR frame data |
| visionOS | Immersive spaces with ``ImmersiveRenderContent`` |

## Topics

### SwiftUI Integration

- ``RenderView``
- ``RenderViewContext``

### visionOS Immersive Rendering

- ``ImmersiveRenderContent``
- ``ImmersiveRenderPass``

### Debugging

- ``RenderViewDebugging``

### Utilities

- ``YCbCrBillboardRenderPass``
