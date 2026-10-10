# iOS26 Legacy

A complete Swift / UIKit iPhone application that recreates an iOS 26-inspired clear glass Home Screen **inside its own app**. Deployment target: **iOS 12.0**. Designed around the 375 × 667 pt display of iPhone 6 and 6s; adapts to newer portrait iPhones.

It does not replace the system Home Screen, lock the device, intercept system gestures, inject into SpringBoard, or require a jailbreak. Its glass is an approximation drawn with Core Graphics and Core Animation, not Apple’s iOS 26 Liquid Glass API. No SwiftUI, SF Symbols, third-party packages, private APIs, remote assets, analytics, or special entitlements are used.

**Windows without a Mac:** the project has been pushed to [blankayn/IOS4OS24](https://github.com/blankayn/IOS4OS24) and its [first cloud IPA build passed](https://github.com/blankayn/IOS4OS24/actions/runs/38024634655). Download the IPA artifact from that run and install with Sideloadly on Windows. See **[Build without owning a Mac](docs/BUILD_WITHOUT_MAC.md)**. The macOS 14 runner it uses is scheduled to retire on November 2, 2026; the guide includes that availability limit.

## Open and run

1. Transfer this entire folder to a Mac and open **`iOS26Legacy.xcodeproj`**. The shared scheme is `iOS26Legacy`; no project generator is needed.
2. Use **Xcode 15.x**, preferably **15.4 on macOS Sonoma 14.x**, to preserve iOS 12 support. Apple lists iOS 12 as a supported deployment target and device OS for Xcode 15.4. Xcode 16 and newer toolchains have higher deployment floors; do not raise this project’s target to resolve a toolchain warning. [Apple’s Xcode requirements](https://developer.apple.com/xcode/system-requirements/)
3. Select the app target → Signing & Capabilities → choose your team and change `com.example.ios26legacy` to your own unique bundle ID if building a signed app. Leave the deployment target at `12.0` and device family at iPhone.
4. Select a connected iPhone 6/6s with iOS 12 or later, or an installed simulator, and Run. Xcode 15.4’s available simulators are newer than iOS 12; an actual iOS 12 device is needed to verify that OS.

This source was created on Windows. Project structure and Swift grammar checks passed locally, and the Release arm64 app compiled successfully with Xcode 15.4 on GitHub’s cloud Mac. The downloaded IPA passed checksum, resource, architecture and iOS 12 minimum-version checks. XCTest execution, on-device rendering and hardware performance have **not** been verified. See `docs/VALIDATION.md` for the remaining checks.

## Included features

| Feature | Behavior |
| --- | --- |
| Home Screen | Clear or colored glass icons, translucent dock, paging and page dots |
| Customization | Four built-in wallpapers, 3/4 columns, four widget modes, configurable dock, up to five pages, add/remove/reorder/move icons |
| Return Home | Swipe up starting in the bottom Home area, or tap Home |
| App switcher | Swipe up from the bottom and hold still briefly before releasing, or tap Apps; browse horizontally, tap Open, swipe a card up or tap Close card |
| Control Center | Tap Controls or swipe down on the in-app top toolbar; connectivity indicators, demo media and volume, app-only brightness slider |
| Lock preview | Tap Lock; local clock/date, labeled sample notifications, clear samples, swipe up or tap Enter Home |
| Internal apps | Autosaved Notes, working Calculator, current-month Calendar, local Clock, wallpaper Gallery, device information and labeled demo screens |
| App launching | Explicit, user-initiated browser, Maps, Mail, Messages, Phone and Spotify links; availability and completion checked |
| Accessibility | VoiceOver labels, adjustable sliders, button alternatives for gestures, Reduce Motion and Reduce Transparency |

The stock Home layout starts with two pages. Swipe left for **Customize**, or add its icon to the first page using the page editor. In Customize, select a page to add icons, use the drag handles to reorder, tap an icon to move it to another page, and use the delete controls to remove it. Changes and notes persist in `UserDefaults`. Recents and simulated Control Center state are session-only. Weather, conversations, notifications, camera preview and media are labeled sample/demo content. Gallery contains built-in wallpapers and does not read Photos.

Connectivity switches do **not** change Wi-Fi, cellular, Bluetooth, airplane mode, Focus, or device rotation. Volume does not affect the system. Brightness dims only this app and does not alter `UIScreen.brightness`. The Device widget uses public battery monitoring and `NWPathMonitor` route availability, which does not reveal SSIDs or passwords. Actual notifications from other apps are not accessible here. No notification, camera, contacts, calendar, photo or location permission is requested.

## Build an IPA for Sideloadly

An IPA must contain an **arm64 iPhone device build**, not a simulator `.app`. Creating the app binary requires a Mac with Xcode; Sideloadly on Windows can sign/install the resulting IPA but cannot compile Swift/UIKit source.

On the Mac, select the legacy-compatible Xcode toolchain if more than one is installed:

```bash
export DEVELOPER_DIR=/Applications/Xcode_15.4.app/Contents/Developer
xcodebuild -version
bash scripts/build-ipa.sh
```

Adjust the Xcode application path to match its installed name. The script builds Release without signing, verifies `MinimumOSVersion` is `12.0`, and packages `Payload/iOS26Legacy.app` as **`build/iOS26Legacy-unsigned.ipa`**. Sideloadly supplies the signing needed for installation. The target has no restricted capabilities or extensions.

Alternatively, choose **Any iOS Device (arm64)** in Xcode, configure your development team, then Product → Archive. In Organizer, use an available development/ad-hoc export option with a valid provisioning profile for the intended device. Personal Teams may not offer all Organizer export routes; the unsigned-build script plus Sideloadly is the intended alternative. An unsigned IPA cannot be installed directly using Finder or Xcode Devices.

## Install with Sideloadly

1. Download Sideloadly from its [official website](https://sideloadly.io/). Install its documented Apple device dependencies for your platform; on Windows follow its current instructions for Apple’s web versions of iTunes/iCloud if required.
2. Connect the iPhone by USB, unlock it, and accept **Trust This Computer**. Confirm the device appears in Sideloadly.
3. Drag `iOS26Legacy-unsigned.ipa` into Sideloadly, choose the device, and enter your Apple ID in Sideloadly. Complete its authentication prompts and click **Start**. Credentials are entered only in Sideloadly, never this app.
4. On iOS 12, open Settings → General → **Profiles & Device Management** (wording may be Device Management), choose the developer identity and trust it. Launch **iOS26 Legacy** from the actual system Home Screen. Newer iOS releases may additionally require Developer Mode; follow the installer/device prompts.
5. Free-account signatures normally last **seven days**. Re-sign with the same Apple ID and bundle ID or configure Sideloadly’s automatic refresh. Keep the same identity to preserve the existing app container; deleting the app deletes its saved notes/layout. See the [official Sideloadly FAQ](https://sideloadly.io/faq.html) for current device, account and refresh limitations.

## Performance choices

The default is static glass: cached 1× wallpapers, cached 2× procedural icons, small gradient surfaces, no per-icon live blur, parallax, continuous shimmer, snapshot capture, or display link. Springs run only on interaction. Optional blur is limited to the Home dock or one Control Center panel; it is disabled in Low Power Mode and under Reduce Transparency. Lock notification and switcher cards always use the lightweight material. Foreground clock refresh runs every fifteen seconds with timer tolerance; it stops when the app becomes inactive. Clock displays minutes. UIKit haptics are skipped on iPhone 6 and simulators and enabled on supported iPhones such as 6s.

These are design decisions, not measured frame-rate guarantees. Profile the Release build on an actual iPhone 6 before treating 60 fps as achieved. Keep blur off on that device.

## Tests and source map

```bash
python3 tools/validate_project.py  # portable structural checks, not a compiler
xcrun simctl list devices available
bash scripts/test-on-mac.sh SIMULATOR_UDID
```

The shared scheme includes unit tests for preference recovery/persistence, recents, calculator chaining/error recovery and URL allowlisting, plus UI tests for navigation, gestures and calculation. UI tests use a separate preferences suite and reset it on launch; normal user settings are unaffected.

`AppDelegate.swift` launches the UIKit app without scenes so iOS 12 works. `ShellViewController.swift` owns containment, the toolbar and in-app gestures. `HomeViewController.swift` lays out pages and dock. `Glass.swift` draws the materials, wallpaper and icon glyphs. `CustomizeViewController.swift` edits persisted layout. The other controllers implement internal screens, Control Center, Lock preview and recents. `CalculatorEngine.swift` holds arithmetic state. `Model.swift` holds preferences, public device information and the permitted link catalog.

`tools/generate_project.py` can regenerate the checked-in project and procedural app icon using Python’s standard library. It resets project build settings, so preserve any personal signing changes separately before regenerating. The source files and Xcode project are ready to open; regeneration is optional.

Public URL schemes are declared in `Info.plist` and checked with `canOpenURL` before `open`. There is no installed-app enumeration or private Settings URL. See [Apple’s canOpenURL documentation](https://developer.apple.com/documentation/uikit/uiapplication/canopenurl(_:)) and [Apple’s Liquid Glass design overview](https://developer.apple.com/documentation/technologyoverviews/liquid-glass) for the public APIs and the visual inspiration.
