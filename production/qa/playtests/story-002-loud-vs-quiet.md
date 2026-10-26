# Playtest Note: Loud vs quiet (story 002)

**Story**: production/epics/quarantine-breach/story-002-noise-driven-horde-and-time-of-day.md
**Criterion**: "This story proves 'loud vs quiet' is a real choice: a playtest note records whether quiet play is a viable alternative to loud play"
**Status**: PLAYED 2026-10-27 by the player (answers recorded by Claude from the player's replies).

## How to play

Open `res://src/squads/greybox_block.tscn` in Godot and press F6. Pick a loadout, deploy, then try both styles on the same horde size and the same time of day:

- **Loud:** loud weapons (e.g. machine gun, shotgun), no suppressor, fight whatever comes.
- **Quiet:** suppressed or low-noise weapons (e.g. hunting rifle with suppressor, pistol), move slowly, avoid unneeded shots.

Debug keys (confirm in the on-screen help line): N noise rings, H horde heat map, T toggle day/night.

## Results (fill in)

| Run | Style | Difficulty | Time of day | Result (survived / lost soldiers) | Roughly how many zombies reached the squad |
|-----|-------|------------|-------------|-----------------------------------|--------------------------------------------|
| 1 | Loud | Normal | Day | Depends on tactics: rushing into the horde wipes every squad; playing strategically saves some soldiers, or all of them when played well | Nearly all of the horde |
| 2 | Quiet | Normal | Day | Depends on tactics in the same way: strategizing or not decides the outcome | A few |

## Verdict

- **Is quiet play a viable alternative to loud play?** Yes
- **Why (what made the difference, e.g. reach of noise, how fast the horde reacts)?** Loud play drew nearly the whole horde, quiet play only a few zombies. In both styles survival came down to tactics (rushing in got squads killed; careful play kept them alive), so quiet is a real choice rather than a forced one.
- **Does the choice change at night?** Not tested: only day was played.
- **What would you change (noise radii, horde reaction, weapon values in `assets/data/`)?** Nothing yet: the values feel fine for the greybox.
