# Verification

Release: v1.0.1. Checked on 2026-11-02.

## Automated checks

- Release compilation for arm64 and x86_64.
- Separate `xcrun lipo -verify_arch` checks for both CPU slices. This replaces the combined architecture check that prevented packaging on the development Mac.
- Minimum macOS version checked from executable load commands and application metadata.
- 14 Swift Testing tests covering real `pmset` output parsing, unknown values, fixed command selection, keyboard filtering, mouse-event allowance, recovery modifiers, and the triple-Esc recovery sequence.
- Password tests cover Korean language variants, English fallback, unchanged privileged commands, and compilation of both sleep commands in both languages without executing them.
- Recovery tests reject held-key repeats, slow sequences, and sequences interrupted by another key.
- Shell syntax, app property-list validation, ad-hoc code-signature verification, ZIP integrity, and DMG verification.

## Interactive checks

- The app was launched from a local Applications folder on an Apple Silicon Mac.
- Menu-bar controls, selection indicators, descriptions, and permission guidance were inspected.
- Actual `SleepDisabled` settings of both 1 and 0 were observed during development.
- A permitted build created an enabled keyboard event tap and was released using the mouse.
- `docs/assets/screenshot-live.png` was captured from the running app window. Its metadata was removed without changing pixels.
- Korean and English quick-start posters were generated with ImageGen and visually inspected. They are labeled separately from real captures.

## Limits

- Language selection and script syntax are tested. These checks do not verify the text shown by macOS security UI. A subsequent macOS 27 report confirmed that the system can replace the requested short prompt with its own long script-security warning. The app cannot customize that warning. No credentials are entered during tests.

- The Intel slice is compiled and structurally verified; execution on a physical Intel Mac has not been tested.
- Triple-Esc recovery is covered by automated policy tests. A physical-keyboard end-to-end recovery check has not been completed; synthetic UI input did not establish this result. Mouse release remains available.
- Accessibility permission must be granted separately to the installed release. Changing the locally signed executable may require removing and re-adding its permission entry.
- This release is ad-hoc signed and has no Apple Developer ID signature or notarization. Local signature validity is separate from Gatekeeper approval for an Internet download.

## Reproduce

```sh
bash Scripts/test.sh
bash Scripts/build.sh
python3 Scripts/audit-public.py --archive artifacts.nosync/MacSwitch.zip
```

Build caches, diagnostic tools, logs, and local review copies are excluded through `artifacts.nosync/` and `.gitignore`.
