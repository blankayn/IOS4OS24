"""Optional grammar check. Does not type-check Swift or check UIKit availability.

Install optional tools with:
python -m pip install --target build/validation-deps tree-sitter==0.26.0 tree-sitter-swift==0.7.4
"""
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'build/validation-deps'))
from tree_sitter import Language, Parser
import tree_sitter_swift

parser = Parser(Language(tree_sitter_swift.language()))
files = sorted(file for folder in ['iOS26Legacy', 'iOS26LegacyTests', 'iOS26LegacyUITests'] for file in (root / folder).glob('*.swift'))
errors = []
for file in files:
    source = file.read_bytes()
    tree = parser.parse(source)
    def inspect(node):
        if node.is_error or node.is_missing:
            errors.append(f'{file.relative_to(root)}:{node.start_point.row + 1}: {node.type}: {source[node.start_byte:node.end_byte][:100]!r}')
        for child in node.children:
            if child.has_error or child.is_error or child.is_missing:
                inspect(child)
    if tree.root_node.has_error:
        inspect(tree.root_node)
if errors:
    print('\n'.join(errors))
    raise SystemExit(1)
print(f'PASS: Swift grammar parse for all {len(files)} source/test files (tree-sitter-swift).')
print('NOTE: This is syntax parsing, not Xcode compilation or SDK availability checking.')
