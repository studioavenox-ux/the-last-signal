# Asset and license register

| Component | Origin | License / attribution |
| --- | --- | --- |
| Station, platform, monitor figure, puddles, furniture, 3D signage, UI | Original procedural GDScript in this repository | Project-original; no external asset |
| Procedural fallback sleepers and rails (`ProceduralTrackFallback`) | Original procedural GDScript in `scripts/station_builder.gd` | Project-original; no external asset |
| 64 × 64 floor, wall and rust wear maps | Generated deterministically in `scripts/station_builder.gd` at runtime | Project-original; no external texture |
| Aarav/Rohan narrative, documents, journal, chapter/ending text | Original project writing | Project-original; no external asset |
| Rain-like noise, electrical hum, footsteps, signal cue | Original runtime synthesis in `scripts/ambient_audio.gd` | Project-original; no external asset |
| `railroad-straight.glb`, `railroad-damaged-straight.glb`, `railroad-rail-straight.glb` | Railway modules at the repository root; containers report generator `UnityGLTF`, glTF 2.0 | Kenney **Train Kit (1.1)**, https://kenney.nl — Creative Commons Zero (CC0), per the root `License.txt`. Additional credit in that file: Guus Vermeulen, Tony Schaer. Credit is optional under CC0. |
| `kenney/*.glb` building kit (6 modules) | Building-kit modules under `kenney/`; containers report generator `UnityGLTF`, glTF 2.0 | Kenney **Building Kit (1.0)**, https://kenney.nl — Creative Commons Zero (CC0), per `kenney/License.txt` |
| `Textures/colormap.png`, `kenney/Textures/colormap.png` | 64 × 64 flat-swatch **placeholder** generated for this repository | Project-original placeholder; **not** the vendor colormap. See the note below. |
| Godot game engine | https://godotengine.org/license/ | MIT license; retain Godot's license notice with distributed engine binaries |

## Measured module geometry

Read out of the `.glb` vertex buffers, not taken from filenames or documentation:

| Module | X (width) | Y (height) | Z (length) | Tris | Notes |
| --- | --- | --- | --- | --- | --- |
| `railroad-straight.glb` | −0.500 … 0.500 | 0 … 0.100 | 0 … 4.000 | 376 | Ballast, 6 sleepers, both rails |
| `railroad-damaged-straight.glb` | −0.514 … 0.514 | 0 … 0.100 | 0 … 4.000 | 376 | Displaced ballast, +0.014 spill each side |
| `railroad-rail-straight.glb` | −0.350 … 0.350 | 0 … 0.100 | 0 … 4.000 | 160 | Rails only, no ballast, no sleepers |
| `kenney/wall-low.glb` | −0.050 … 0.050 | 0 … 1.200 | −1.000 … 1.000 | 10 | Used for the trackside parapet |

All three railway modules put their rail heads at x = ±0.25 … ±0.30 … ±0.35, y = 0 … 0.100,
and all three carry rails right out to both end faces, so modules butt together with a
continuous gauge and no visible rail seam. Their ballast stops 0.207 short of each end, which
is why `station_builder.gd` lays one continuous formation strip underneath the whole run.
Winding is counter-clockwise and outward on all three, so back-face culling is safe.

**The two kits are not at the same scale.** The Building Kit is authored at 1 unit = 1 m
(2 m modules, 1.200 m and 2.400 m walls). The Train Kit railway is a toy scale — a 0.600 m
gauge inside a 1.000 m module. They are reconciled by scaling only the railway, uniformly by
2.8, which brings the gauge to 1.680 m (Indian broad gauge, 1676 mm) and matches the 2.65 m
wide train. Uniform scaling is deliberate: it preserves the kit's own sleeper and ballast
proportions instead of stretching them. The Building Kit parapet is laid unscaled.

Also note the railway containers carry a root node `translation: [0, −1, 0]` from the Unity
exporter, while the Building Kit nodes carry none. `station_builder.gd` measures the imported
bounding box at runtime and rebases it, so that offset is cancelled whichever way the importer
applies it.

## Note on the supplied GLB modules and their texture dependency

All nine `.glb` files in this repository (three railway modules at the root, six building-kit
modules under `kenney/`) declare exactly one texture, by relative URI:

```
"images": [{ "uri": "Textures/colormap.png", "name": "colormap" }]
```

That file was **not** uploaded with the modules. Checked before import: the geometry buffers
are embedded in each container's `BIN` chunk, `extensionsRequired` is empty, and no other
external file is referenced — so the colormap is the only unresolved dependency.

It is the Kenney Train Kit / Building Kit colormap, itself CC0. It has **not** been obtained:
`kenney.nl` is not reachable from the build environment used for this integration (the request
returned no response), so the genuine file could not be downloaded and verified. The
placeholders therefore remain in place. Two mitigations cover the gap:

1. `Textures/colormap.png` and `kenney/Textures/colormap.png` are small project-original
   placeholder swatch sheets (260 bytes, 64 × 64 RGBA) committed at the paths the modules
   expect, so a Godot import resolves every declared URI. They are **not** the vendor colormap
   and must not be described as such. Replacing either file with the genuine texture restores
   the original look with no code change — this is the one remaining placeholder dependency.
2. `scripts/station_builder.gd` applies `material_override` to every imported surface with a
   project-original `StandardMaterial3D`, so Platform 03 renders identically whether or not the
   colormap is present. The placeholder is imported but never sampled.

## Note on what is and is not verified

External content bundled in this repository is limited to the nine CC0 Kenney `.glb` modules
above and their placeholder textures. No external images, recordings, music or paid
dependencies are bundled, and all narrative text and audio synthesis remain project-original.
The provided visual references are **mood references only** and are not distributed as game
assets. Future additions must document name, author, original source URL, license and
attribution. This inventory is not a claim of legal registration or a formal
intellectual-property assignment.
