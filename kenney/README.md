# Kenney Station Assets

Six modules from the **Kenney Building Kit (1.0)**, CC0 — see `License.txt` in this folder.
Authored at **1 unit = 1 m**: 2 m square modules, 1.200 m and 2.400 m wall heights.

| File | Measured bounds (X, Y, Z) | Tris | Used in game |
| --- | --- | --- | --- |
| `wall-low.glb` | 0.100 × 1.200 × 2.000 | 10 | **Yes** — trackside parapet, 6 instances |
| `border.glb` | 0.200 × 0.300 × 2.000 | 20 | No |
| `roof-flat-center.glb` | 2.000 × 0.100 × 2.000 | 12 | No |
| `wall-corner.glb` | 2.000 × 2.400 × 2.000 | 16 | No |
| `wall-doorway-square.glb` | 0.200 × 2.400 × 2.000 | 64 | No |
| `wall-window-square.glb` | 0.200 × 2.400 × 2.000 | 94 + 4 | No |

## What is instanced

`scripts/station_builder.gd` → `parapet()` lays six `wall-low` modules along the far side of
the track at x = 9.60, z = −13 … −1, as a single `MultiMeshInstance3D` (one draw call, 60
triangles). They are laid **unscaled**, because the kit's 1 unit = 1 m already matches the
station walls. The module is centred on its own origin with its base at y = 0, so it needs no
rebasing — unlike the railway modules, whose containers carry a `y = −1` root offset.

The other five modules are imported and documented but not instanced. The station shell is
still the procedural blockout; nothing in the current build depends on them.

## Scale note

This kit and the Train Kit railway at the repository root are **not** at the same scale — the
railway is a toy 0.600 m gauge inside a 1.000 m module. They are reconciled by scaling only the
railway, uniformly by 2.8, to a 1.680 m Indian broad gauge. See `docs/ASSETS.md`.

## Texture dependency

Every module declares one external texture, `Textures/colormap.png`, resolved from this folder.
The original colormap was not uploaded with the kit and could not be downloaded (`kenney.nl` is
unreachable from the build environment). A 260-byte project-original placeholder swatch sheet is
committed at `kenney/Textures/colormap.png` so imports resolve; it is **not** the vendor
colormap. Replace it with the genuine CC0 colormap from the Building Kit to get the intended
look — the parapet's `material_override` would also need removing. See `docs/ASSETS.md`.
