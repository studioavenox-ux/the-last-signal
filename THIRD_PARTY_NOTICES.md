# Third-party components and licences

This file records everything in THE LAST SIGNAL that was **not** created for the project.
Keep it up to date whenever an asset, font, plugin or library is added.

## Shipped with the game

| Component | Version | Licence | Source | Notes |
|---|---|---|---|---|
| Godot Engine | 4.7.2-stable | MIT ("Expat") | <https://godotengine.org> | The engine/runtime. Its licence notice must be included when the game is distributed. |
| Third-party code bundled inside Godot Engine (e.g. FreeType, Jolt Physics, mbedTLS, libogg/libvorbis, ThorVG, zlib, Open Sans font…) | as bundled with Godot 4.7.2 | various open-source licences — mostly permissive (MIT/Expat, BSD, Apache-2.0, Zlib, FTL, OFL-1.1), plus a few MPL-2.0 files | Godot's `COPYRIGHT.txt` | Covered by Godot's notices (shown in-game). Godot is routinely used in commercial games; review the list before release. |
| Open Sans (Godot's default UI font) | bundled with Godot | SIL Open Font License 1.1 | <https://github.com/googlefonts/opensans> | Used because no custom font is set. |
| Jolt Physics (Godot module) | bundled with Godot | MIT | <https://github.com/jrouwe/JoltPhysics> | Selected as the 3D physics engine. |

**How the notices are provided:** the title screen has a **Credits & licenses** screen that shows Godot's
licence text, the list of bundled third-party components and their full licence texts, generated at runtime
from `Engine.get_license_text()`, `Engine.get_copyright_info()` and `Engine.get_license_info()` — so it always
matches the engine version used for export. Review this before any public/commercial release.

## Game content

| Content | Origin |
|---|---|
| Story, characters (Aarav, Kabir), station (Raatpur Junction), all text | Original, written for this project |
| Code (all `.gd` files), scenes | Original, written for this project |
| 3D geometry (station, props) | Original, generated procedurally from code (`station_builder.gd`, scene primitives) |
| Textures (tiles, noise) | Original, generated procedurally at runtime (`procedural_textures.gd`) |
| All sound effects, ambience, chime and PA voice | Original, synthesised at runtime (`procedural_audio.gd`) |
| Icon (`icon.svg`) | Original |
| Music | None yet |

No third-party art, models, textures, fonts (other than Godot's default), music or sound files are included.

## Development tools (not shipped)

| Tool | Licence | Use |
|---|---|---|
| gdtoolkit (`gdlint`, `gdformat`, `gdparse`) | MIT | Linting/formatting GDScript during development |
| SCons | MIT | Only used to compile the Godot editor from source for headless testing on the build machine |

## Adding new third-party assets

For every new asset record: **name, author, source URL, licence (with version), date obtained, files it
covers, and the exact attribution text required**. Only use licences that allow commercial use
(e.g. CC0, CC-BY with attribution, OFL for fonts). Do not use assets whose licence is unclear.
