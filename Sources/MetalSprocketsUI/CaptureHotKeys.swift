import Foundation
import Metal
import MetalSprockets
import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Keyboard shortcuts that trigger a GPU frame capture of descendant ``RenderView``s.
public struct CaptureHotKeys: Sendable {
    /// Captures to Xcode's frame debugger. `nil` turns this key off.
    public var developerTools: KeyboardShortcut?
    /// Writes a `.gputrace` file. `nil` turns this key off.
    public var traceFile: KeyboardShortcut?
    public var frames: Int
    public var target: CaptureTarget
    /// Where `.gputrace` files go. `nil` means the temporary directory.
    public var outputDirectory: URL?
    /// Reveals the `.gputrace` file in the Finder when the capture finishes (macOS only).
    public var revealFile: Bool

    public init(
        developerTools: KeyboardShortcut? = KeyboardShortcut("c", modifiers: [.control, .option, .command]),
        traceFile: KeyboardShortcut? = KeyboardShortcut("c", modifiers: [.control, .option, .command, .shift]),
        frames: Int = 5,
        target: CaptureTarget = .device,
        outputDirectory: URL? = nil,
        revealFile: Bool = true
    ) {
        precondition(frames > 0, "`frames` must be positive.")
        self.developerTools = developerTools
        self.traceFile = traceFile
        self.frames = frames
        self.target = target
        self.outputDirectory = outputDirectory
        self.revealFile = revealFile
    }

    /// ⌃⌥⌘C captures to Xcode; ⌃⌥⌘⇧C writes a `.gputrace` file.
    public static let `default` = Self()
}

public enum CaptureHotKeyResult: Sendable {
    case developerTools
    case file(URL)
}

public extension View {
    /// Adds keyboard shortcuts that capture the next frames of descendant ``RenderView``s.
    ///
    /// ```swift
    /// RenderView { ... }
    ///     .captureHotKeys()
    /// ```
    func captureHotKeys(_ keys: CaptureHotKeys = .default, onCapture: ((CaptureHotKeyResult) -> Void)? = nil) -> some View {
        modifier(CaptureHotKeysModifier(keys: keys, onCapture: onCapture))
    }
}

internal struct CaptureHotKeysModifier: ViewModifier {
    var keys: CaptureHotKeys
    var onCapture: ((CaptureHotKeyResult) -> Void)?

    @State
    private var configuration: RenderViewCaptureConfiguration?

    func body(content: Content) -> some View {
        content
            .transformEnvironment(\.renderViewCapture) { value in
                // Until a key is pressed, leave any outer `.capture` alone.
                if let configuration {
                    value = configuration
                }
            }
            .background {
                ZStack {
                    if let shortcut = keys.developerTools {
                        Button("Capture GPU Frame") { trigger(.developerTools) }
                            .keyboardShortcut(shortcut)
                    }
                    if let shortcut = keys.traceFile {
                        Button("Capture GPU Trace File") { trigger(.gpuTraceDocument) }
                            .keyboardShortcut(shortcut)
                    }
                }
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
    }

    private func trigger(_ destination: MTLCaptureDestination) {
        guard MTLCaptureManager.shared().isCapturing == false else {
            return
        }
        var outputURL: URL?
        if destination == .gpuTraceDocument {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate, .withTime]
            let name = "RenderView-\(formatter.string(from: Date())).gputrace"
            outputURL = (keys.outputDirectory ?? FileManager.default.temporaryDirectory).appendingPathComponent(name)
        }
        configuration = RenderViewCaptureConfiguration(
            enabled: true,
            target: keys.target,
            destination: destination,
            outputURL: outputURL,
            frames: keys.frames,
            generation: (configuration?.generation ?? 0) + 1
        )
        onCapture?(outputURL.map { .file($0) } ?? .developerTools)
        #if os(macOS)
        if keys.revealFile, let outputURL {
            Task { await reveal(outputURL) }
        }
        #endif
    }

    #if os(macOS)
    // The capture starts on a later frame, so wait for it to begin and then end.
    private func reveal(_ url: URL) async {
        let manager = MTLCaptureManager.shared()
        for _ in 0..<200 where !manager.isCapturing {
            try? await Task.sleep(for: .milliseconds(50))
        }
        for _ in 0..<600 where manager.isCapturing {
            try? await Task.sleep(for: .milliseconds(50))
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    #endif
}
