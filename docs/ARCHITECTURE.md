# Architecture

QingCapture is a native macOS menu-bar screenshot utility with no third-party runtime dependencies.

## Modules

- **QingCaptureCore**: point/pixel coordinate conversion, non-destructive annotation models, snapshot undo/redo, Core Graphics rendering, Vision OCR, shortcut persistence and single-instance file locking, translation text chunking, and `VerticalStitcher`.
- **QingCaptureApp**: AppKit lifecycle, Carbon hotkeys, ScreenCaptureKit capture, selection canvases, annotation toolbar, settings/shortcut recording, floating screenshots, OCR results, scrolling capture, and a SwiftUI window backed by Apple Translation.
- **scripts**: compatible SDK discovery, build, tests, local installation, packaging, and sanitized source export.

## Capture

The app requests the normal macOS Screen Recording permission. It freezes each display at native pixel resolution and presents a selection view in logical points. Export converts the selected rect to pixel coordinates, clips the original capture and renders annotation objects without reducing Retina resolution. No screenshot is automatically written to disk.

## Scrolling capture

A selected region stays fixed in display coordinates while the user scrolls the original application. The capture session hides the frozen overlay and excludes the app's own windows from ScreenCaptureKit output. A click-through border marks the region; a control panel provides pause, manual sample, finish and cancel.

The compositor downsamples horizontally, searches vertical overlap at coarse resolution, refines to individual pixels, rejects unchanged or ambiguous frames and appends only the newly revealed strip. Stable top/bottom regions receive special treatment so sticky interface chrome is not repeatedly inserted. Reverse or non-overlapping frames do not alter the accumulated result.

The default limit is 32 million output pixels and 30,000 pixels in height. Accepted strips are copied into bounded storage so cropped images do not retain every full display frame. Finishing opens a scrollable annotation editor; cancellation restores the original selection.

Scroll slowly with overlapping content. Animated pages, repeated identical rows, parallax, cross-display changes and horizontal movement can prevent reliable alignment. Such frames are rejected instead of blindly concatenated.

## Translation

Vision OCR extracts text locally. The translation window allows editing the source, choosing source/target languages and copying the result. macOS 15+ Apple Translation sessions manage language detection, model download approval and translation. Text is divided into bounded Unicode-safe chunks; no API key or external translation service is used. macOS 14 keeps screenshot/OCR features and shows the translation version requirement.

## Lifecycle

A process file lock prevents duplicate normal instances. Hotkey replacement is transactional: register the candidate exclusively before releasing the active binding; conflict leaves the previous binding intact. Recording temporarily pauses the binding and restores it on completion, focus loss or window close.

At most one capture session is active. OCR/translation/scrolling UI retains the current session and brings it forward on repeated invocation. Closing/cancelling releases timers, child panels, result windows and capture overlays.
