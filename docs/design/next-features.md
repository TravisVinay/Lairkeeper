# Next features: difficulty modifiers, more rooms, the Dark Lord and Squire

Status: all three sections are built: the modifiers, the first batch of five rooms, and the
Dark Lord and Squire. The rest of the room list in section 2 is still planned. It picks up ideas from
[rooms-and-roguelike.md](rooms-and-roguelike.md) (room IDs like R13 refer to that file) and
turns three of them into buildable specs with numbers.

Suggested build order, smallest to largest:

1. **Difficulty modifiers** (medium). Self-contained, and gives late players a reason to keep going.
2. **More rooms** (small each, can ship a few at a time). Mostly data plus one rule each.
3. **The Dark Lord and Squire** (large). The game assumes one monster in about 38 places.

---

## 1. Difficulty modifiers

**Built.** The modifiers are `Data.MODS`; the rules live in `Game` (`has_mod`, `day_hours`,
`kill_gold`, `boss_every`, `soul_mult`) and `Battle` (`mk_unit`, `spots_traps`). Your
picks are remembered in `meta.last_mods`, and a modded run's best night goes in
`meta.best_dread`. Per-monster records are not built yet.

Before a run, on the monster pick screen, you can switch on **Dread modifiers**. Each one
makes the run harder and adds a souls bonus. Bonuses add up, and the total is shown before
you start ("Souls ×1.65"). This is the pick-your-own version of Dread levels (M04 in the
catalog), in the style of Hades' Heat.

### The modifiers

| ID | Name | What it does | Souls |
| --- | --- | --- | --- |
| DM1 | Zealous Village | Heroes have +25% HP. | +15% |
| DM2 | Hardened Raiders | Heroes deal +1 damage. | +15% |
| DM3 | Crowded Gate | One extra hero every night. | +20% |
| DM4 | Sharp Eyes | Every hero spots traps and walks around them, like a Rogue. | +20% |
| DM5 | Short Days | 2 hours a day instead of 3. | +25% |
| DM6 | Lean Coffers | Half gold from kills and from the dawn tribute. | +15% |
| DM7 | No Rest | Nothing heals you at dawn (the Larder still works on minions, if we add that). | +15% |
| DM8 | Restless Crusade | Boss nights every 4 nights instead of 5. Floors also open sooner. | +10% |
| DM9 | Godless | No dark boons after nights. | +30% |
| DM10 | Glass Lair | Your monster starts with 25% less max HP. | +20% |

All ten together is ×2.85 souls, which is a fair reward for something close to unplayable.

### Rules

- **Unlocking:** modifiers unlock after your first run that reaches night 5, so new players never see them. A small note on the monster pick screen says how to unlock them.
- **The bonus applies to everything the run banks** at the end: kills, boss kills and the 2 souls per night.
- **No changes mid-run.** The run's modifiers are saved with it and shown in the pause menu and on the death screen.
- **Records:** store "most nights survived" per monster with and without modifiers, so a modded run gets its own record.
- **The tutorial ignores modifiers.**

### Where it touches the code

| Modifier | Hook |
| --- | --- |
| DM1, DM2 | `Battle.mk_unit` hero branch |
| DM3 | `Game.make_party` |
| DM4 | `Battle.reach_of` / hero AI `sense` checks |
| DM5, DM7 | `Game.dawn` and `Game.new_run` |
| DM6 | `Game.dawn`, and the loot in `Battle.resolve_win` |
| DM8 | `Game.BOSS_EVERY` becomes a function |
| DM9 | `main._on_finished`: skip the pick, go straight to dawn |
| DM10 | `Game.new_run` |
| The bonus | `Game.end_run` |

New state: `Game.mods` (an Array of IDs), added to `RUN_KEYS` so it saves.
UI: a toggle row on the monster pick screen, a line in the pause menu and on the death screen.

---

## 2. More rooms

Picked from the catalog because each fits the current engine with little new machinery,
and each asks the player a placement question. Sizes: **S** is mostly data, **M** adds one
new rule or unit, **L** needs new systems.

**Built (first batch):** Maze of Bones, Shrine of Desecration, Stitching Room, Scrying Pool,
Ogre Den. Changes from the table below:

- **Maze of Bones:** a winding layout isn't possible, because the furniture rules keep every doorway and the center cross open. Instead, a hero that walks in from outside loses its way and stops for the turn. At level 2 it can't attack that turn either.
- **Scrying Pool:** level 1 shows tomorrow's raiders and level 2 the night after too. Upcoming parties are rolled ahead of time (`Game.future`) and saved with the run.
- **Stitching Room:** works automatically at dawn, if you have the gold and the room has space.

### Common rooms (unlocked with souls)

| ID | Room | Souls | What it does | Size |
| --- | --- | --- | --- | --- |
| R16 | Maze of Bones | 30 | Internal walls of blocking furniture make heroes take the long way through. Level 2 adds a shortcut only your units can use. | S (level 1 is just a furniture layout) |
| R40 | Shrine of Desecration | 35 | Holy heroes inside lose their holy bonus and take 1 damage a turn. Clerics can't heal in here. Counters Paladin nights. | S |
| R29 | Stitching Room | 35 | At dawn, bring back one minion that died last night for half its cost. Level 2: two minions. | S |
| R32 | Scrying Pool | 40 | Shows the next two nights' raiders, not just tonight's. Level 2 also shows each hero's planned target on the map. | S |
| R23 | Ogre Den | 40 | Houses one ogre: 30 HP, move 2, hits for 6. Level 2 houses two. Ogres plug doorways. | M (new unit) |
| R22 | Kobold Warren | 30 | Cheap kobolds (5 gold, 4 HP). Once per fight, a kobold can lay a spike trap where it stands instead of attacking. | M (new unit action) |
| R13 | Spider Nest | 45 | Webbed tiles stop a hero the first time it steps in. Webs regrow every night. Level 2 adds a giant spider minion. | M |
| R36 | False Treasury | 40 | A decoy vault. Rogues and greedy heroes go for it first. Pair it with traps. | M (hero AI target) |
| R11 | Portcullis Gatehouse | 50 | Once per fight, slam one doorway shut for 2 turns. Level 2: slam it twice, and whoever stands under it takes damage. | M (room power, like Collapsing Hall) |
| R28 | Training Grounds | 55 | Minions that survive a night gain a rank: a name and +2 HP, +1 damage per rank, up to rank 3. | M |

Ten new common rooms takes the catalog from 25 to 35, plus 3 more from the duo below.

### Signature rooms for the existing monsters (later)

One new signature room each, from the catalog: R42 Soul Prison (Lich), R44 Feeding Gallery
(Vampire Lord), R47 Embalming Room (Necromancer), R51 Dream Chamber (Mind Flayer),
R53 Hoard of Fakes (Mimic). These are each M or L, so they come after the common rooms.

### Checklist per room

Each room needs: an entry in `Data.ROOMS` (name, color, costs, furniture, `unlock`), its
text in `Data.room_eff`, its rule in `battle.gd` or `game.gd`, new furniture sprites in
`sprites.gd` if it uses new pieces, and a line in `tests/sim.gd` `_check_layouts` (which
already checks that every room's furniture leaves every doorway connected).

---

## 3. New monster: the Dark Lord and Squire

Two weaker monsters played as one. Together they are about as tough as one monster, but
there are two of them. They can hold two doorways at once or split across floors, and
they are strongest when they stay together.

**Decided:** the **evil wizard is the Dark Lord** (the brains) and the **dark knight is his
Squire** (the sword arm).

**Built.** The Dark Lord is the run's monster unit (`Battle.mon`); the Squire is a second
unit of kind `"squire"` (`Battle.squire`). `Battle.is_mon()` treats both as monsters for the
lair's damage cut, boons, and losing the night. Spells belong to whoever casts them
(`Battle.caster_of`), so the 1 and 2 keys cast the selected member's spells. The Squire's HP is
`Game.shp`/`Game.smax`, and fallen members are in `Game.down` until bought back from the
"Fallen" panel by day. Doombolt ignores armor. A level 2 lair also gives the Squire +6 max HP.

### The two units

For comparison: the Lich has 28 HP and a 5-damage, range-3 attack plus two strong spells.
The Vampire Lord has 38 HP and an 8-damage claw.

**The Squire (dark knight): melee, protects and leads**

| | |
| --- | --- |
| HP | 24 |
| Move | 3 |
| Attack | Black Blade, 6 damage, range 1 |
| Armor | 1 (blocks 1 damage per hit, like a Knight) |

- **Challenge** (cooldown 3): heroes within 2 must attack the Squire on their next turn if they can reach him. This protects the Dark Lord.
- **Rally** (cooldown 4, free action): your minions within 3 get +1 move and +2 damage this turn.

**The Dark Lord (evil wizard): fragile caster, weaker than the Lich**

| | |
| --- | --- |
| HP | 18 |
| Move | 3 |
| Attack | Doombolt, 3 damage, range 3 (ignores armor, like the Lich) |

- **Hex** (cooldown 3): a hero within 4 deals 2 less damage and takes 2 more damage for 2 turns.
- **Dark Ward** (cooldown 3, free action): the Squire or a minion within 3 gets a shield that absorbs the next 6 damage.

That's 42 HP across two bodies (the Vampire Lord has 38 in one). Damage is lower than any
current monster's: the duo wins through Hex, Challenge and minions, not raw hits.

### Bond

While the two stand within 3 tiles of each other, both get +1 damage, and the Dark Lord's
spells recharge 1 turn faster. A thin line on the map shows when the bond is up. This is the
duo's main decision: stay together for power, or split up to cover two places.

### When one falls

**Decided:** a fallen partner can be bought back with this run's souls.

- If **one** of them dies, the other fights on alone for the rest of the night.
- At dawn you can **buy the fallen one back for souls equal to the current night number** (night 7 costs 7 souls). These are souls earned this run, so buying back lowers what the run banks when it ends. They return at full HP.
- If you can't afford it, or choose not to, the survivor carries on alone, and the offer comes back every dawn.
- If **both** are dead at the same time, the run ends. The death screen counts it as the Dark Lord's run.

### Signature rooms

| Room | Starter? | What it does |
| --- | --- | --- |
| **Dark Sanctum** | Starter | Doombolt and Hex deal +1 damage per level. Level 3: Hex also slows. |
| **Training Yard** | 35 souls | The Squire gets +4 max HP per level, and Challenge's range grows by 1 at level 2. |
| **Oath Stone** | 45 souls | The bond reaches 5 tiles instead of 3. Level 2: when one of them is hit while bonded, the other heals 1. |

### Boons

Boons that say "your monster" (Cruel Claws, Swift Shadow, Thick Hide, Blood Feast) apply to
**both** units. Arcane Surge and Dark Rituals only matter for the Dark Lord. No boon changes
are needed beyond that wording.

### Engine work (the large part)

The code assumes exactly one monster in about 38 places. What needs to change:

- **Battle:** `mon` becomes a list of monster units. The loss check becomes "every monster unit is dead", and all of the monster's code (spells, `atk_of`, lair damage reduction, holy damage) works per unit.
- **Game:** `mhp`/`mmax` become per-unit, added to `RUN_KEYS`. `monster_start()` gives the Squire a second tile next to the throne. The Velvet Coffin and lair upgrades raise both units' HP.
- **Data:** a monster entry can list `units`, each with its own stats and `specials`. Existing monsters keep working as a one-unit list.
- **Night HUD:** the unit card already follows the selected unit; the spell keys become 1–2 for whichever monster unit is selected.
- **Sprites:** two new monster sprites, plus the bond line.
- **Title screen, monster pick, catalog, death screen:** show both portraits, a "Duo" role tag, and the new rooms.
- **Tests:** add `"darklord"` to the sim's monster list, and a check that losing one unit doesn't end the night.

Do the "monster becomes a list" refactor first, as its own change, with every existing
monster still passing the sim. Then add the duo on top.

---

## Open questions

1. Should Dread modifiers have a cap or a few preset tiers instead of free picks?
2. Which rooms ship first? Suggested first batch: R16 Maze of Bones, R40 Shrine of Desecration, R29 Stitching Room, R32 Scrying Pool, R23 Ogre Den. All five are S, except the Ogre Den (M).
