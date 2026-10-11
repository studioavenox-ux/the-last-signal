# Design notes — Mission 001 prototype

**Spoilers:** this document contains the puzzle solution and the ending.

## Story beats (prototype)

| # | Beat | Where | Implemented by |
|---|---|---|---|
| 1 | Message from Kabir: *"Platform Three. Midnight."* Fade in, 11:41 PM. | Entrance hall | `StationLevel._run_intro()` |
| 2 | The entrance doors slam and lock behind Aarav (thunder, camera shake). Objective: *Find a way to Platform Three.* | Entrance hall | `Door.slam_and_lock()` |
| 3 | Notice board: the station is closed; the Platform 3 gate needs emergency power from the Electrical Room. Stopped clock at 11:57 (second hand twitches). | Entrance hall | `ReadableNote`, `StationClock` |
| 4 | Announcement: *"Passenger Aarav, please proceed to Platform Three. Your brother is waiting."* | Waiting hall (trigger) | `StoryTrigger` → `AudioManager.play_announcement()` |
| 5 | Platform 3 gate: electronic lock dead. Kabir's torn note; signal-aspect poster (clue). Objective: *Restore emergency power.* | Waiting hall | `Door` (locked), `ReadableNote` |
| 6 | Maintenance corridor: maintenance log (clue). | Corridor | `ReadableNote` |
| 7 | Breaker puzzle. Objective: *Close the three emergency breakers in the correct order.* | Electrical room | `SwitchPuzzle` + `PowerSwitch` |
| 8 | **Suspense event**: blackout → emergency lighting → monitors boot (*PASSENGERS WAITING: 2* → *WELCOME BACK, AARAV.*) → announcement *"…Passenger Aarav. Welcome back."* → clock restarts → stinger. Objective: *Go to Platform Three.* | Electrical room / station-wide | `PowerRestoredEvent` |
| 9 | A silhouette stands behind the gate for a moment when Aarav looks at the platform. | Waiting hall → platform | `StationLevel._check_apparition()`, `Apparition` |
| 10 | Platform 3 in the rain; the signal glows red. Objective: *Find Kabir.* | Platform | `StoryTrigger` |
| 11 | Kabir's phone on a bench: the message was sent at 11:57 PM **three years ago** (the minute the clock stopped). Midnight bell, distant horn, the signal turns yellow → green: *the last signal*. End of prototype. | Platform | `EndingSequence` |

All text is in `scripts/story/story_text.gd`.

## Puzzle

* Breakers on the panel, left → right: **GREEN, RED, YELLOW** (deliberately not in solution order).
* Clue 1 (maintenance log, corridor): close the breakers *in the order the platform signal shows when a blocked line clears*.
* Clue 2 (safety poster, waiting hall): RED = danger/stop, YELLOW = caution/clearing, GREEN = clear; a clearing line goes danger → caution → clear.
* **Solution: RED → YELLOW → GREEN.**
* Wrong breaker: sparks, red screen flash, camera shake, all breakers snap back OFF.
  After 2 mistakes Aarav recalls the clue; after 4 he says the answer outright (no one gets stuck).
* Accessibility: every breaker has a text label, not just a colour.

## Level map (top view, metres; +X east, -Z north)

```
            Z=-34  ── retaining wall ──────────────────────────────
                   ═════════ broad-gauge track (1.676 m) ═════════   rain falls here
            Z=-26  ─ ─ platform edge (invisible safety barrier) ─ ─ [signal @ x=8]
                   │            PLATFORM 3  (X -10..10)          │
                   │   bench        (apparition)     bench+PHONE │
            Z=-18  ────────────────[ GATE ]──────────────────────── station wall
┌─────────────┐    │         WAITING HALL (X -7..7)        [poster]│
│ ELECTRICAL  │    │  bench  bench           bench  bench+NOTE   │
│ ROOM        ├────┤DOOR                                          │
│ [breakers]  │corridor (Z -13..-11)          [departure board]  │
│ [monitor]   │    │                                              │
└─────────────┘    Z=-8 ─────────────[ ARCHWAY ]────── [clock] ────
 X=-21    X=-15  X=-7  │        ENTRANCE HALL (X -6..6)           │
                       │[NOTICE]  benches          booking office │
                 Z=+2  ────────────[ ENTRANCE DOORS ]──────────────
```

Geometry lives in `scripts/level/station_builder.gd` (data-driven boxes). Gameplay objects are scene
instances in `scenes/levels/station.tscn`, so designers can move them in the editor; the builder is a
`@tool` script so the blockout is visible while editing (generated nodes are not saved).

## Architecture

```
            ┌───────────── GameState (autoload: flags, objective, pause stack, event bus) ─────────────┐
            │                                                                                          │
 PlayerInput ──► PlayerController ──► PlayerInteractor (ray) ──► Interactable ──► Door / Note / Switch │
   ▲   ▲                                                         (component)       / StoryObject ...  │
   │   └── keyboard, mouse, gamepad (Input Map)                                                         │
   └────── VirtualInput (autoload) ◄── TouchControls                                                    │
                                                                                                        │
 StationLevel (composition root) ── wires signals, runs story beats ── PowerRestoredEvent, EndingSequence
 HUD / DocumentViewer / PauseMenu ◄── listen to GameState signals ─────────────────────────────────────┘
 AudioManager (autoload) ── file if present, else ProceduralAudio
```

Reuse examples: a new locked door is `door_single.tscn` + `locked = true` + a `StoryText` line id;
a new clue is `readable_note.tscn` + a new entry in `StoryText.DOCUMENTS`; a new sequence puzzle is a
`SwitchPuzzle` with different `PowerSwitch` children and `solution`.

## Low-end Android budget (design targets — not yet measured on a device)

* **Renderer:** Compatibility (GLES3). No SSAO/SSR/SDFGI/volumetric fog/glow; simple exponential fog.
* **Lights:** 7 station omni lights + signal glow + phone glow + torch spot; **no shadows**. Lights at zero
  energy are hidden. Per-room merged meshes keep each mesh under the per-object light limit.
* **Draw calls:** ~25 merged geometry meshes + props/signs (roughly 100 in total at worst).
* **Textures:** two 128 px procedural textures; materials are flat-coloured StandardMaterial3D.
* **Particles:** one CPUParticles3D rain emitter (260 particles) over the tracks only.
* **Physics:** box/capsule shapes only; Jolt physics; 60 ticks/s.
* **Audio:** short mono procedural clips (8–22 kHz), generated off the main thread.
* **UI:** 1280×720 canvas, `canvas_items` stretch with `expand` aspect; 22–30 px text; 64+ px tall buttons.
