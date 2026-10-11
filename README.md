# THE LAST SIGNAL

A four-chapter, original first-person 3D thriller for **Godot 4.3+**, designed for **Android landscape**. Aarav Sen, 17, follows a call from his missing brother Rohan to fictional Nirva Halt, where a train disappeared twelve years ago. The complete narrative path and ending are **implemented in source**. Until an engine/device playtest is completed, this must **not** be treated as a verified 10–20-minute commercial release or a tested APK.

## Install and run

1. Install the standard Godot 4 editor (4.4.1 recommended). No plugins, downloads or paid assets are required by the game project.
2. In Godot's Project Manager, import this folder's `project.godot`. Allow imports to finish. Press **F5** to start, or open `scenes/main.tscn` and press **F6**.
3. Choose **BEGIN / ENTER THE STATION**. The introduction is text-only; tap **CLOSE / CONTINUE** to enter the hall.

**Desktop:** WASD/arrows move, mouse looks, **E** interacts, **J** opens collected notes, **Esc** pauses or closes an investigation screen. Click the scene to recapture the mouse. **Android:** left touch stick moves, drag the right half to look, tap **INTERACT**, **NOTES**, or **II PAUSE**. Aim the reticle within approximately 3.3 m. The right look area starts below the top HUD buttons; the stick and interaction button sit in opposite bottom corners. There is no jump, combat or compulsory audio cue.

## Four-chapter route (contains puzzle spoilers)

1. **The locked door:** Read the logbook on the waiting-room desk and the departure board near its back wall. Both stay available for rereading.
2. **The security archive:** Inspect the monitor on the waiting-room counter, then read the operator transcript on the ticket counter in the entrance hall. The **NOTES** screen records clues you have actually discovered.
3. **Emergency power:** Read the maintenance memo on the shelf. The logbook says **LAMP → BELL → LINE**; the memo maps them to switches **3 → 1 → 2**. A mistake resets all three. Power changes the station lights and monitor. Return to the monitor, read the new passenger list, then open the Platform Three gate.
4. **Platform Three:** Answer the service phone at the far end and close the transcript. The train approaches in the world. Find the **PA / CUT-OFF** control nearby and interact to stop the announcement. The train retreats, the original entrance unlocks and the ending follows. The ending can be replayed with **PLAY AGAIN**.

The route permits finding objects early: clues remain readable, mistaken switch attempts can be retried, the monitor can be revisited, and the gate will explain what is missing. The gate cannot open before power and the passenger list. Settings can be changed from the title or pause screen; audio level and look sensitivity are saved to Godot's `user://settings.cfg`. Pause includes resume and restart.

## Project files

| Path | Purpose |
| --- | --- |
| `project.godot`, `scenes/main.tscn` | Entry scene, desktop bindings, Android landscape and Compatibility renderer |
| `scripts/game.gd`, `scripts/story_text.gd` | Four chapters, story text, evidence, puzzle, objective state, train and ending |
| `scripts/station_builder.gd` | Procedural station, 64 px wear textures, canopy, fixtures, rails and detailed train silhouette |
| `scripts/player.gd`, `scripts/interactable.gd` | First-person physics, look and reusable ray-targets |
| `scripts/ui/` | Responsive HUD, touch controls, scrollable investigation, notes, title, pause, settings and ending |
| `scripts/ambient_audio.gd`, `audio/README.md` | Generated rain-like noise, electrical hum, footstep ticks and announcement cues |
| `docs/ASSETS.md` | Third-party component and license register |
| `tests/test_project.py`, `tests/test_navigation.py` | Offline resource/state checks and approximate 2D walkability audit |
| `tests/runtime_smoke.gd` | **Godot-dependent** route, gate raycast, title/settings and pause checks |

The environment is actual primitive 3D geometry, not a backdrop image. Tiny deterministic wear textures, plaster bands, a barred waiting-room window, electrical conduit, tile seams, puddles, benches, canopy, signal mast, lamps and a segmented train reinforce the teal/amber station identity. Decorative pieces have no collision. Four shadowless local lights and no particles target low-end devices; emergency power changes both bulbs and light levels. Fog is enabled only when not running on mobile. The train is a lightweight animated silhouette. All essential dialogue and announcements are displayed as text; **no voice acting or recorded rain** is included. The user-provided reference images are not packaged.

## Testing

Offline checks (Python 3, standard library only):

```sh
python3 -m unittest discover -s tests -v
```

Optional syntax and style checks with `gdtoolkit` (a testing tool, **not** a game dependency):

```sh
python3 -m pip install gdtoolkit==4.5.0
gdparse $(find scripts tests -name '*.gd')
gdlint $(find scripts tests -name '*.gd')
```

With Godot installed, import and run the complete state-route test:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/runtime_smoke.gd
```

The route test calls most interactions directly and checks a gate raycast; it **does not** prove all objects can be physically reached, collision behavior throughout the level, visual legibility, touch ergonomics, frame rate, sound output, or story length. The Python navigation audit inflates selected wall and furniture footprints for a capsule-sized player on a 2D grid; it is an approximation, not a Godot physics test. Manually test the entire route in the editor and on a real Android phone. Include a wrong switch order, settings and restart, pause/resume, rereading clues, rotating/look with two simultaneous fingers, and phone/override interactions. For desktop collision testing, stand by the gate before and after solving: it must block entry until opened.

## Android export (no APK included)

Required: a **Godot editor** and matching **export templates** (Editor → Manage Export Templates), **JDK 17**, and **Android SDK** with command-line tools, platform-tools (`adb`), build-tools and a target platform. Point Godot's **Editor Settings → Export → Android** to the SDK and Java paths. In **Project → Export**, add an Android preset, choose your own unique package ID such as `com.avenoxgames.thelastsignal`, export a debug APK, then install with `adb install -r /path/to/your-debug.apk`. Inspect `adb logcat` if launch fails. Use a locally generated debug keystore; never commit a keystore, passwords, or release credentials. `export_presets.cfg` is ignored until a credential-free preset can be reviewed. No APK is claimed or stored in this repository.

## Troubleshooting and honest limitations

- If scripts fail to load, open the project in **Godot 4.3+** and let import finish; run the headless route test to capture engine error messages. `gdparse` alone does not validate engine APIs.
- If the camera does not rotate on desktop, click inside the game after closing an overlay. If a document clips on a small phone, scroll its text area. Opening a document or pause resets active touch fingers so a held joystick cannot move Aarav after resuming.
- If there is no sound, confirm the in-game volume slider and the device audio output. Narrative information never depends on sound.
- Settings save, **progress does not**. The clock changes with scripted chapters rather than real elapsed time. There is no localized text, accessibility narration, recorded voice acting, hardware benchmark or verified playtime yet. The compact blockout uses deliberate low-cost scenery rather than final art.

This is original project code and writing, but this inventory is not a legal registration or formal IP-ownership claim. Consult `docs/ASSETS.md` before adding any third-party material.
