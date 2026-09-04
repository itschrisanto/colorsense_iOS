# ColorSense iOS — photo picker re-presents itself after a successful extraction

## Read first
`~/Developer/ColorSense-iOS/CLAUDE.md`. It is long and load-bearing. Two sections matter
most here: "The live camera tile, and why it crashed (fixed 2026-09-03)" and "Running the
app". That file records that this screen has already produced **two wrong diagnoses**, so
do not start from a theory.

## The bug, in user terms
Open the app, tap the dock's **+**, tap a photo (or use the camera cell). The palette
updates correctly, the picker closes — and then the picker **immediately opens again by
itself**. The user reported this as "the camera is crashing" and "selecting a photo also
crashes". It is not a crash.

## Ruled out, with evidence. Do not re-investigate these.
The app never terminates. Four independent sources agree:
1. No ColorSense crash report on the device for 2026-09-05. Newest is 2026-09-04.
   `xcrun devicectl device copy from --device <id> --domain-type systemCrashLogs --source . --destination <dir>`
2. No Jetsam (memory-kill) event names ColorSense.
3. PostHog's bundled PLCrashReporter has no pending report in `Library/Caches`.
4. An in-app diagnostic log prints `=== launch ===` from `ColorSenseApp.init()`. A single
   launch marker covers an entire multi-minute reproduction session, so the process never
   restarted.

All ten crash reports from 2026-09-04 are `0x8BADF00D` watchdog kills, mostly "failed to
terminate gracefully" from build/install cycles. They are not this bug.

The AttributeGraph "cyclic graph" crash that CLAUDE.md documents for this screen is **not**
what is happening now. The deferred `previewLayer.session` assignment in
`CameraPreviewSession.PreviewView` is still in place and still correct. Leave it alone.

## The actual trace
From the instrumented build, one full cycle:

```
2:23:29  photo chosen, requesting image      mem=42MB
2:23:29  extract() called                    mem=42MB
2:23:29  extraction starting                 mem=42MB
2:23:29  sheet binding true -> false         mem=43MB
2:23:29  isExtracting -> true                mem=43MB
2:23:29  extraction done, 5 colors           mem=44MB
2:23:29  palette replaced                    mem=44MB
2:23:29  isExtracting -> false               mem=43MB
2:23:30  picker onDisappear                  mem=42MB
2:23:31  sheet binding false -> true         mem=41MB   <-- the bug
2:23:31  picker task, args=[...]             mem=41MB
2:23:31  picker onAppear                     mem=41MB
```

Everything up to and including `palette replaced` is correct. Extraction works, five
colors are produced, the palette is replaced, the sheet dismisses properly. Then the
binding flips back to true on its own.

The camera path behaves the same way, and the camera itself works:
```
2:11:33  camera cell TAPPED
2:11:33  stop done, presenting camera
2:11:33  CameraPicker.makeUIViewController
2:11:41  camera cover dismissed              mem=113MB
```

## The narrowed question
`sourceChoiceIsPresented` is written to `true` in exactly one place in the whole codebase:
the dock's **+** button action, `ColorSense/Features/Home/RootView.swift:206`.

```swift
Button {
    plusTaps += 1
    sourceChoiceIsPresented = true
} label: { ... }
```

So either that action is being re-invoked after the sheet dismisses, or SwiftUI is
re-presenting the sheet without the binding being written by app code (in which case the
`.onChange` log is reporting a state restoration rather than a deliberate write).

Hypotheses worth testing, in rough order of cheapness:
- **A stray second tap landing on the dock.** The sheet dismisses in roughly 300ms while
  the user's finger is still near the bottom of the screen, and the **+** sits at bottom
  centre. Test by adding a log line inside the button action itself (not just on the
  binding) — if the action logs, it is a real touch or a real invocation; if it does not,
  SwiftUI is re-presenting on its own.
- **A write during a view update.** `onImage(image)` runs *before* `dismiss()` in
  `PhotoSourcePicker.choose(_:)`, and `onImage` is `extract(_:)`, which mutates
  `@State isExtracting` and then `PaletteStore` (an `@Observable`). Mutating observed state
  from inside the dismissal path can make SwiftUI re-evaluate the presentation. Try
  reordering so `dismiss()` happens first and `onImage` is deferred to the next runloop
  turn, and see whether the re-present stops.
- **Identity churn on `RootView`.** If the view holding the `@State` is rebuilt, state can
  restore unexpectedly. Check what changes when `store.replace(with:)` fires.

## Read-only review findings (added 2026-09-05)

The strongest code-level suspect is the ordering of successful selection and dismissal, not the
camera. All three success paths call `onImage` before dismissing the picker:

- the authorised-library path in `PhotoSourcePicker.choose(_:)`;
- the denied-access `PhotosPicker` fallback in `loadFallback(_:)`;
- the camera callback inside the nested `fullScreenCover`.

`onImage` is `RootView.extract(_:)`. It immediately starts a task that changes `isExtracting`, then
replaces the `@Observable` palette inside an animation. The captured trace has exactly that order:
extraction begins, the sheet binding becomes false, the palette is replaced, the sheet disappears,
and only then the binding returns to true. This makes an overlapping model-update/presentation
transaction a more concrete explanation than generic `RootView` identity churn. `RootView` is
instantiated once by `ColorSenseApp`, and its `PaletteStore` is owned in stable app-level `@State`;
an ordinary observation-driven re-render should not recreate `sourceChoiceIsPresented`.

The robust fix to test is a two-phase handoff that performs extraction only after the sheet has
finished dismissing:

```swift
@State private var pendingExtraction: UIImage?

.sheet(isPresented: $sourceChoiceIsPresented, onDismiss: {
    guard let image = pendingExtraction else { return }
    pendingExtraction = nil
    extract(image)
}) {
    PhotoSourcePicker { image in
        pendingExtraction = image
        sourceChoiceIsPresented = false
    }
}
```

With this shape, successful `PhotoSourcePicker` paths report the image but do not call their own
environment `dismiss()`. The parent clears the presentation binding, and its `onDismiss` consumes
the pending image and mutates the palette after the presentation transaction is over. The camera
path should likewise let its inner `fullScreenCover` finish dismissing before it requests dismissal
of the outer photo-source sheet; avoid dismissing both presentation levels from the image-picker
delegate callback.

Do not implement that theory before adding the one missing discriminating trace inside the dock
`+` action itself:

```swift
diagLog("dock plus action, tap=\(plusTaps + 1)")
```

If that line appears immediately before the unexpected `sheet binding false -> true`, the binding
is being restored by a real second button activation and the fix belongs in touch/presentation
gating instead. If the binding returns to true without the button-action line, test the two-phase
dismissal above first. The existing diagnostics only log the binding and therefore cannot yet
distinguish those two cases.

## How to build, install and read the log
```bash
cd ~/Developer/ColorSense-iOS
eval "$(/opt/homebrew/bin/brew shellenv)"
xcodegen generate                     # project file is generated, never hand-edited

# Physical device (an iPhone 17 Pro Max, paired):
xcrun devicectl list devices
xcodebuild -project ColorSense.xcodeproj -scheme ColorSense \
  -destination 'platform=iOS,id=<DEVICE_ID>' -derivedDataPath .build/device build
xcrun devicectl device install app --device <DEVICE_ID> \
  .build/device/Build/Products/Debug-iphoneos/ColorSense.app
xcrun devicectl device process launch --device <DEVICE_ID> --terminate-existing online.colorsense.ios

# Pull the diagnostic log after a reproduction:
xcrun devicectl device copy from --device <DEVICE_ID> \
  --domain-type appDataContainer --domain-identifier online.colorsense.ios \
  --source "Library/Application Support/diag.log" --destination ./diag.log
```

Two traps that cost real time already:
- `devicectl ... --console` only forwards stdout/stderr, and its session **ends when the
  app is backgrounded**, reporting "terminated with exit code 0". That is an artifact, not
  a clean exit. Do not read it as evidence of anything. Log to the container file instead.
- The simulator **cannot** reproduce this. Its synthetic camera never runs a session, and
  scripted runs of the exact same code path complete successfully on device too. This
  needs a real device and a real tap.
- `osascript` has no assistive access on this machine, so simulator taps cannot be
  scripted. Driving the UI requires temporary launch-argument flags in the source.

## State of the repo when you receive it
`main` is clean and builds; 113 tests pass. Head is `5d5e9a2`.

**The instrumentation is not on main.** It lives on the branch
`diagnostics/photo-picker-repro` (commit `69b31b0`), and the same changes are also here as
`handoff/photo-picker-diagnostics.patch` if you would rather apply them onto whatever
you are working on:

```bash
git checkout diagnostics/photo-picker-repro     # or:
git apply handoff/photo-picker-diagnostics.patch
```

That instrumentation is a debugging aid, not a fix. It must not reach main in any form:
`diagLog(_:)` / `diagFootprintMB()` in `CameraPicker.swift`, the `diagLog` calls through
`PhotoSourcePicker.swift` and `RootView.swift`, the `=== launch ===` line in
`ColorSenseApp.swift`, and the `-photo-source` and `-auto-camera` launch flags.

**The build currently installed on the phone is the instrumented one**, so you can
reproduce and pull `diag.log` immediately without rebuilding. Rebuilding from clean `main`
replaces it with a build that logs nothing.

## Two uncommitted changes in the tree that are NOT mine and NOT this bug
`project.yml` and `CLAUDE.md` carry someone else's in-progress work: a PostHog dSYM upload
post-build script and `ENABLE_USER_SCRIPT_SANDBOXING: NO` for Release, with the matching
CLAUDE.md edit. It is unrelated to this bug. Leave it alone, and take care not to sweep it
into a commit about the picker.

## The raw evidence is here
- `handoff/device-trace.log` — the full device trace, including the cycles quoted above.

## House rules that apply to the fix
- No `.xcodeproj` is committed. Add files under `ColorSense/` and re-run `xcodegen generate`.
- Contrast decisions route through `ContrastCalculator`; brand values live in `DesignSystem/`.
- American spelling in user-visible strings; no em or en dashes in user-facing copy.
- Tests are Swift Testing, not XCTest. 113 currently pass:
  `xcodebuild -project ColorSense.xcodeproj -scheme ColorSense -destination 'platform=iOS Simulator,name=iPhone 17' test`
