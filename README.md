# Star Dragon Voyager

HD-2D elemental space-pirate action RPG (Godot 4.7, GDScript).
**Focus right now: Windows desktop** (keyboard + mouse). Mobile (iOS/Android) support is
already built in (touch controls, Mobile renderer for phone exports) and comes later.
Current build: **Phase 1 (visual foundation) + a playable combat test scene.**

> All art is **procedural placeholder art** generated in code (`scripts/render/`).
> It establishes proportions, palettes and animation timing, not final quality.

## Run it

Use the `sdv` launcher in the project folder. Type `sdv` in Command Prompt, or `.\sdv` in PowerShell:

| Command | What it does |
|---|---|
| `sdv` | Play the game |
| `sdv edit` | Open the project in the Godot editor |
| `sdv test` | Automated smoke test that fires every ability and prints PASS/FAIL |
| `sdv shot` | Save a screenshot to `build\screenshot.png` |
| `sdv build` | Export `build\windows\StarDragonVoyager.exe` |
| `sdv touch` | Try the phone touch controls with the mouse |
| `sdv sprites` | Export the generated sprite sheets to `assets\generated\` |
| `sdv wave 3` | Play, starting at wave 3 (to test later enemies) |

In VS Code, press **F5** to play, just like F5 in the Godot editor. Close the game window to stop.
Pick touch controls or the smoke test from the *Run and Debug* dropdown. **Ctrl+Shift+B** also plays.

`sdv` finds Godot through the `GODOT` environment variable, or `godot` on your PATH.
Before the first `sdv build`, install the export templates once. In the editor:
*Editor > Manage Export Templates > Download and Install*.

## Controls

| Action | Phone | PC |
|---|---|---|
| Move (8 directions) | Left-thumb floating joystick | WASD / arrows |
| Aim | Automatic (nearest enemy in your direction) | Mouse |
| Basic attack (3-hit combo) | Tap **ATTACK** | Left click |
| Charged attack | Hold **ATTACK**, release when the ring fills | Hold right click |
| Dash (brief invulnerability) | **DASH** | Space |
| Switch element | Small element button | Q / mouse wheel |
| Elemental ability | Big element button | 1 (2–4 reserved) |
| Dragon special: Comet Shower | Dragon portrait button | F (lands at the mouse) |
| Pause / settings | **II** (or Android back) | Esc |
| Restart encounter | Pause menu | R |

## What's in this build

- Celestial Pirate Harbor arena: wood and brass dock, lanterns, energy conduits, compass inlay, a docked starship, floating islands, a nebula sky, stardust.
- HD-2D pipeline: orthographic 3/4 camera, pixel-perfect sprites, sun shadows, selective bloom, height fog, tilt-shift blur, vignette.
- Pirate captain, fully animated (placeholder): idle, walk, run, dash, 3 attacks, charge, charged attack, cast, hit, knockout, in 3 facings.
- Combat: combo, charged attack, dash with i-frames, crits, hit-stop, screen shake, damage numbers, knockback, stagger.
- Five elements, each with its own ability and status effect:
  - **Sun:** Solar Flare. A fireball that explodes and burns.
  - **Comet:** Comet Shard. A piercing shard that chills, then freezes.
  - **Storm:** Arc Lightning. Chains between enemies and shocks them.
  - **Gravity:** Gravity Well. Pulls enemies in, then implodes.
  - **Void:** Void Step. Teleports you, then bursts and hexes enemies.
- Element combos: Melt, Shatter, Overload, Solar Vortex, Frozen, Hexed (see `scripts/core/elements.gd`).
- Enemies, built on a reusable state machine:
  - **Voidling:** circles you, then telegraphs a lunge.
  - **Admiralty Marine:** electrified saber with a red arc warning. It shrugs off light hits but combo finishers stagger it.
  - **Admiralty Rifleman:** keeps its distance and aims with a red sight line that locks before firing. You can dash through its bolts.
- **Nova, the dragon companion** (Comet element):
  - Follows you and hovers at your side.
  - Breathes frost at nearby enemies. Two frost hits freeze an enemy, which sets up your Shatter and Melt combos.
  - Returns to you after a fight.
  - **F:** Comet Shower rains frost comets on the target area (14 s cooldown).
  - She can be knocked out and recovers after 10 seconds.
  - She has her own HUD panel, sounds and personality.
- Four mixed waves, victory and knockout states, restart.
- Responsive combat: clicks are buffered, swings snap and lunge toward nearby enemies, and a ground marker shows your aim.
- Placeholder sound effects synthesized in code, with Music/SFX/Ambience/UI buses. Drop a real file in `assets/audio/<name>.ogg` to replace one.
- Health, mana and stamina. Mobile HUD, touch controls, pause menu with Graphics (Low/Med/High), screen shake and touch toggles.

## Roadmap (from the design doc)

| Phase | Status |
|---|---|
| 1. Visual foundation | ✅ first pass |
| 2. Player movement | ✅ first pass |
| 3. Ground combat | ✅ first pass (all 3 enemy types) |
| 4. Dragon companion | ✅ first pass (Nova) |
| 5. Encounter: miniboss, boss HUD | ⏳ next |
| 6. Polish: audio, animation, VFX | 🟡 placeholder sound effects in; music not yet |

## Project layout

```
scripts/core/        Game autoload (settings, effects), elements, damage, HD-2D constants
scripts/render/      camera, post-processing, procedural pixel art, sprite sheets
scripts/world/       Celestial Pirate Harbor arena
scripts/components/  HealthComponent, StatusEffectManager
scripts/player/      PlayerController, CombatController, ElementalAbilityManager
scripts/combat/      projectiles, gravity well
scripts/enemies/     enemy FSM base + Voidling
scripts/ui/          HUD, touch controls, pause menu, UI style
docs/                rendering pipeline, mobile and app store guide
```
