# Validation and device acceptance

## Checks available in this workspace

Run `python tools/validate_project.py`. It parses the OpenStep project, checks object references, source/resource membership, deployment and scheme/test configuration, verifies plist/XML and all icon PNG sizes/CRCs, and checks declared URL schemes and forbidden API markers. It cannot type-check Swift, compile storyboard/assets, exercise UIKit, or measure frame rates.

The local creation environment is Windows with Python 3.11 and no Swift compiler, Xcode, iPhone simulator or connected iPhone runtime. A subsequent cloud Release build succeeded with Xcode 15.4 on GitHub’s macOS 14 runner. XCTest execution and hardware performance remain unverified.

Local results on October 10, 2026:

- Structural validation passed: 68 project objects, three targets, thirteen Swift source/test files, complete build-phase membership, iOS 12 settings and two test bundles in the shared scheme.
- Plist, storyboard/scheme XML, URL allowlist, and all nine app icon renditions passed format, size and PNG checksum checks.
- All thirteen Swift files parsed without grammar errors using `tree-sitter` 0.26.0 and `tree-sitter-swift` 0.7.4. This does not verify types, platform availability or runtime behavior. [Swift grammar](https://github.com/alex-pinkus/tree-sitter-swift), [Python parser API](https://github.com/tree-sitter/py-tree-sitter).
- The source archive was checked for ZIP integrity. Its contents include the Xcode project, sources, assets, tests, build scripts and instructions; it excludes temporary validation dependencies and build output.
- Cloud build for source commit `5c214431d213ef95f39c1e280c3c3caee39099f4` passed on October 10, 2026. [Build run and compiler log](https://github.com/blankayn/IOS4OS24/actions/runs/38024634655).
- Downloaded artifact and IPA SHA-256 digests matched the cloud output. `tools/verify_ipa.py` verified the iPhone-only bundle, arm64 executable, iOS `12.0` minimum in both Info.plist and Mach-O load commands, compiled launch storyboard and asset catalog, and thirteen embedded Swift runtime libraries. No provisioning profile is included; Sideloadly must sign it.
- IPA SHA-256: `d00548ba52542b2f3e7586b84ef6e46566745e90e4aba07b2abb45b1c648fef0`.

To repeat the optional syntax check, install the two pinned packages into `build/validation-deps` as shown in `tools/check_swift_syntax.py`, then run `python tools/check_swift_syntax.py`. They are development-only tools and are not app dependencies.

## Required Mac checks

- Select Xcode 15.x and confirm `xcodebuild -version`.
- Open the project, resolve personal signing if using a device, and build Debug and Release.
- Run `bash scripts/test-on-mac.sh SIMULATOR_UDID` on an available simulator. Unit tests and UI tests are included in the shared scheme. Review the `.xcresult` bundle.
- Run `bash scripts/build-ipa.sh`, unpack the IPA, and confirm `Payload/iOS26Legacy.app`, arm64 binary, bundled Swift support libraries where required, app icon and launch storyboard. The compiler’s deployment target embeds the iOS 12 minimum and weak-links platform libraries appropriately.
- Install the Sideloadly-signed IPA on actual iPhone 6 with iOS 12 and iPhone 6s with iOS 12 or later. Record device/OS/build in the results.

## Functional acceptance on hardware

1. Start cold and verify launch screen, first Home page, four dock icons and readable labels at 375 × 667 pt.
2. Swipe pages both ways and use page dots. Test three/four columns and all widget choices. Fill a page to twelve icons. Add all five pages, remove a page, reorder, move and delete icons. Customize every dock position. Relaunch and confirm persistence.
3. Edit Notes, dismiss its keyboard using Done, leave via Home, reopen, background/relaunch and verify text survives. Confirm the bottom Home area works when the keyboard is dismissed.
4. Calculator: `1.5 + 2 = =` → `5.5`; `8 ÷ 0 =` → `Error`; press a digit to recover. Check decimal entry, AC, sign and percent.
5. Controls: toggle all six demo indicators, drag each slider, check limits and VoiceOver increment/decrement. Observe that device radios/volume/brightness remain untouched. Check Done returns to the originating internal app or Home.
6. Lock: correct local time/date, sample labels, clear samples, Enter Home and upward swipe. Background and resume after the minute changes.
7. Recents: open multiple internal apps; cards are most-recent-first without duplicates, capped at six. Swipe left/right, open a card, dismiss by button and by upward swipe. Empty state appears when all cards are closed. A quick bottom swipe goes Home; upward drag, hold still briefly and release opens recents.
8. Open permitted links with their apps installed/uninstalled. Simulator phone/SMS may be unavailable. Phone requires a user-entered valid number and iOS’s confirmation; test cancellation. Verify app return uses normal iOS navigation. No in-app gesture is expected to operate while another app is foreground.
9. Battery/network data may be unavailable on simulator; actual device information should update after returning to the foreground. Changing network route must not crash or block the UI.
10. Enable Reduce Motion, Reduce Transparency and Low Power Mode individually; confirm spring reduction and blur fallback. Test VoiceOver for all critical actions, including page editing, Home, switcher cards and sliders.

## Performance acceptance

Use an optimized Release build on **iPhone 6**, static glass enabled, debug tools disconnected for visual assessment. Measure scrolling and transitions with Instruments Core Animation, Time Profiler, Allocations and Energy Log. Target the device’s 60 Hz budget (~16.7 ms per frame); report measured results rather than inferring them from the code.

- Scroll both Home pages continuously, then five customized pages, and open/close screens repeatedly.
- Compare static glass with optional live blur. Keep blur disabled if it causes missed frames.
- Open six recent cards, scroll and dismiss repeatedly; memory should stabilize rather than grow with visits.
- Change all wallpapers, trigger a memory warning in simulator, and verify cache recreation.
- Background the app and verify clock updates stop. No background audio, tasks, timers or animation loop should run.
- Check label contrast on all wallpapers and clear/colored icons, and inspect layouts on 375 × 667 pt and one newer safe-area device.

## Intended limits

Portrait iPhone only. No widgets outside the app, real lock enforcement, cross-app notifications, real camera capture, media playback or filesystem browsing. Control Center radio/volume/rotation indicators are simulations. Gallery uses included artwork. Recents are semantic previews of internal screens, not screenshots of installed apps. Newer device debugging may need a separate newer Xcode installation, while iOS 12 binary creation must retain a compatible legacy toolchain.
