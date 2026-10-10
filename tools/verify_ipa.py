"""Verify an unsigned device IPA without macOS (Python standard library only)."""
from pathlib import Path
from zipfile import ZipFile
import hashlib
import plistlib
import struct
import sys

ipa = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('artifacts/iOS26Legacy-unsigned.ipa')
with ZipFile(ipa) as archive:
    assert archive.testzip() is None, 'IPA ZIP checksum failure'
    app = 'Payload/iOS26Legacy.app/'
    info = plistlib.loads(archive.read(app + 'Info.plist'))
    assert info['MinimumOSVersion'] == '12.0'
    assert info['CFBundleDisplayName'] == 'iOS26 Legacy'
    assert info['UIDeviceFamily'] == [1]
    binary = archive.read(app + info['CFBundleExecutable'])
    header = struct.unpack('<8I', binary[:32])
    assert header[0] == 0xFEEDFACF, 'Expected a thin 64-bit Mach-O executable'
    assert header[1] == 0x0100000C, 'Expected arm64, not a simulator executable'
    offset, minimum = 32, None
    for _ in range(header[4]):
        command, size = struct.unpack_from('<2I', binary, offset)
        assert size >= 8 and offset + size <= len(binary)
        if command == 0x25:  # LC_VERSION_MIN_IPHONEOS
            minimum = struct.unpack_from('<I', binary, offset + 8)[0]
        elif command == 0x32:  # LC_BUILD_VERSION
            platform, minimum = struct.unpack_from('<2I', binary, offset + 8)
            assert platform == 2, 'Expected iOS device platform'
        offset += size
    assert minimum == 0x000C0000, f'Unexpected Mach-O deployment minimum: {minimum}'
    files = archive.namelist()
    assert any(name.startswith(app + 'LaunchScreen.storyboardc/') for name in files)
    assert app + 'Assets.car' in files
    assert app + 'Frameworks/libswiftCore.dylib' in files, 'Missing Swift runtime for iOS 12.0'
    assert app + 'embedded.mobileprovision' not in files, 'Expected unsigned IPA for Sideloadly'
    runtime_count = len([name for name in files if name.startswith(app + 'Frameworks/') and name.endswith('.dylib')])
print('PASS: IPA ZIP, iPhone family, arm64 Mach-O and iOS 12.0 minimum in plist and executable.')
print(f'PASS: compiled launch storyboard, asset catalog and {runtime_count} embedded Swift libraries.')
print('SHA256:', hashlib.sha256(ipa.read_bytes()).hexdigest())
print('Signing/install and device behavior still need verification with Sideloadly and an iPhone.')
