# Procedural sound and future audio hooks

No third-party audio is packaged. `scripts/ambient_audio.gd` continuously generates a quiet rain-like filtered-noise bed and power-dependent hum. Movement adds brief low-noise footstep ticks; puzzle, announcement, phone and ending events use synthetic chirps. The volume slider controls their shared AudioStreamPlayer. Missing recordings cannot crash the game because none are loaded.

Announcements and Rohan's call are **on-screen text only**, not synthesized or recorded speech. To add original/licensed Ogg Vorbis recordings later, add them here, register author/source/license/attribution in `docs/ASSETS.md`, and connect AudioStreamPlayer nodes to `solve_puzzle()`, `start_arrival()` and `cut_announcement()` in `scripts/game.gd`. Keep transcripts visible for accessibility and mute support. Test loops and loudness on actual Android hardware.
