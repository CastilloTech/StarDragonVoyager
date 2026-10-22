# Progression: Skills, Dragons and Gear

All numbers live in code you can tune:

| What | File |
|---|---|
| Skill tree | `scripts/core/skills.gd` |
| Spells per element | `scripts/core/spells.gd` |
| Dragons and evolution | `scripts/core/dragons.gd` |
| Equipment | `scripts/core/items.gd` |
| Gear sets | `scripts/core/gear_sets.gd` |
| Levels, saving, final stats | `scripts/core/progress.gd` |

Progress saves automatically to `user://progress.json`
(`%APPDATA%\Godot\app_userdata\Star Dragon Voyager\`).

## Captain levels
- XP comes from kills: Voidling 10, Rifleman 18, Marine 22. The active dragon earns the same XP.
- XP to the next level is `40 + 25 × (level − 1)`. The level cap is **50**.
- You get **1 skill point per level up to 30**, then 1 every 2 levels: 29 points at level 30, 39 at level 50. Leveling up also heals 25%.

## Skill tree: Swordsman
Rows unlock by points spent **in that branch**: 0, 1, 3, 5 and 8. Maxing a branch
costs 17 points. With 39 points at the cap you can max two branches and dip into the third,
or spread out. Respec is free (Captain's Log, Skills tab).

| | Duelist (speed) | Vanguard (power) | Spellblade (magic) |
|---|---|---|---|
| Row 1 (5 ranks) | **Swift Blades**: +6% attack speed | **Heavy Hand**: +12% charged, +6% finisher damage | **Mana Siphon**: +2 mana per sword hit |
| Row 2 (5 ranks) | **Keen Edge**: +3% crit chance, +8% crit damage | **Iron Hide**: +12 health, +3% armor | **Arcane Focus**: +8% spell power, 4% faster cooldowns |
| Row 3 (3 ranks) | **Riposte**: a last-moment dash counters for 150/200/250% | **Unshakable**: no flinching, −10/20/30% damage while attacking | **Imbue**: finisher carries the dragon's element, +20/35/50% |
| Row 4 (3 ranks) | **Fleetfoot**: −15% dash cost, +5% move speed | **Quick Charge**: charges 15% faster | **Spell Weave**: casting empowers the next 2 swings +20/35/50% |
| Capstone | **Flurry**: a 4th combo strike (double slash) | **Earthsplitter**: charged attacks send out a shockwave | **Dragon's Echo**: 25% chance spells cast twice; spells cut the dragon's cooldown by 1 s |

Gear can add **bonus ranks** to any skill. That works even for skills you haven't
learned, and can go up to 3 past the normal max (gear plus set bonuses).

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

| Grade | Required level | Random bonuses | Value multiplier | Drop weight |
|---|---|---|---|---|
| Common | — | 0 | ×1.0 | 52% |
| Uncommon | 5 | 1 | ×1.3 | 27% |
| Rare | 15 | 2 | ×1.7 | 13% |
| Epic | 25 | 3 | ×2.2 | 6% |
| Legendary | 35 | 4 | ×2.8 | 1.8% |
| Mythic | 45 | 5 | ×3.5 | 0.2% |

The level requirement uses the **captain's** level, for dragon gear too. Gear you
can't wear yet still drops; it waits in the bag, dimmed and tagged "(Lv X)". Items
from an older save that you're under-leveled for move to the bag on load.

Captain bonus pool:
- Sword damage, crit chance, crit damage, attack speed
- Health, armor, move speed
- Mana, mana regen, spell power, faster cooldowns, stamina regen
- Dragon damage
- **+ranks to a skill:** +1 up to Epic, +1–2 Legendary, +2 Mythic. Capstones only on Legendary and up.

### Item names tell you the specialty
An item's **prefix** names its specialty: its strongest bonus, meaning the one that
rolled closest to its maximum. Common items have no bonuses, so they use their
main stat. Items with a **+skill rank** bonus are named after that skill's branch.
Prefixes get grander with grade; the grade itself shows by color.

| Specialty | From | Common–Uncommon | Rare–Epic | Legendary–Mythic |
|---|---|---|---|---|
| Might | Sword damage, crit damage | Sharp | Starsteel | Admiral-Slayer |
| Precision | Crit chance | Keen | Hawkeye | Deadeye |
| Swiftness | Attack speed, move speed, stamina | Quick | Swift | Stormforged |
| Vitality | Health | Sturdy | Stalwart | Undying |
| Bulwark | Armor | Riveted | Ironclad | Unbreakable |
| Arcana | Spell power, mana, cooldowns | Charmed | Moonlit | Nebula-Woven |
| Draconic | Dragon damage (captain gear) | Drakeling | Dragonheart | Starwyrm |
| Guardian | Dragon health, armor | Thick-Scaled | Ironscale | Mountainhide |
| Ferocity | Dragon damage, breath speed (dragon gear) | Fierce | Savage | Primal |
| Fury | Dragon special cooldown and damage | Roaring | Thunderous | Cataclysmic |
| Kinship | Dragon XP gain | Bonded | Kindred | Soulbound |
| Duelist skills | +ranks to a Duelist skill | Duelist's | Bladedancer's | Swordsaint's |
| Vanguard skills | +ranks to a Vanguard skill | Soldier's | Vanguard's | Warlord's |
| Spellblade skills | +ranks to a Spellblade skill | Apprentice's | Spellblade's | Archmage's |

Drops:
- **Enemies:** Voidling 12%, Rifleman 22%, Marine 25%.
- **Wave clear:** every cleared wave drops a guaranteed item with extra luck, which can bump the grade up.
- **Pickup:** a new item goes into an empty slot automatically, otherwise into the bag (40 items).

## Gear sets (captain only)
Three sets, one per skill tree. Each set has 5 pieces: weapon, hat, coat, gloves
and boots. Each comes in five versions:

| Version | I | II | III | IV | V |
|---|---|---|---|---|---|
| Required level | 10 | 20 | 30 | 40 | 50 |
| Piece stats | ×1.7 | ×2.3 | ×2.9 | ×3.6 | ×4.4 |
| Bonus strength | ×1.0 | ×1.4 | ×1.8 | ×2.3 | ×2.8 |

Mixed versions work, but the set bonus uses the **lowest version** you wear.

| | Galeblade (Duelist) | Ironwake (Vanguard) | Astral Weaver (Spellblade) |
|---|---|---|---|
| Piece bonuses (on top of the slot's main stat) | Attack speed, crit chance | Health, armor | Spell power, mana |
| 2 pieces | +5% attack speed, +3% crit chance | +20 health, +3% armor | +8% spell power, +10 mana |
| 3 pieces | +1 to all Duelist skills (+2 from IV) | +1 to all Vanguard skills (+2 from IV) | +1 to all Spellblade skills (+2 from IV) |
| 5 pieces | **Gale Step**: after a dash, your next strike within 2 s is a sure crit with +25% damage | **Bulwark Surge**: charged attacks heal 5% of max health and halve damage taken for 2.5 s | **Starfall Echo**: every 3rd spell costs no mana and deals +30% damage |

Values in the 2- and 5-piece rows are for version I and scale with bonus strength.
Attack speed is capped at ×2.25.

Set pieces show in teal. They drop once you reach **level 10**, at the version for
your level:
- **Enemies:** 2% per kill, 4% for Marines.
- **Wave clear:** 20% chance of an extra set piece.

Test tools (pause menu): **+10 Levels** and **Set piece**.
