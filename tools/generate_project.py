"""Regenerate the dependency-free Xcode 15 project and procedural app icon.

Python 3 standard library only. Run from any directory.
"""
from pathlib import Path
import hashlib
import json
import math
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
OBJECTS = {}


def ident(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()


def quote(value):
    return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"') + '"'


def array(values):
    return "(" + ", ".join(values) + ("," if values else "") + ")"


def obj(identity, isa, **fields):
    key = ident(identity)
    OBJECTS[key] = "{ isa = " + isa + "; " + " ".join(f"{k} = {v};" for k, v in fields.items()) + " }"
    return key


def settings(values):
    return "{ " + " ".join(f"{key} = {quote(value)};" for key, value in values.items()) + " }"


def configs(name, common):
    refs = []
    for mode in ["Debug", "Release"]:
        values = dict(common)
        values["SWIFT_OPTIMIZATION_LEVEL"] = "-Onone" if mode == "Debug" else "-O"
        if mode == "Debug":
            values["ENABLE_TESTABILITY"] = "YES"
            values["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG"
        else:
            values["SWIFT_COMPILATION_MODE"] = "wholemodule"
            values["DEBUG_INFORMATION_FORMAT"] = "dwarf-with-dsym"
        refs.append(obj(name + mode, "XCBuildConfiguration", buildSettings=settings(values), name=quote(mode)))
    return obj(name + "ConfigList", "XCConfigurationList", buildConfigurations=array(refs), defaultConfigurationIsVisible="0", defaultConfigurationName="Release")


def generate_project():
    groups, targets, products = [], [], []
    common = {
        "IPHONEOS_DEPLOYMENT_TARGET": "12.0", "SDKROOT": "iphoneos", "SWIFT_VERSION": "5.0",
        "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES",
        "CLANG_WARN_UNGUARDED_AVAILABILITY": "YES_AGGRESSIVE", "GCC_WARN_UNUSED_VARIABLE": "YES",
        "GCC_WARN_UNUSED_FUNCTION": "YES", "GCC_C_LANGUAGE_STANDARD": "gnu11",
        "ONLY_ACTIVE_ARCH": "NO", "ENABLE_BITCODE": "NO",
    }
    app_target = ident("TargetiOS26Legacy")
    for name, kind in [("iOS26Legacy", "application"), ("iOS26LegacyTests", "bundle.unit-test"), ("iOS26LegacyUITests", "bundle.ui-testing")]:
        children, sources, resources = [], [], []
        for file in sorted((ROOT / name).glob("*.swift")):
            ref = obj(str(file.relative_to(ROOT)), "PBXFileReference", lastKnownFileType="sourcecode.swift", path=quote(file.name), sourceTree=quote("<group>"))
            children.append(ref)
            sources.append(obj("Build" + str(file.relative_to(ROOT)), "PBXBuildFile", fileRef=ref))
        if kind == "application":
            for resource, type_name in [("Info.plist", "text.plist.xml"), ("LaunchScreen.storyboard", "file.storyboard"), ("Assets.xcassets", "folder.assetcatalog")]:
                ref = obj(resource, "PBXFileReference", lastKnownFileType=type_name, path=quote(resource), sourceTree=quote("<group>"))
                children.append(ref)
                if resource != "Info.plist":
                    resources.append(obj("Build" + resource, "PBXBuildFile", fileRef=ref))
        groups.append(obj(name + "Group", "PBXGroup", children=array(children), path=quote(name), sourceTree=quote("<group>")))
        extension = "app" if kind == "application" else "xctest"
        product = obj(name + "Product", "PBXFileReference", explicitFileType="wrapper.application" if kind == "application" else "wrapper.cfbundle", includeInIndex="0", path=quote(name + "." + extension), sourceTree="BUILT_PRODUCTS_DIR")
        products.append(product)
        phases = [
            obj(name + "Sources", "PBXSourcesBuildPhase", buildActionMask="2147483647", files=array(sources), runOnlyForDeploymentPostprocessing="0"),
            obj(name + "Frameworks", "PBXFrameworksBuildPhase", buildActionMask="2147483647", files="()", runOnlyForDeploymentPostprocessing="0"),
            obj(name + "Resources", "PBXResourcesBuildPhase", buildActionMask="2147483647", files=array(resources), runOnlyForDeploymentPostprocessing="0"),
        ]
        target_settings = {
            "PRODUCT_NAME": "$(TARGET_NAME)", "PRODUCT_BUNDLE_IDENTIFIER": "com.example." + name.lower(),
            "TARGETED_DEVICE_FAMILY": "1", "CODE_SIGN_STYLE": "Automatic", "DEVELOPMENT_TEAM": "",
            "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator", "IPHONEOS_DEPLOYMENT_TARGET": "12.0",
            "SWIFT_VERSION": "5.0", "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks",
        }
        dependencies = []
        if kind == "application":
            target_settings.update({"INFOPLIST_FILE": name + "/Info.plist", "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon", "MARKETING_VERSION": "1.0", "CURRENT_PROJECT_VERSION": "1", "GENERATE_INFOPLIST_FILE": "NO", "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES": "YES"})
        else:
            target_settings.update({"GENERATE_INFOPLIST_FILE": "YES", "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @loader_path/Frameworks"})
            proxy = obj(name + "Proxy", "PBXContainerItemProxy", containerPortal=ident("Project"), proxyType="1", remoteGlobalIDString=app_target, remoteInfo="iOS26Legacy")
            dependencies.append(obj(name + "Dependency", "PBXTargetDependency", target=app_target, targetProxy=proxy))
            if kind == "bundle.unit-test":
                target_settings.update({"TEST_HOST": "$(BUILT_PRODUCTS_DIR)/iOS26Legacy.app/iOS26Legacy", "BUNDLE_LOADER": "$(TEST_HOST)"})
            else:
                target_settings["TEST_TARGET_NAME"] = "iOS26Legacy"
        targets.append(obj("Target" + name, "PBXNativeTarget", buildConfigurationList=configs(name, target_settings), buildPhases=array(phases), buildRules="()", dependencies=array(dependencies), name=quote(name), productName=quote(name), productReference=product, productType=quote("com.apple.product-type." + kind)))
    products_group = obj("Products", "PBXGroup", children=array(products), name="Products", sourceTree=quote("<group>"))
    main = obj("MainGroup", "PBXGroup", children=array(groups + [products_group]), sourceTree=quote("<group>"))
    attrs = "{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1540; TargetAttributes = { " + " ".join(t + " = { CreatedOnToolsVersion = 15.4; };" for t in targets) + " }; }"
    project = obj("Project", "PBXProject", attributes=attrs, buildConfigurationList=configs("Project", common), compatibilityVersion=quote("Xcode 14.0"), developmentRegion="en", hasScannedForEncodings="0", knownRegions="(en, Base)", mainGroup=main, productRefGroup=products_group, projectDirPath=quote(""), projectRoot=quote(""), targets=array(targets))
    project_dir = ROOT / "iOS26Legacy.xcodeproj"
    project_dir.mkdir(exist_ok=True)
    text = "// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n"
    text += "\n".join(f"\t{key} = {value};" for key, value in OBJECTS.items())
    text += f"\n}}; rootObject = {project}; }}\n"
    (project_dir / "project.pbxproj").write_text(text, encoding="utf-8")
    schemes = project_dir / "xcshareddata" / "xcschemes"
    schemes.mkdir(parents=True, exist_ok=True)
    def reference(index):
        name = ["iOS26Legacy", "iOS26LegacyTests", "iOS26LegacyUITests"][index]
        extension = "app" if index == 0 else "xctest"
        return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{targets[index]}" BuildableName="{name}.{extension}" BlueprintName="{name}" ReferencedContainer="container:iOS26Legacy.xcodeproj"/>'
    scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1540" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference(0)}</BuildActionEntry>
</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{reference(1)}</TestableReference><TestableReference skipped="NO">{reference(2)}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="NO"><BuildableProductRunnable runnableDebuggingMode="0">{reference(0)}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference(0)}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
    (schemes / "iOS26Legacy.xcscheme").write_text(scheme, encoding="utf-8")


def png(size):
    """Opaque procedural artwork: gradient ribbons and a glass tile, no Apple assets."""
    raw = bytearray()
    for y in range(size):
        raw.append(0)
        for x in range(size):
            u, v = x / size, y / size
            color = [int(20 + 58 * v), int(43 + 99 * v), int(85 + 104 * v)]
            wave = math.sin(u * 4 + v * 4) * 0.1
            if abs(u - 0.45 - wave - v * 0.22) < 0.16:
                color = [min(255, c + 22) for c in color]
            # Rounded center tile and inner four squares communicate a Home grid.
            def rounded(px, py, left, top, right, bottom, radius):
                cx = max(left + radius, min(right - radius, px))
                cy = max(top + radius, min(bottom - radius, py))
                return (px - cx) ** 2 + (py - cy) ** 2 < radius ** 2 and left <= px <= right and top <= py <= bottom
            if rounded(u, v, 0.17, 0.17, 0.83, 0.83, 0.15):
                color = [int(c * 0.7 + 255 * 0.3) for c in color]
                if not rounded(u, v, 0.177, 0.177, 0.823, 0.823, 0.145):
                    color = [int(c * 0.3 + 255 * 0.7) for c in color]
                for sx in [0.31, 0.54]:
                    for sy in [0.31, 0.54]:
                        if rounded(u, v, sx, sy, sx + 0.15, sy + 0.15, 0.04):
                            color = [int(c * 0.2 + 255 * 0.8) for c in color]
            raw.extend(color)
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(bytes(raw))) + chunk(b"IEND", b"")


def generate_icons():
    assets = ROOT / "iOS26Legacy" / "Assets.xcassets"
    icons = assets / "AppIcon.appiconset"
    icons.mkdir(parents=True, exist_ok=True)
    (assets / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    images = []
    for points, scales in [(20, [2, 3]), (29, [2, 3]), (40, [2, 3]), (60, [2, 3]), (1024, [1])]:
        for scale in scales:
            pixel = points * scale
            filename = f"icon-{pixel}.png"
            (icons / filename).write_bytes(png(pixel))
            images.append({"idiom": "ios-marketing" if points == 1024 else "iphone", "size": f"{points}x{points}", "scale": f"{scale}x", "filename": filename})
    (icons / "Contents.json").write_text(json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")


if __name__ == "__main__":
    generate_project()
    generate_icons()
    print("Generated iOS26Legacy.xcodeproj, shared scheme and app icons.")
