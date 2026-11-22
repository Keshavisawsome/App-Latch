# AppLatch for macOS 11+

A native menu bar prototype that hides selected apps and asks macOS to authenticate before bringing them back. **Your Mac login password works even if your Mac has no Touch ID.**

This download contains source code, an Xcode project, and build instructions. It is not a prebuilt installer. The app has not yet been compiled or tested on a Mac.

## Build on your Mac

1. Unzip this folder.
2. Install an Xcode version that runs on your macOS version. **Xcode 12.4** supports macOS 11.0; **Xcode 13.2.1** requires macOS 11.3 or later. Get older versions from [Apple Developer Downloads](https://developer.apple.com/download/all/). A free Apple account may be needed to download Xcode. The newest App Store version of Xcode may not run on Big Sur.
3. Open `AppLatch.xcodeproj` in Xcode. Select the **AppLatch** scheme and **My Mac** as the destination.
4. Press **Command–R** to build and run. The project uses local ad hoc signing and does not require a paid developer team for this local build.
5. Look for the shield/lock icon in your menu bar. The main window also opens at launch.

An alternative after installing and opening Xcode once is to run `bash build.command` from Terminal in this folder. It builds `build/Build/Products/Release/AppLatch.app` and opens the containing folder. It does not install or start the app automatically. If `xcodebuild` says only Command Line Tools are selected, choose your full Xcode installation under **Xcode → Preferences → Locations → Command Line Tools**.

For daily use, quit the debug copy, build the Release version with the script, and copy the resulting `AppLatch.app` to Applications. Run just one copy. If you want it to open at login on Big Sur, add that copy under **System Preferences → Users & Groups → Login Items**. There is no automatic login helper in this prototype, and protection starts only after AppLatch is running.

## Try it without Touch ID

1. Click **Add Apps…** and choose a simple app such as TextEdit. Confirm the system password prompt to add protection.
2. Open TextEdit. AppLatch attempts to hide it and presents its unlock window.
3. Choose **1 minute**, **5 minutes**, or **15 minutes**, then click **Unlock**.
4. Enter the password you use to log in to your Mac **in the macOS system prompt**.
5. After successful authentication, the app opens for that duration. When time runs out, AppLatch attempts to hide it again. **Lock All Now** ends all unlock sessions immediately.

Wrong passwords or canceled authentication do not grant access. If macOS authentication is unavailable, AppLatch reports the error and does not unlock. Anyone who knows your Mac login password can authenticate; this version does not add a separate PIN.

## Included behavior

- Select multiple `.app` bundles and persist the protected list across launches.
- Native password authentication using `LAContext` with `.deviceOwnerAuthentication`; Touch ID and supported Apple Watch authentication remain optional system capabilities.
- Temporary unlocks for each app, stored only in memory.
- Monotonic time for expiry so changes to the wall clock do not extend a grant.
- Relock after a protected app quits, after AppLatch restarts, and on system sleep, display sleep, wake, or session-switch notifications.
- Authenticate before adding or removing apps and before quitting through AppLatch's own menu.
- Menu bar controls, a countdown for each unlocked app, and native light/dark appearance.
- Cancel pending authentication when all apps are locked or a different app's gate takes over. Ignore stale callbacks after cancellation.
- Show a warning if an application refuses a hide request.

Finder and AppLatch itself are excluded. Closing the settings window leaves the menu bar utility running. Closing the unlock window cancels that attempt.

## What this prototype protects

AppLatch is a **casual privacy barrier**, not an operating-system security boundary. It reacts after activation and attempts to hide apps. Content can briefly appear before the gate. Some apps, full-screen windows, or Spaces behavior may not cooperate with hiding; test each app you plan to use.

Force-quitting, terminating, or uninstalling AppLatch bypasses protection. The protected list can be modified by someone with access to your user account. Apps keep running in the background. Their files, notifications, audio, previews, and other ways to access data are not locked or encrypted. The gate does not cover every display or replace the macOS lock screen.

The public notifications used here handle sleep/display sleep and session changes. **Screen locking alone is not guaranteed to revoke an existing unlock immediately.** Use Lock All Now before sharing your Mac. This is not an iOS 18-equivalent native app lock.

No network requests, analytics, custom password fields, or stored passwords are included. The protected apps' names, bundle identifiers, and paths are saved locally in UserDefaults. macOS performs authentication; the app receives its success/failure result.

## Validation status

The project targets macOS 11.0 and Swift 5, uses Xcode 12-compatible project syntax, and includes a shared scheme. Source/project references, plist/XML, and shell syntax were checked in the Linux workspace. All six Swift files passed a tree-sitter syntax parse; this is not compiler type checking or an SDK compatibility test. **AppKit compilation, the UI, and real macOS password prompts still require testing on a Mac.**

`swift test` runs the Foundation-only lock-policy tests included under `Tests`. They cover independent app grants, the exact expiry boundary, revocation, and invalidation of pending authorization after Lock All. The Swift toolchain was not available in the workspace, so these tests were not executed here. The Xcode app scheme does not contain the package tests; run them with `swift test` in this directory.

Use [MANUAL_TESTS.md](MANUAL_TESTS.md) for the first run, especially on your Mac without Touch ID.

## Project files

| File | Purpose |
|---|---|
| `AppLatch/AppLatchApp.swift` | Menu bar, native windows, application picker |
| `AppLatch/AppModel.swift` | Password authentication, app monitoring, persistence, unlock flow |
| `AppLatch/LockPolicy.swift` | In-memory expiry and authorization generation |
| `AppLatch/Views.swift` | Settings and unlock views |
| `AppLatch/Info.plist` | macOS menu bar app metadata |
| `Package.swift` and `Tests` | Foundation-only policy test package |

## Apple references

- [Device owner authentication](https://developer.apple.com/documentation/localauthentication/lapolicy/deviceownerauthentication): macOS supports the user's password when biometrics are unavailable.
- [LAContext](https://developer.apple.com/documentation/localauthentication/lacontext): system-managed authentication and its callback.
- [App activation notification](https://developer.apple.com/documentation/appkit/nsworkspace/didactivateapplicationnotification).
- [Hiding a running app](https://developer.apple.com/documentation/appkit/nsrunningapplication/hide()).
- [Xcode 12.4 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-12_4-release-notes).
- [Xcode 13.2.1 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-13_2_1-release-notes).
