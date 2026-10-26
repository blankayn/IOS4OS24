# Real system features: source review

Reviewed 2026-10-10. This is a feasibility assessment, not an installable tweak or a claim of device-tested compatibility. The existing iOS26 Legacy IPA implements an in-app simulation.

## Gesture candidates

[Neptune](https://github.com/duraidabdul/Neptune) publishes an iOS 12-oriented tweak. Its README describes a fluid app switcher, home indicator, modern status bar, and lock screen controls. Its package depends on MobileSubstrate, firmware >=12.0, and PreferenceLoader. The repository carries LGPL-3.0; redistribution of an adaptation must preserve the applicable license and source obligations.

The [gesture source](https://github.com/duraidabdul/Neptune/blob/master/neptune/Tweak.xm) hooks `BSPlatform.homeButtonType` to activate an existing fluid interface. This is a SpringBoard modification, not a new gesture engine implemented by an ordinary app. Reviewed source blob: `300bc75aa1bb171ea342a18a6a049cf331c23011`. The upstream minimum firmware dependency is not proof of compatibility with every later iOS release.

[LittleXS](https://github.com/alexcpr/LittleXS) advertises iOS 11–12 support. Its source also changes the home-button classification and contains keyboard, inset, status bar, and app-specific fixes. The swipe-to-kill hook is explicitly labelled for iOS 11. Licensing needs clarification before copying: the README describes GPL terms and HomeGesture ancestry, while LICENSE.md contains an MIT notice naming unrelated minima contributors. Treat it as a research reference until provenance is resolved.

## Feature boundaries

| Requested behavior | Implementation direction | Limit |
| --- | --- | --- |
| Swipe home, enter switcher, switch apps | Enable the existing fluid SpringBoard interface using a version-specific tweak | Exact firmware and jailbreak must be verified; test Control Center, rotation, keyboard, and Touch ID |
| Close apps | Use the real switcher's card dismissal | Verify the enabled interface's dismissal behavior on the target firmware |
| Go back | A separate app navigation integration | UIKit navigation stacks, web history, and custom app navigation differ; cannot promise one action works in every app |
| Change theme | Install original theme assets through a compatible theming engine | Icon appearance does not supply the newer operating system's frameworks |
| Liquid Glass appearance | Selective visual approximation with restrained effects | Full iOS 26 rendering and performance on iPhone 6 are unverified |

[Apple's navigation gesture API](https://developer.apple.com/documentation/uikit/uinavigationcontroller/interactivepopgesturerecognizer) belongs to a navigation controller. [SloppySwiper](https://github.com/fastred/SloppySwiper) provides a source example for broader swipe-back inside UIKit navigation, with documented animation and gesture conflicts. Neither is a system-wide installation mechanism.

[SnowBoard's developer page](https://www.sparkdev.me/package/com.spark.snowboard) describes a theming engine supporting iOS 7 and later. The displayed current release is rootless; choose a package for the actual jailbreak rather than assuming that release fits iOS 12. No SnowBoard engine source was reviewed here.

## Build and target information

[Theos packaging documentation](https://theos.dev/docs/packaging) describes `.deb` tweak packages and process filters; rootful and rootless packages use different architecture metadata. [Theos supports Windows through WSL](https://theos.dev/docs/installation-linux), so tweak development does not inherently require owning a Mac.

Before producing a device-specific package, obtain the exact iPhone model, iOS version, jailbreak name/version, and available tweak loader. Those determine compatible hooks and packaging. No jailbreak procedure has been selected, no system tweak has been built, and no change has been installed on the phone.
