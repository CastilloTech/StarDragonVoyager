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

In VS Code, **Ctrl+Shift+B** plays the game. The other commands are under *Terminal > Run Task*.

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
| Dragon special | **DRAGON** (Phase 4) | F (Phase 4) |
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
- Voidling enemy: a reusable state machine (circle, telegraph, lunge, recover, stagger).
- Three waves, victory and knockout states, restart.
- Health, mana and stamina. Mobile HUD, touch controls, pause menu with Graphics (Low/Med/High), screen shake and touch toggles.

## Roadmap (from the design doc)

| Phase | Status |
|---|---|
| 1. Visual foundation | ✅ first pass |
| 2. Player movement | ✅ first pass |
| 3. Ground combat | 🟡 elements and Voidling done; Marine and Rifleman next |
| 4. Dragon companion | ⏳ |
| 5. Encounter: miniboss, boss HUD | ⏳ |
| 6. Polish: audio, animation, VFX | ⏳ (no audio yet) |

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
