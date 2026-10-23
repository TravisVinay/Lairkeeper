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
}

const UNITS := {
	"goblin": {"name": "Goblin", "hp": 8, "move": 3, "atk": 3, "rng": 1, "cost": 15},
	"hound": {"name": "Hellhound", "hp": 11, "move": 5, "atk": 4, "rng": 1, "cost": 25},
	"spawn": {"name": "Vampire Spawn", "hp": 10, "move": 4, "atk": 4, "rng": 1, "leech": true, "undead": true, "cost": 30},
	"skeleton": {"name": "Skeleton", "hp": 6, "move": 2, "atk": 3, "rng": 1, "undead": true, "cost": 8},
	"thrall": {"name": "Thrall", "hp": 10, "move": 3, "atk": 3, "rng": 1, "cost": 18},
	"ghoul": {"name": "Ghoul", "hp": 11, "move": 3, "atk": 4, "rng": 1, "undead": true},
	"peasant": {"name": "Peasant", "hp": 9, "move": 3, "atk": 2, "rng": 1, "gold": 6, "col": "#a8794e"},
	"rogue": {"name": "Rogue", "hp": 10, "move": 4, "atk": 3, "rng": 1, "gold": 10, "col": "#7b5aac", "sense": true, "thief": true, "note": "Spots traps. Robs your Treasury and runs for the exit."},
	"archer": {"name": "Archer", "hp": 9, "move": 3, "atk": 3, "rng": 4, "gold": 10, "col": "#6e9a5a", "note": "Shoots 4 tiles. Walls and furniture block arrows."},
	"knight": {"name": "Knight", "hp": 18, "move": 2, "atk": 4, "rng": 1, "armor": 1, "gold": 14, "col": "#b9c3cd", "note": "Armor blocks 1 damage per hit."},
	"cleric": {"name": "Cleric", "hp": 12, "move": 3, "atk": 2, "rng": 1, "heal": 5, "holy": true, "gold": 12, "col": "#efe6cf", "note": "Heals heroes within 3. Holy: +3 damage to undead and vampires."},
	"sapper": {"name": "Dwarf Sapper", "hp": 13, "move": 3, "atk": 3, "rng": 1, "armor": 1, "sense": true, "disarm": true, "gold": 13, "col": "#b0703a", "note": "Dismantles every trap next to him. Permanently."},
	"mage": {"name": "Battle Mage", "hp": 10, "move": 3, "atk": 4, "rng": 3, "splash": true, "gold": 15, "col": "#4f7fd8", "note": "Fireballs also hit everything next to the target."},
	"barbarian": {"name": "Barbarian", "hp": 24, "move": 3, "atk": 6, "rng": 1, "gold": 16, "col": "#c0603a", "note": "Huge HP, huge hits."},
	"paladin": {"name": "Paladin", "hp": 40, "move": 2, "atk": 6, "rng": 1, "armor": 2, "holy": true, "gold": 60, "col": "#e3b23f", "boss": true, "note": "Boss. Armor blocks 2. Holy."},
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

# Furniture is [x, y, kind, blocks] in room-local tiles. Blocking pieces only sit on the four
# corners or the four inner diagonals, never on a doorway or the center cross, so every door connects.
const ROOMS := {
	"lair": {"name": "Your Lair", "col": "#c0304c", "fixed": true, "cost": [0, 40, 70, 100], "next": "+6 max HP",
		"objs": [[1, 1, "pillar", 1], [3, 1, "pillar", 1], [1, 3, "pillar", 1], [3, 3, "pillar", 1], [2, 1, "throne"], [2, 2, "rug"], [2, 3, "rug"], [0, 0, "brazier", 1], [4, 0, "brazier", 1]]},
	"treasury": {"name": "Treasury", "col": "#e4a648", "cost": [25, 40, 60],
		"objs": [[0, 0, "chest", 1], [4, 0, "chest", 1], [3, 1, "chest", 1], [0, 4, "coins"], [4, 4, "coins"], [1, 1, "coins"], [3, 3, "coins"]]},
	"larder": {"name": "Larder", "col": "#d08a5a", "cost": [20, 35, 50],
		"objs": [[1, 1, "table", 1], [3, 1, "table", 1], [0, 4, "barrel", 1], [4, 4, "barrel", 1], [0, 0, "meat"], [4, 0, "meat"], [1, 3, "meat"]]},
	"barracks": {"name": "Goblin Barracks", "col": "#86b35e", "cost": [25, 40, 60], "recruit": "goblin", "cap": 2,
		"objs": [[0, 0, "bunk", 1], [4, 0, "bunk", 1], [1, 1, "bunk", 1], [3, 1, "bunk", 1], [2, 2, "fire"], [0, 4, "rack", 1], [4, 4, "rack", 1]]},
	"kennel": {"name": "Hellhound Kennel", "col": "#d9573f", "cost": [40, 65], "recruit": "hound", "cap": 1,
		"objs": [[0, 0, "cage", 1], [4, 0, "cage", 1], [0, 4, "cage", 1], [4, 4, "cage", 1], [1, 1, "bones"], [3, 3, "bones"], [3, 1, "bones"]]},
	"workshop": {"name": "Trap Workshop", "col": "#9aa7b6", "cost": [25, 40, 60],
		"objs": [[1, 1, "anvil", 1], [3, 1, "bench", 1], [3, 3, "bench", 1], [1, 3, "gear"], [0, 4, "gear"]]},
	"armory": {"name": "Armory", "col": "#b9c3cd", "cost": [30, 50, 75],
		"objs": [[0, 0, "rack", 1], [4, 0, "rack", 1], [0, 4, "rack", 1], [4, 4, "rack", 1], [1, 1, "armor", 1], [3, 3, "armor", 1]]},
	"cistern": {"name": "Flooded Cistern", "col": "#4f8fbf", "cost": [30, 50],
		"objs": [[1, 1, "pillar", 1], [3, 1, "pillar", 1], [1, 3, "pillar", 1], [3, 3, "pillar", 1]]},
	"torture": {"name": "Torture Chamber", "col": "#b8243c", "cost": [35, 55, 80],
		"objs": [[1, 1, "rack2", 1], [3, 1, "maiden", 1], [1, 3, "chains"], [3, 3, "blood"], [2, 2, "blood"], [0, 4, "chains"]]},
	"collapse": {"name": "Collapsing Hall", "col": "#8a7f90", "cost": [30, 50, 75],
		"objs": [[1, 1, "cracked", 1], [3, 3, "cracked", 1], [3, 1, "rubble"], [1, 3, "rubble"], [0, 0, "rubble"]]},
	"library": {"owner": "lich", "name": "Arcane Library", "col": "#9b84ff", "cost": [35, 55, 80],
		"objs": [[0, 0, "shelf", 1], [4, 0, "shelf", 1], [1, 1, "shelf", 1], [3, 1, "shelf", 1], [0, 4, "shelf", 1], [4, 4, "shelf", 1], [2, 2, "candles"], [1, 3, "candles"]]},
	"manawell": {"owner": "lich", "name": "Mana Well", "col": "#7fb4ff", "cost": [40, 70],
		"objs": [[2, 2, "well"], [1, 1, "crystal", 1], [3, 3, "crystal", 1], [3, 1, "runecircle"], [1, 3, "runecircle"]]},
	"phylactery": {"owner": "lich", "name": "Phylactery Vault", "col": "#d6c8ff", "cost": [40, 60, 85],
		"objs": [[1, 1, "pillar", 1], [3, 1, "pillar", 1], [2, 2, "altar"], [1, 3, "candles"], [3, 3, "candles"]]},
	"crypt": {"owner": "vampire", "name": "Crypt of Brides", "col": "#e0405a", "cost": [35, 55, 75], "recruit": "spawn", "cap": 2,
		"objs": [[1, 1, "coffin", 1], [3, 1, "coffin", 1], [1, 3, "coffin", 1], [3, 3, "coffin", 1], [2, 2, "blood"]]},
	"bloodpool": {"owner": "vampire", "name": "Blood Pool", "col": "#a3122c", "cost": [35, 55, 80],
		"objs": [[2, 2, "pool"], [1, 1, "pillar", 1], [3, 3, "pillar", 1], [3, 1, "blood"], [1, 3, "blood"]]},
	"coffin": {"owner": "vampire", "name": "Velvet Coffin", "col": "#8a4b6a", "cost": [30, 50, 70], "next": "+8 max HP",
		"objs": [[2, 1, "bigcoffin"], [1, 1, "candles"], [3, 1, "candles"], [0, 4, "pillar", 1], [4, 4, "pillar", 1]]},
	"graveyard": {"owner": "necro", "name": "Graveyard", "col": "#6fd3a0", "cost": [25, 40, 60], "recruit": "skeleton", "cap": 3,
		"objs": [[1, 1, "tomb", 1], [3, 1, "tomb", 1], [1, 3, "tomb", 1], [3, 3, "tomb", 1], [0, 0, "tomb", 1], [4, 4, "tomb", 1], [2, 2, "bones"]]},
	"boneforge": {"owner": "necro", "name": "Bone Forge", "col": "#cfe8d8", "cost": [35, 55, 80],
		"objs": [[1, 1, "forge", 1], [3, 1, "anvil", 1], [1, 3, "bones"], [3, 3, "bones"], [4, 4, "bones"]]},
	"soulcage": {"owner": "necro", "name": "Soul Cage", "col": "#58a88a", "cost": [40, 70],
		"objs": [[1, 1, "cage", 1], [3, 1, "cage", 1], [2, 2, "wisp"], [1, 3, "wisp"]]},
	"thrallpens": {"owner": "flayer", "name": "Thrall Pens", "col": "#a48ac0", "cost": [30, 50, 70], "recruit": "thrall", "cap": 2,
		"objs": [[0, 0, "bars", 1], [4, 0, "bars", 1], [0, 4, "bars", 1], [4, 4, "bars", 1], [1, 1, "chains"], [3, 3, "chains"]]},
	"brainjars": {"owner": "flayer", "name": "Brain Jar Gallery", "col": "#c77dff", "cost": [30, 50, 75],
		"objs": [[0, 0, "jar", 1], [4, 0, "jar", 1], [1, 1, "jar", 1], [3, 1, "jar", 1], [0, 4, "jar", 1], [4, 4, "jar", 1], [2, 2, "runecircle"]]},
	"amplifier": {"owner": "flayer", "name": "Psionic Amplifier", "col": "#f08cff", "cost": [45, 80],
		"objs": [[1, 1, "crystal", 1], [3, 3, "crystal", 1], [3, 1, "crystal", 1], [2, 2, "wisp"]]},
	"clockwork": {"owner": "mimic", "name": "Clockwork Forge", "col": "#e4a648", "cost": [30, 50, 75],
		"objs": [[1, 1, "gearbig", 1], [3, 1, "gearbig", 1], [1, 3, "gear"], [3, 3, "gear"], [2, 2, "gear"]]},
	"snareden": {"owner": "mimic", "name": "Snare Den", "col": "#b08a5a", "cost": [25, 45],
		"objs": [[0, 0, "crate", 1], [4, 4, "crate", 1], [1, 1, "rope"], [3, 3, "rope"], [3, 1, "rope"]]},
	"runes": {"owner": "mimic", "name": "Rune Chamber", "col": "#ff7a3a", "cost": [35, 55, 80],
		"objs": [[2, 2, "runecircle"], [1, 1, "candles"], [3, 3, "candles"], [0, 4, "crystal", 1]]},
}
const EMPTY_OBJS := [[0, 4, "rubble"], [4, 0, "rubble"]]

const TRAPS := {
	"spikes": {"name": "Spike trap", "cost": 10, "desc": "Hurts every hero that steps on it. Permanent."},
	"snare": {"name": "Snare", "cost": 8, "desc": "Holds a hero in place through its next turn. Used up."},
	"rune": {"name": "Blast rune", "cost": 20, "desc": "Explodes in a 3x3 area. Used up."},
}

const BOONS := [
	{"id": "hide", "name": "Thick Hide", "desc": "+6 max HP and heal 6."},
	{"id": "claws", "name": "Cruel Claws", "desc": "Your basic attack deals +2 damage."},
	{"id": "surge", "name": "Arcane Surge", "desc": "Your damaging spells deal +2 damage."},
	{"id": "swift", "name": "Swift Shadow", "desc": "You move 1 extra tile."},
	{"id": "pack", "name": "Pack Tactics", "desc": "Your minions deal +1 damage."},
	{"id": "feast", "name": "Blood Feast", "desc": "Heal 3 HP whenever you kill a hero."},
	{"id": "rituals", "name": "Dark Rituals", "desc": "All your spells recharge 1 turn faster."},
	{"id": "greed", "name": "Greed", "desc": "Heroes drop 50% more gold."},
	{"id": "jagged", "name": "Jagged Traps", "desc": "Traps deal +3 damage."},
	{"id": "owl", "name": "Night Owl", "desc": "+1 hour of work every day."},
	{"id": "press", "name": "Press Gang", "desc": "A free goblin joins you now. It does not use barracks space."},
]


static func col(hex: String, a := 1.0) -> Color:
	var c := Color(hex)
	c.a = a
	return c


static func room_eff(t: String, l: int) -> String:
	match t:
		"lair": return "You start each fight on your throne and take 1 less damage while in here." + (" +%d max HP." % ((l - 1) * 6) if l > 1 else "")
		"treasury": return "+%d gold every dawn. Rogues try to rob it and run." % [12, 20, 30][l - 1]
		"larder": return "Heal %d HP every dawn." % [6, 10, 15][l - 1]
		"barracks": return "Recruit up to %d goblins." % (l * 2)
		"kennel": return "Recruit up to %d hellhound%s. Fast hunters." % [l, "s" if l > 1 else ""]
		"workshop": return "Room for %d traps. Unlocks %s." % [3 + l * 3, ["spikes", "spikes and snares", "spikes, snares and blast runes"][l - 1]]
		"armory": return "Your minions deal +%d damage." % l
		"cistern": return "Heroes in this room move %d tile%s less." % [l, "s" if l > 1 else ""]
		"torture": return "Heroes who start their turn in here take %d damage." % (2 + l)
		"collapse": return "Once per fight, drop the ceiling: %d damage to everyone inside, yours too." % (8 + (l - 1) * 4)
		"library": return "Your spells deal +%d damage." % (l * 2)
		"manawell": return "Your spells recharge %d turn%s faster." % [l, "s" if l > 1 else ""]
		"phylactery": return "Once per fight, when you die, reform at the altar with %d HP." % [8, 14, 20][l - 1]
		"crypt": return "Recruit up to %d vampire spawn. They drink blood too." % (l * 2)
		"bloodpool": return "Your claws deal +%d damage." % (l * 2)
		"coffin": return "+%d max HP." % (l * 8)
		"graveyard": return "Recruit up to %d skeletons. Cheap and plentiful." % (l * 3)
		"boneforge": return "All your undead get +%d HP and +%d damage." % [l * 2, l]
		"soulcage": return "Raise Dead recharges 1 turn faster." if l == 1 else "Raise Dead recharges faster and raises two skeletons."
		"thrallpens": return "Recruit up to %d brainwashed thralls." % (l * 2)
		"brainjars": return "Psychic Lash deals +%d damage." % (l * 2)
		"amplifier": return "Dominate recharges 1 turn faster." if l == 1 else "Dominate recharges faster and works on bosses."
		"clockwork": return "All your traps deal +%d damage." % (l * 2)
		"snareden": return "Unlocks snares. +%d trap slots." % (l * 3)
		"runes": return "Unlocks blast runes (%d damage in 3x3). +%d trap slots." % [6 + l * 3, l * 2]
	return ""
