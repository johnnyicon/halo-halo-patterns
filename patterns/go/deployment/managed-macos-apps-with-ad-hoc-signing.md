---
id: "managed-macos-apps-with-ad-hoc-signing"
title: "Build and install local macOS apps with ad hoc signing"
type: implementation
status: validated
confidence: high
revision: 1
languages:
  - language: any
    versions: "*"
frameworks:
  - name: macOS application bundles
    version: "*"
    ecosystem: other
dependencies: []
runtime: ["macos"]
domain: deployment
tags: [macos, local-apps, internal-deployment, tauri, code-signing, notarization, launchd]
introduced: 2026-11-25
last_verified: 2026-11-25
review_by: 2027-02-25
maintainers: ["@kanekoa"]
related: [macos-xattr-provenance-sigkill-binary]
sanitized: true
---

# Build and install local macOS apps with ad hoc signing

Use ad hoc signing for apps built locally or installed directly by a trusted
operator on their own Macs. This includes a Tauri app with a bundled background
agent. Ad hoc signing seals the bundle locally without an Apple Developer ID
certificate. Build and deploy through the app's existing managed path.

For an app distributed as a download to other users, plan for Developer ID
signing and notarization so macOS Gatekeeper can recognize the release.
[Apple's distribution guidance](https://developer.apple.com/macos/distribution/)
[Apple's Gatekeeper guidance](https://support.apple.com/en-us/102445)

## Managed install

1. Check the existing installed app and the owner's deployment method. This
   shows the current signing identity.

   ```sh
   codesign -dv --verbose=4 "/Applications/Example.app" 2>&1
   ```

2. Build the native app and bundle its helper before signing. For a Tauri CLI
   build with ad hoc signing, set `APPLE_SIGNING_IDENTITY=-`. Have the build
   sign the nested executable and then the enclosing app.

3. Verify the final bundle on the build machine and, where applicable, again
   after transfer to the destination Mac.

   ```sh
   codesign --verify --deep --strict "/path/to/Example.app"
   ```

4. Use the existing managed installation process at a stable path. Retain a
   rollback copy and preserve worker state. Verify launch, login startup if
   applicable, and a background check-in with the app closed before retiring
   an older service. Keep macOS security controls enabled.

## Evidence and limits

The installed Forge apps on two owner-managed Macs reported
`Signature=adhoc`. A newer test bundle with an embedded Go agent passed
strict signature verification on the destination Mac, and the helper ran
from inside that bundle. A separate disposable launchd test verified that
a paired helper could run in the background and disconnect. The test bundle
was verified in staging. Live worker replacement and post-upgrade behavior
remain acceptance checks for the managed rollout.
