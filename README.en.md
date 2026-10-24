# QingCapture · 轻截

<img src="docs/assets/icon.png" width="88" alt="QingCapture icon">

A native macOS menu-bar screenshot utility with annotation, scrolling capture, local OCR and Apple-powered translation. Built with Swift, AppKit, ScreenCaptureKit, Vision and SwiftUI. No third-party runtime required.

[简体中文](README.md) · [Downloads](https://github.com/296777101-creator/QingCapture/releases) · [Development](docs/DEVELOPMENT.md) · [Architecture](docs/ARCHITECTURE.md) · [Privacy](docs/PRIVACY.md)

## Features

- Region/full-screen selection and original-resolution Retina export.
- Shapes, filled shapes, single/double-ended arrows, lines, freehand drawing, highlighter, text, numbered markers, eraser, mosaic and blur.
- Color, stroke width, font size, undo/redo and undoable clear.
- Manual-scroll automatic-overlap **long screenshots**, with pause/resume and a scrollable annotation editor.
- Local **OCR and translation**, editable source text, language selectors and copyable results.
- Floating pinned screenshots, PNG saving and PNG/TIFF clipboard output.
- Persistent customizable global shortcut, conflict detection and single-instance startup.

## Requirements and installation

macOS 14 or later; translation requires macOS 15 or later. The current prebuilt package targets Apple Silicon (`arm64`). Intel builds are available from source.

Download a ZIP from [Releases](https://github.com/296777101-creator/QingCapture/releases), move `轻截.app` to Applications and grant Screen Recording in System Settings. Community packages are ad-hoc signed and not Developer ID notarized; macOS may ask you to approve opening them. Source builds are an alternative.

The default capture shortcut is **Control + Option + A**. Use the app's shortcut settings to record and save another combination. Enter copies, Command+S saves, Esc/right-click cancels, Command+Z undoes and Shift+Command+Z redoes.

## Scrolling capture

Select the page region, click **长截图**, then scroll the underlying app downward slowly while keeping overlapping content. The app excludes its floating controls from capture and automatically appends confidently matched strips. Pause, sample manually or finish from the floating panel. Finished images open in a scrollable editor for annotation/export.

Duplicate, reversed and uncertain frames are rejected. Animated content, repeated identical rows, parallax and horizontal movement may prevent alignment. The default output limit is 32 million pixels and 30,000 pixels in height. Cross-display stitching is not supported.

## Translation

Click **翻译** on the screenshot toolbar or the OCR result window. Edit the source if needed, choose languages, translate and copy the result. Apple's system may request a language-model download on first use. Translation uses system-managed on-device models, not a third-party screenshot upload API. See [privacy details](docs/PRIVACY.md).

## Build

Install a matching Xcode/Command Line Tools toolchain with a macOS 15+ SDK:

```bash
git clone https://github.com/296777101-creator/QingCapture.git
cd QingCapture
bash scripts/test.sh
bash scripts/build.sh
open build/Artifacts.noindex/轻截.app
```

`bash scripts/install.sh` installs locally and creates a Desktop entry. `bash scripts/package.sh` creates a signed application ZIP and SHA-256 checksum. Override SDK/architecture using `QINGCAPTURE_SDK_PATH` and `QINGCAPTURE_ARCH` if needed.

See [Contributing](CONTRIBUTING.md), [Changelog](CHANGELOG.md), [Security](SECURITY.md) and [MIT License](LICENSE). This independent project is not affiliated with WeChat or Apple.
