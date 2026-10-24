# Development and testing

## Toolchain

Use macOS with Xcode or Command Line Tools containing a macOS 15+ SDK. The runtime deployment target is macOS 14; Translation APIs are guarded behind macOS 15 availability checks. Scripts discover a compatible installed SDK without changing the selected system toolchain. If automatic selection fails, set `QINGCAPTURE_SDK_PATH` explicitly.

Builds target the current CPU by default. Cross-compile by setting `QINGCAPTURE_ARCH=arm64` or `QINGCAPTURE_ARCH=x86_64` with a compatible SDK. Release ZIP names include the architecture.

## Commands

```bash
bash scripts/test.sh       # Core rendering, stitching, OCR and archive recovery tests
bash scripts/build.sh      # Build and ad-hoc sign the app
bash scripts/smoke.sh      # Native UI integration checks in a GUI session
bash scripts/install.sh    # Install and create the Desktop entry
bash scripts/package.sh    # Create a release ZIP and checksum
```

`Package.swift` describes module boundaries; direct compiler scripts are provided to avoid SwiftPM/toolchain component mismatches on some local installations.

## Tests

Core tests use synthetic images, no live private screenshots. They validate coordinate conversion, pixel orientation, Retina output dimensions, render effects, annotation hit testing/history, shortcut persistence, process exclusion, Vision recognition, overlap stitching and Unicode-preserving translation chunking. The Python test verifies two same-named application archives can both be recovered.

Smoke tests create actual AppKit windows and native events using isolated preferences, then verify shortcut recording/conflicts, save cancellation, clipboard consistency, pinned/long image windows and cleanup. They temporarily save/restore clipboard data. Run them in a logged-in GUI session; background-user focus changes can interfere with menu-key event tests. Real ScreenCaptureKit sampling and first language-model downloads need manual acceptance checks.

## Manual checks

- Trigger the global hotkey while another app is foreground; record a different shortcut and relaunch.
- Capture/save/copy on Retina and external displays; cancel save and resume editing.
- Start long capture over a scrollable page, scroll with overlap, pause/resume, cancel, and finish to the long editor.
- Translate a synthetic sentence, approve the system's language download if necessary, retry, cancel and copy the result.
- Close OCR/translation/long-capture windows and confirm no hidden capture session or timer remains.

## Distribution

The local installer preserves old builds as verified ZIPs in `build/Archives.noindex/`, unregisters generated development copies and keeps one installed app at `/Applications/轻截.app`. Duplicate application entries outside the project are unregistered without deleting those files.

Community ZIPs use ad-hoc signatures. A production distributor can replace that step with their Developer ID signing and notarization pipeline. Do not add quarantine-removal or TCC modification commands to the installer.
