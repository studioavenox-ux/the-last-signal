# THE LAST SIGNAL — Mission 001 prototype

A first-person, story-driven 3D thriller set in an abandoned Indian railway station.
**Android-first**, built with **Godot 4 + GDScript** by **AVENOX Games**.

> **Status: early playable prototype — not a complete game.** It contains one short level
> (roughly 5–10 minutes) that proves the core loop: explore → read clues → solve a puzzle →
> scripted suspense moment → short story ending. All art is blockout geometry.

## The premise

Aarav receives a message from his missing brother Kabir: *"Platform Three. Midnight."*
He enters **Raatpur Junction** — a fictional station closed for years — on a monsoon night.
The entrance doors slam and lock behind him, the station clock has stopped at 11:57, and the
announcement system calls him by name. To reach Platform Three he must restore emergency power.

## What's in the prototype

| Area | Implemented |
|---|---|
| Environment | Entrance hall, waiting hall, maintenance corridor, electrical room and Platform 3 with broad-gauge track, built procedurally from boxes (no imported models). Merged per room/material for few draw calls. Fog, flickering lights, rain over the tracks, occasional lightning. |
| Player | First-person walk/look with collision, no jumping, gentle speeds, head-bob, footsteps, phone torch. |
| Input | Keyboard + mouse, gamepad, and on-screen touch controls (floating joystick, drag-to-look, big **USE** button, **LIGHT**, pause). All routed through one input layer. |
| Interaction | Reusable `Interactable` component used by doors, notes/posters, breaker switches, monitors, the clock and story objects, with a contextual prompt. |
| Puzzle | Three emergency breakers (RED, GREEN, YELLOW — physically out of order). Clues: maintenance log + signal-aspect poster. Wrong order trips the panel (sparks, red flash, reset); hints get clearer after repeated mistakes; solving unlocks the Platform 3 gate. |
| Suspense event | Blackout → emergency lighting (colour/mood change) → monitors boot with a new message → the announcement greets Aarav by name → stopped clock restarts → stinger. Plus a silhouette on the platform. |
| Story moment | Kabir's phone on Platform 3 reveals the message was sent *three years ago*; midnight strikes and the platform signal turns green — "the last signal". |
| UI | Title screen, How to play, Credits & licenses, objective panel, interaction prompt, subtitles, document reader, pause menu (resume / restart / main menu / look sensitivity / invert Y / touch controls), end screen. Sized for phones; respects notches (safe area). |
| Audio | Rain, 50 Hz electrical hum, station chime + PA "voice", doors, breakers, thunder, footsteps, etc. — all **procedurally generated at runtime** (original, no files needed). Drop-in replacement files are picked up automatically. |

## Requirements

* **Godot 4.7.2** (standard build, *not* .NET) — free and open source (MIT): <https://godotengine.org/download>.
  The project was developed and tested against 4.7.2; older 4.x versions are not tested.
* For Android builds: see [docs/ANDROID_EXPORT.md](docs/ANDROID_EXPORT.md) (JDK 17, Android SDK, export templates).

## Quick start (desktop)

1. Clone this repository.
2. Start Godot 4.7.2 → **Import** → select `project.godot` → **Import & Edit**. (The first import takes a few seconds.)
3. Press **F5** (Run Project). The game starts on the title screen.
   * To jump straight into the level: open `scenes/levels/station.tscn` and press **F6**.
     Tick **Skip Intro** on the root `Station` node to skip the opening sequence while iterating.
4. To try the touch controls with a mouse: press **F3** in game (or Pause → *On-screen touch controls*).

## Controls

| Action | Phone / tablet | Keyboard & mouse | Gamepad |
|---|---|---|---|
| Walk | Left thumb — drag (floating joystick) | WASD / arrow keys | Left stick |
| Look | Right side — drag | Mouse | Right stick |
| Interact | **USE** button (pulses when something is usable) | E or left click | A |
| Phone torch | **LIGHT** button | F | Y |
| Hurry | — (joystick magnitude) | Shift | Left-stick click |
| Pause | **II** button / Android Back | Esc or P | Start |

Input actions live in **Project Settings → Input Map**, so bindings can be changed without code.

## Project structure

```
project.godot              Engine settings: Compatibility renderer, sensor-landscape, input map, Jolt physics
export_presets.cfg         Android export preset (no credentials stored)
icon.svg                   Original project icon
audio/                     Optional replacement audio files + bus layout (see docs/AUDIO.md)
scenes/
  main/title_screen.tscn   Main scene (title, how to play, credits)
  levels/station.tscn      The playable level: lights, interactables, triggers, events, player, UI
  player/player.tscn       First-person player (camera, torch, interaction ray)
  interactables/           Doors, gate, breaker switch, notes, posters, monitor, clock, signal, phone...
  ui/                      HUD, touch controls, document viewer, pause menu
scripts/
  autoload/                GameState (state + event bus), AudioManager, VirtualInput, Settings
  audio/                   ProceduralAudio - runtime sound synthesis
  interaction/             Interactable component (the reusable interaction system)
  interactables/           Door, PowerSwitch, ReadableNote, StoryObject, StationClock, StationMonitor...
  player/                  PlayerController, PlayerInput (device-agnostic), PlayerInteractor (ray)
  puzzle/                  SequenceLock (pure logic) + SwitchPuzzle (scene side)
  events/                  StoryTrigger, PowerRestoredEvent (suspense), EndingSequence
  level/                   StationBuilder (procedural geometry), MeshUtil, ProceduralTextures
  levels/                  StationLevel - level director / composition root for the story
  lighting/                FlickerLight
  story/                   StoryText - ALL narrative text in one place (ready for localisation)
  ui/                      HUD, touch controls, menus, title
tests/                     Headless automated tests (run_tests.gd + suites)
tools/run_tests.sh         One-command test runner
docs/                      Design notes, Android export guide, audio guide, testing guide
```

How the pieces talk to each other:

* **Objects are generic and reusable.** A door, note or switch only knows about its own behaviour and its `Interactable` child.
* **`GameState` is the event bus.** Gameplay calls `GameState.say()`, `set_objective()`, `open_document()`...; the HUD listens. No object references the HUD directly.
* **`StationLevel` is the composition root.** It wires signals and runs the level-specific story beats; words live in `StoryText`.
* **Input is device-agnostic.** Touch widgets write into `VirtualInput` / send Input Map actions; `PlayerInput` merges keyboard, mouse, gamepad and touch.

More detail (level map, story beats, puzzle solution, performance budget) in [docs/DESIGN.md](docs/DESIGN.md).

## Testing

Automated tests run headless (no window), including a scripted end-to-end playthrough of the level:

```bash
# Linux/macOS (set GODOT to your Godot 4.7.2 executable if it is not on PATH)
GODOT=/path/to/godot tools/run_tests.sh

# Any OS, manually (on Windows use the *_console.exe build):
godot --headless --path . --import
godot --headless --path . --fixed-fps 60 --script res://tests/run_tests.gd
```

Exit code `0` means every check passed. See [docs/TESTING.md](docs/TESTING.md) for what is covered,
what is **not** covered (rendering/visuals, real devices) and a manual on-device checklist.

## Android

The project is configured for Android: Compatibility (OpenGL ES 3.0) renderer for low-end devices,
sensor-landscape orientation, immersive mode, touch controls, Back-button handling, auto-pause when the
app loses focus, `arm64-v8a` + `armeabi-v7a`, min SDK 24. **No APK has been built yet** — the step-by-step
remaining setup is in [docs/ANDROID_EXPORT.md](docs/ANDROID_EXPORT.md).

## Audio

Every sound is synthesised at runtime by `scripts/audio/procedural_audio.gd`, so the game never depends
on missing files. To replace a placeholder, drop a file at the documented path (e.g.
`res://audio/ambience/rain_loop.ogg`) — no code changes needed. See [docs/AUDIO.md](docs/AUDIO.md).

## Known limitations (prototype)

* Visuals, lighting balance and frame rate have **not** been checked on a real screen or Android device yet
  (development so far used a headless build; see docs/TESTING.md).
* Blockout art only; English text only; no save system; one level.
* The PA "voice" is unintelligible procedural audio — subtitles carry the words. Real voice-over is future work.

## Ownership, licensing and credits

* The game's story, characters, code and generated content were written for AVENOX Games' THE LAST SIGNAL.
  No open-source licence is granted for the game itself. Formal arrangements (company registration,
  contributor/assignment agreements, trademark searches) are **not** established by this repository and
  should be handled separately with professional advice.
* The game is built on Godot Engine (MIT) which bundles third-party components — see
  [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The in-game **Credits & licenses** screen shows the
  engine notices required when distributing the game.
