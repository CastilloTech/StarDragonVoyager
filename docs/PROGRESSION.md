# Progression: Skills, Dragons and Gear

All numbers live in code you can tune:

| What | File |
|---|---|
| Skill tree | `scripts/core/skills.gd` |
| Spells per element | `scripts/core/spells.gd` |
| Dragons and evolution | `scripts/core/dragons.gd` |
| Equipment | `scripts/core/items.gd` |
| Levels, saving, final stats | `scripts/core/progress.gd` |

Progress saves automatically to `user://progress.json`
(`%APPDATA%\Godot\app_userdata\Star Dragon Voyager\`).

## Captain levels
- XP comes from kills: Voidling 10, Rifleman 18, Marine 22. The active dragon earns the same XP.
- XP to the next level is `40 + 25 × (level − 1)`. The level cap is 30.
- You get **1 skill point per level**, so 29 at the cap. Leveling up also heals 25%.

## Skill tree: Swordsman
Rows unlock by points spent **in that branch**: 0, 1, 3, 5 and 8. Maxing a branch
costs 17 points. With 29 points you can max one branch and dip into another,
or spread out. Respec is free (Captain's Log, Skills tab).

| | Duelist (speed) | Vanguard (power) | Spellblade (magic) |
|---|---|---|---|
| Row 1 (5 ranks) | **Swift Blades**: +6% attack speed | **Heavy Hand**: +12% charged, +6% finisher damage | **Mana Siphon**: +2 mana per sword hit |
| Row 2 (5 ranks) | **Keen Edge**: +3% crit chance, +8% crit damage | **Iron Hide**: +12 health, +3% armor | **Arcane Focus**: +8% spell power, 4% faster cooldowns |
| Row 3 (3 ranks) | **Riposte**: a last-moment dash counters for 150/200/250% | **Unshakable**: no flinching, −10/20/30% damage while attacking | **Imbue**: finisher carries the dragon's element, +20/35/50% |
| Row 4 (3 ranks) | **Fleetfoot**: −15% dash cost, +5% move speed | **Quick Charge**: charges 15% faster | **Spell Weave**: casting empowers the next 2 swings +20/35/50% |
| Capstone | **Flurry**: a 4th combo strike (double slash) | **Earthsplitter**: charged attacks send out a shockwave | **Dragon's Echo**: 25% chance spells cast twice; spells cut the dragon's cooldown by 1 s |

Gear can add **bonus ranks** to any skill. That works even for skills you haven't
learned, and can go up to 2 past the normal max.

## Dragons: your spells come from your dragon
Your active dragon's **element** picks your spell set. Its **evolution stage**
unlocks the spells:

| Stage | Dragon level | Spells | Size | Power | Health |
|---|---|---|---|---|---|
| Hatchling | 1 | 1st | 85% | ×1.0 | 60 |
| Drake | 5 | + 2nd | 100% | ×1.45 | 90 |
| Wyrm | 10 | + 3rd | 122% | ×2.0 | 130 |

| Dragon | Hatchling | Drake | Wyrm | Special |
|---|---|---|---|---|
| Ember (Sun) | Solar Flare | Flame Wave | Supernova | Meteor Shower |
| Nova (Comet) | Comet Shard | Frost Nova | Glacial Spikes | Comet Shower |
| Volt (Storm) | Arc Lightning | Thunder Strike | Storm Field | Thunderstorm |
| Orbit (Gravity) | Gravity Well | Repulse | Singularity | Starfall |
| Nyx (Void) | Void Step | Void Orb | Rift Barrage | Rift Rain |

All five hatchlings are available from the start. Switch your active dragon in
the Captain's Log, Dragons tab. Only Nova has her own art. The others are
**recolored Nova sprites** until their art is made.

## Equipment

**Captain, 7 slots:**

| Slot | Main stat |
|---|---|
| Weapon | Sword damage |
| Hat | Health and mana |
| Coat | Health and armor |
| Gloves | Attack speed and crit chance |
| Boots | Move speed and stamina regen |
| Ring | Crit damage and spell power |
| Charm | Spell power and mana |

**Dragon, 4 slots.** Each dragon keeps its own gear, so it follows them when you swap:

| Slot | Main stat |
|---|---|
| Saddle | Dragon health and armor |
| Talon Guards | Dragon damage |
| Crest | Faster special and special damage |
| Bond Charm | Dragon XP gain, plus spell power for the captain |

Dragon gear rolls bonuses from its own pool:
- Dragon health, armor, damage, breath speed
- Special cooldown and damage, XP gain
- **Bond stats** that help the captain: spell power, mana regen, faster spell cooldowns. These apply only while that dragon is active.

About 30% of drops are dragon gear. A new piece goes into an empty slot automatically: the captain's, or your active dragon's.

| Grade | Random bonuses | Value multiplier | Drop weight |
|---|---|---|---|
| Common | 0 | ×1.0 | 52% |
| Uncommon | 1 | ×1.3 | 27% |
| Rare | 2 | ×1.7 | 13% |
| Epic | 3 | ×2.2 | 6% |
| Legendary | 4 | ×2.8 | 1.8% |
| Mythic | 5 | ×3.5 | 0.2% |

Captain bonus pool:
- Sword damage, crit chance, crit damage, attack speed
- Health, armor, move speed
- Mana, mana regen, spell power, faster cooldowns, stamina regen
- Dragon damage
- **+ranks to a skill:** +1 up to Epic, +1–2 Legendary, +2 Mythic. Capstones only on Legendary and up.

Drops:
- **Enemies:** Voidling 12%, Rifleman 22%, Marine 25%.
- **Wave clear:** every cleared wave drops a guaranteed item with extra luck, which can bump the grade up.
- **Pickup:** a new item goes into an empty slot automatically, otherwise into the bag (40 items).
