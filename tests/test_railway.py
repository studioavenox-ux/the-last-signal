"""Alignment audit of the imported GLB railway against the literal Platform 03 track bed.

Reads the real vertex buffers out of the .glb files and the placement constants out of
scripts/station_builder.gd, then checks that what the builder asks Godot to do lands the
track where the procedural level says the track is. This is geometry arithmetic, not an
engine test: it cannot prove Godot imports the modules or that they look right.
"""
from pathlib import Path
import json
import re
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]
BUILDER = (ROOT / 'scripts/station_builder.gd').read_text()

# 5120/5121 (byte indices) are in the Building Kit modules; 5123/5125/5126 in the railway.
COMPONENT_TYPES = {5120: ('b', 1), 5121: ('B', 1), 5123: ('H', 2), 5125: ('I', 4),
                   5126: ('f', 4)}
COMPONENT_COUNTS = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}

# Literal Platform 03 track bed in scripts/station_builder.gd, kept in sync by hand.
TRACK_BED_MIN_X, TRACK_BED_MAX_X = 6.0, 10.0
TRACK_BED_MIN_Z, TRACK_BED_MAX_Z = -13.0, 0.0
FALLBACK_RAIL_TOP = 0.14 + 0.28 / 2  # centre y + half height of the procedural rail box


def glb_chunks(name):
    data = (ROOT / name).read_bytes()
    magic, _version, total = struct.unpack('<III', data[:12])
    assert magic == 0x46546C67, f'{name} is not a binary glTF container'
    offset, payload_json, payload_bin = 12, None, None
    while offset < total:
        length, kind = struct.unpack('<II', data[offset:offset + 8])
        body = data[offset + 8:offset + 8 + length]
        if struct.pack('<I', kind) == b'JSON':
            payload_json = json.loads(body)
        else:
            payload_bin = body
        offset += 8 + length
    return payload_json, payload_bin


def accessor(document, blob, index):
    spec = document['accessors'][index]
    view = document['bufferViews'][spec['bufferView']]
    fmt, size = COMPONENT_TYPES[spec['componentType']]
    span = COMPONENT_COUNTS[spec['type']]
    start = view.get('byteOffset', 0) + spec.get('byteOffset', 0)
    stride = view.get('byteStride', size * span)
    return [
        struct.unpack_from(f'<{span}{fmt}', blob, start + row * stride)
        for row in range(spec['count'])
    ]


def positions(name):
    document, blob = glb_chunks(name)
    primitive = document['meshes'][0]['primitives'][0]
    return accessor(document, blob, primitive['attributes']['POSITION'])


def module_bounds(name):
    points = positions(name)
    return (
        min(p[0] for p in points), min(p[1] for p in points), min(p[2] for p in points),
        max(p[0] for p in points), max(p[1] for p in points), max(p[2] for p in points),
    )


def rail_centres(name):
    """X centres of the two rail heads, read off the highest vertices of the module."""
    points = positions(name)
    top = max(p[1] for p in points)
    xs = sorted({round(p[0], 4) for p in points if abs(p[1] - top) < 1e-5})
    left = [x for x in xs if x < 0]
    right = [x for x in xs if x > 0]
    assert left and right, f'{name} exposes no rail head at its top surface'
    return sum(left) / len(left), sum(right) / len(right)


def constant(name):
    match = re.search(rf'(?m)^const {name} := (.+)$', BUILDER)
    assert match is not None, f'Missing constant {name} in station_builder.gd'
    return eval(match.group(1).replace('Vector3', '_vector3'), {'_vector3': lambda *a: a}, {})


def pieces():
    block = re.search(r'(?ms)^const RAILWAY_PIECES := \[(.*?)^\]', BUILDER)
    assert block is not None, 'Missing RAILWAY_PIECES table in station_builder.gd'
    return [
        (path, material)
        for path, material in re.findall(r'\{"path": "([^"]+)", "material": "([^"]+)"\}',
                                         block.group(1))
    ]


class RailwayModuleTests(unittest.TestCase):
    """What the uploaded .glb files actually contain."""

    def test_modules_are_straight_four_metre_sections(self):
        for name in ['railroad-straight.glb', 'railroad-damaged-straight.glb',
                     'railroad-rail-straight.glb']:
            with self.subTest(module=name):
                min_x, min_y, min_z, max_x, max_y, max_z = module_bounds(name)
                self.assertAlmostEqual(min_y, 0.0, places=5)
                self.assertAlmostEqual(max_y, 0.1, places=5)
                self.assertAlmostEqual(min_z, 0.0, places=5)
                self.assertAlmostEqual(max_z, 4.0, places=5)
                self.assertLess(min_x, -0.2)
                self.assertGreater(max_x, 0.2)

    def test_all_three_modules_share_one_gauge(self):
        found = {name: rail_centres(name) for name in
                 ['railroad-straight.glb', 'railroad-damaged-straight.glb',
                  'railroad-rail-straight.glb']}
        for name, (left, right) in found.items():
            with self.subTest(module=name):
                self.assertAlmostEqual(-left, right, places=4, msg='gauge is off-centre')
        gauges = {round(right - left, 5) for left, right in found.values()}
        self.assertEqual(1, len(gauges), f'modules disagree on gauge: {found}')

    def test_declared_texture_dependency_is_satisfied(self):
        for name in ['railroad-straight.glb', 'railroad-damaged-straight.glb',
                     'railroad-rail-straight.glb']:
            document, _ = glb_chunks(name)
            with self.subTest(module=name):
                self.assertEqual([], document.get('extensionsRequired') or [])
                for image in document.get('images', []):
                    uri = image.get('uri')
                    if uri is None or uri.startswith('data:'):
                        continue
                    self.assertTrue((ROOT / uri).is_file(),
                                    f'{name} needs {uri}, which is not in the repository')


class RailwayPlacementTests(unittest.TestCase):
    """Where station_builder.gd asks Godot to put them."""

    def setUp(self):
        self.scale = constant('RAILWAY_TRACK_SCALE')
        self.centre_x = constant('RAILWAY_CENTER_X')
        self.gauge = constant('RAILWAY_GAUGE')
        self.start_z = constant('RAILWAY_START_Z')
        self.length = constant('RAILWAY_PIECE_LENGTH')
        self.table = pieces()
        self.run = []
        for index in range(len(self.table)):
            centre = self.start_z + self.length * (index + 0.5)
            self.run.append((centre - self.length / 2, centre + self.length / 2))

    def laid(self, path):
        min_x, min_y, min_z, max_x, max_y, max_z = module_bounds(path.removeprefix('res://'))
        return (self.centre_x + min_x * self.scale[0], self.centre_x + max_x * self.scale[0],
                min_y * self.scale[1], max_y * self.scale[1],
                min_z * self.scale[2], max_z * self.scale[2])

    def test_every_table_entry_points_at_a_real_module(self):
        self.assertEqual(3, len(self.table), 'all three uploaded modules should be used')
        for path, material in self.table:
            with self.subTest(module=path):
                self.assertTrue((ROOT / path.removeprefix('res://')).is_file(), path)
                self.assertIn(material, ('ballast', 'rail_steel'))
                self.assertTrue(f'"{material}": mat(' in BUILDER,
                                f'material "{material}" is not defined in the builder')

    def test_scale_is_uniform_so_the_kit_is_not_distorted(self):
        """A non-uniform scale stretches sleepers and ballast out of the kit's proportions."""
        self.assertEqual(1, len(set(round(axis, 6) for axis in self.scale)),
                         f'non-uniform track scale {self.scale}')
        self.assertAlmostEqual(4.0 * self.scale[2], self.length, places=6)

    def test_gauge_constant_matches_the_scaled_mesh(self):
        left, right = rail_centres(self.table[2][0].removeprefix('res://'))
        self.assertAlmostEqual((right - left) * self.scale[0], self.gauge, places=4)
        self.assertLess(abs(self.gauge - 1.676), 0.01,
                        'laid gauge is not Indian broad gauge (1676 mm)')

    def test_every_module_lays_its_rail_heads_on_one_gauge(self):
        """Modules are 1.000, 1.028 and 0.700 wide, so gauge continuity is the real check."""
        for path, _ in self.table:
            min_x, max_x, _, _, _, _ = self.laid(path)
            with self.subTest(module=path):
                self.assertAlmostEqual(min_x + (max_x - min_x) / 2, self.centre_x, places=4)
            left, right = rail_centres(path.removeprefix('res://'))
            with self.subTest(module=path):
                self.assertAlmostEqual(self.centre_x + left * self.scale[0],
                                       self.centre_x - self.gauge / 2, places=4)
                self.assertAlmostEqual(self.centre_x + right * self.scale[0],
                                       self.centre_x + self.gauge / 2, places=4)

    def test_ballast_module_sits_inside_the_track_bed_with_shoulder_each_side(self):
        path = self.table[2][0]
        min_x, max_x, _, _, _, _ = self.laid(path)
        shoulder_low = min_x - TRACK_BED_MIN_X
        shoulder_high = TRACK_BED_MAX_X - max_x
        self.assertGreater(shoulder_low, 0.2, 'ballast spills over the platform edge')
        self.assertGreater(shoulder_high, 0.2, 'ballast spills past the trackside kerb')
        self.assertAlmostEqual(shoulder_low, shoulder_high,
                               msg='ballast is not centred on the track bed', places=4)

    def test_bare_rail_module_sits_inside_the_ballast_footprint(self):
        bare = self.laid(self.table[0][0])
        ballast = self.laid(self.table[2][0])
        self.assertGreater(bare[0], ballast[0])
        self.assertLess(bare[1], ballast[1])

    def test_damaged_module_overhang_is_debris_scale_only(self):
        """The damaged variant displaces ballast, so it is allowed to spill a little."""
        damaged = self.laid(self.table[1][0])
        intact = self.laid(self.table[2][0])
        overhang = max(intact[0] - damaged[0], damaged[1] - intact[1])
        self.assertLess(overhang, 0.1, 'debris reaches the platform edge or the kerb')
        self.assertGreater(damaged[0], TRACK_BED_MIN_X)
        self.assertLess(damaged[1], TRACK_BED_MAX_X)

    def test_rail_top_matches_the_procedural_fallback_rail(self):
        for path, _ in self.table:
            with self.subTest(module=path):
                self.assertAlmostEqual(self.laid(path)[3], FALLBACK_RAIL_TOP, places=4)

    def test_pieces_tile_the_run_with_no_seam_or_overhang(self):
        for (_, previous_end), (next_start, _) in zip(self.run, self.run[1:]):
            self.assertAlmostEqual(previous_end, next_start, places=6, msg='gap between modules')

    def test_run_covers_the_platform_and_reaches_past_the_barrier(self):
        self.assertAlmostEqual(TRACK_BED_MAX_Z, self.run[-1][1],
                               msg='track does not reach the concourse wall', places=4)
        self.assertLess(self.run[0][0], -13.0 - 15.0,
                        'track stops at the barrier instead of running off into the night')
        self.assertLessEqual(self.run[0][0], -26.4, 'the arriving train runs off the track')

    def test_formation_strip_spans_the_whole_run_under_the_seams(self):
        match = re.search(
            r'box\("Ballast formation", Vector3\(8, ([-\d.]+), ([-\d.]+)\), '
            r'Vector3\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)', BUILDER)
        self.assertIsNotNone(match, 'no continuous formation strip under the module seams')
        centre_y, centre_z, width, height, depth = (float(v) for v in match.groups())
        self.assertAlmostEqual(centre_z - depth / 2, self.run[0][0], places=4)
        self.assertAlmostEqual(centre_z + depth / 2, self.run[-1][1], places=4)
        ballast_shoulder = 0.05 * self.scale[1]
        top = centre_y + height / 2
        self.assertLess(top, ballast_shoulder, 'strip pokes above the ballast shoulder')
        self.assertGreater(top, ballast_shoulder - 0.05, 'strip sits too low to hide the seams')
        self.assertAlmostEqual(width, 1.0 * self.scale[0], places=4)

    def test_fallback_rails_are_declared_on_the_scaled_gauge(self):
        pattern = (
            r'for x in \[RAILWAY_CENTER_X - RAILWAY_GAUGE \* 0\.5, '
            r'RAILWAY_CENTER_X \+ RAILWAY_GAUGE \* 0\.5\]:\s*\n'
            r'\s*box\("Rail", Vector3\(x, 0\.14, -6\.5\)')
        self.assertIsNotNone(re.search(pattern, BUILDER),
                             'fallback rails must derive from the gauge constants')

    def test_procedural_fallback_is_retained_and_toggled(self):
        for fragment in ['box("Sleeper", Vector3(8, 0.11, float(z)), Vector3(2.8, 0.2, 0.7)',
                         'track_fallback.visible = laid == 0',
                         '"Track bed", Vector3(8, -0.15, -6.5)']:
            with self.subTest(fragment=fragment):
                self.assertTrue(fragment in BUILDER, 'procedural fallback was not preserved')

    def test_fallback_sleeper_top_matches_the_imported_sleeper(self):
        sleeper_top = 0.11 + 0.2 / 2
        self.assertAlmostEqual(0.075 * self.scale[1], sleeper_top, places=4)

    def test_train_bogies_follow_the_laid_gauge(self):
        pattern = (
            r'for x in \[RAILWAY_CENTER_X - RAILWAY_GAUGE \* 0\.5, '
            r'RAILWAY_CENTER_X \+ RAILWAY_GAUGE \* 0\.5\]:\s*\n'
            r'\s*box\("Train wheel"')
        self.assertIsNotNone(re.search(pattern, BUILDER),
                             'train bogies no longer follow the laid gauge')

    def test_train_body_is_centred_on_the_track(self):
        for name in ['Train carriage', 'Train roof', 'Cab glass']:
            match = re.search(rf'box\("{name}", Vector3\(([-\d.]+),', BUILDER)
            self.assertIsNotNone(match, name)
            with self.subTest(part=name):
                self.assertAlmostEqual(
                    float(match.group(1)), self.centre_x,
                    msg=f'{name} is off the track centreline', places=4)


class BuildingKitTests(unittest.TestCase):
    """The Building Kit parapet, and whether it agrees with the railway's scale."""

    def setUp(self):
        self.scale = constant('RAILWAY_TRACK_SCALE')
        self.centre_x = constant('RAILWAY_CENTER_X')
        self.x = constant('PARAPET_X')
        self.step = constant('PARAPET_STEP')
        self.count = int(constant('PARAPET_COUNT'))
        self.first_z = constant('PARAPET_FIRST_Z')
        self.bounds = module_bounds('kenney/wall-low.glb')

    def test_module_is_centred_with_its_base_at_the_origin(self):
        """The MultiMesh places instances directly, so the pivot has to be trustworthy."""
        min_x, min_y, min_z, max_x, max_y, max_z = self.bounds
        self.assertAlmostEqual(min_x, -max_x, places=5)
        self.assertAlmostEqual(min_z, -max_z, places=5)
        self.assertAlmostEqual(min_y, 0.0, places=5)
        self.assertAlmostEqual(max_z - min_z, self.step, places=5,
                               msg='module length does not match PARAPET_STEP')

    def test_kit_is_laid_at_its_own_scale_while_the_railway_is_scaled(self):
        """Building Kit is 1 unit = 1 m; the Train Kit railway is a toy 0.600 m gauge."""
        self.assertNotIn('PARAPET_SCALE', BUILDER,
                         'parapet should be unscaled; the kits are reconciled on the railway')
        self.assertTrue('holder.multimesh = multi' in BUILDER)
        min_x, _, _, max_x, _, _ = self.bounds
        self.assertGreater(max_x - min_x, 0.05, 'wall-low should be a real 0.1 m thick wall')

    def test_parapet_runs_the_platform_and_stops_before_the_concourse_wall(self):
        first = self.first_z - self.step / 2
        last = self.first_z + self.step * (self.count - 1) + self.step / 2
        self.assertAlmostEqual(first, TRACK_BED_MIN_Z, places=4)
        self.assertLess(last, 0.0, 'parapet runs into the concourse wall at z = 0')

    def test_parapet_stands_outside_the_ballast_and_inside_the_kerb(self):
        min_x, _, _, max_x, _, _ = self.bounds
        rail_module = module_bounds('railroad-straight.glb')
        ballast_edge = self.centre_x + rail_module[3] * self.scale[0]
        self.assertGreater(self.x + min_x, ballast_edge,
                           'parapet stands in the ballast')
        self.assertLess(self.x + max_x, 9.8 + 0.15, 'parapet pokes outside the kerb')


if __name__ == '__main__':
    unittest.main()
