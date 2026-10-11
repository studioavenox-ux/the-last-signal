# Testing

## Automated tests

```bash
GODOT=/path/to/godot tools/run_tests.sh            # import + all suites
GODOT=/path/to/godot tools/run_tests.sh --suite=gameplay
```

or manually (any OS; on Windows use the `_console.exe` Godot build so output is visible):

```bash
godot --headless --path . --import                                      # needed once on a fresh clone
godot --headless --path . --fixed-fps 60 --script res://tests/run_tests.gd
```

Exit code `0` = all checks passed, `1` = failures (listed at the end), `2` = watchdog timeout.
`--fixed-fps 60` makes timing deterministic. A full run takes about 10 seconds.

| Suite | What it checks |
|---|---|
| `test_sequence_lock.gd` | Puzzle logic: correct order solves, mistakes reset, repeats ignored, empty solution safe. |
| `test_project_config.gd` | Input actions + keyboard/gamepad bindings, autoloads, audio buses + bus layout file, renderer, orientation, stretch mode, Jolt physics, Back-button setting, main scene. |
| `test_content_integrity.gd` | Every `res://` path in scenes/scripts resolves; every document/lines id used by the level and by code exists in `StoryText`; puzzle solution matches the switches; switches are not laid out in solution order; every sound id has a procedural fallback. |
| `test_procedural_assets.gd` | All 24 sounds generate with sane lengths; ambience loops; unknown ids fall back to silence; background pre-warm completes without blocking frames; procedural mesh winding matches Godot's front faces; textures generate and cache. |
| `test_scenes_load.gd` | Every `.tscn` loads and instantiates; title screen runs with focus on Begin; credits include Godot's licence and third-party notices. |
| `test_gameplay_flow.gd` | **End-to-end playthrough in the real level**: geometry + colliders built; intro locks the doors and sets the objective; joystick input walks the right distance/direction; walls and the platform edge block the player; the ray targets the notice and the HUD shows the prompt; the Interact *action* opens the document and pauses; touch joystick, drag-look and the LIGHT button work through simulated touch events; pause menu; locked gate; announcement trigger; maintenance door opens and the corridor is walkable; puzzle with two deliberate mistakes then the correct order; gate unlocks; suspense event (monitor message, clock restarts, emergency lights, hum); apparition; walking onto the platform; Kabir's phone; ending; signal turns green; end screen. |

### What automated tests do NOT cover

* **Rendering and visuals** (lighting balance, fog, readability of 3D signs, UI layout on real screens).
  Tests run with Godot's headless/dummy renderer.
* **Real devices**: frame rate, memory, thermal behaviour, actual touch hardware, audio output.
* **Android export/install** (no toolchain on the development machine yet — see ANDROID_EXPORT.md).

### Static checks

* Godot's own compiler (via `--import` + running every scene). All scripts were also compiled with nearly every
  GDScript warning promoted to an error (excluding opt-in ones such as `UNSAFE_*`, `INFERRED_DECLARATION`,
  `RETURN_VALUE_DISCARDED` and `MISSING_AWAIT`) — no warnings.
* Style: [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) (`pip install "gdtoolkit==4.*"`):
  `gdlint scripts tests` (config: `gdlintrc`, 120 columns) and `gdformat --line-length 120 --check scripts tests`.

### Known harmless output

* `WARNING: N ObjectDB instances were leaked at exit` after headless runs: these are
  `AudioStreamWAV`/playback objects of sounds still playing when the process exits; the audio server
  releases them after the object database check. Not a gameplay leak.
* The test suite intentionally requests an unknown sound id once and prints a warning about it.

## Manual on-device checklist

Run on at least one **low-end Android phone** and one phone with a **notch**:

- [ ] App launches in landscape, full screen; rotating the phone flips landscape orientation.
- [ ] Title text and buttons are readable and easy to tap; Credits & How to play open and close; Back works.
- [ ] Joystick appears under the left thumb; walking speed feels right; right-side drag looks around smoothly.
- [ ] Look sensitivity / invert Y in Pause change the feel and persist after restarting the app.
- [ ] USE button pulses when looking at something usable; prompt text appears above it.
- [ ] Notes open full screen, are readable, scroll if needed, and close with *Close* or Back.
- [ ] Objective and subtitles don't overlap the touch controls or the notch.
- [ ] Puzzle: wrong order shows sparks/red flash and resets; correct order unlocks the gate.
- [ ] Suspense event: lights change, monitors show text, announcement plays with subtitles.
- [ ] Ending plays and the end screen offers Play again / Main menu.
- [ ] Switching to another app and back pauses the game.
- [ ] Frame rate is stable (target 30+ fps on low-end; use Godot's remote debugger *Monitors*).
- [ ] Rain, hum, chime, doors and footsteps are audible at sensible volumes.
- [ ] Lighting: the station is dark but navigable with the torch; signs/notes are findable.
