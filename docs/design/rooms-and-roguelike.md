# Rooms and roguelike structure: idea catalog

Status: brainstorm. Nothing in this file is implemented. Every idea has an ID so we can
cut it down quickly ("keep R03, R11, R27; cut the rest of section B").

Each room lists what it does, what upgrading it adds, its furniture, and the decision it
asks the player to make. A room that does not create a decision about *where* it goes or
*what you build next* is a weak room; those are marked **weak** so they are easy to cut.

For reference, the 25 rooms already in the game:

- **Common (10):** Your Lair, Treasury, Larder, Goblin Barracks, Hellhound Kennel, Trap Workshop, Armory, Flooded Cistern, Torture Chamber, Collapsing Hall.
- **Signature (15):** Arcane Library, Mana Well, Phylactery Vault (Lich); Crypt of Brides, Blood Pool, Velvet Coffin (Vampire Lord); Graveyard, Bone Forge, Soul Cage (Necromancer); Thrall Pens, Brain Jar Gallery, Psionic Amplifier (Mind Flayer); Clockwork Forge, Snare Den, Rune Chamber (Mimic).

---

## Part 1: New rooms

### A. Economy and management

**R01 Mine Shaft.** Gold every dawn based on how deep it is: rooms in the bottom row pay double. Upgrades raise the payout. Furniture: ore carts, support beams (block). *Decision:* the best mine spot is far from the entrance, which is also the best spot for your lair.

**R02 Black Market.** Each dawn a goblin fence offers 3 random items (one-use battle consumables, a minion at a discount, a rare blueprint). Upgrades add a 4th slot and a reroll. Furniture: stalls, crates. *Decision:* spend gold now on a sure thing or save it for rooms.

**R03 Ransom Cells.** Heroes knocked below 20% HP in this room surrender instead of dying. At dawn you ransom them for 3x their gold, or break them into a free thrall. Upgrades add cells. Furniture: cell bars (block), shackles. *Decision:* fight heroes in a specific room rather than wherever is convenient.

**R04 Counting House.** +10% interest on your gold at each dawn, capped by level. Furniture: ledgers, scales. *Decision:* hoarding versus spending. **Weak**: no placement decision.

**R05 Gambling Den.** Once per day, wager gold on an imp dice game: lose it, double it, or win a boon. Upgrades let you load the dice. *Decision:* risk appetite. **Weak** but fun flavor.

**R06 Mushroom Farm.** Feeds minions. Introduces upkeep: each minion past the first three costs 2 gold per dawn unless fed. Upgrades feed more. Furniture: fungus beds (flat), glowing caps. *Decision:* only worth it if we add minion upkeep, which also nerfs minion spam.

**R07 Smuggler's Tunnel.** A second, secret door on the map edge that only your side can use. Minions posted here flank heroes from behind. Upgrades let fleeing rogues be ambushed in it. *Decision:* where the second door goes changes every fight.

**R08 Trophy Hall.** Mounts the gear of every hero type you have killed. Each new type adds a small permanent run bonus (first knight: +1 armor for your lair minions, and so on). Furniture: armor stands, mounted heads. *Decision:* hunt for variety. **Weak** placement decision, strong run goal.

### B. Terrain and battlefield control

**R09 Chasm Bridge.** A pit splits the room; a 1-wide bridge crosses it. Any unit pushed into the pit dies (bosses climb out at half HP). Adds a **shove** action to your monster and bruiser minions. Furniture: the chasm (impassable), broken railings. *Decision:* where to make the heroes cross.

**R10 Dark Hall.** No light. Heroes in this room can only see and target 1 tile away; your units are unaffected. Clerics and mages light it up for a turn. *Decision:* a safe zone for your ranged attackers.

**R11 Portcullis Gatehouse.** Once per fight, slam one of its doorways shut for 2 turns. Upgrades: 2 slams, crush damage on whoever stands under it. Furniture: winch, chains. *Decision:* split the hero party in half at the right moment.

**R12 Lava Forge.** A strip of lava tiles burns anything standing on them each turn. Heroes avoid it unless shoved or lured. Upgrades widen the strip. *Decision:* combo room for the Mimic's Lure and the Chasm's shove.

**R13 Spider Nest.** Webbed floor: the first time a hero enters a webbed tile it stops moving. Spiders respawn webs each night. Upgrades add a giant spider minion. *Decision:* a slower, softer cousin of snares that refreshes for free.

**R14 Hall of Mirrors.** Arrows and spells fired into or out of this room have a 50% chance to hit the wrong target. Mirrors shatter when hit (they come back at dawn). *Decision:* hard counter to archers and mages, but it hurts your Lich too.

**R15 Fungal Grotto.** Spore clouds: heroes who end their turn here have a 33% chance to be confused next turn. Upgrades raise the chance. *Decision:* a cheaper, random Mind Flayer effect for everyone.

**R16 Maze of Bones.** Internal walls turn the room into a winding corridor, so crossing it takes 3x as many steps. Upgrades add a hidden shortcut only your side knows. *Decision:* place it between the entrance and the lair to buy turns.

**R17 Rolling Boulder Run.** Once per fight, release a boulder that rolls the full length of the room in one direction, hitting everything in its row. Upgrades: reset each night, then twice per fight. *Decision:* line heroes up.

**R18 Murder Holes.** Wall slits overlooking a neighboring room. Archers posted here shoot into that room and cannot be reached in melee. Upgrades add slits. *Decision:* which neighbor gets covered.

**R19 Barricade Works.** Lets you build destructible barricades anywhere (wall tiles with HP that heroes must chop through). Upgrades add HP and spikes. *Decision:* temporary walls that reshape paths each night.

**R20 Teleport Circles.** Build two linked circles anywhere in your dungeon. Your units can step from one to the other. Upgrades let you yank a hero through once per fight. *Decision:* lets you put your lair far away without abandoning the front line.

**R21 Flooded Sluice.** A lever floods the room for 2 turns, turning it into a Cistern and dousing torches and fire. Can drown snared heroes. *Decision:* timing, not placement.

### C. Minion rooms

**R22 Kobold Warren.** Cheap kobolds (5 gold, 4 HP) that, instead of attacking, can lay a spike trap where they stand once per fight. *Decision:* traps that move with the battle.

**R23 Ogre Den.** One ogre: 30 HP, slow, hits hard and can shove. Upgrades add a second ogre. *Decision:* a doorway plug.

**R24 Imp Hatchery.** Flying imps: ranged firebolts, ignore furniture when moving. Fragile. *Decision:* ranged minion option for monsters without one.

**R25 Troll Pool.** A troll that regenerates 4 HP a turn unless hit by fire (mages, braziers). *Decision:* strong unless a Battle Mage shows up.

**R26 Slime Pit.** Slimes split into two smaller slimes when killed, twice. *Decision:* clogs corridors; great with the Mimic's lure.

**R27 Gargoyle Roost.** Gargoyles that turn to stone (immune to damage) on any turn they do not move or attack. Posted on doorways, they are walls with teeth. *Decision:* positional puzzle for both sides.

**R28 Training Grounds.** Minions that survive a night earn a rank. Ranked minions keep a name, gain stats, and stay ranked until they die. Upgrades raise the rank cap. *Decision:* protect your veterans instead of throwing them away. Strong attachment hook.

**R29 Stitching Room.** At dawn, revive one minion that died last night for half its cost. Upgrades: two revives, revived minions return with a stitched-on bonus. *Decision:* soft safety net for the "dead minions stay dead" rule.

**R30 War Drum Hall.** While its drummer goblin lives, every minion gets +1 move. Heroes target the drummer first. *Decision:* where to hide the drummer.

**R31 Bat Colony.** Bats scout the road: you see the next night's party a day early and which heroes carry elite traits. Upgrades reveal the party's planned target. *Decision:* information for planning. **Weak** placement decision.

### D. Monster support and specials

**R32 Scrying Pool.** Shows the next two nights' raiders, their traits and the route they will take. Once per fight, peek at what every hero will do next turn (Into the Breach style telegraphs). *Decision:* information versus power.

**R33 Ritual Chamber.** Spend hours during the day performing rituals for a one-night buff (Blood Moon: +3 damage; Eclipse: heroes start slowed; Hex: one random hero starts cursed). *Decision:* hours on building versus hours on rituals.

**R34 Alchemist's Lab.** Brews one potion per dawn (healing, haste, fire flask). Potions are used in battle by any of your units as their action. Upgrades add potion types and slots. *Decision:* consumables add tactical variety each night.

**R35 Curse Forge.** Crafts cursed treasure to leave in the Treasury. Rogues who steal it are cursed and their whole party is weakened. *Decision:* turns the rogue threat into bait.

**R36 False Treasury.** A decoy vault that heroes and rogues mistake for the real one. Looks identical by day. *Decision:* combine with traps for a classic dungeon ambush.

**R37 Interrogation Room.** One captured hero per night (from Ransom Cells or Dominate) can be interrogated for intel: reveals the next boss's weakness, or unlocks a blueprint. *Decision:* pairs with R03.

**R38 Alarm Bell Tower.** When the first hero crosses into a room you mark, every minion gets a free move before the heroes' turn. *Decision:* tripwire placement.

**R39 Banner of Infamy.** Raises your infamy: bigger, stronger parties, but +50% gold and souls. Upgrades raise it further. Can be torn down to cool off. *Decision:* a manual difficulty dial with real rewards.

**R40 Shrine of Desecration.** Holy heroes who enter lose their holy bonus and take 1 damage per turn. Clerics cannot heal inside. *Decision:* hard counter to Paladin nights; matters most for the Vampire and Lich.

### E. New signature rooms (3 per monster)

**Lich**
- **R41 Astral Observatory.** Spells gain +1 range, and Chain Lightning arcs one extra time.
- **R42 Soul Prison.** Every hero killed by a spell reduces all your cooldowns by 1.
- **R43 Frozen Vault.** The whole room is permanently frozen: heroes inside are slowed, and your Frost Nova cast from inside reaches the entire room.

**Vampire Lord**
- **R44 Feeding Gallery.** Captive villagers. Before each fight, drink one to start the night overhealed (+10 temporary HP). Upgrades add captives.
- **R45 Masquerade Ballroom.** Heroes who enter must pass a check or be charmed (they skip attacking you) for 1 turn. Your spawn fight better here.
- **R46 Bat Belfry.** Bat Form range +3, and it leaves a swarm on your old tile that blocks and nibbles.

**Necromancer**
- **R47 Embalming Room.** Up to 3 corpses carry over between nights, so Raise Fallen has targets from the first turn.
- **R48 Plague Pit.** Heroes who enter are diseased: they take 1 damage per turn for the rest of the fight and spread it to adjacent heroes.
- **R49 Mausoleum.** Holds one Bone Golem built from 5 corpses collected across nights. It is a permanent, very large minion.

**Mind Flayer**
- **R50 Elder Brain Pool.** Spawns an Intellect Devourer each night: a small minion that, if it kills a hero, takes over the body as a thrall.
- **R51 Dream Chamber.** The first 2 heroes through the gate each night start asleep (they wake when hurt or after 2 turns).
- **R52 Memory Gallery.** When you Dominate a hero, you also learn its trick for the rest of the run (a Cleric's heal, an Archer's range) and can use it once per fight.

**Mimic**
- **R53 Hoard of Fakes.** Places 3 decoy chests in the dungeon. Heroes rush the nearest "treasure"; decoys snap shut for damage when opened.
- **R54 Pressure-Plate Gallery.** Traps in this room are linked: springing one springs them all.
- **R55 Gearworks.** Lets you rotate one room 90 degrees between nights, moving its doorways and furniture. Upgrades: a second rotation, or swap two rooms.

---

## Part 2: Roguelike structure

The current game has one run-level layer (pick a boon after each night) and one meta layer
(souls buy starting gold). That is thin. Below is a fuller structure, split into what
changes *within* a run and what carries *between* runs. Runs are endless: they end when
your monster dies or you retire, and the lair keeps growing upward (Part 3).

### F. The shape of a run

**S01 Endless runs that grow upward.** *(Replaces the earlier "15 nights and you win" idea.)* A run never ends on its own; it ends when you die or retire. What keeps it moving is height: every few nights you can build a new floor on top, and each floor brings new rooms, richer rewards and tougher heroes. Full design in **Part 3** below.

**S02 Boss nights every 5 nights.** The pacing beat of an endless run. Each boss night ends with a pick of 1 of 3 **Dark Relics** (see H) and unlocks the next floor's dig. Bosses rotate and escalate: Paladin, then the Archmage Council (three mages that combine spells), then the Chosen One (levels up mid-fight), then they repeat with stacking traits.

**S03 Hero party traits.** From act 2, some heroes arrive with traits shown in the party preview: Torchbearer (lights Dark Halls), Veteran (+1 move), Blessed (immune to the first hit), Looter (goes for the Treasury), Sapper's Apprentice (disarms in a 2-tile radius). You plan around the party you see coming.

**S04 Dawn events.** Some mornings bring an event with a choice: a deserter knight asks to join your minions; a rival monster offers a deal; a cave-in seals a room for a day; the village sends tribute or an ultimatum. Keeps days from feeling identical.

**S05 Omens at run start.** Before night 1, pick 1 of 3 omens that bend the run: Blood Moon (heroes and minions both hit harder), Famine (no Larder healing, +50% gold), Crusade (more holy heroes, more souls). Easy replayability.

### G. Room drafting (my strongest recommendation)

**S06 Blueprint draft.** Instead of every room being available, you start each run knowing only your Lair, an empty chamber and 3 random common blueprints. Each dawn you are offered 3 new blueprints and keep 1. Signature rooms show up more often for your monster. This is what makes each run's dungeon different, and it is the most roguelike change on the list.

**S07 Blueprint rarity.** Common, rare and legendary rooms. Legendary rooms (Chasm Bridge, Teleport Circles, Gearworks) only appear after act 1.

**S08 Room synergies.** Some pairs of adjacent rooms unlock a bonus, shown when you hover: Torture Chamber next to Ransom Cells breaks prisoners faster; Lava Forge next to Flooded Sluice makes steam clouds; Library next to Observatory adds a spell slot. Rewards thinking about layout, not just picking rooms.

### H. In-run rewards

**S09 Boon rarity and tiers.** Keep the after-night boon pick, but give boons rarity. Rare boons change rules ("Your traps re-arm once per fight"). Legendary boons define a build ("Every minion death heals you 5").

**S10 Pacts.** Some boons are pacts with a cost: "+50% spell damage, but the Larder no longer heals you"; "Minions cost half, but heroes gain +1 armor." Players love deals with the devil.

**S11 Dark Relics.** Rare items from boss nights and dawn events. Each has a unique effect and there is no cap, so a run's relic pile becomes its identity. Examples: Cracked Crown (+1 hour per day), Bleeding Idol (every kill drips 1 HP to your monster), Jar of Screams (start each fight with Psychic Scream ready, for any monster), Lockpick of the Damned (rogues who rob you drop double when killed).

**S12 Hero loot drops.** Elite heroes can drop gear that you equip on your monster (one weapon, one charm slot). Simple, visible power curve within a run.

### I. Meta progression (between runs)

The rule I would hold to: **meta unlocks add options, they rarely add raw power.** A new
run should feel different, not just easier.

**M01 Blueprint unlocks.** New rooms enter the draft pool as you unlock them. Early runs use a small, readable set; later runs get Chasm Bridges and Gearworks. Unlock by spending souls or by milestones ("kill 10 Rogues to unlock the Curse Forge").

**M02 Monster mastery.** Each monster levels up separately as you play it. Mastery unlocks an alternate spell to swap in (Lich: Bone Wall instead of Frost Nova), an alternate starting room, and a cosmetic skin at max level. Gives a reason to replay each monster.

**M03 Heirlooms.** Starting items you unlock and pick one of at run start: an extra starting blueprint, 2 veteran goblins, a free Trap Workshop, +1 hour on day 1. Replaces the current "bury treasure" gold perk with choices.

**M04 Dread levels.** After your first win, unlock Dread 1 to 10 (Hades heat / Slay the Spire ascension style). Each level adds a hero modifier: heroes +10% HP, elites from night 1, two bosses at act 3, and so on. This is the long-tail endgame.

**M05 Bestiary and Hero Codex.** Every hero type you meet gets an entry with its stats and tricks; fill it out by killing them in different ways. Cheap to build, satisfying to complete, and it teaches the game.

**M06 The Abyss (meta hub).** A between-runs screen that is itself a tiny lair. Spending souls physically builds it out (a statue for each mastery, a shelf of relics you have found). Visible progress, and a good Steam screenshot.

**M07 Small permanent stats.** A short list of capped, cheap upgrades (+5 max HP, +10 starting gold, +1 trap slot), mainly so early failed runs still feel rewarding. Keep this list short so it does not replace skill.

---

## Part 3: Floors and the Stairs room (the lair grows upward)

The run is endless, and the lair grows **up** into a tower. Heroes always break in on the
ground floor and have to climb to reach you. This section is the core of the late game.

**Implemented:** D01-D04 (merged in PR #1, flipped to grow upward on
`feature/map-hud-unlocks-tower`). Differences from the text below: rooms can be built once
*per floor* (bonuses use the highest level, recruit rooms add up); the Stairs Up room's level 2
is the Spiral Stair and level 3 adds "bring down the stairs" (the Lift is not built yet); the
lair can move to another floor for 3 hours. Not built yet: D05 onward.

### How floors work

**D01 Each floor is its own map.** The ground floor is the original grid (5x4 room slots of 5x5 tiles), dug out of rock. Each new floor above starts as open air with one chamber where the stairs arrive, and you build it out room by room. A tab strip on the map (Ground floor, Floor 2, ...) switches which floor you are looking at, by day and by night.

**D02 The Stairs Up room.** A special room, at most one per floor, that connects that floor to the next one up. Building it costs gold and hours, and you can only build it after a boss night (so a new floor opens every 5 nights at most). The stairs arrive on the floor above **in the same slot position**, so where you put your stairs decides where the next floor starts.

Stairs upgrades:
- **Spiral Stair:** heroes who climb it stop at the top for the rest of their turn. A chokepoint between floors.
- **Collapsible Stair:** once per fight, bring down every staircase for 2 turns. Heroes are stuck on their floor; anyone on the stairs takes heavy damage.
- **Lift** (not built yet): your units can move between two floors in one step, so one monster can defend several floors.

**D03 Where your lair goes.** Your Lair can be on any floor. High up is safer, because heroes must fight through every floor below it, but those floors are held mostly by minions and traps while you wait. Low lets your monster fight from the first turn. Moving the lair between floors costs a full day of hours.

**D04 Heroes climb.** Heroes come in through the gate on the ground floor and take the stairs up when that is their shortest way to you. A fight spans every floor the heroes reach. All floors take their turns together, and the camera jumps to whichever floor is acting. Rogues who rob a Treasury high in the tower have a long way to run back down, which makes high Treasuries safer.

**D05 Siege ladders.** From floor 3 onward, some nights a party skips the gate and scales the outside of the tower, breaking into an upper floor through an outer wall. The ladder point is shown on the morning scouting report, so you can fortify that room. This stops "just make the ground floor a death maze" from solving every night.

### What higher floors give you

**D06 Floor themes.** Each new floor rolls a theme. A theme changes the rules for that floor and unlocks blueprints that can only be built there:
- **Battlements:** arrow slits along the outer walls; your ranged units get +1 range. Blueprints: Murder Holes, Ballista Nest.
- **Belfry:** bats and bells; clerics cannot heal heroes on other floors. Blueprints: Bat Colony, Alarm Bell Tower.
- **Storm Gallery:** lightning strikes a random open tile each round. Blueprints: Lightning Rod, Wind Chamber.
- **Crystal Spire:** crystals amplify spells but reflect arrows. Blueprints: Hall of Mirrors, Astral Observatory.
- **Ruined Observatory:** comes with one pre-built ruin room holding a relic, guarded by a dormant golem you can wake and keep.

**D07 Height pays more.** Heroes killed on a higher floor drop more gold and souls (+25% per floor above the ground). This rewards drawing heroes up instead of killing them at the door.

**D08 More floors, more upkeep.** You get +1 hour per day for each floor you own, but every floor's minions and traps need looking after: traps sprung on a floor stay sprung until you spend an hour there, and minions on a floor with no Larder or Mushroom Farm slowly lose HP. This keeps a five-floor tower from running itself.

### What keeps an endless run tense

**D09 Infamy keeps rising.** Party size, hero stats and elite traits keep scaling with nights survived and with how many floors you have. There is no ceiling, so every run eventually ends. The question is how high you get.

**D10 Retire on your terms.** Once you have 3 or more floors, you can retire the lair at dawn: the run ends and you bank a large souls bonus based on height and nights. Dying banks less.

**D11 Records.** Each run records nights survived, highest floor and heroes slain, per monster. These feed Steam leaderboards; a "tallest tower" leaderboard fits the theme.

---

## Part 4: Room catalog: what you start with and what you unlock

**Implemented on `feature/map-hud-unlocks-tower`.** A run only offers starter rooms plus the
blueprints you have bought. Blueprints are bought with souls on the monster-select screen and
stay unlocked for every future run. The costs live in `scripts/data.gd` (the `unlock` field).

### Starter rooms (every run)

| Room | Notes |
| --- | --- |
| Your Lair | Fixed. One per dungeon. |
| Stairs Up | Opens new floors after boss nights. |
| Treasury, Larder, Goblin Barracks, Trap Workshop | The four basics: gold, healing, a cheap minion, traps. |
| One signature room per monster | Lich: Arcane Library. Vampire Lord: Crypt of Brides. Necromancer: Graveyard. Mind Flayer: Thrall Pens. Mimic: Snare Den. |

### Unlockable now (built and in the game)

| Room | Souls | For |
| --- | --- | --- |
| Armory | 25 | Everyone |
| Flooded Cistern | 25 | Everyone |
| Hellhound Kennel | 30 | Everyone |
| Torture Chamber | 35 | Everyone |
| Collapsing Hall | 40 | Everyone |
| Velvet Coffin | 30 | Vampire Lord |
| Blood Pool | 35 | Vampire Lord |
| Brain Jar Gallery | 35 | Mind Flayer |
| Clockwork Forge | 35 | Mimic |
| Mana Well | 40 | Lich |
| Bone Forge | 40 | Necromancer |
| Soul Cage | 45 | Necromancer |
| Rune Chamber | 45 | Mimic |
| Psionic Amplifier | 50 | Mind Flayer |
| Phylactery Vault | 55 | Lich |

A run earns roughly 20-40 souls, so a new player unlocks about one room per run early on.

### Planned unlocks (from Part 1, not built yet)

Suggested tiers, so early unlocks are simple and late ones change how you play:

- **Tier 1, cheap (20-40 souls):** R13 Spider Nest, R22 Kobold Warren, R23 Ogre Den, R29 Stitching Room, R36 False Treasury.
- **Tier 2 (40-70 souls):** R03 Ransom Cells, R10 Dark Hall, R11 Portcullis Gatehouse, R16 Maze of Bones, R28 Training Grounds, R32 Scrying Pool, R40 Shrine of Desecration.
- **Tier 3, milestones instead of souls:** R09 Chasm Bridge (kill 20 heroes with falls or traps), R20 Teleport Circles (reach floor 3), R55 Gearworks (win 5 nights as the Mimic).
- **Signature rooms R41-R55:** unlocked through each monster's mastery levels (M02) rather than souls.
- **Floor-theme rooms (D06):** never unlocked globally; they only appear on a floor with the matching theme.

---

## My suggested shortlist

If we want a strong first pass without overbuilding:

- **Rooms:** R03 Ransom Cells, R09 Chasm Bridge, R10 Dark Hall, R11 Portcullis Gatehouse, R13 Spider Nest, R16 Maze of Bones, R20 Teleport Circles, R22 Kobold Warren, R23 Ogre Den, R28 Training Grounds, R29 Stitching Room, R32 Scrying Pool, R36 False Treasury, R40 Shrine of Desecration, plus one new signature room per monster (R42, R44, R47, R51, R53).
- **Run structure:** S01 endless runs, S02 boss nights every 5, S03 hero traits, S06 blueprint draft, S09 boon rarity, S11 relics.
- **Floors:** D01 floor maps, D02 Stairs Up room, D03 lair on any floor, D04 heroes climb, D06 floor themes, D07 height pays more, D10 retire.
- **Meta:** M01 blueprint unlocks, M02 monster mastery, M03 heirlooms, M04 dread levels.

Build order I would suggest: floors and the Stairs room first (D01–D04), because they
change the map, the camera and the battle loop. Then blueprint drafting (S06), then boss
nights and relics (S02, S11). Biomes, breaches and upkeep come after the core loop is fun.
