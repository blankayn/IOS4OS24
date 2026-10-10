"""Create a transferable source ZIP, excluding Git, personal signing and build output."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).resolve().parents[1]
output = root / 'artifacts/iOS26Legacy-source.zip'
output.parent.mkdir(exist_ok=True)
folders = ['iOS26Legacy', 'iOS26Legacy.xcodeproj', 'iOS26LegacyTests', 'iOS26LegacyUITests', 'docs', 'scripts', 'tools', '.github']
files = [root / 'README.md', root / '.gitignore', root / '.gitattributes']
for folder in folders:
    files.extend(file for file in (root / folder).rglob('*') if file.is_file() and not any(part in {'__pycache__', 'xcuserdata'} for part in file.parts))
with ZipFile(output, 'w', ZIP_DEFLATED) as archive:
    for file in sorted(files):
        archive.write(file, 'iOS26Legacy-source/' + file.relative_to(root).as_posix())
with ZipFile(output) as archive:
    assert archive.testzip() is None
    assert 'iOS26Legacy-source/iOS26Legacy.xcodeproj/project.pbxproj' in archive.namelist()
    assert 'iOS26Legacy-source/.github/workflows/build-ipa.yml' in archive.namelist()
print(f'Packaged {len(files)} files: {output}')
