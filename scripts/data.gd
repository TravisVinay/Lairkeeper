class_name Data
extends RefCounted
## Static game content: monsters, units, rooms, furniture, traps, patron gifts and the trader's goods.
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
		"blurb": "Looks like treasure, so heroes rush it. Has 5 wildcard trap slots for any trap, and buys traps at half price. Iron bands block 1 damage.",
		"specials": [
			{"id": "lure", "name": "Glittering Lure", "cd": 3, "kind": "tile", "range": 7, "any": true, "desc": "Pick a tile. Every hero is dragged 2 steps toward it, over your traps."},
			{"id": "coin", "name": "Coin Shot", "cd": 2, "kind": "enemy", "range": 4, "desc": "Spit up to 20 of your gold at a hero within 4. It takes that much damage, ignoring armor. Never spends more than the hero has HP."}]},
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

# Every room is open from the first run. Rooms with an "owner" can only be built by that monster.
# Furniture is [x, y, kind, blocks] in room-local tiles. Blocking pieces only sit on the four
# corners or the four inner diagonals, never on a doorway or the center cross, so every door connects.
## Room categories, in the order the catalog and build list show them. Every room has a "cat".
const CATS := [
	{"id": "minions", "name": "Minions", "col": "#86b35e", "desc": "House minions, free, or raise fighters for the night."},
	{"id": "training", "name": "Minion training", "col": "#a0b060", "desc": "Make every minion tougher, faster or deadlier."},
	{"id": "monster", "name": "Monster power", "col": "#c0304c", "desc": "Make you (and your Squire) stronger."},
	{"id": "traps", "name": "Traps", "col": "#9aa7b6", "desc": "Each trap room lets you lay its own trap, or more of one."},
	{"id": "hazards", "name": "Hazards", "col": "#d86a3a", "desc": "Hurt, slow and weaken the heroes who walk through."},
	{"id": "holds", "name": "Strongholds", "col": "#8a9ab0", "desc": "Your units fight better while standing inside."},
	{"id": "upkeep", "name": "Upkeep", "col": "#e4a648", "desc": "Gold, healing and a look at the raids to come."},
	{"id": "arms", "name": "Arms", "col": "#c8a070", "desc": "Forge weapons, scribe scrolls and strip the dead of their gear."},
]

static func cat_info(id: String) -> Dictionary:
	for c in CATS:
		if c.id == id:
			return c
	return {"id": id, "name": id.capitalize(), "col": "#a7998f", "desc": ""}

const ROOMS := {
	"lair": {"cat": "core", "name": "Throne Room", "col": "#c0304c", "fixed": true, "cost": [0, 40, 70], "next": "+6 max HP",
		"objs": [[1, 1, "pillar", 1], [3, 1, "pillar", 1], [1, 3, "pillar", 1], [3, 3, "pillar", 1], [2, 1, "throne"], [2, 2, "rug"], [2, 3, "rug"], [0, 0, "brazier", 1], [4, 0, "brazier", 1]]},
	"treasury": {"cat": "upkeep", "name": "Treasury", "col": "#e4a648", "cost": [25, 40, 60],
		"objs": [[0, 0, "chest", 1], [4, 0, "chest", 1], [3, 1, "chest", 1], [0, 4, "coins"], [4, 4, "coins"], [1, 1, "coins"], [3, 3, "coins"]]},
	"larder": {"cat": "upkeep", "name": "Larder", "col": "#d08a5a", "cost": [20, 35, 50],
		"objs": [[1, 1, "table", 1], [3, 1, "table", 1], [0, 4, "barrel", 1], [4, 4, "barrel", 1], [0, 0, "meat"], [4, 0, "meat"], [1, 3, "meat"]]},
	"barracks": {"cat": "minions", "name": "Goblin Barracks", "col": "#86b35e", "cost": [25, 40, 60], "recruit": "goblin", "cap": 2,
		"objs": [[0, 0, "bunk", 1], [4, 0, "bunk", 1], [1, 1, "bunk", 1], [3, 1, "bunk", 1], [2, 2, "fire"], [0, 4, "rack", 1], [4, 4, "rack", 1]]},
	"kennel": {"cat": "minions", "name": "Hellhound Kennel", "col": "#d9573f", "cost": [40, 65, 95], "recruit": "hound", "cap": 1,
		"objs": [[0, 0, "cage", 1], [4, 0, "cage", 1], [0, 4, "cage", 1], [4, 4, "cage", 1], [1, 1, "bones"], [3, 3, "bones"], [3, 1, "bones"]]},
	"lodge": {"cat": "minions", "name": "Spirit Lodge", "col": "#b8c85a", "cost": [30, 50, 75], "recruit": "shaman", "cap": 1,
		"objs": [[2, 2, "fire"], [0, 0, "brazier", 1], [4, 0, "brazier", 1], [4, 4, "jar", 1], [1, 1, "bones"], [3, 3, "bones"], [1, 3, "candles"]]},
	"coven": {"cat": "minions", "name": "Warlock Coven", "col": "#9a4fd0", "cost": [35, 55, 80], "recruit": "warlock", "cap": 1,
		"objs": [[2, 2, "runecircle"], [0, 0, "brazier", 1], [4, 0, "jar", 1], [0, 4, "shelf", 1], [4, 4, "brazier", 1], [3, 3, "candles"], [1, 1, "blood"]]},
	"workshop": {"cat": "traps", "name": "Spike Workshop", "col": "#9aa7b6", "cost": [25, 40, 60],
		"objs": [[1, 1, "anvil", 1], [3, 1, "bench", 1], [3, 3, "bench", 1], [1, 3, "gear"], [0, 4, "gear"]]},
	"armory": {"cat": "training", "name": "Armory", "col": "#b9c3cd", "cost": [30, 50, 75],
		"objs": [[0, 0, "rack", 1], [4, 0, "rack", 1], [0, 4, "rack", 1], [4, 4, "rack", 1], [1, 1, "armor", 1], [3, 3, "armor", 1]]},
	"cistern": {"cat": "hazards", "name": "Flooded Cistern", "col": "#4f8fbf", "cost": [30, 50, 75],
		"objs": [[1, 1, "pillar", 1], [3, 1, "pillar", 1], [1, 3, "pillar", 1], [3, 3, "pillar", 1]]},
	"torture": {"cat": "hazards", "name": "Torture Chamber", "col": "#b8243c", "cost": [35, 55, 80],
		"objs": [[1, 1, "rack2", 1], [3, 1, "maiden", 1], [1, 3, "chains"], [3, 3, "blood"], [2, 2, "blood"], [0, 4, "chains"]]},
	"collapse": {"cat": "hazards", "name": "Collapsing Hall", "col": "#8a7f90", "cost": [30, 50, 75],
		"objs": [[1, 1, "cracked", 1], [3, 3, "cracked", 1], [3, 1, "rubble"], [1, 3, "rubble"], [0, 0, "rubble"]]},
	"sanctum": {"cat": "monster", "owner": "darklord", "name": "Dark Sanctum", "col": "#7d8cff", "cost": [35, 55, 80],
		"objs": [[2, 2, "runecircle"], [0, 0, "shelf", 1], [4, 0, "shelf", 1], [1, 3, "candles"], [3, 3, "candles"], [3, 1, "crystal", 1]]},
	"trainingyard": {"cat": "monster", "owner": "darklord", "name": "Training Yard", "col": "#a8aec8", "cost": [30, 50, 75],
		"objs": [[0, 0, "rack", 1], [4, 0, "rack", 1], [1, 1, "armor", 1], [3, 3, "armor", 1], [1, 3, "anvil", 1]]},
	"oathstone": {"cat": "monster", "owner": "darklord", "name": "Oath Stone", "col": "#b89cff", "cost": [45, 70, 100],
		"objs": [[2, 2, "altar"], [1, 1, "pillar", 1], [3, 1, "pillar", 1], [1, 3, "pillar", 1], [3, 3, "pillar", 1], [0, 4, "candles"]]},
	"maze": {"cat": "hazards", "name": "Maze of Bones", "col": "#d8ccb0", "cost": [30, 50, 75],
		"objs": [[0, 0, "bonewall", 1], [4, 0, "bonewall", 1], [1, 1, "bonewall", 1], [3, 1, "bonewall", 1], [1, 3, "bonewall", 1], [3, 3, "bonewall", 1], [0, 4, "bonewall", 1], [4, 4, "bonewall", 1], [2, 2, "bones"]]},
	"shrine": {"cat": "hazards", "name": "Shrine of Desecration", "col": "#7a5a9a", "cost": [35, 55, 80],
		"objs": [[2, 2, "altar"], [0, 0, "brazier", 1], [4, 0, "brazier", 1], [1, 3, "candles"], [3, 3, "candles"], [3, 1, "blood"]]},
	"forge": {"cat": "arms", "name": "War Forge", "col": "#d07a3a", "cost": [35, 55, 80],
		"objs": [[1, 1, "forge", 1], [3, 1, "anvil", 1], [0, 4, "rack", 1], [4, 4, "rack", 1], [3, 3, "crate"]]},
	"scribes": {"cat": "arms", "name": "Hall of Scribes", "col": "#8fa8d8", "cost": [35, 55, 80],
		"objs": [[0, 0, "shelf", 1], [4, 0, "shelf", 1], [1, 3, "table", 1], [3, 3, "candles"], [2, 2, "candles"]]},
	"scavenger": {"cat": "arms", "name": "Scavenger's Den", "col": "#a89070", "cost": [25, 40, 60], "fx": {"drop_pct": 10},
		"objs": [[0, 0, "crate", 1], [4, 4, "crate", 1], [3, 1, "bones"], [1, 3, "rope"], [4, 0, "barrel", 1]]},
	"bladehall": {"cat": "arms", "name": "Hall of Blades", "col": "#c0c8d0", "cost": [30, 50, 75], "fx": {"armed_atk": 1},
		"objs": [[0, 0, "rack", 1], [4, 0, "rack", 1], [1, 1, "armor", 1], [3, 3, "armor", 1], [0, 4, "rack2", 1]]},
	"scrying": {"cat": "upkeep", "name": "Scrying Pool", "col": "#5fa8c8", "cost": [40, 60, 85],
		"objs": [[2, 2, "well"], [1, 1, "crystal", 1], [3, 3, "crystal", 1], [1, 3, "candles"], [3, 1, "candles"]]},
	"ogreden": {"cat": "minions", "name": "Ogre Den", "col": "#8a9a5a", "cost": [40, 65, 95], "recruit": "ogre", "cap": 1,
		"objs": [[0, 0, "cage", 1], [4, 4, "barrel", 1], [1, 1, "meat"], [3, 3, "bones"], [3, 1, "bones"], [0, 4, "rack", 1]]},
	"library": {"cat": "monster", "owner": "lich", "name": "Arcane Library", "col": "#9b84ff", "cost": [35, 55, 80],
		"objs": [[0, 0, "shelf", 1], [4, 0, "shelf", 1], [1, 1, "shelf", 1], [3, 1, "shelf", 1], [0, 4, "shelf", 1], [4, 4, "shelf", 1], [2, 2, "candles"], [1, 3, "candles"]]},
	"manawell": {"cat": "monster", "owner": "lich", "name": "Mana Well", "col": "#7fb4ff", "cost": [40, 70, 100],
		"objs": [[2, 2, "well"], [1, 1, "crystal", 1], [3, 3, "crystal", 1], [3, 1, "runecircle"], [1, 3, "runecircle"]]},
	"phylactery": {"cat": "monster", "owner": "lich", "name": "Phylactery Vault", "col": "#d6c8ff", "cost": [40, 60, 85],
		"objs": [[1, 1, "pillar", 1], [3, 1, "pillar", 1], [2, 2, "altar"], [1, 3, "candles"], [3, 3, "candles"]]},
	"crypt": {"cat": "minions", "owner": "vampire", "name": "Crypt of Brides", "col": "#e0405a", "cost": [35, 55, 75], "recruit": "spawn", "cap": 2,
		"objs": [[1, 1, "coffin", 1], [3, 1, "coffin", 1], [1, 3, "coffin", 1], [3, 3, "coffin", 1], [2, 2, "blood"]]},
	"bloodpool": {"cat": "monster", "owner": "vampire", "name": "Blood Pool", "col": "#a3122c", "cost": [35, 55, 80],
		"objs": [[2, 2, "pool"], [1, 1, "pillar", 1], [3, 3, "pillar", 1], [3, 1, "blood"], [1, 3, "blood"]]},
	"coffin": {"cat": "monster", "owner": "vampire", "name": "Velvet Coffin", "col": "#8a4b6a", "cost": [30, 50, 70], "next": "+8 max HP",
		"objs": [[2, 1, "bigcoffin"], [1, 1, "candles"], [3, 1, "candles"], [0, 4, "pillar", 1], [4, 4, "pillar", 1]]},
	"graveyard": {"cat": "minions", "owner": "necro", "name": "Graveyard", "col": "#6fd3a0", "cost": [25, 40, 60], "recruit": "skeleton", "cap": 3,
		"objs": [[1, 1, "tomb", 1], [3, 1, "tomb", 1], [1, 3, "tomb", 1], [3, 3, "tomb", 1], [0, 0, "tomb", 1], [4, 4, "tomb", 1], [2, 2, "bones"]]},
	"soulcage": {"cat": "monster", "owner": "necro", "name": "Soul Cage", "col": "#58a88a", "cost": [40, 70, 100],
		"objs": [[1, 1, "cage", 1], [3, 1, "cage", 1], [2, 2, "wisp"], [1, 3, "wisp"]]},
	"thrallpens": {"cat": "minions", "owner": "flayer", "name": "Thrall Pens", "col": "#a48ac0", "cost": [30, 50, 70], "recruit": "thrall", "cap": 2,
		"objs": [[0, 0, "bars", 1], [4, 0, "bars", 1], [0, 4, "bars", 1], [4, 4, "bars", 1], [1, 1, "chains"], [3, 3, "chains"]]},
	"brainjars": {"cat": "monster", "owner": "flayer", "name": "Brain Jar Gallery", "col": "#c77dff", "cost": [30, 50, 75],
		"objs": [[0, 0, "jar", 1], [4, 0, "jar", 1], [1, 1, "jar", 1], [3, 1, "jar", 1], [0, 4, "jar", 1], [4, 4, "jar", 1], [2, 2, "runecircle"]]},
	"amplifier": {"cat": "monster", "owner": "flayer", "name": "Psionic Amplifier", "col": "#f08cff", "cost": [45, 80, 115],
		"objs": [[1, 1, "crystal", 1], [3, 3, "crystal", 1], [3, 1, "crystal", 1], [2, 2, "wisp"]]},
	"clockwork": {"cat": "traps", "owner": "mimic", "name": "Clockwork Forge", "col": "#e4a648", "cost": [30, 50, 75],
		"objs": [[1, 1, "gearbig", 1], [3, 1, "gearbig", 1], [1, 3, "gear"], [3, 3, "gear"], [2, 2, "gear"]]},
	"snareden": {"cat": "traps", "name": "Snare Den", "col": "#b08a5a", "cost": [25, 45, 65],
		"objs": [[0, 0, "crate", 1], [4, 4, "crate", 1], [1, 1, "rope"], [3, 3, "rope"], [3, 1, "rope"]]},
	"runes": {"cat": "traps", "name": "Rune Chamber", "col": "#ff7a3a", "cost": [35, 55, 80],
		"objs": [[2, 2, "runecircle"], [1, 1, "candles"], [3, 3, "candles"], [0, 4, "crystal", 1]]},
	# ---- rooms built from shared effects ("fx": value per level; see Game.fx and Data.fx_text)
	"spikefoundry": {"cat": "traps", "name": "Spike Foundry", "col": "#b9a48a", "cost": [35, 55, 80], "fx": {"spike_slots": 1, "spike_dmg": 2},
		"objs": [[1, 1, "forge", 1], [3, 3, "anvil", 1], [2, 2, "fire"], [0, 4, "gear"]]},
	"snarewarren": {"cat": "traps", "name": "Snare Warren", "col": "#9a7a4a", "cost": [30, 50, 75], "fx": {"snare_slots": 1, "snare_dmg": 2},
		"objs": [[0, 4, "crate", 1], [4, 4, "barrel", 1], [1, 1, "rope"], [3, 1, "rope"]]},
	"runekiln": {"cat": "traps", "name": "Rune Kiln", "col": "#ff9a5a", "cost": [40, 65, 95], "fx": {"rune_slots": 1},
		"objs": [[2, 2, "runecircle"], [0, 0, "brazier", 1], [4, 4, "brazier", 1], [1, 3, "candles"]]},
	"trapvault": {"cat": "traps", "name": "Trap Vault", "col": "#e4c048", "cost": [40, 65, 95], "fx": {"wild_slots": 1},
		"objs": [[1, 1, "chest", 1], [3, 3, "chest", 1], [3, 1, "gear"], [1, 3, "rope"]]},
	"trapstudy": {"cat": "traps", "name": "Trapmaster's Study", "col": "#c8a060", "cost": [40, 65, 95], "fx": {"trap_dmg": 2},
		"objs": [[0, 0, "shelf", 1], [4, 0, "shelf", 1], [2, 2, "table"], [1, 3, "candles"]]},
	"mistchamber": {"cat": "holds", "name": "Mist Chamber", "col": "#b8c8d8", "cost": [30, 50, 75], "fx": {"here_slow": 1, "here_def": 1},
		"objs": [[2, 2, "wisp"], [0, 0, "jar", 1], [4, 4, "jar", 1], [3, 1, "candles"]]},
	"acidvats": {"cat": "hazards", "name": "Acid Vats", "col": "#9ad040", "cost": [35, 55, 80], "fx": {"here_shred": 1},
		"objs": [[1, 1, "jar", 1], [3, 1, "jar", 1], [1, 3, "jar", 1], [2, 2, "pool"]]},
	"gibbet": {"cat": "hazards", "name": "Gibbet Hall", "col": "#8a7a6a", "cost": [25, 40, 60], "fx": {"here_weak": 1, "enter_dmg": 2},
		"objs": [[1, 1, "cage", 1], [3, 3, "cage", 1], [1, 3, "chains"], [3, 1, "chains"]]},
	"gauntlet": {"cat": "hazards", "name": "Gauntlet", "col": "#c04040", "cost": [35, 55, 80], "fx": {"enter_dmg": 5},
		"objs": [[1, 1, "maiden", 1], [3, 1, "maiden", 1], [2, 2, "blood"], [1, 3, "chains"]]},
	"echohall": {"cat": "hazards", "name": "Echo Hall", "col": "#9080a0", "cost": [30, 50, 75], "fx": {"hero_shaken": 4},
		"objs": [[0, 0, "pillar", 1], [4, 4, "pillar", 1], [2, 2, "wisp"]]},
	"warroom": {"cat": "holds", "name": "War Room", "col": "#c05030", "cost": [35, 55, 80], "fx": {"here_power": 2},
		"objs": [[1, 1, "table", 1], [3, 3, "table", 1], [2, 2, "rug"], [3, 1, "candles"]]},
	"bastion": {"cat": "holds", "name": "Bastion", "col": "#7080a0", "cost": [35, 55, 80], "fx": {"here_def": 2},
		"objs": [[0, 0, "pillar", 1], [4, 0, "pillar", 1], [0, 4, "pillar", 1], [4, 4, "pillar", 1], [2, 2, "rug"]]},
	"heart": {"cat": "monster", "name": "Beating Heart", "col": "#d03050", "cost": [35, 55, 80], "fx": {"mon_hp": 6},
		"objs": [[2, 2, "pool"], [1, 1, "blood"], [3, 3, "blood"], [0, 4, "jar", 1]]},
	"feasthall": {"cat": "monster", "name": "Feasting Hall", "col": "#d08a5a", "cost": [35, 55, 80], "fx": {"mon_atk": 1},
		"objs": [[1, 1, "table", 1], [3, 1, "table", 1], [1, 3, "meat"], [3, 3, "meat"], [2, 2, "fire"]]},
	"bonearmorer": {"cat": "monster", "name": "Bone Armorer", "col": "#d8d0c0", "cost": [45, 75, 110], "fx": {"mon_armor": 1},
		"objs": [[1, 1, "anvil", 1], [3, 3, "rack", 1], [2, 2, "bones"], [0, 4, "armor", 1]]},
	"stables": {"cat": "monster", "name": "Shadow Stables", "col": "#504870", "cost": [40, 65, 95], "fx": {"mon_move": 1},
		"objs": [[0, 0, "cage", 1], [4, 0, "cage", 1], [2, 2, "rubble"], [1, 3, "bones"]]},
	"hotsprings": {"cat": "monster", "name": "Hot Springs", "col": "#70c0d0", "cost": [35, 55, 80], "fx": {"mon_regen": 1},
		"objs": [[2, 2, "pool"], [0, 0, "brazier", 1], [4, 4, "brazier", 1]]},
	"scriptorium": {"cat": "monster", "name": "Scriptorium", "col": "#9b84ff", "cost": [30, 50, 75], "fx": {"spell_dmg": 1},
		"objs": [[0, 0, "shelf", 1], [4, 0, "shelf", 1], [2, 2, "table"], [1, 3, "candles"]]},
	"drillyard": {"cat": "training", "name": "Drill Yard", "col": "#b0a060", "cost": [35, 55, 80], "fx": {"minion_move": 1},
		"objs": [[0, 0, "rack", 1], [4, 0, "rack", 1], [2, 2, "rug"]]},
	"smithy": {"cat": "training", "name": "Smithy", "col": "#a09080", "cost": [40, 65, 95], "fx": {"minion_armor": 1},
		"objs": [[1, 1, "forge", 1], [3, 1, "anvil", 1], [2, 2, "fire"], [1, 3, "gear"]]},
	"messhall": {"cat": "training", "name": "Mess Hall", "col": "#c09060", "cost": [25, 40, 60], "fx": {"minion_hp": 3},
		"objs": [[1, 1, "table", 1], [3, 3, "table", 1], [3, 1, "meat"], [0, 4, "barrel", 1]]},
	"countinghouse": {"cat": "upkeep", "name": "Counting House", "col": "#d8b860", "cost": [25, 40, 60], "fx": {"kill_gold": 1},
		"objs": [[1, 1, "table", 1], [3, 3, "chest", 1], [3, 1, "coins"], [1, 3, "candles"]]},
	"trophyhall": {"cat": "upkeep", "name": "Trophy Hall", "col": "#c0a080", "cost": [35, 55, 80], "fx": {"boss_souls": 2, "kill_gold": 1},
		"objs": [[0, 0, "armor", 1], [4, 0, "armor", 1], [2, 2, "rug"], [1, 3, "bones"]]},
	"charnel": {"cat": "minions", "owner": "necro", "name": "Charnel House", "col": "#6fa080", "cost": [35, 55, 80], "fx": {"raise_here": 1},
		"objs": [[1, 1, "tomb", 1], [3, 1, "tomb", 1], [2, 2, "bones"], [1, 3, "blood"]]},
	"hoard": {"cat": "monster", "owner": "mimic", "name": "Gilded Hoard", "col": "#ffd060", "cost": [25, 40, 60], "fx": {"coin_cap": 10, "kill_gold": 1},
		"objs": [[0, 0, "chest", 1], [4, 4, "chest", 1], [2, 2, "coins"], [1, 3, "coins"], [3, 1, "coins"]]},
	"toothvault": {"cat": "traps", "owner": "mimic", "name": "Vault of Teeth", "col": "#e4c070", "cost": [40, 65, 95], "fx": {"wild_slots": 2},
		"objs": [[1, 1, "chest", 1], [3, 3, "chest", 1], [2, 2, "bones"], [3, 1, "gear"]]},
}
const EMPTY_OBJS := [[0, 4, "rubble"], [4, 0, "rubble"]]

## Furniture you can rearrange by day. Heroes walled off from you smash blocking pieces;
## a smashed piece leaves rubble that anyone can walk over until you repair it.
const FIXED_DECOR := ["throne"]
const DECOR_REPAIR := 5   # gold per smashed piece
const STURDY_DECOR := ["pillar", "cracked", "bonewall", "tomb", "coffin", "forge", "anvil", "maiden", "gearbig", "cage"]
const DECOR_NAMES := {"rack2": "rack", "gearbig": "great gear", "bonewall": "bone wall", "bigcoffin": "coffin", "bars": "cell bars"}

const TRAPS := {
	"spikes": {"name": "Spike trap", "cost": 10, "desc": "Badly hurts the first hero to step on it. Fires once a night, re-arms at dawn."},
	"snare": {"name": "Snare", "cost": 8, "desc": "Hurts the first hero to step on it and holds it through its next turn. Once a night."},
	"rune": {"name": "Blast rune", "cost": 20, "desc": "Explodes in a 3x3 area when a hero steps on it. Once a night."},
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
	{"id": "godless", "name": "Godless", "desc": "No patron gifts.", "bonus": 0.3},
	{"id": "glass", "name": "Glass Lair", "desc": "Your monster starts with 25% less max HP.", "bonus": 0.2},
]

## Patron gifts: after night 1 and every Game.GIFT_EVERY nights after, the patron offers three
## and you take one. Each can be taken once a run. "fx" effects stack with rooms and perks
## (see Game.perk); the rest are applied by Game.apply_gift.
const GIFTS := [
	{"id": "hide", "name": "Thick Hide", "desc": "+20 max HP and heal to full."},
	{"id": "claws", "name": "Cruel Claws", "desc": "Your basic attack deals +5 damage."},
	{"id": "surge", "name": "Arcane Surge", "desc": "Your damaging spells deal +5 damage."},
	{"id": "swift", "name": "Swift Shadow", "desc": "You move 2 extra tiles."},
	{"id": "pack", "name": "Pack Tactics", "desc": "Your minions deal +2 damage and have +5 HP."},
	{"id": "feast", "name": "Blood Feast", "desc": "Heal 8 HP whenever you kill a hero."},
	{"id": "rituals", "name": "Dark Rituals", "desc": "All your spells recharge 1 turn faster and deal +2 damage."},
	{"id": "greed", "name": "Greed", "desc": "Heroes drop double gold."},
	{"id": "jagged", "name": "Jagged Traps", "desc": "Traps deal +10 damage."},
	{"id": "owl", "name": "Night Owl", "desc": "+1 hour of work every day, and 50 gold now."},
	{"id": "press", "name": "Press Gang", "desc": "An ogre and two goblins join you now. They don't use any room space."},
	{"id": "tithe", "name": "Tithe of Fear", "desc": "The village leaves 20 more gold every dawn.", "fx": {"dawn_gold": 20}},
	{"id": "iron", "name": "Iron Skin", "desc": "You and your minions get +1 armor.", "fx": {"mon_armor": 1, "minion_armor": 1}},
	{"id": "vigor", "name": "Unholy Vigor", "desc": "Heal 3 HP at the start of each of your turns.", "fx": {"mon_regen": 3}},
	{"id": "barbs", "name": "Barbed Hide", "desc": "Heroes who hit you up close take 4 damage back.", "fx": {"thorns": 4}},
	{"id": "bloodprice", "name": "Blood Price", "desc": "Heal 4 HP whenever one of your traps fires.", "fx": {"trap_heal": 4}},
	{"id": "restless", "name": "Restless Dead", "desc": "1 in 3 slain heroes rises as a skeleton that fights for you until dawn.", "fx": {"raise_pct": 33}},
	{"id": "hoard", "name": "Dragon's Hoard", "desc": "Every dawn, gain 10% of the gold you're holding (up to 25).", "fx": {"interest": 10}},
	{"id": "dread", "name": "Aura of Dread", "desc": "Heroes arrive with 15% less HP.", "fx": {"hero_shaken": 15}},
	{"id": "arsenal", "name": "Hidden Arsenal", "desc": "+2 wildcard trap slots, for any trap.", "fx": {"wild_slots": 2}},
	{"id": "favor", "name": "Patron's Favor", "desc": "The wandering trader brings 1 more relic and sells everything for 20% less.", "fx": {"trader_slots": 1, "trader_disc": 20}},
	{"id": "reach", "name": "Long Reach", "desc": "You attack from 1 tile further away.", "fx": {"mon_rng": 1}},
	{"id": "bloodpact", "name": "Blood Pact", "desc": "Your basic attack deals +7 damage, but you lose 15 max HP."},
	{"id": "blessed", "name": "Black Blessing", "desc": "A rare weapon, forged in the dark, appears in your armory now."},
	{"id": "tome", "name": "Forbidden Tome", "desc": "Two magic scrolls now, and every scroll you get has 1 more charge.", "fx": {"scroll_charges": 1}},
	{"id": "plunder", "name": "Plunderer", "desc": "Slain heroes drop their gear 15% more often.", "fx": {"drop_pct": 15}},
	{"id": "warband", "name": "Armed Warband", "desc": "Every minion you have without a weapon now picks up a common one."},
	{"id": "cursed", "name": "Cursed Ground", "desc": "One more hero raids every night, but heroes drop 50% more gold and this run banks 50% more souls.", "fx": {"extra_hero": 1, "soul_pct": 50}},
]

## Relics: a unit carries one in its relic slot, and while anyone carries it, it works for the
## whole lair. Prices rise a little as the nights go on (Game.ware_price).
const RELICS := [
	{"id": "whetstone", "name": "Bloodied Whetstone", "cost": 45, "desc": "Your basic attack deals +2 damage.", "fx": {"mon_atk": 2}},
	{"id": "bonecharm", "name": "Bone Charm", "cost": 55, "desc": "+1 armor.", "fx": {"mon_armor": 1}},
	{"id": "boots", "name": "Shadowstep Boots", "cost": 50, "desc": "You move 1 extra tile.", "fx": {"mon_move": 1}},
	{"id": "ichor", "name": "Vial of Ichor", "cost": 40, "desc": "Heal 1 HP at the start of each of your turns.", "fx": {"mon_regen": 1}},
	{"id": "grimoire", "name": "Torn Grimoire", "cost": 50, "desc": "Your damaging spells deal +2 damage.", "fx": {"spell_dmg": 2}},
	{"id": "hourglass", "name": "Hourglass of Dusk", "cost": 95, "desc": "All your spells recharge 1 turn faster.", "fx": {"spell_cd": 1}},
	{"id": "caltrops", "name": "Rusted Caltrops", "cost": 35, "desc": "All traps deal +4 damage.", "fx": {"trap_dmg": 4}},
	{"id": "purse", "name": "Grave Purse", "cost": 40, "desc": "Heroes drop +2 gold.", "fx": {"kill_gold": 2}},
	{"id": "drum", "name": "War Drum", "cost": 45, "desc": "Your minions deal +1 damage.", "fx": {"minion_atk": 1}},
	{"id": "splints", "name": "Bone Splints", "cost": 40, "desc": "Your minions have +5 HP.", "fx": {"minion_hp": 5}},
	{"id": "collar", "name": "Thorned Collar", "cost": 50, "desc": "Heroes who hit you up close take 2 damage back.", "fx": {"thorns": 2}},
	{"id": "chalice", "name": "Black Chalice", "cost": 50, "desc": "Heal 3 HP whenever a hero dies.", "fx": {"kill_heal": 3}},
	{"id": "idol", "name": "Golden Idol", "cost": 60, "desc": "Every dawn, gain 5% of the gold you're holding (up to 25).", "fx": {"interest": 5}},
	{"id": "crown", "name": "Crown of Dread", "cost": 55, "desc": "Heroes arrive with 10% less HP.", "fx": {"hero_shaken": 10}},
	{"id": "heart", "name": "Spare Heart", "cost": 110, "desc": "Once a night, when you would fall, you rise again with 20 HP.", "fx": {"cheat_death": 20}},
	{"id": "pouch", "name": "Trapper's Pouch", "cost": 45, "desc": "+1 wildcard trap slot, for any trap.", "fx": {"wild_slots": 1}},
	{"id": "lantern", "name": "Ghost Lantern", "cost": 40, "desc": "Bosses give +3 souls.", "fx": {"boss_souls": 3}},
	{"id": "scrollcase", "name": "Scroll Case", "cost": 45, "desc": "Every scroll you get has 1 more charge.", "fx": {"scroll_charges": 1}},
	{"id": "sack", "name": "Loot Sack", "cost": 40, "desc": "Slain heroes drop their gear 8% more often.", "fx": {"drop_pct": 8}},
	{"id": "oil", "name": "Weapon Oil", "cost": 45, "desc": "Your armed units deal +1 damage.", "fx": {"armed_atk": 1}},
	{"id": "coin", "name": "Lucky Coin", "cost": 30, "desc": "The trader sells everything for 10% less.", "fx": {"trader_disc": 10}},
]

## The trader's supplies: used the moment you buy them, and restocked every visit.
const WARES := [
	{"id": "draught", "name": "Healing Draught", "cost": 20, "desc": "Heal 30 HP now."},
	{"id": "ale", "name": "Strong Ale", "cost": 25, "desc": "+1 hour of work today."},
	{"id": "elixir", "name": "Elixir of Vigor", "cost": 45, "desc": "+8 max HP for the rest of the run."},
	{"id": "sellsword", "name": "Hired Ogre", "cost": 40, "desc": "An ogre joins you for the rest of the run. It uses no room space."},
	{"id": "souljar", "name": "Soul Jar", "cost": 35, "desc": "+8 souls, banked when this run ends."},
	{"id": "mortar", "name": "Mason's Mortar", "cost": 15, "desc": "Repair every piece of smashed furniture in the dungeon."},
]

## Every unit you have (monster, Squire, each minion) carries up to one weapon, one armor and
## one relic. Weapons: "atk", "armor", "move" and "rng" add to
## the unit; "rng_set" makes it attack from at least that far; "pierce" ignores armor, "leech"
## drinks a third of the damage, "splash" hits heroes next to the target for half, "slow" slows.
## Tier 1 is common, 3 rare. A room's minions keep their gear when they fall (they're back at
## dawn); a minion with no room, hired or gifted, loses its gear with its life.
const WEAPONS := [
	{"id": "sword", "name": "Rusty Sword", "tier": 1, "cost": 25, "atk": 1, "desc": "+1 damage."},
	{"id": "club", "name": "Spiked Club", "tier": 1, "cost": 30, "atk": 2, "move": -1, "desc": "+2 damage, 1 less move."},
	{"id": "dagger", "name": "Dagger", "tier": 1, "cost": 30, "atk": 1, "move": 1, "desc": "+1 damage, 1 more move."},
	{"id": "spear", "name": "Spear", "tier": 1, "cost": 30, "rng": 1, "desc": "Attacks from 1 tile further away."},
	{"id": "shortbow", "name": "Shortbow", "tier": 1, "cost": 35, "rng_set": 3, "atk": -1, "desc": "Attacks from 3 tiles away, for 1 less damage."},
	{"id": "axe", "name": "War Axe", "tier": 2, "cost": 55, "atk": 3, "desc": "+3 damage."},
	{"id": "hammer", "name": "Warhammer", "tier": 2, "cost": 60, "atk": 2, "pierce": true, "desc": "+2 damage, ignores armor."},
	{"id": "flail", "name": "Chain Flail", "tier": 2, "cost": 60, "atk": 1, "splash": true, "desc": "+1 damage. Heroes next to the target take half."},
	{"id": "fang", "name": "Fang Blade", "tier": 2, "cost": 60, "atk": 2, "leech": true, "desc": "+2 damage, and drinks a third of the damage dealt as health."},
	{"id": "frostbrand", "name": "Frost Brand", "tier": 2, "cost": 55, "atk": 2, "slow": true, "desc": "+2 damage, and slows the heroes it hits."},
	{"id": "longbow", "name": "Longbow", "tier": 2, "cost": 60, "rng_set": 4, "atk": 1, "desc": "Attacks from 4 tiles away, for +1 damage."},
	{"id": "runeblade", "name": "Runeblade", "tier": 3, "cost": 100, "atk": 4, "pierce": true, "desc": "+4 damage, ignores armor."},
	{"id": "reaper", "name": "Soul Reaper", "tier": 3, "cost": 110, "atk": 4, "leech": true, "desc": "+4 damage, and drinks a third of the damage dealt as health."},
	{"id": "glaive", "name": "Storm Glaive", "tier": 3, "cost": 110, "atk": 3, "rng": 1, "splash": true, "desc": "+3 damage, attacks from 1 tile further, and heroes next to the target take half."},
	{"id": "oathblade", "name": "Fallen Oathblade", "tier": 3, "cost": 120, "atk": 5, "armor": 1, "desc": "A Paladin's sword, turned. +5 damage and +1 armor."},
]

## Armor: "armor", "move" and "hp" add to the unit (hp only lasts the night), "regen" heals it
## at the start of your turn, "thorns" hurts heroes who hit it up close.
const ARMOR := [
	{"id": "buckler", "name": "Buckler", "tier": 1, "cost": 30, "armor": 1, "desc": "+1 armor."},
	{"id": "leather", "name": "Boiled Leather", "tier": 1, "cost": 25, "hp": 6, "desc": "+6 HP in battle."},
	{"id": "cloak", "name": "Shadow Cloak", "tier": 1, "cost": 30, "move": 1, "desc": "1 more move."},
	{"id": "chain", "name": "Chain Shirt", "tier": 2, "cost": 55, "armor": 1, "hp": 6, "desc": "+1 armor and +6 HP in battle."},
	{"id": "tower", "name": "Tower Shield", "tier": 2, "cost": 55, "armor": 2, "move": -1, "desc": "+2 armor, 1 less move."},
	{"id": "spiked", "name": "Spiked Mail", "tier": 2, "cost": 60, "armor": 1, "thorns": 2, "desc": "+1 armor. Heroes who hit it up close take 2 damage."},
	{"id": "bloodmail", "name": "Bloodsoaked Mail", "tier": 2, "cost": 55, "regen": 2, "desc": "Heals 2 HP at the start of each of your turns."},
	{"id": "aegis", "name": "Aegis of Night", "tier": 3, "cost": 100, "armor": 3, "desc": "+3 armor."},
	{"id": "boneplate", "name": "Bone Plate", "tier": 3, "cost": 110, "armor": 2, "hp": 12, "desc": "+2 armor and +12 HP in battle."},
]

## Magic scrolls: a spell for your monster's bar with a few charges, then it crumbles. Cast like
## any spell (it uses your action unless it says otherwise), at most once a turn each.
const SCROLLS := [
	{"id": "fireball", "name": "Scroll of Fireball", "tier": 1, "cost": 35, "charges": 3, "kind": "area", "range": 4, "desc": "Heroes in a 3x3 area within 4 take 7 spell damage."},
	{"id": "lightning", "name": "Scroll of Lightning", "tier": 1, "cost": 35, "charges": 3, "kind": "enemy", "range": 5, "desc": "Strike a hero within 5 for 12 spell damage."},
	{"id": "mending", "name": "Scroll of Mending", "tier": 1, "cost": 30, "charges": 2, "kind": "self", "desc": "Heal 15 HP."},
	{"id": "frost", "name": "Scroll of Frost", "tier": 1, "cost": 30, "charges": 3, "kind": "enemy", "range": 4, "desc": "A hero within 4 takes 4 spell damage and is frozen in place for 2 turns."},
	{"id": "blink", "name": "Scroll of Blinking", "tier": 1, "cost": 25, "charges": 3, "kind": "tile", "range": 5, "free": true, "desc": "Teleport to an empty tile within 5. Free action."},
	{"id": "terror", "name": "Scroll of Terror", "tier": 2, "cost": 45, "charges": 2, "kind": "self", "desc": "Heroes within 2 tiles are confused for a turn and may strike each other."},
	{"id": "grave", "name": "Scroll of the Grave", "tier": 2, "cost": 45, "charges": 3, "kind": "tile", "range": 3, "desc": "Two skeletons claw up from an empty tile within 3 and beside it."},
	{"id": "warding", "name": "Scroll of Warding", "tier": 2, "cost": 40, "charges": 2, "kind": "self", "free": true, "desc": "A ward soaks the next 12 damage you take. Free action."},
	{"id": "meteor", "name": "Scroll of Meteor", "tier": 3, "cost": 80, "charges": 1, "kind": "area", "range": 5, "desc": "Heroes in a 3x3 area within 5 take 18 spell damage."},
	{"id": "doom", "name": "Scroll of Doom", "tier": 3, "cost": 80, "charges": 1, "kind": "enemy", "range": 4, "desc": "A hero within 4 loses half its current HP. Bosses lose a quarter."},
]

static func weapon_by_id(id: String) -> Dictionary:
	for w in WEAPONS:
		if w.id == id:
			return w
	return {}

static func armor_by_id(id: String) -> Dictionary:
	for w in ARMOR:
		if w.id == id:
			return w
	return {}

## "weapon", "armor" or "relic" for gear a unit can carry, "scroll", or "".
static func slot_of(id: String) -> String:
	if not weapon_by_id(id).is_empty(): return "weapon"
	if not armor_by_id(id).is_empty(): return "armor"
	if not relic_by_id(id).is_empty(): return "relic"
	if not scroll_by_id(id).is_empty(): return "scroll"
	return ""

## A weapon, armor or relic entry by id.
static func gear_by_id(id: String) -> Dictionary:
	for o in [weapon_by_id(id), armor_by_id(id), relic_by_id(id)]:
		if not o.is_empty():
			return o
	return {}

static func scroll_by_id(id: String) -> Dictionary:
	for w in SCROLLS:
		if w.id == id:
			return w
	return {}

## The item's tag on cards: tier and kind.
static func item_tag(id: String) -> String:
	var kind := slot_of(id)
	if kind == "relic":
		return "relic"
	var it := gear_by_id(id)
	if kind == "scroll":
		it = scroll_by_id(id)
		kind = "scroll · %d charge%s" % [it.get("charges", 1), "" if it.get("charges", 1) == 1 else "s"]
	var tiers := ["common", "uncommon", "rare"]
	return "%s %s" % [tiers[clampi(int(it.get("tier", 1)), 1, 3) - 1], kind]

static func gift_by_id(id: String) -> Dictionary:
	for g in GIFTS:
		if g.id == id:
			return g
	return {}

static func relic_by_id(id: String) -> Dictionary:
	for r in RELICS:
		if r.id == id:
			return r
	return {}

static func ware_by_id(id: String) -> Dictionary:
	for w in WARES:
		if w.id == id:
			return w
	for o in [relic_by_id(id), weapon_by_id(id), armor_by_id(id), scroll_by_id(id)]:
		if not o.is_empty():
			return o
	return {}


static func col(hex: String, a := 1.0) -> Color:
	var c := Color(hex)
	c.a = a
	return c


## Gold to raise a room from level l to l + 1 (l = 0 builds it). Every room lists three prices
## and stops at level 3 (Game.MAX_LVL).
static func room_cost(t: String, l: int) -> int:
	return ROOMS[t].cost[l]


# ---- level scaling for rooms whose effect isn't a plain multiple of the level

static func treasury_gold(l: int) -> int:
	return 0 if l <= 0 else ([12, 20, 30][l - 1] if l <= 3 else 30 + 10 * (l - 3))

static func larder_heal(l: int) -> int:
	return 0 if l <= 0 else ([6, 10, 15][l - 1] if l <= 3 else 15 + 5 * (l - 3))

static func phylactery_hp(l: int) -> int:
	return 0 if l <= 0 else 8 + 6 * (l - 1)

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


## Blast rune damage with a Rune Chamber at level l (a Workshop's runes count as level 1).
static func rune_dmg(l: int) -> int:
	return 14 + 6 * maxi(1, l)

static func room_eff(t: String, l: int) -> String:
	match t:
		"lair": return "You start each fight on your throne and take 1 less damage while in here." + (" +%d max HP." % ((l - 1) * 6) if l > 1 else "")
		"treasury": return "+%d gold every dawn. Rogues try to rob it and run." % treasury_gold(l)
		"larder": return "Heal %d HP every dawn." % larder_heal(l)
		"barracks": return "Comes with %d goblins." % (l * 2)
		"lodge": return "Comes with %d goblin shaman%s. At the start of your turn, each heals your units within 2 tiles for %d HP." % [l, "s" if l > 1 else "", shaman_mend(l)]
		"coven": return "Comes with %d warlock%s. Their bolts ignore armor" % [l, "s" if l > 1 else ""] + (" and deal +%d damage." % (l - 1) if l > 1 else ".")
		"kennel": return "Comes with %d hellhound%s. Fast hunters." % [l, "s" if l > 1 else ""]
		"workshop": return "Lay up to %d spike traps. Spikes deal %d." % [1 + 2 * l, 8 + 4 * l]
		"armory": return "Your minions deal +%d damage." % l
		"cistern": return "Heroes in this room move %d tile%s less." % [l, "s" if l > 1 else ""] + (" They take %d damage at the start of each turn in the water." % cistern_drown(l) if l >= 3 else "")
		"torture": return "Heroes who start their turn in here take %d damage." % (2 + l)
		"collapse": return "Once per fight, drop the ceiling: %d damage to everyone inside, yours too." % (8 + (l - 1) * 4)
		"sanctum": return "Doombolt deals +%d damage, and Hexed heroes take %d more." % [l, l] + (" Hex also slows." if l >= 3 else "")
		"trainingyard": return "The Squire gets +%d max HP." % (l * 4) + (" Challenge reaches 3 tiles." if l >= 2 else "")
		"oathstone": return "The bond between the Dark Lord and his Squire reaches %d tiles." % oath_range(l) + (" While bonded, a hit on one heals the other %d HP." % oath_heal(l) if l >= 2 else "")
		"maze": return "Heroes who wander in lose their way and stop for the turn." + (" They can't attack that turn either." if l > 1 else "") + (" They also take %d damage." % maze_dmg(l) if l >= 3 else "")
		"shrine": return "Holy heroes inside lose their holy bonus and take %d damage a turn. Clerics can't heal in here." % l
		"scrying": return ("See tomorrow night's raiders." if l == 1 else "See the raiders of the next %d nights." % l) + (" Foreseen heroes arrive with %d%% less HP." % roundi(scry_shaken(l) * 100) if l >= 3 else "")
		"ogreden": return "Comes with %d ogre%s: 30 HP, slow, hits for 6. Good for plugging a doorway." % [l, "s" if l > 1 else ""]
		"library": return "Your spells deal +%d damage." % (l * 2)
		"forge": return "Forges a weapon at dawn %s." % ["every third day", "every other day", "every day"][clampi(l, 1, 3) - 1] + (" Better weapons at level %d." % (l + 1) if l < 3 else " Its best work.")
		"scribes": return "Scribes a magic scroll at dawn %s." % ["every third day", "every other day", "every day"][clampi(l, 1, 3) - 1] + (" Rarer scrolls at level %d." % (l + 1) if l < 3 else " Its rarest scrolls.")
		"manawell": return "Your spells recharge %d turn%s faster." % [l, "s" if l > 1 else ""] + (" Your spells deal +%d damage." % well_dmg(l) if l >= 3 else "")
		"phylactery": return "Once per fight, when you die, reform at the altar with %d HP." % phylactery_hp(l)
		"crypt": return "Comes with %d vampire spawn. They drink blood too." % (l * 2)
		"bloodpool": return "Your claws deal +%d damage." % (l * 2)
		"coffin": return "+%d max HP." % (l * 8)
		"graveyard": return "Comes with %d skeletons. Cheap and plentiful." % (l * 3)
		"soulcage": return "Raise Dead recharges 1 turn faster." if l == 1 else "Raise Dead recharges faster and raises %d skeletons." % soul_skeletons(l)
		"thrallpens": return "Comes with %d brainwashed thralls." % (l * 2)
		"brainjars": return "Psychic Lash deals +%d damage." % (l * 2)
		"amplifier": return ("Dominate recharges 1 turn faster." if l == 1 else "Dominate recharges faster and works on bosses.") + (" Your thralls deal +%d damage." % amp_dmg(l) if l >= 3 else "")
		"clockwork": return "All your traps deal +%d damage." % (l * 4)
		"snareden": return "Lay up to %d snares. A snare holds a hero in place for a turn." % (1 + l)
		"runes": return "Lay up to %d blast rune%s (%d damage in 3x3)." % [l, "s" if l > 1 else "", rune_dmg(l)]
	if ROOMS.has(t) and ROOMS[t].has("fx"):
		return fx_text(t, l)
	return ""

## One sentence per effect, for rooms built from shared effects. %d is the value at level l.
const FX_TEXT := {
	"mon_hp": "+%d max HP.", "mon_atk": "Your attacks deal +%d damage.", "mon_armor": "You gain %d armor.",
	"mon_move": "You move %d more tile(s).", "spell_dmg": "Your spells deal +%d damage.",
	"mon_regen": "Your monster heals %d HP at the start of each of your turns.", "kill_heal": "Your monster heals %d HP whenever a hero dies.",
	"minion_hp": "Minions get +%d HP.", "minion_atk": "Minions deal +%d damage.", "minion_move": "Minions move %d more tile(s).",
	"minion_armor": "Minions gain %d armor.", "minion_regen": "Minions heal %d HP at the start of your turn.",
	"here_dmg": "Heroes who start their turn in here take %d damage.", "here_slow": "Heroes in here move %d tile(s) less.",
	"here_weak": "Heroes in here deal %d less damage.", "here_shred": "Heroes in here take %d more damage from everything.",
	"here_def": "Your units in here take %d less damage.", "here_power": "Your units in here deal +%d damage.",
	"enter_dmg": "The first time each hero walks in each night, it takes %d damage.",
	"dawn_gold": "+%d gold every dawn.", "dawn_heal": "Heal %d HP every dawn.", "kill_gold": "Heroes drop +%d gold.",
	"boss_souls": "Bosses give +%d souls.", "spike_slots": "Lay %d more spike trap(s).", "snare_slots": "Lay %d more snare(s).",
	"rune_slots": "Lay %d more blast rune(s).", "wild_slots": "+%d wildcard trap slot(s), for any trap.",
	"spike_dmg": "Spike traps deal +%d damage.", "snare_dmg": "Snares deal +%d damage.", "rune_dmg": "Blast runes deal +%d damage.",
	"trap_dmg": "All traps deal +%d damage.", "hero_shaken": "Heroes arrive with %d%% less HP.",
	"coin_cap": "Coin Shot can spend up to %d more gold.",
	"drop_pct": "Slain heroes drop their gear %d%% more often.", "armed_atk": "Your armed units deal +%d damage.",
	"raise_here": "Heroes who die in here rise as your skeletons for the rest of the night, up to %d a night.",
}

static func fx_text(t: String, l: int) -> String:
	var R: Dictionary = ROOMS[t]
	var parts := []
	for k in R.fx:
		var v: int = R.fx[k] * l
		if k == "garrison":
			var U: Dictionary = UNITS[R.garrison]
			parts.append("%d %s fight%s in here every night, on top of your housed minions." % [v, U.name.to_lower() + ("s" if v > 1 else ""), "" if v > 1 else "s"])
		elif k == "hero_shaken":
			parts.append(FX_TEXT[k] % mini(40, v))
		else:
			var line: String = FX_TEXT[k] % v
			parts.append(line.replace("(s)", "s" if v != 1 else ""))
	return " ".join(parts)


# ---------------------------------------------------------------- monster levels
# Souls level up a monster between runs. Every level adds something: a perk choice (pick 1 of 2,
# swap freely between runs), a new spell for the pool, or a third loadout slot. You bring
# 2 spells into a run (3 from level 5; per unit for the duo) from the ones you have.

const MON_MAX_LVL := 8
## What each level from 2 up gives.
const LEVEL_TRACK := {2: "perk", 3: "spell", 4: "perk", 5: "slot", 6: "perk", 7: "spell", 8: "perk"}
const PERK_LEVELS := [2, 4, 6, 8]

## Souls to go from level l to l + 1.
static func mon_level_cost(l: int) -> int:
	return 25 + 15 * (l - 1)

## Spells a monster learns as it levels, on top of its two starting ones. "lvl" is when it opens;
## "who": "squire" puts it in the Squire's pool.
const SPELL_POOL := {
	"lich": [
		{"id": "siphon", "lvl": 3, "name": "Soul Siphon", "cd": 3, "kind": "enemy", "range": 3, "desc": "Drain a hero within 3 for 6 spell damage. You heal what it loses."},
		{"id": "blizzard", "lvl": 7, "name": "Blizzard", "cd": 4, "kind": "area", "range": 5, "desc": "Heroes in a 3x3 area within 5 take 3 spell damage and are frozen in place for a turn."}],
	"vampire": [
		{"id": "bite", "lvl": 3, "name": "Crimson Bite", "cd": 2, "kind": "enemy", "range": 1, "desc": "Bite a hero next to you for your claw damage +4, and drink twice as much as usual."},
		{"id": "mist", "lvl": 7, "name": "Blood Mist", "cd": 4, "kind": "self", "desc": "Heroes within 2 take 4 damage. You drink from each, and heal 3 more for each one caught."}],
	"necro": [
		{"id": "boom", "lvl": 3, "name": "Corpse Explosion", "cd": 3, "kind": "corpse", "range": 5, "desc": "Blow up a corpse within 5. Heroes on and next to it take 8 spell damage."},
		{"id": "pact", "lvl": 7, "name": "Death Pact", "cd": 3, "kind": "ally", "range": 4, "free": true, "desc": "Sacrifice a minion within 4. You heal 8 HP, and your minions within 3 of it are rallied (+1 move, +2 damage) this turn."}],
	"flayer": [
		{"id": "blast", "lvl": 3, "name": "Mind Blast", "cd": 2, "kind": "enemy", "range": 4, "desc": "Hit a hero within 4 for 6 spell damage. Confused heroes take double."},
		{"id": "puppet", "lvl": 7, "name": "Puppeteer", "cd": 3, "kind": "enemy", "range": 4, "free": true, "desc": "A hero within 4 attacks the nearest hero it can reach, right now. If none, it is confused."}],
	"mimic": [
		{"id": "tongue", "lvl": 3, "name": "Tongue Lash", "cd": 3, "kind": "enemy", "range": 4, "desc": "Yank a hero within 4 toward you, over your traps, then chomp it if it lands next to you."},
		{"id": "rain", "lvl": 7, "name": "Golden Rain", "cd": 4, "kind": "area", "range": 5, "desc": "Spend 15 gold: heroes in a 3x3 area within 5 take 10 damage, ignoring armor."}],
	"darklord": [
		{"id": "rend", "lvl": 3, "name": "Soul Rend", "cd": 3, "kind": "enemy", "range": 4, "desc": "Hit a hero within 4 for 6 spell damage. Hexed heroes take double."},
		{"id": "cleave", "lvl": 7, "who": "squire", "name": "Cleave", "cd": 3, "kind": "self", "desc": "The Squire strikes every hero next to him with his Black Blade."}],
}

## Perk choices at levels 2, 4, 6 and 8: two options each. "fx" keys add up like room effects
## (see Game.perk and Game.fx); "<spell>_cd", "<spell>_rng" and "<spell>_dmg" tune one spell.
const PERKS := {
	"lich": [
		[{"id": "glacial", "name": "Glacial Reach", "desc": "Frost Nova reaches 3 tiles.", "fx": {"nova_rng": 1}},
		 {"id": "forked", "name": "Forked Lightning", "desc": "Chain Lightning arcs to 2 more heroes.", "fx": {"chain_jumps": 2}}],
		[{"id": "boneward", "name": "Bone Ward", "desc": "+1 armor and +6 max HP.", "fx": {"mon_armor": 1, "mon_hp": 6}},
		 {"id": "focus", "name": "Arcane Focus", "desc": "Your spells deal +2 damage.", "fx": {"spell_dmg": 2}}],
		[{"id": "quicken", "name": "Quickened Mind", "desc": "All your spells recharge 1 turn faster.", "fx": {"spell_cd": 1}},
		 {"id": "battlelich", "name": "Battle Lich", "desc": "Bone Lance deals +3 damage and reaches 1 tile farther.", "fx": {"mon_atk": 3, "mon_rng": 1}}],
		[{"id": "undying", "name": "Undying", "desc": "+15 max HP, and heal 2 HP at the start of each turn.", "fx": {"mon_hp": 15, "mon_regen": 2}},
		 {"id": "glass", "name": "Glass Cannon", "desc": "Your spells deal +6 damage, but you have 10 less max HP.", "fx": {"spell_dmg": 6, "mon_hp": -10}}]],
	"vampire": [
		[{"id": "longflight", "name": "Long Flight", "desc": "Bat Form reaches 8 tiles.", "fx": {"bats_rng": 3}},
		 {"id": "deepgaze", "name": "Deep Gaze", "desc": "Mesmerize reaches 5 tiles and recharges 1 turn faster.", "fx": {"mesmer_rng": 2, "mesmer_cd": 1}}],
		[{"id": "thickblood", "name": "Thick Blood", "desc": "+10 max HP.", "fx": {"mon_hp": 10}},
		 {"id": "fangs", "name": "Sharpened Fangs", "desc": "Your claws deal +3 damage.", "fx": {"mon_atk": 3}}],
		[{"id": "lordnight", "name": "Lord of the Night", "desc": "Your minions get +4 HP and deal +1 damage.", "fx": {"minion_hp": 4, "minion_atk": 1}},
		 {"id": "gorge", "name": "Gorge", "desc": "Heal 6 HP whenever a hero dies.", "fx": {"kill_heal": 6}}],
		[{"id": "ancient", "name": "Ancient Blood", "desc": "You drink half the damage you deal instead of a third.", "fx": {"vamp_leech": 1}},
		 {"id": "stalker", "name": "Nightstalker", "desc": "+1 move, and Bat Form recharges 1 turn faster.", "fx": {"mon_move": 1, "bats_cd": 1}}]],
	"necro": [
		[{"id": "massgrave", "name": "Mass Grave", "desc": "Raise Dead raises 1 more skeleton.", "fx": {"raise_extra": 1}},
		 {"id": "ghoullord", "name": "Ghoul Lord", "desc": "Raise Fallen recharges 1 turn faster, and ghouls get +6 HP.", "fx": {"ghoul_cd": 1, "ghoul_hp": 6}}],
		[{"id": "legion", "name": "Bone Legion", "desc": "Skeletons get +3 HP and deal +1 damage.", "fx": {"skel_hp": 3, "skel_atk": 1}},
		 {"id": "blackarts", "name": "Black Arts", "desc": "Death Bolt and your spells deal +2 damage.", "fx": {"mon_atk": 2, "spell_dmg": 2}}],
		[{"id": "gravechill", "name": "Grave Chill", "desc": "Heroes hit by your undead minions are slowed.", "fx": {"undead_slow": 1}},
		 {"id": "vigor", "name": "Unholy Vigor", "desc": "+8 max HP, and heal 1 HP at the start of each turn.", "fx": {"mon_hp": 8, "mon_regen": 1}}],
		[{"id": "army", "name": "Army of the Dead", "desc": "Raise Dead recharges 1 turn faster.", "fx": {"raise_cd": 1}},
		 {"id": "harvest", "name": "Soul Harvest", "desc": "Heal 4 HP whenever a hero dies, and heroes drop +2 gold.", "fx": {"kill_heal": 4, "kill_gold": 2}}]],
	"flayer": [
		[{"id": "ironwill", "name": "Iron Will", "desc": "Dominate recharges 1 turn faster.", "fx": {"dominate_cd": 1}},
		 {"id": "echo", "name": "Echoing Scream", "desc": "Psychic Scream deals +3 damage and reaches 2 tiles farther.", "fx": {"scream_dmg": 3, "scream_rng": 2}}],
		[{"id": "thrallmaster", "name": "Thrall Master", "desc": "Your thralls get +6 HP and deal +2 damage.", "fx": {"thrall_hp": 6, "thrall_atk": 2}},
		 {"id": "mindshield", "name": "Mind Shield", "desc": "+1 armor and +6 max HP.", "fx": {"mon_armor": 1, "mon_hp": 6}}],
		[{"id": "madness", "name": "Lingering Madness", "desc": "Confusion lasts 1 more turn.", "fx": {"conf_turns": 1}},
		 {"id": "lash", "name": "Barbed Lash", "desc": "Psychic Lash deals +3 damage and reaches 1 tile farther.", "fx": {"mon_atk": 3, "mon_rng": 1}}],
		[{"id": "overmind", "name": "Overmind", "desc": "Dominate works on bosses.", "fx": {"dominate_boss": 1}},
		 {"id": "brainfeast", "name": "Brain Feast", "desc": "Heal 6 HP whenever a hero dies, and your spells deal +3 damage.", "fx": {"kill_heal": 6, "spell_dmg": 3}}]],
	"mimic": [
		[{"id": "irresistible", "name": "Irresistible", "desc": "Glittering Lure drags heroes 3 steps.", "fx": {"lure_steps": 1}},
		 {"id": "pockets", "name": "Deep Pockets", "desc": "Coin Shot can spend 10 more gold.", "fx": {"coin_cap": 10}}],
		[{"id": "bands", "name": "Iron Bands", "desc": "+1 armor.", "fx": {"mon_armor": 1}},
		 {"id": "bigteeth", "name": "Big Teeth", "desc": "Chomp deals +3 damage.", "fx": {"mon_atk": 3}}],
		[{"id": "savant", "name": "Trap Savant", "desc": "All traps deal +4 damage.", "fx": {"trap_dmg": 4}},
		 {"id": "hoarder", "name": "Hoarder", "desc": "+10 gold every dawn.", "fx": {"dawn_gold": 10}}],
		[{"id": "vault", "name": "Living Vault", "desc": "+3 wildcard trap slots.", "fx": {"wild_slots": 3}},
		 {"id": "gilded", "name": "Gilded Hide", "desc": "+15 max HP.", "fx": {"mon_hp": 15}}]],
	"darklord": [
		[{"id": "deephex", "name": "Deep Hex", "desc": "Hex lasts 1 more turn and reaches 6 tiles.", "fx": {"hex_turns": 1, "hex_rng": 2}},
		 {"id": "greaterward", "name": "Greater Ward", "desc": "Dark Ward soaks 4 more damage.", "fx": {"ward_amt": 4}}],
		[{"id": "oath", "name": "Squire's Oath", "desc": "The Squire gets +8 max HP and +1 armor.", "fx": {"sq_hp": 8, "sq_armor": 1}},
		 {"id": "scholar", "name": "Dark Scholar", "desc": "The Dark Lord gets +6 max HP, and his spells deal +2 damage.", "fx": {"mon_hp": 6, "spell_dmg": 2}}],
		[{"id": "warband", "name": "Warband", "desc": "Your minions get +3 HP and deal +1 damage.", "fx": {"minion_hp": 3, "minion_atk": 1}},
		 {"id": "unbreakable", "name": "Unbreakable", "desc": "Challenge reaches 1 tile farther, and the Squire gets +1 armor.", "fx": {"challenge_rng": 1, "sq_armor": 1}}],
		[{"id": "twinsouls", "name": "Twin Souls", "desc": "While bonded, both heal 2 HP at the start of each turn.", "fx": {"bond_regen": 2}},
		 {"id": "blackknight", "name": "Black Knight", "desc": "The Squire deals +3 damage and moves 1 tile farther.", "fx": {"sq_atk": 3, "sq_move": 1}}]],
}

static func perk_by_id(id: String) -> Dictionary:
	for k in PERKS:
		for pair in PERKS[k]:
			for p in pair:
				if p.id == id:
					return p
	return {}

## Every spell a monster can ever use, starting ones first. Pool spells carry the level they open at.
## who: "" for the monster itself, "squire" for the Dark Lord's partner.
static func spells_of(k: String, who := "") -> Array:
	var M: Dictionary = MONSTERS[k]
	var o := []
	if who == "squire" and not M.has("partner"):
		return o
	var base: Array = M.partner.specials if who == "squire" else M.specials
	o.append_array(base)   # starting spells have no "lvl": they're known from level 1
	for sp in SPELL_POOL.get(k, []):
		if sp.get("who", "") == who:
			o.append(sp)
	return o
