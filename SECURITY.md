# Security and privacy

MacSwitch filters keyboard events through the public macOS Accessibility and Quartz event-tap APIs. It processes event types and recovery key codes in memory. It does not record typed content or send keyboard events to a server.

Sleep changes invoke only two fixed commands: `/usr/bin/pmset disablesleep 0` and `/usr/bin/pmset disablesleep 1`. The macOS authorization dialog handles administrator credentials; the application never receives a password field.

The application does not request Full Disk Access, Screen Recording, microphone, camera, or location access. Accessibility access is required for keyboard filtering. Screenshot tooling used to prepare documentation is separate from the shipped application.

The initial downloadable build is ad-hoc signed, without Developer ID notarization. Published checksums identify release assets; they are not an Apple security assessment.

When filing an issue, describe the affected behavior and version. Do not include credentials, private documents, your home-folder path, or keyboard contents. If the issue involves sensitive data, start with a minimal description and request a private reporting channel.
