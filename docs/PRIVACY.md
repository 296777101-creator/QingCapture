# Privacy

- Screenshots, annotation, overlap matching and OCR are processed on your Mac.
- The application does not upload screenshots or recognized text to a third-party server.
- Translation uses Apple's system Translation framework. Its language models may require a system-managed download on first use. Apple may collect API performance and language-pair metadata under its own policies; see [Apple Translation documentation](https://developer.apple.com/documentation/translation/translationsession).
- The app contains no analytics SDK, advertising, account system, third-party API key, or built-in cloud history.
- Screen Recording is required for capture. The app does not require Accessibility, microphone or camera access.
- Your configured shortcut is stored in local UserDefaults. A local file lock is used to prevent duplicate instances.
- Images reach the clipboard or filesystem only when you choose copy/save. The operating system and other apps with clipboard access can then access copied content.
- Mosaic/blur are visual effects, not a cryptographic guarantee that highly sensitive text cannot be inferred. Use opaque filled shapes when appropriate.
- Local development test output, recovery archives and personal screenshots are excluded from the public repository.
