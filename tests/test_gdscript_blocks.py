"""Block-integrity check for the GDScript sources.

gdtoolkit's gdparse accepts a loop or branch whose body is only a comment, which is a hard
parse error in Godot itself and an undefined-identifier bug wherever the body used the loop
variable. This audit catches that class of mistake offline, so a green `gdparse` run is not
mistaken for a valid script.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
BUILDER = ROOT / 'scripts/station_builder.gd'
SOURCES = sorted(p for p in ROOT.rglob('*.gd') if '.git' not in p.parts)


def strip_comment(line):
    """Remove a trailing # comment, ignoring a # inside a quoted string."""
    quote = None
    for index, char in enumerate(line):
        if quote is not None:
            if char == quote:
                quote = None
        elif char in '"\'':
            quote = char
        elif char == '#':
            return line[:index]
    return line


def indent_of(line):
    return len(line) - len(line.lstrip('\t'))


def scan(path):
    """Yield (line_number, opener, next_statement, has_body) for every block opener."""
    lines = path.read_text().splitlines()
    in_triple = False
    depth = 0
    for number, raw in enumerate(lines):
        line = raw.rstrip()
        if in_triple:
            if '"""' in line:
                in_triple = False
            continue
        if not line.strip() or line.strip().startswith('#'):
            continue
        code = strip_comment(line)
        if code.count('"""') % 2 == 1:
            in_triple = True
            continue
        depth += code.count('(') + code.count('[') + code.count('{')
        depth -= code.count(')') + code.count(']') + code.count('}')
        if depth > 0 or not code.rstrip().endswith(':'):
            continue
        depth = 0
        opener_indent = indent_of(line)
        for follow in lines[number + 1:]:
            if not follow.strip() or follow.strip().startswith('#'):
                continue
            yield number + 1, line.strip(), follow.strip(), indent_of(follow) > opener_indent
            break


class BlockIntegrityTests(unittest.TestCase):
    def test_sources_exist(self):
        self.assertGreater(len(SOURCES), 5, 'no GDScript sources found')

    def test_every_block_has_a_statement(self):
        for path in SOURCES:
            for number, opener, follow, has_body in scan(path):
                with self.subTest(file=str(path.relative_to(ROOT)), line=number):
                    self.assertTrue(
                        has_body,
                        f'line {number} "{opener}" opens a block, but the next statement is '
                        f'"{follow}" at the same or lower indent; Godot rejects an empty body')

    def test_train_bogie_loop_is_still_nested(self):
        """Regression guard for the de-indent that gdparse did not catch."""
        pattern = (
            r'(?m)^\tfor z in \[-11\.65, -9\.25\]:\n'
            r'\t\tfor x in \[RAILWAY_CENTER_X - RAILWAY_GAUGE \* 0\.5, '
            r'RAILWAY_CENTER_X \+ RAILWAY_GAUGE \* 0\.5\]:\n'
            r'\t\t\tbox\("Train wheel", Vector3\(x, 0\.14, z\)')
        self.assertTrue(re.search(pattern, BUILDER.read_text()),
                        'train bogie loop is no longer nested inside its z loop')


if __name__ == '__main__':
    unittest.main()
