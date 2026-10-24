# Security

Do not publish credentials or unredacted private screenshots in issues. For a sensitive vulnerability, use GitHub's private vulnerability reporting if enabled, or contact the repository owner through their public GitHub profile before disclosing details.

The app uses macOS Screen Recording permissions and system translation components. It does not edit TCC databases, inject input into other applications or disable system security settings.

Prebuilt community releases may be ad-hoc signed rather than Apple Developer ID signed/notarized. Inspect the source and build locally if you require a different trust model. Enterprise distribution should use its own signing and notarization pipeline.
