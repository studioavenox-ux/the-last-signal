"""Approximate 2D walkability audit of the literal wall boxes in the builder.

Not a physics or engine test. Re-run and manually traverse the route in Godot.
"""
from collections import deque
from functools import lru_cache
from pathlib import Path
import math
import re
import unittest

BUILDER = (Path(__file__).resolve().parents[1] / 'scripts/station_builder.gd').read_text()
RADIUS = 0.32
STEP = 0.25
WALLS = (
    'Back wall left', 'Back wall right', 'Waiting wall north', 'Waiting wall south',
    'Maintenance wall north', 'Maintenance wall south',
    'Platform wall left', 'Platform wall right', 'Platform left boundary',
    'Platform end barrier', 'Track-side boundary',
    'Log desk', 'Monitor counter', 'Ticket counter', 'Memo shelf',
    'Phone pedestal', 'Override pedestal',
)


@lru_cache(maxsize=None)
def rectangle(name):
    pattern = (r'box\(\s*"' + re.escape(name)
               + r'",\s*Vector3\(([^)]*)\),\s*Vector3\(([^)]*)\)')
    match = re.search(pattern, BUILDER)
    if match is None:
        raise AssertionError(f'Missing literal box geometry: {name}')
    x, _, z = (float(v) for v in match.group(1).split(','))
    width, _, depth = (float(v) for v in match.group(2).split(','))
    return (x, z, width, depth)


def walkable(x, z, gate_open):
    if not (-9.45 < x < 9.45 and -12.55 < z < 10.55):
        return False
    for name in WALLS:
        cx, cz, width, depth = rectangle(name)
        if abs(x - cx) < width / 2 + RADIUS and abs(z - cz) < depth / 2 + RADIUS:
            return False
    # Loop-generated benches, perimeter walls, and central gate are explicit here.
    for bench_z in (2.7, 4.2):
        if abs(x + 8.0) < 1.2 + RADIUS and abs(z - bench_z) < 0.34 + RADIUS:
            return False
    if z >= 0 and abs(x) > 9.25:
        return False
    if not gate_open and abs(x) < 1.125 + RADIUS and abs(z) < 0.11 + RADIUS:
        return False
    return True


def reachable(gate_open):
    start = (round(0 / STEP), round(8.5 / STEP))
    queue = deque([start])
    seen = {start}
    while queue:
        cell = queue.popleft()
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            neighbor = (cell[0] + dx, cell[1] + dz)
            if neighbor not in seen and walkable(neighbor[0] * STEP,
                                                 neighbor[1] * STEP, gate_open):
                seen.add(neighbor)
                queue.append(neighbor)
    return seen


def near(seen, x, z, radius=1.2):
    return any(math.hypot(cx * STEP - x, cz * STEP - z) < radius for cx, cz in seen)


class WalkabilityTests(unittest.TestCase):
    def test_rooms_and_clues_reachable_before_gate(self):
        seen = reachable(False)
        for name, x, z in [
            ('waiting desk', -7.2, 8.2), ('departure board', -8, 9.7),
            ('security monitor', -7.5, 1.9), ('operator transcript', 2.5, 6.6),
            ('maintenance memo', 7.4, 8.0), ('switch 3', 8.25, 3.0),
        ]:
            with self.subTest(name=name):
                self.assertTrue(near(seen, x, z), name)
        self.assertFalse(near(seen, -1.8, -10.3), 'platform bypasses the gate')

    def test_platform_and_final_switch_reachable_after_gate(self):
        seen = reachable(True)
        self.assertTrue(near(seen, -1.8, -10.3), 'phone is unreachable')
        self.assertTrue(near(seen, -4.0, -9.1), 'PA cut-off is unreachable')
        self.assertTrue(near(seen, 0, 8.5), 'return path is blocked')


if __name__ == '__main__':
    unittest.main()
