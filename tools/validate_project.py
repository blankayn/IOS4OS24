"""Portable structural checks; explicitly NOT a Swift compiler or UI test runner."""
from pathlib import Path
import json
import plistlib
import re
import struct
import xml.etree.ElementTree as ET
import zlib

ROOT = Path(__file__).resolve().parents[1]


class OpenStepParser:
    def __init__(self, text):
        self.tokens = []
        pattern = re.compile(r'\s+|//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"|[{}()=;,]|[^\s{}()=;,]+', re.S)
        for match in pattern.finditer(text):
            token = match.group()
            if token.isspace() or token.startswith('//') or token.startswith('/*'):
                continue
            self.tokens.append(token)
        self.index = 0

    def next(self):
        assert self.index < len(self.tokens), "Unexpected end of project"
        token = self.tokens[self.index]
        self.index += 1
        return token

    def expect(self, token):
        actual = self.next()
        assert actual == token, f"Expected {token}, found {actual}"

    def value(self):
        token = self.next()
        if token == '{':
            result = {}
            while self.tokens[self.index] != '}':
                key = self.value()
                assert isinstance(key, str)
                assert key not in result, f"Duplicate key: {key}"
                self.expect('=')
                result[key] = self.value()
                self.expect(';')
            self.expect('}')
            return result
        if token == '(':
            result = []
            while self.tokens[self.index] != ')':
                result.append(self.value())
                if self.tokens[self.index] != ')':
                    self.expect(',')
            self.expect(')')
            return result
        if token.startswith('"'):
            return json.loads(token)
        assert token not in '{}()=;,', f"Unexpected token {token}"
        return token

    def parse(self):
        result = self.value()
        assert self.index == len(self.tokens), "Trailing project data"
        return result


def leaves(value):
    if isinstance(value, dict):
        for child in value.values():
            yield from leaves(child)
    elif isinstance(value, list):
        for child in value:
            yield from leaves(child)
    else:
        yield value


def check_png(file, expected):
    data = file.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    offset, image = 8, bytearray()
    seen_header = False
    while offset < len(data):
        length = struct.unpack('>I', data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + length]
        crc = struct.unpack('>I', data[offset + 8 + length:offset + 12 + length])[0]
        assert crc == zlib.crc32(kind + payload), f"Bad CRC: {file}"
        if kind == b'IHDR':
            width, height, depth, color, compression, filtering, interlace = struct.unpack('>IIBBBBB', payload)
            assert (width, height) == (expected, expected)
            assert (depth, color, compression, filtering, interlace) == (8, 2, 0, 0, 0), "Icons must be opaque RGB"
            seen_header = True
        if kind == b'IDAT':
            image.extend(payload)
        offset += 12 + length
        if kind == b'IEND':
            break
    assert seen_header and offset == len(data)
    assert len(zlib.decompress(image)) == expected * (1 + expected * 3)


def main():
    file = ROOT / 'iOS26Legacy.xcodeproj/project.pbxproj'
    project = OpenStepParser(file.read_text(encoding='utf-8')).parse()
    objects = project['objects']
    assert objects[project['rootObject']]['isa'] == 'PBXProject'
    for identifier, entry in objects.items():
        assert re.fullmatch(r'[A-F0-9]{24}', identifier)
        for value in leaves(entry):
            if isinstance(value, str) and re.fullmatch(r'[A-F0-9]{24}', value):
                assert value in objects, f"Dangling project reference: {value}"
    targets = {entry['name']: entry for entry in objects.values() if entry['isa'] == 'PBXNativeTarget'}
    assert set(targets) == {'iOS26Legacy', 'iOS26LegacyTests', 'iOS26LegacyUITests'}
    source_count = 0
    for name, target in targets.items():
        source_phases = [objects[ref] for ref in target['buildPhases'] if objects[ref]['isa'] == 'PBXSourcesBuildPhase']
        assert len(source_phases) == 1
        compiled = {objects[objects[ref]['fileRef']]['path'] for ref in source_phases[0]['files']}
        present = {file.name for file in (ROOT / name).glob('*.swift')}
        assert compiled == present, f"Source membership mismatch: {name}"
        source_count += len(compiled)
        for ref in objects[target['buildConfigurationList']]['buildConfigurations']:
            settings = objects[ref]['buildSettings']
            assert settings['IPHONEOS_DEPLOYMENT_TARGET'] == '12.0'
            assert settings['TARGETED_DEVICE_FAMILY'] == '1'
            assert settings['SWIFT_VERSION'] == '5.0'
        if name != 'iOS26Legacy':
            assert len(target['dependencies']) == 1
    app = targets['iOS26Legacy']
    resources = [objects[ref] for ref in app['buildPhases'] if objects[ref]['isa'] == 'PBXResourcesBuildPhase'][0]
    included = {objects[objects[ref]['fileRef']]['path'] for ref in resources['files']}
    assert included == {'LaunchScreen.storyboard', 'Assets.xcassets'}
    for entry in objects.values():
        if entry['isa'] == 'PBXGroup' and entry.get('path') in targets:
            for ref in entry['children']:
                assert (ROOT / entry['path'] / objects[ref]['path']).exists()
    scheme = ET.parse(ROOT / 'iOS26Legacy.xcodeproj/xcshareddata/xcschemes/iOS26Legacy.xcscheme').getroot()
    assert len(scheme.findall('./TestAction/Testables/TestableReference')) == 2
    for ref in scheme.findall('.//BuildableReference'):
        assert ref.attrib['BlueprintIdentifier'] in objects
    info = plistlib.loads((ROOT / 'iOS26Legacy/Info.plist').read_bytes())
    assert info['CFBundleDisplayName'] == 'iOS26 Legacy'
    assert info['UIRequiredDeviceCapabilities'] == ['arm64']
    assert info['UISupportedInterfaceOrientations'] == ['UIInterfaceOrientationPortrait']
    assert set(info['LSApplicationQueriesSchemes']) == {'https', 'mailto', 'sms', 'tel', 'spotify'}
    assert 'UIApplicationSceneManifest' not in info
    assert not any(k.endswith('UsageDescription') for k in info), 'Unexpected permission request'
    storyboard = ET.parse(ROOT / 'iOS26Legacy/LaunchScreen.storyboard').getroot()
    assert storyboard.attrib['launchScreen'] == 'YES'
    icons = ROOT / 'iOS26Legacy/Assets.xcassets/AppIcon.appiconset'
    manifest = json.loads((icons / 'Contents.json').read_text())
    assert len(manifest['images']) == 9
    for icon in manifest['images']:
        size = int(icon['size'].split('x')[0]) * int(icon['scale'][:-1])
        check_png(icons / icon['filename'], size)
    source = '\n'.join(file.read_text(encoding='utf-8') for file in (ROOT / 'iOS26Legacy').glob('*.swift'))
    banned = ['import SwiftUI', 'UIVisualEffectView(effect: UIGlass', 'UIGlassEffect', 'UIImage(systemName:', 'UIApplication.shared.windows', 'performSelector', 'NSClassFromString', 'App-Prefs:', 'prefs:', 'SBApplicationController', 'SBIconController', 'UIWindowScene']
    for marker in banned:
        assert marker not in source, f"Forbidden/unavailable API marker: {marker}"
    assert 'import Network' in source and 'import UIKit' in source and 'CAGradientLayer' in source and 'CGGradient' in source
    assert 'canOpenURL' in source and 'UIApplication.shared.open' in source
    print(f"PASS: {len(objects)} project objects; {len(targets)} targets; {source_count} Swift sources.")
    print("PASS: source/resource membership, references, iOS 12 settings, shared test scheme.")
    print("PASS: Info.plist, launch XML, allowlisted URLs and nine opaque app icon renditions.")
    print("NOTE: Swift compilation, XCTest, rendering and device profiling require Xcode on macOS.")


if __name__ == '__main__':
    main()
