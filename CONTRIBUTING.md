# Contributing

1. Fork the repository and create a focused branch.
2. Use a matching Xcode/Command Line Tools installation. `scripts/swift-env.sh` discovers a compatible SDK; override with `QINGCAPTURE_SDK_PATH` if necessary.
3. Run `bash scripts/test.sh` and `bash scripts/build.sh` before submitting a pull request.
4. For AppKit interaction changes, run `bash scripts/smoke.sh` in a logged-in GUI session. It uses synthetic images and an isolated shortcut preference domain. Screen capture and first language-model download need separate manual checks.
5. Add a regression test for the bug you fix. Keep screenshot fixtures synthetic and do not include private images, logs, credentials or machine-specific paths.

Changes to overlap matching should cover duplicate/reverse/non-overlapping frames, sticky chrome, exact output pixels and memory limits. Changes to native UI should verify capture cancellation, save cancellation, shortcuts, result-window focus and cleanup.

Include macOS version, CPU architecture, reproduction steps and expected/actual behavior in bug reports. Please redact screenshots before sharing.
