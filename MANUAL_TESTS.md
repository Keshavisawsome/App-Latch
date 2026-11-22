# First Mac test

These checks are **pending**. Start with TextEdit and non-sensitive sample text. A successful source review is not a substitute for this run on macOS 11.

| Check | Expected result |
|---|---|
| Build with Xcode 12.4 or a compatible newer Xcode | App builds and starts without unavailable-API errors |
| Launch on a Mac with no Touch ID | Settings show the password explanation; menu bar icon appears |
| Add TextEdit and cancel the system prompt | App list stays unchanged |
| Add TextEdit with the Mac login password | TextEdit appears in the protected list |
| Open TextEdit from Dock, Spotlight, and Command–Tab | AppLatch attempts to hide TextEdit and shows the gate |
| Click Unlock without Touch ID | macOS presents a password-capable prompt; there is no AppLatch password field |
| Cancel or submit an incorrect password | TextEdit receives no unlock grant |
| Successfully unlock for one minute | TextEdit opens; settings show a countdown |
| Open another protected app | The second app still requires authentication |
| Wait until the first grant expires with TextEdit active | TextEdit hides and the gate returns; allow normal timer scheduling delay |
| Lock All during an unlock session | All grants disappear and protected apps are hidden |
| Lock All while a system authentication prompt is pending | Pending request is canceled; a late result does not reopen the app |
| Close the gate while authentication is pending | Request is canceled, with no unlock grant |
| Open app B while app A's authentication is pending | A's request is invalidated; it cannot unlock B |
| Quit and reopen a protected app | It requires authentication again |
| Sleep/wake the Mac during an unlock session | Grants are revoked; a fresh authentication is required |
| Lock the screen without display sleep | Record behavior; immediate revocation is not guaranteed in this prototype |
| Remove an app; first cancel, then authenticate | Cancel preserves protection; success removes the app |
| Quit using the AppLatch menu; first cancel, then authenticate | Cancel keeps the monitor running; success quits |
| Close settings and reopen from the menu bar | Monitoring continues; settings reopen |
| Restart AppLatch | Protected list persists; no temporary unlocks persist |
| Try full-screen apps, different Spaces, and multiple displays | Check for content flashes or hide failures before relying on that app |
| Force-quit AppLatch | Protection stops, demonstrating the documented limitation |

For policy tests, open Terminal in the source folder and run `swift test`. These tests are separate from the Xcode app scheme.

If there is a build error, retain the first full compiler error and Xcode version. If a hide or authentication check fails, record the macOS version, target app, and exact steps. Do not treat an untested target app as protected against determined access.
