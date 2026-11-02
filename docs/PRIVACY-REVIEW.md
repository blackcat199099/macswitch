# Public-release privacy review

Review date: 2026-11-02. Scope: the initial public source tree, documentation, four PNG assets, ZIP contents, and the packaged executable. The DMG was mounted read-only and its application files compared with the ZIP.

## Result

No credentials or private user identifiers were detected in the publication candidates by the checks below. This is a focused publication review, not an exhaustive security certification.

## Changes made before publication

- Replaced the development-machine home-folder path in documentation with generic installation locations.
- Replaced the personalized application identifier with the public GitHub project identifier.
- Removed textual and EXIF metadata from documentation PNGs while preserving the image-data chunks.
- Limited the real screenshot to the MacSwitch application window; no desktop, account pane, or unrelated document is shown.
- Kept build caches, temporary input probes, logs, review copies, and local artifacts out of Git.
- Configured the initial Git author to use a project name and the public GitHub noreply address, rather than the machine's existing personal Git identity.
- Included the MIT license in the repository and the app bundle. Retained upstream icon notices and licenses.

## Checks

- Credential patterns: private-key headers, common GitHub and API token formats, and cloud access-key patterns.
- Text, images, and the executable: checks for the private development username, former personal branding, and the local cloud-storage path.
- Source documents and release executable: checks for embedded personal home-folder paths.
- Images: manual visual inspection of the real app capture and both generated guides; no personal names, emails, accounts, passwords, or unrelated screen contents were found.
- PNG structure: no text/EXIF metadata remains in the published images.
- ZIP: no environment files, private keys, Finder sidecar metadata, diagnostic tools, or build-cache directories are included.
- DMG: checked its visible file list, the Applications shortcut, application signatures, and equality with the ZIP application.
- Git: the initial commit contains only the reviewed project files. The public GitHub handle and project links are intentionally included as ownership information.

The app itself has no analytics, backend, account system, credential store, or keyboard-content log. Keyboard events are handled in memory to filter input and recognize recovery gestures. Administrator authentication is handled by macOS for the two fixed sleep-setting commands.

## Reproduce

```sh
python3 Scripts/audit-public.py --archive artifacts.nosync/MacSwitch.zip
```

For a private review, add `--forbid` arguments for local identifiers and `--binary` for the extracted app executable. Matched values are never printed by the audit script. Do not commit a private identifier list or local scan logs.

The review covers material being published. It does not assess unrelated files elsewhere on the developer's computer. Intel hardware execution, physical-keyboard emergency recovery, and Apple notarization limits are documented in `VERIFICATION.md`.

## v1.0.1 follow-up

The short Korean and English password messages were reviewed together with the updated executable and installer. Publication checks were repeated for the new tracked files, ZIP contents, and release executable. The password tests compile the authorization scripts without executing them or entering credentials. Password handling still belongs to the existing macOS authorization dialog.
