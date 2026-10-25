# Game Brief: Quarantine Breach

**One-sentence pitch:** Lead squads into procedurally generated towns overrun by the dead to pull out survivors and supplies before the chopper leaves, where every gunshot calls the horde and every bite turns your own people against you, all while the infection eats the region sector by sector.

## Core loop
- Pick an infected sector on the region map, weighing risk against the loot and survivors there.
- Deploy squads, then scavenge and rescue under the evac timer, choosing quiet and slow or loud and fast.
- Extract with whatever and whoever survived.
- Spend the loot on soldiers, gear and support call-ins while the infection spreads, then pick the next sector.

## Player goal & fail state — what "working" looks like
- **Goal:** hold the region by clearing sectors faster than the infection takes them. A mission succeeds when at least one unit reaches evac before the timer ends.
- **Fail:** a mission fails when the squad is wiped or turned before extracting. The campaign is lost when the infected sectors pass the difficulty's threshold.

## MVP — what must exist to be the game
1. **Procedural suburb:** generated streets, houses, yards and a main street, with buildings you can enter. Building interiors show as icons for loot and occupants, and zombies and fights can happen inside.
2. **Squad control and loadouts:** select, move and attack with 2–3 squads, with line of sight and fog. Each soldier has a class (rifleman, medic, engineer, scout, heavy) and gear slots chosen before the mission.
3. **Noise-driven horde with time of day:** zombies are drawn by noise (silenced vs loud weapons). Each mission is set by day or night, and night means shorter sight and more roaming zombies. Horde size is set by difficulty.
4. **Infection turning:** bitten soldiers and civilians turn after a delay and join the horde. Antidote items or a medic can stop it.
5. **Extraction mission:** civilians to escort, supply caches to grab, and an evac countdown. Loot has weight, so heavy squads move slower.
6. **Call-in support that grows with equipment:** abilities unlock by buying equipment. The MVP ships with 2–3 (e.g. barricade drop, airstrike).
7. **Region campaign map:** sectors, infection spread (rate set by difficulty), sector choice, a shop for soldiers, gear and call-ins, and the loss threshold.

## Out of scope — not building this
- Base building
- Real-world or Google map data
- Multiplayer
- Story, cutscenes and voiced characters
- Saving mid-mission (saves only between missions)

## Later — after the MVP is built
- XP, skills and skill trees
- Personal traits
- Injuries and fatigue
- Morale and panic
- A memorial for the fallen
- Vehicles as buyable equipment: fast transport (with a loud engine), armored mobile cover, and extra evac capacity
- Weather: rain masks noise, fog cuts vision
- A live day/night cycle during missions
- More call-in abilities
- More town types: dense city blocks, rural farmland, industrial areas
- A rotatable 360° camera with zoom
- Zombie variants (runners, bloated, armored), each visibly distinct

## Build order
1. A greybox block with one squad (classes and loadouts) versus noise-drawn zombies. This is the risky core: prove that "loud vs quiet" is fun.
2. Infection turning and the antidote, for soldiers and civilians.
3. A full extraction mission: civilians, loot with carry weight, evac timer and win/fail.
4. Procedural town generation, replacing the greybox.
5. The equipment-unlocked call-in support system with 2–3 abilities.
6. The region campaign map with spread, sector choice and the shop.
7. Day/night per mission.
8. Difficulty presets for horde size and spread speed.

---
**Who it's for / what they feel:** RTS and zombie-sim fans who enjoy outsmarting a horde. Missions run from quick raids on small sectors to long operations on big ones, and the reward is the satisfaction of a clean, clever extraction.

**Art & audio direction:** Low-poly 3D rendered as medium-resolution pixel art, viewed top-down at a 3/4 angle. The palette is muted, units are small but readable, the gore is light, and the music builds dynamically with the threat.

**Look notes:**
- Units are about 16–24 px. They're told apart by color, by silhouette and gear, and by selection rings with squad numbers.
- Night is dark, and flashlight and streetlight cones are what reveal the map.
- The fog of war is black where never explored and grey where already seen.
- The world takes light damage: broken windows, burnt cars, bullet marks.
- Soldiers animate smoothly, and zombies move in a jerky, shambling way.
- Noise rings, a horde heat map and infection countdowns make threats readable.
- The UI is pixel art, and the region map uses the same pixel style with sectors colored by infection.

**Reference game:** Atom Zombie Smasher: the region map with spreading infection and evac-under-pressure missions. The MVP keeps that loop but adds direct squad control in the style of Ebbtide.
