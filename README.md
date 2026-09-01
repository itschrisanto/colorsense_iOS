# ColorSense iOS

Native iOS companion to [ColorSense](https://colorsense.online), built with SwiftUI and
generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen).

## Generate and run

1. Copy `Config/Secrets.xcconfig.example` to `Config/Secrets.xcconfig`.
2. Add the production Clerk publishable key and your Apple Developer Team ID.
3. Run `xcodegen generate`.
4. Open `ColorSense.xcodeproj`, or run `Scripts/run-sim.sh` for a simulator build.

`Config/Secrets.xcconfig` and generated project files are ignored by git. Project structure and
build settings belong in `project.yml`; the committed Apple entitlement is under `Config/`.

## Authentication

ColorSense uses the existing production Clerk tenant so iOS and the web app share users. Do not
create a second Clerk application.

- Google OAuth returns to `online.colorsense.ios://callback`. That exact URL must remain in the
  production Clerk instance's redirect allowlist.
- Sign in with Apple uses Clerk's native iOS flow. The Apple Developer App ID for
  `online.colorsense.ios` must have the **Sign in with Apple** capability enabled, and the same
  bundle ID plus Apple Team ID must be registered under Clerk's **Native applications**.
- Apple must also be enabled for sign-up and sign-in under the production Clerk instance's social
  connections. Once enabled, ClerkKitUI's existing `AuthView` displays the Apple button
  automatically; no second sign-in screen is needed.

The Apple entitlement is stored in `Config/ColorSense.entitlements` and attached to Release builds
by `project.yml`. Apple does not provision Sign in with Apple for Personal Teams, so Debug builds
omit the entitlement to preserve local device development; Release builds include it and require
a paid Apple Developer team.
