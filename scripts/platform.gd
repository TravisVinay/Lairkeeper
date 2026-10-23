extends Node
## Storefront hooks, autoloaded as `Platform`. Uses GodotSteam when its singleton is present
## and does nothing otherwise, so the same project runs in the editor, on mobile and on
## desktop builds without Steam.

## Replace with your Steam App ID once Valve assigns one. 480 is Valve's public test app.
const STEAM_APP_ID := 480

const ACHIEVEMENTS := {
	"first_night": "ACH_FIRST_NIGHT",
	"night_5": "ACH_NIGHT_5",
	"night_10": "ACH_NIGHT_10",
	"paladin": "ACH_PALADIN_SLAIN",
}

var steam: Object = null


func _ready() -> void:
	if not Engine.has_singleton("Steam"):
		return
	steam = Engine.get_singleton("Steam")
	if steam.has_method("steamInitEx"):
		steam.steamInitEx(STEAM_APP_ID, true)
	elif steam.has_method("steamInit"):
		steam.steamInit()


func _process(_dt: float) -> void:
	if steam and steam.has_method("run_callbacks"):
		steam.run_callbacks()


func unlock(key: String) -> void:
	if steam == null or not ACHIEVEMENTS.has(key):
		return
	steam.setAchievement(ACHIEVEMENTS[key])
	steam.storeStats()


func on_night_survived(day: int) -> void:
	if day >= 1: unlock("first_night")
	if day >= 5: unlock("night_5")
	if day >= 10: unlock("night_10")


func on_hero_slain(kind: String) -> void:
	if kind == "paladin":
		unlock("paladin")
