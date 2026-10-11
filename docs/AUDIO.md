# Audio guide

## How audio works

* `scripts/autoload/audio_manager.gd` (**AudioManager** autoload) plays everything: looping ambience,
  one-shot sounds, positional (3D) sounds and station announcements (chime + voice).
* Every sound has an **id** (e.g. `&"rain"`). For each id, AudioManager looks for a real file first and
  otherwise uses an **original procedural placeholder** from `scripts/audio/procedural_audio.gd`.
* Placeholders are generated once on a background thread while the title screen is shown, then cached.
  **A missing audio file can never break the game** — it simply falls back to the placeholder
  (tested by `tests/test_procedural_assets.gd`).

Buses (`audio/default_bus_layout.tres`; recreated at runtime if the file is missing):

| Bus | Used for | Effects |
|---|---|---|
| `Ambience` | rain, electrical hum | — |
| `SFX` | doors, breakers, footsteps, thunder, UI | — |
| `Announcer` | station chime and voice | Reverb (big tiled hall) |

## Replacing a placeholder with a real sound

1. Get a sound you are allowed to use (see *Licensing* below).
2. Save it at the path listed for its id, with extension `.ogg` (preferred), `.wav` or `.mp3`:

| Id | File path (without extension) | Notes |
|---|---|---|
| `rain` | `res://audio/ambience/rain_loop` | seamless loop |
| `hum` | `res://audio/ambience/electrical_hum` | seamless loop |
| `chime` | `res://audio/announcements/chime` | station "ding-dong" before announcements |
| `announce_name` | `res://audio/announcements/announce_name` | "Passenger Aarav, please proceed to Platform Three…" |
| `announce_power` | `res://audio/announcements/announce_power` | "Emergency power has been restored… Welcome back." |
| `announce_last_train` | `res://audio/announcements/announce_last_train` | "The last train is now arriving on Platform Three." |
| `door_open` / `door_close` / `door_locked` / `door_slam` | `res://audio/sfx/<id>` | |
| `switch_on` / `breaker_trip` / `power_up` / `power_down` | `res://audio/sfx/<id>` | |
| `paper` / `footstep` / `thunder` / `stinger` / `train_horn` | `res://audio/sfx/<id>` | `footstep` is played with random pitch |
| `clock_tick` / `clock_bell` / `ui_click` / `monitor_on` / `phone_buzz` | `res://audio/sfx/<id>` | |

3. Open the project in the Godot editor once so the file is imported. For loops, select the file →
   *Import* dock → enable **Loop** → *Reimport* (AudioManager also forces looping for `rain` and `hum`).
4. Run the game. `AudioManager.has_asset_file(&"rain")` returns `true` when a file is being used.

The authoritative list is `AudioManager.CATALOGUE`; subtitles for announcements are in
`scripts/story/story_text.gd`, so voice lines should match that text.

## Recommended formats for low-end Android

* **Ogg Vorbis**, mono for effects, 22–44.1 kHz, quality ~0.4–0.5. Keep ambience loops short (10–30 s).
* Avoid long uncompressed WAVs (memory). Avoid many simultaneous 3D sounds.

## Licensing — what is allowed

* Only use sounds that are **original**, **procedural**, **CC0 / public domain**, or under a licence that
  permits **commercial** use. Read the licence of every file (many "free" sounds forbid commercial use or
  require attribution).
* Record every third-party sound in [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md): name, author,
  source URL, licence, and any attribution text required.
* Do **not** use sounds ripped from films, TV, other games, or real railway announcements/jingles.
* The current placeholders are original synthesis code written for this project (including the four-note
  chime, which is an original pattern). No third-party audio is included.

## Adding a new sound

1. Add an id → path entry to `CATALOGUE` in `audio_manager.gd`.
2. Add a generator branch in `ProceduralAudio.generate()` and the id to `ProceduralAudio.IDS`
   (the test suite checks every catalogue id has a fallback).
3. Play it: `AudioManager.play(&"my_sound")` or `AudioManager.play_at(&"my_sound", position)`.
