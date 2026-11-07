class_name Data
extends RefCounted
## Static game content: monsters, units, rooms, furniture, traps and boons.
## Colors are hex strings; turn them into Colors with Data.col().

const MONSTERS := {
	"lich": {"name": "The Lich", "role": "Arcane caster", "col": "#9b84ff", "hp": 28, "move": 3, "atk": 5, "rng": 3, "attack": "Bone Lance",
		"blurb": "Fragile, but every room it builds sharpens its spells. Spells ignore armor.",
		"specials": [
			{"id": "nova", "name": "Frost Nova", "cd": 3, "kind": "self", "desc": "Heroes within 2 tiles take 4 spell damage and are slowed."},
			{"id": "chain", "name": "Chain Lightning", "cd": 3, "kind": "enemy", "range": 4, "desc": "Hit a hero within 4 for 6 spell damage. It arcs to 2 more nearby heroes."}]},
	"vampire": {"name": "The Vampire Lord", "role": "Powerhouse", "col": "#e0405a", "hp": 38, "move": 3, "atk": 8, "rng": 1, "attack": "Claw",
		"blurb": "Drinks a third of the damage it deals. Holy heroes burn it.",
		"specials": [
			{"id": "bats", "name": "Bat Form", "cd": 3, "kind": "tile", "range": 5, "free": true, "desc": "Fly to an empty tile within 5, even past walls. You can still attack afterward."},
			{"id": "mesmer", "name": "Mesmerize", "cd": 3, "kind": "enemy", "range": 3, "desc": "A hero within 3 loses its next turn."}]},
	"necro": {"name": "The Necromancer", "role": "Summoner", "col": "#6fd3a0", "hp": 24, "move": 3, "atk": 4, "rng": 2, "attack": "Death Bolt",
		"blurb": "Weak alone. Fills the halls with the dead, then makes them stronger.",
		"specials": [
			{"id": "raise", "name": "Raise Dead", "cd": 2, "kind": "adj", "desc": "Summon a skeleton next to you for this fight."},
			{"id": "ghoul", "name": "Raise Fallen", "cd": 3, "kind": "corpse", "range": 4, "desc": "Turn a dead hero's corpse within 4 into a ghoul for this fight."}]},
	"flayer": {"name": "The Mind Flayer", "role": "Trickster", "col": "#c77dff", "hp": 28, "move": 3, "atk": 5, "rng": 2, "attack": "Psychic Lash",
		"blurb": "Turns heroes against each other, and against themselves.",
		"specials": [
			{"id": "dominate", "name": "Dominate", "cd": 4, "kind": "enemy", "range": 3, "desc": "A hero within 3 becomes your thrall for the rest of the fight. Not bosses."},
			{"id": "scream", "name": "Psychic Scream", "cd": 3, "kind": "area", "range": 4, "desc": "Heroes in a 3x3 area take 2 damage and attack each other next turn."}]},
	"mimic": {"name": "The Mimic", "role": "Trapmaster", "col": "#e4a648", "hp": 36, "move": 2, "atk": 7, "rng": 1, "armor": 1, "attack": "Chomp",
		"blurb": "Looks like treasure, so heroes rush it. Builds traps without a workshop, at half price. Iron bands block 1 damage.",
		"specials": [
			{"id": "lure", "name": "Glittering Lure", "cd": 3, "kind": "tile", "range": 7, "any": true, "desc": "Pick a tile. Every hero is dragged 2 steps toward it, over your traps."},
			{"id": "snap", "name": "Snap Trap", "cd": 2, "kind": "tile", "range": 4, "notrap": true, "desc": "Place a permanent spike trap on an empty tile within 4."}]},
	# a duo: the Dark Lord is the run's monster; his Squire fights beside him as a second unit
	"darklord": {"name": "The Dark Lord", "role": "Duo", "col": "#7d8cff", "hp": 18, "move": 3, "atk": 3, "rng": 3, "attack": "Doombolt",
		"blurb": "A frail wizard and his armored Squire, played as two units. Stronger side by side. Doombolt ignores armor.",
		"specials": [
			{"id": "hex", "name": "Hex", "cd": 3, "kind": "enemy", "range": 4, "desc": "A hero within 4 deals 2 less damage and takes 2 more for 2 turns."},
			{"id": "ward", "name": "Dark Ward", "cd": 3, "kind": "ally", "range": 3, "free": true, "desc": "The Squire or a minion within 3 gets a shield that soaks the next 6 damage."}],
		"partner": {"name": "The Squire", "col": "#a8aec8", "hp": 24, "move": 3, "atk": 6, "rng": 1, "armor": 1, "attack": "Black Blade",
			"specials": [
				{"id": "challenge", "name": "Challenge", "cd": 3, "kind": "self", "range": 2, "desc": "Heroes within 2 must come at the Squire on their next turn."},
				{"id": "rally", "name": "Rally", "cd": 4, "kind": "self", "range": 3, "free": true, "desc": "Your minions within 3 get +1 move and +2 damage this turn."}]}},
}

const UNITS := {
	"goblin": {"name": "Goblin", "hp": 8, "move": 3, "atk": 3, "rng": 1, "cost": 12},
	"hound": {"name": "Hellhound", "hp": 11, "move": 5, "atk": 4, "rng": 1, "cost": 20},
	"spawn": {"name": "Vampire Spawn", "hp": 10, "move": 4, "atk": 4, "rng": 1, "leech": true, "undead": true, "cost": 24},
	"skeleton": {"name": "Skeleton", "hp": 6, "move": 2, "atk": 3, "rng": 1, "undead": true, "cost": 6},
	"ogre": {"name": "Ogre", "hp": 30, "move": 2, "atk": 6, "rng": 1, "cost": 32},
	"thrall": {"name": "Thrall", "hp": 10, "move": 3, "atk": 3, "rng": 1, "cost": 14},
	"shaman": {"name": "Goblin Shaman", "hp": 7, "move": 3, "atk": 2, "rng": 3, "cost": 24,
		"note": "Heals your units within 2 tiles at the start of each of your turns."},
	"warlock": {"name": "Warlock", "hp": 6, "move": 3, "atk": 3, "rng": 3, "cost": 28, "magic": true,
		"note": "A lesser dark wizard. Its eldritch bolts ignore armor."},
	"ghoul": {"name": "Ghoul", "hp": 11, "move": 3, "atk": 4, "rng": 1, "undead": true},
	"peasant": {"name": "Peasant", "hp": 9, "move": 3, "atk": 2, "rng": 1, "gold": 6, "col": "#a8794e"},
	"rogue": {"name": "Rogue", "hp": 10, "move": 4, "atk": 3, "rng": 1, "gold": 10, "col": "#7b5aac", "sense": true, "thief": true, "note": "Spots traps. Robs your Treasury and runs for the exit."},
	"archer": {"name": "Archer", "hp": 9, "move": 3, "atk": 3, "rng": 4, "gold": 10, "col": "#6e9a5a", "note": "Shoots 4 tiles. Walls and furniture block arrows."},
	"knight": {"name": "Knight", "hp": 18, "move": 2, "atk": 4, "rng": 1, "armor": 1, "gold": 14, "col": "#b9c3cd", "note": "Armor blocks 1 damage per hit."},
	"cleric": {"name": "Cleric", "hp": 12, "move": 3, "atk": 2, "rng": 1, "heal": 5, "holy": true, "gold": 12, "col": "#efe6cf", "note": "Heals heroes within 3. Holy: +3 damage to undead and vampires."},
	"sapper": {"name": "Dwarf Sapper", "hp": 13, "move": 3, "atk": 3, "rng": 1, "armor": 1, "sense": true, "disarm": true, "gold": 13, "col": "#b0703a", "note": "Spends its whole turn dismantling a trap next to it. Permanently."},
	"mage": {"name": "Battle Mage", "hp": 10, "move": 3, "atk": 4, "rng": 3, "splash": true, "gold": 15, "col": "#4f7fd8", "note": "Fireballs also hit everything next to the target."},
	"barbarian": {"name": "Barbarian", "hp": 24, "move": 3, "atk": 6, "rng": 1, "gold": 16, "col": "#c0603a", "note": "Huge HP, huge hits."},
	"paladin": {"name": "Paladin", "hp": 36, "move": 2, "atk": 6, "rng": 1, "armor": 2, "holy": true, "gold": 60, "col": "#e3b23f", "boss": true, "note": "Boss. Armor blocks 2. Holy."},
}

const NAMES := {
	"peasant": ["Hob", "Wat", "Gilly", "Tam", "Ned", "Mags", "Old Bram"],
	"rogue": ["Vex", "Silk", "Nim", "Shade", "Corvin"],
	"archer": ["Fletch", "Robyn", "Aster", "Quill"],
	"knight": ["Sir Aldric", "Sir Bertram", "Dame Iselde", "Sir Godric"],
	"cleric": ["Brother Tobin", "Sister Maud", "Father Anselm"],
	"sapper": ["Durgin", "Brokk", "Hilda Stonefist"],
	"mage": ["Ilsabet", "Marrow the Bright", "Thessaly"],
	"barbarian": ["Grom", "Ulfrik", "Big Hedda"],
	"paladin": ["Lord Valerian", "Saint Odile", "High Paladin Cassius"],
}

# Rooms with "unlock" are blueprints bought with souls between runs; the rest are open from the
# first run: the Lair, Stairs Up, the four basics and one signature room per monster.
# Furniture is [x, y, kind, blocks] in room-local tiles. Blocking pieces only sit on the four
# corners or the four inner diagonals, never on a doorway or the center cross, so every door connects.
const ROOMS := {
	"lair": {"name": "Your Lair", "col": "#c0304c", "fixed": true, "cost": [0, 40, 70, 100], "next": "+6 max HP",
		"objs": [[1, 1, "pillar", 1], [3, 1, "pillar", 1], [1, 3, "pillar", 1], [3, 3, "pillar", 1], [2, 1, "throne"], [2, 2, "rug"], [2, 3, "rug"], [0, 0, "brazier", 1], [4, 0, "brazier", 1]]},
	"stairs": {"name": "Stairs Up", "col": "#c8b48a", "cost": [60, 45, 70],
		"objs": [[2, 2, "stairs_up"], [1, 1, "brazier", 1], [3, 3, "brazier", 1]]},
	"treasury": {"name": "Treasury", "col": "#e4a648", "cost": [25, 40, 60],
		"objs": [[0, 0, "chest", 1], [4, 0, "chest", 1], [3, 1, "chest", 1], [0, 4, "coins"], [4, 4, "coins"], [1, 1, "coins"], [3, 3, "coins"]]},
	"larder": {"name": "Larder", "col": "#d08a5a", "cost": [20, 35, 50],
		"objs": [[1, 1, "table", 1], [3, 1, "table", 1], [0, 4, "barrel", 1], [4, 4, "barrel", 1], [0, 0, "meat"], [4, 0, "meat"], [1, 3, "meat"]]},
	"barracks": {"name": "Goblin Barracks", "col": "#86b35e", "cost": [25, 40, 60], "recruit": "goblin", "cap": 2,
		"objs": [[0, 0, "bunk", 1], [4, 0, "bunk", 1], [1, 1, "bunk", 1], [3, 1, "bunk", 1], [2, 2, "fire"], [0, 4, "rack", 1], [4, 4, "rack", 1]]},
	"kennel": {"unlock": 30, "name": "Hellhound Kennel", "col": "#d9573f", "cost": [40, 65], "recruit": "hound", "cap": 1,
		"objs": [[0, 0, "cage", 1], [4, 0, "cage", 1], [0, 4, "cage", 1], [4, 4, "cage", 1], [1, 1, "bones"], [3, 3, "bones"], [3, 1, "bones"]]},
	"lodge": {"unlock": 30, "name": "Spirit Lodge", "col": "#b8c85a", "cost": [30, 50, 75], "recruit": "shaman", "cap": 1,
		"objs": [[2, 2, "fire"], [0, 0, "brazier", 1], [4, 0, "brazier", 1], [4, 4, "jar", 1], [1, 1, "bones"], [3, 3, "bones"], [1, 3, "candles"]]},
	"coven": {"name": "Warlock Coven", "col": "#9a4fd0", "cost": [35, 55, 80], "recruit": "warlock", "cap": 1,
		"objs": [[2, 2, "runecircle"], [0, 0, "brazier", 1], [4, 0, "jar", 1], [0, 4, "shelf", 1], [4, 4, "brazier", 1], [3, 3, "candles"], [1, 1, "blood"]]},
	"workshop": {"name": "Trap Workshop", "col": "#9aa7b6", "cost": [25, 40, 60],
		"objs": [[1, 1, "anvil", 1], [3, 1, "bench", 1], [3, 3, "bench", 1], [1, 3, "gear"], [0, 4, "gear"]]},
	"armory": {"unlock": 25, "name": "Armory", "col": "#b9c3cd", "cost": [30, 50, 75],
		"objs": [[0, 0, "rack", 1], [4, 0, "rack", 1], [0, 4, "rack", 1], [4, 4, "rack", 1], [1, 1, "armor", 1], [3, 3, "armor", 1]]},
	"cistern": {"unlock": 25, "name": "Flooded Cistern", "col": "#4f8fbf", "cost": [30, 50],
		"objs": [[1, 1, "pillar", 1], [3, 1, "pillar", 1], [1, 3, "pillar", 1], [3, 3, "pillar", 1]]},
	"torture": {"unlock": 35, "name": "Torture Chamber", "col": "#b8243c", "cost": [35, 55, 80],
		"objs": [[1, 1, "rack2", 1], [3, 1, "maiden", 1], [1, 3, "chains"], [3, 3, "blood"], [2, 2, "blood"], [0, 4, "chains"]]},
	"collapse": {"unlock": 40, "name": "Collapsing Hall", "col": "#8a7f90", "cost": [30, 50, 75],
		"objs": [[1, 1, "cracked", 1], [3, 3, "cracked", 1], [3, 1, "rubble"], [1, 3, "rubble"], [0, 0, "rubble"]]},
	"sanctum": {"owner": "darklord", "name": "Dark Sanctum", "col": "#7d8cff", "cost": [35, 55, 80],
		"objs": [[2, 2, "runecircle"], [0, 0, "shelf", 1], [4, 0, "shelf", 1], [1, 3, "candles"], [3, 3, "candles"], [3, 1, "crystal", 1]]},
	"trainingyard": {"unlock": 35, "owner": "darklord", "name": "Training Yard", "col": "#a8aec8", "cost": [30, 50, 75],
		"objs": [[0, 0, "rack", 1], [4, 0, "rack", 1], [1, 1, "armor", 1], [3, 3, "armor", 1], [1, 3, "anvil", 1]]},
	"oathstone": {"unlock": 45, "owner": "darklord", "name": "Oath Stone", "col": "#b89cff", "cost": [45, 70],
		"objs": [[2, 2, "altar"], [1, 1, "pillar", 1], [3, 1, "pillar", 1], [1, 3, "pillar", 1], [3, 3, "pillar", 1], [0, 4, "candles"]]},
	"maze": {"unlock": 30, "name": "Maze of Bones", "col": "#d8ccb0", "cost": [30, 50],
		"objs": [[0, 0, "bonewall", 1], [4, 0, "bonewall", 1], [1, 1, "bonewall", 1], [3, 1, "bonewall", 1], [1, 3, "bonewall", 1], [3, 3, "bonewall", 1], [0, 4, "bonewall", 1], [4, 4, "bonewall", 1], [2, 2, "bones"]]},
	"shrine": {"unlock": 35, "name": "Shrine of Desecration", "col": "#7a5a9a", "cost": [35, 55],
		"objs": [[2, 2, "altar"], [0, 0, "brazier", 1], [4, 0, "brazier", 1], [1, 3, "candles"], [3, 3, "candles"], [3, 1, "blood"]]},
	"stitching": {"unlock": 35, "name": "Stitching Room", "col": "#9a8a6a", "cost": [35, 55],
		"objs": [[1, 1, "table", 1], [3, 1, "table", 1], [2, 2, "candles"], [0, 4, "chains"], [4, 4, "barrel", 1], [3, 3, "blood"]]},
	"scrying": {"unlock": 40, "name": "Scrying Pool", "col": "#5fa8c8", "cost": [40, 60],
		"objs": [[2, 2, "well"], [1, 1, "crystal", 1], [3, 3, "crystal", 1], [1, 3, "candles"], [3, 1, "candles"]]},
	"ogreden": {"unlock": 40, "name": "Ogre Den", "col": "#8a9a5a", "cost": [40, 65], "recruit": "ogre", "cap": 1,
		"objs": [[0, 0, "cage", 1], [4, 4, "barrel", 1], [1, 1, "meat"], [3, 3, "bones"], [3, 1, "bones"], [0, 4, "rack", 1]]},
	"library": {"owner": "lich", "name": "Arcane Library", "col": "#9b84ff", "cost": [35, 55, 80],
		"objs": [[0, 0, "shelf", 1], [4, 0, "shelf", 1], [1, 1, "shelf", 1], [3, 1, "shelf", 1], [0, 4, "shelf", 1], [4, 4, "shelf", 1], [2, 2, "candles"], [1, 3, "candles"]]},
	"manawell": {"unlock": 40, "owner": "lich", "name": "Mana Well", "col": "#7fb4ff", "cost": [40, 70],
		"objs": [[2, 2, "well"], [1, 1, "crystal", 1], [3, 3, "crystal", 1], [3, 1, "runecircle"], [1, 3, "runecircle"]]},
	"phylactery": {"unlock": 55, "owner": "lich", "name": "Phylactery Vault", "col": "#d6c8ff", "cost": [40, 60, 85],
		"objs": [[1, 1, "pillar", 1], [3, 1, "pillar", 1], [2, 2, "altar"], [1, 3, "candles"], [3, 3, "candles"]]},
	"crypt": {"owner": "vampire", "name": "Crypt of Brides", "col": "#e0405a", "cost": [35, 55, 75], "recruit": "spawn", "cap": 2,
		"objs": [[1, 1, "coffin", 1], [3, 1, "coffin", 1], [1, 3, "coffin", 1], [3, 3, "coffin", 1], [2, 2, "blood"]]},
	"bloodpool": {"unlock": 35, "owner": "vampire", "name": "Blood Pool", "col": "#a3122c", "cost": [35, 55, 80],
		"objs": [[2, 2, "pool"], [1, 1, "pillar", 1], [3, 3, "pillar", 1], [3, 1, "blood"], [1, 3, "blood"]]},
	"coffin": {"unlock": 30, "owner": "vampire", "name": "Velvet Coffin", "col": "#8a4b6a", "cost": [30, 50, 70], "next": "+8 max HP",
		"objs": [[2, 1, "bigcoffin"], [1, 1, "candles"], [3, 1, "candles"], [0, 4, "pillar", 1], [4, 4, "pillar", 1]]},
	"graveyard": {"owner": "necro", "name": "Graveyard", "col": "#6fd3a0", "cost": [25, 40, 60], "recruit": "skeleton", "cap": 3,
		"objs": [[1, 1, "tomb", 1], [3, 1, "tomb", 1], [1, 3, "tomb", 1], [3, 3, "tomb", 1], [0, 0, "tomb", 1], [4, 4, "tomb", 1], [2, 2, "bones"]]},
	"boneforge": {"unlock": 40, "owner": "necro", "name": "Bone Forge", "col": "#cfe8d8", "cost": [35, 55, 80],
		"objs": [[1, 1, "forge", 1], [3, 1, "anvil", 1], [1, 3, "bones"], [3, 3, "bones"], [4, 4, "bones"]]},
	"soulcage": {"unlock": 45, "owner": "necro", "name": "Soul Cage", "col": "#58a88a", "cost": [40, 70],
		"objs": [[1, 1, "cage", 1], [3, 1, "cage", 1], [2, 2, "wisp"], [1, 3, "wisp"]]},
	"thrallpens": {"owner": "flayer", "name": "Thrall Pens", "col": "#a48ac0", "cost": [30, 50, 70], "recruit": "thrall", "cap": 2,
		"objs": [[0, 0, "bars", 1], [4, 0, "bars", 1], [0, 4, "bars", 1], [4, 4, "bars", 1], [1, 1, "chains"], [3, 3, "chains"]]},
	"brainjars": {"unlock": 35, "owner": "flayer", "name": "Brain Jar Gallery", "col": "#c77dff", "cost": [30, 50, 75],
		"objs": [[0, 0, "jar", 1], [4, 0, "jar", 1], [1, 1, "jar", 1], [3, 1, "jar", 1], [0, 4, "jar", 1], [4, 4, "jar", 1], [2, 2, "runecircle"]]},
	"amplifier": {"unlock": 50, "owner": "flayer", "name": "Psionic Amplifier", "col": "#f08cff", "cost": [45, 80],
		"objs": [[1, 1, "crystal", 1], [3, 3, "crystal", 1], [3, 1, "crystal", 1], [2, 2, "wisp"]]},
	"clockwork": {"unlock": 35, "owner": "mimic", "name": "Clockwork Forge", "col": "#e4a648", "cost": [30, 50, 75],
		"objs": [[1, 1, "gearbig", 1], [3, 1, "gearbig", 1], [1, 3, "gear"], [3, 3, "gear"], [2, 2, "gear"]]},
	"snareden": {"owner": "mimic", "name": "Snare Den", "col": "#b08a5a", "cost": [25, 45],
		"objs": [[0, 0, "crate", 1], [4, 4, "crate", 1], [1, 1, "rope"], [3, 3, "rope"], [3, 1, "rope"]]},
	"runes": {"unlock": 45, "owner": "mimic", "name": "Rune Chamber", "col": "#ff7a3a", "cost": [35, 55, 80],
		"objs": [[2, 2, "runecircle"], [1, 1, "candles"], [3, 3, "candles"], [0, 4, "crystal", 1]]},
}
const EMPTY_OBJS := [[0, 4, "rubble"], [4, 0, "rubble"]]

## Furniture you can rearrange by day. Heroes walled off from you smash blocking pieces;
## a smashed piece leaves rubble that anyone can walk over until you repair it.
const FIXED_DECOR := ["throne", "stairs_up"]
const DECOR_REPAIR := 5   # gold per smashed piece
const STURDY_DECOR := ["pillar", "cracked", "bonewall", "tomb", "coffin", "forge", "anvil", "maiden", "gearbig", "cage"]
const DECOR_NAMES := {"rack2": "rack", "gearbig": "great gear", "bonewall": "bone wall", "bigcoffin": "coffin", "bars": "cell bars"}

const TRAPS := {
	"spikes": {"name": "Spike trap", "cost": 10, "desc": "Hurts every hero that steps on it. Permanent."},
	"snare": {"name": "Snare", "cost": 8, "desc": "Holds a hero in place through its next turn. Used up."},
	"rune": {"name": "Blast rune", "cost": 20, "desc": "Explodes in a 3x3 area. Used up."},
}

## Dread modifiers: picked before a run, each makes it harder and adds to the souls it banks.
const MODS := [
	{"id": "zealous", "name": "Zealous Village", "desc": "Heroes have 25% more HP.", "bonus": 0.15},
	{"id": "hardened", "name": "Hardened Raiders", "desc": "Heroes deal 1 more damage.", "bonus": 0.15},
	{"id": "crowded", "name": "Crowded Gate", "desc": "One extra hero every night.", "bonus": 0.2},
	{"id": "sharp", "name": "Sharp Eyes", "desc": "Every hero spots traps and walks around them.", "bonus": 0.2},
	{"id": "short", "name": "Short Days", "desc": "2 hours a day instead of 3.", "bonus": 0.25},
	{"id": "lean", "name": "Lean Coffers", "desc": "Half gold from kills and from the dawn tribute.", "bonus": 0.15},
	{"id": "norest", "name": "No Rest", "desc": "Nothing heals you at dawn.", "bonus": 0.15},
	{"id": "crusade", "name": "Restless Crusade", "desc": "Boss nights every 4 nights instead of 5.", "bonus": 0.1},
	{"id": "godless", "name": "Godless", "desc": "No dark boons.", "bonus": 0.3},
	{"id": "glass", "name": "Glass Lair", "desc": "Your monster starts with 25% less max HP.", "bonus": 0.2},
]

## Earned every Game.BOON_EVERY nights, so each one is a big step up.
const BOONS := [
	{"id": "hide", "name": "Thick Hide", "desc": "+20 max HP and heal to full."},
	{"id": "claws", "name": "Cruel Claws", "desc": "Your basic attack deals +5 damage."},
	{"id": "surge", "name": "Arcane Surge", "desc": "Your damaging spells deal +5 damage."},
	{"id": "swift", "name": "Swift Shadow", "desc": "You move 2 extra tiles."},
	{"id": "pack", "name": "Pack Tactics", "desc": "Your minions deal +2 damage and have +5 HP."},
	{"id": "feast", "name": "Blood Feast", "desc": "Heal 8 HP whenever you kill a hero."},
	{"id": "rituals", "name": "Dark Rituals", "desc": "All your spells recharge 1 turn faster and deal +2 damage."},
	{"id": "greed", "name": "Greed", "desc": "Heroes drop double gold."},
	{"id": "jagged", "name": "Jagged Traps", "desc": "Traps deal +8 damage."},
	{"id": "owl", "name": "Night Owl", "desc": "+1 hour of work every day, and 50 gold now."},
	{"id": "press", "name": "Press Gang", "desc": "An ogre and two goblins join you now. They don't use any room space."},
]


static func col(hex: String, a := 1.0) -> Color:
	var c := Color(hex)
	c.a = a
	return c


## Gold to raise a room from level l to l + 1 (l = 0 builds it). Rooms have no level cap:
## past the listed prices, each level costs 40% more than the one before.
static func room_cost(t: String, l: int) -> int:
	var c: Array = ROOMS[t].cost
	if l < c.size():
		return c[l]
	return roundi(c.back() * pow(1.4, l - c.size() + 1) / 5.0) * 5


# ---- level scaling for rooms whose effect isn't a plain multiple of the level

static func treasury_gold(l: int) -> int:
	return 0 if l <= 0 else ([12, 20, 30][l - 1] if l <= 3 else 30 + 10 * (l - 3))

static func larder_heal(l: int) -> int:
	return 0 if l <= 0 else ([6, 10, 15][l - 1] if l <= 3 else 15 + 5 * (l - 3))

static func phylactery_hp(l: int) -> int:
	return 0 if l <= 0 else 8 + 6 * (l - 1)

## Hero turns every staircase stays down after the Stairs power (level 3+).
static func stairs_shut_turns(l: int) -> int:
	return maxi(2, l - 1)

## Damage to heroes who start their turn in the Flooded Cistern (level 3+).
static func cistern_drown(l: int) -> int:
	return maxi(0, 2 * (l - 2))

## How far apart the Dark Lord and Squire can stand and stay bonded.
static func oath_range(l: int) -> int:
	return 3 if l <= 0 else 5 + maxi(0, l - 2)

## HP a hit on one of the bonded pair heals the other (Oath Stone level 2+).
static func oath_heal(l: int) -> int:
	return maxi(0, l - 1)

## Damage to heroes who blunder into the Maze of Bones (level 3+).
static func maze_dmg(l: int) -> int:
	return maxi(0, 3 * (l - 2))

## Share of max HP that foreseen heroes lose (Scrying Pool level 3+), capped at half.
static func scry_shaken(l: int) -> float:
	return minf(0.5, 0.05 * maxi(0, l - 2))

## Extra spell damage from the Mana Well once recharge is already maxed out (level 3+).
static func well_dmg(l: int) -> int:
	return maxi(0, l - 2)

## HP each Goblin Shaman restores to nearby units at the start of your turn.
static func shaman_mend(l: int) -> int:
	return 1 + maxi(1, l)

## Skeletons each Raise Dead brings up.
static func soul_skeletons(l: int) -> int:
	return maxi(1, l)

## Extra damage for dominated heroes (Psionic Amplifier level 3+).
static func amp_dmg(l: int) -> int:
	return maxi(0, 2 * (l - 2))

## How many hits of damage a blocking piece of furniture takes before it breaks.
static func decor_hp(kind: String) -> int:
	return 20 if kind in STURDY_DECOR else 12

static func decor_name(kind: String) -> String:
	return DECOR_NAMES.get(kind, kind)

## Roman numerals for room labels on the map.
static func roman(n: int) -> String:
	var vals := [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
	var syms := ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
	var o := ""
	for i in vals.size():
		while n >= vals[i]:
			o += syms[i]
			n -= vals[i]
	return o


static func room_eff(t: String, l: int) -> String:
	match t:
		"lair": return "You start each fight on your throne and take 1 less damage while in here." + (" +%d max HP." % ((l - 1) * 6) if l > 1 else "")
		"stairs":
			if l == 1: return "Leads up to a new floor. One per floor; the floor above starts where these stairs arrive."
			if l == 2: return "Spiral stair: heroes who climb it stop at the top for the rest of their turn."
			return "Spiral stair. Once per fight you can also collapse every staircase for %d turns." % stairs_shut_turns(l)
		"treasury": return "+%d gold every dawn. Rogues try to rob it and run." % treasury_gold(l)
		"larder": return "Heal %d HP every dawn." % larder_heal(l)
		"barracks": return "Recruit up to %d goblins." % (l * 2)
		"lodge": return "Recruit up to %d goblin shaman%s. At the start of your turn, each heals your units within 2 tiles for %d HP." % [l, "s" if l > 1 else "", shaman_mend(l)]
		"coven": return "Recruit up to %d warlock%s. Their bolts ignore armor" % [l, "s" if l > 1 else ""] + (" and deal +%d damage." % (l - 1) if l > 1 else ".")
		"kennel": return "Recruit up to %d hellhound%s. Fast hunters." % [l, "s" if l > 1 else ""]
		"workshop": return "Room for %d traps. Unlocks %s." % [3 + l * 3, ["spikes", "spikes and snares", "spikes, snares and blast runes"][mini(l, 3) - 1]]
		"armory": return "Your minions deal +%d damage." % l
		"cistern": return "Heroes in this room move %d tile%s less." % [l, "s" if l > 1 else ""] + (" They take %d damage at the start of each turn in the water." % cistern_drown(l) if l >= 3 else "")
		"torture": return "Heroes who start their turn in here take %d damage." % (2 + l)
		"collapse": return "Once per fight, drop the ceiling: %d damage to everyone inside, yours too." % (8 + (l - 1) * 4)
		"sanctum": return "Doombolt deals +%d damage, and Hexed heroes take %d more." % [l, l] + (" Hex also slows." if l >= 3 else "")
		"trainingyard": return "The Squire gets +%d max HP." % (l * 4) + (" Challenge reaches 3 tiles." if l >= 2 else "")
		"oathstone": return "The bond between the Dark Lord and his Squire reaches %d tiles." % oath_range(l) + (" While bonded, a hit on one heals the other %d HP." % oath_heal(l) if l >= 2 else "")
		"maze": return "Heroes who wander in lose their way and stop for the turn." + (" They can't attack that turn either." if l > 1 else "") + (" They also take %d damage." % maze_dmg(l) if l >= 3 else "")
		"shrine": return "Holy heroes inside lose their holy bonus and take %d damage a turn. Clerics can't heal in here." % l
		"stitching": return "At dawn, sew %s that died last night back together for half its cost." % ("one minion" if l == 1 else "up to %d minions" % l)
		"scrying": return ("See tomorrow night's raiders." if l == 1 else "See the raiders of the next %d nights." % l) + (" Foreseen heroes arrive with %d%% less HP." % roundi(scry_shaken(l) * 100) if l >= 3 else "")
		"ogreden": return "Recruit up to %d ogre%s: 30 HP, slow, hits for 6. Good for plugging a doorway." % [l, "s" if l > 1 else ""]
		"library": return "Your spells deal +%d damage." % (l * 2)
		"manawell": return "Your spells recharge %d turn%s faster." % [l, "s" if l > 1 else ""] + (" Your spells deal +%d damage." % well_dmg(l) if l >= 3 else "")
		"phylactery": return "Once per fight, when you die, reform at the altar with %d HP." % phylactery_hp(l)
		"crypt": return "Recruit up to %d vampire spawn. They drink blood too." % (l * 2)
		"bloodpool": return "Your claws deal +%d damage." % (l * 2)
		"coffin": return "+%d max HP." % (l * 8)
		"graveyard": return "Recruit up to %d skeletons. Cheap and plentiful." % (l * 3)
		"boneforge": return "All your undead get +%d HP and +%d damage." % [l * 2, l]
		"soulcage": return "Raise Dead recharges 1 turn faster." if l == 1 else "Raise Dead recharges faster and raises %d skeletons." % soul_skeletons(l)
		"thrallpens": return "Recruit up to %d brainwashed thralls." % (l * 2)
		"brainjars": return "Psychic Lash deals +%d damage." % (l * 2)
		"amplifier": return ("Dominate recharges 1 turn faster." if l == 1 else "Dominate recharges faster and works on bosses.") + (" Your thralls deal +%d damage." % amp_dmg(l) if l >= 3 else "")
		"clockwork": return "All your traps deal +%d damage." % (l * 2)
		"snareden": return "Unlocks snares. +%d trap slots." % (l * 3)
		"runes": return "Unlocks blast runes (%d damage in 3x3). +%d trap slots." % [6 + l * 3, l * 2]
	return ""
