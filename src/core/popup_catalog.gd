class_name PopupCatalog
extends RefCounted
## Data definitions for every pop-up type. Content scripts live in src/popups/content/.
##
## Fields:
##   title            window title
##   size             window size in pixels
##   ram_cost         system resources occupied while open
##   dismiss_reward   bytes for clicking the X
##   complete_reward  bytes for doing what the pop-up actually asks (always higher)
##   imp_complete_time seconds a trained imp needs to complete it (dismiss is always fast)
##   min_wave         first wave this type can spawn on
##   weight           relative spawn weight once unlocked
##   lifetime         seconds before on_timeout fires (0 = never)
##   on_timeout       {kind: "none"|"multiply"|"spawn"|"escalate", type, count}
##   x_lock           seconds the X button is disabled after spawning
##   content          script path for the window body

const DEFS := {
	"ad": {
		"title": "Congratulations!!!",
		"size": Vector2(300, 170),
		"ram_cost": 8,
		"dismiss_reward": 1,
		"complete_reward": 4,
		"imp_complete_time": 1.5,
		"min_wave": 1,
		"weight": 10,
		"lifetime": 0.0,
		"on_timeout": {"kind": "none"},
		"x_lock": 0.0,
		"content": "res://src/popups/content/ad_content.gd",
	},
	"error": {
		"title": "Error",
		"size": Vector2(320, 140),
		"ram_cost": 6,
		"dismiss_reward": 1,
		"complete_reward": 2,
		"imp_complete_time": 0.8,
		"min_wave": 1,
		"weight": 9,
		"lifetime": 12.0,
		"on_timeout": {"kind": "multiply", "count": 1},
		"x_lock": 0.0,
		"content": "res://src/popups/content/error_content.gd",
	},
	"survey": {
		"title": "Quick Survey",
		"size": Vector2(320, 190),
		"ram_cost": 10,
		"dismiss_reward": 1,
		"complete_reward": 5,
		"imp_complete_time": 2.5,
		"min_wave": 2,
		"weight": 7,
		"lifetime": 0.0,
		"on_timeout": {"kind": "none"},
		"x_lock": 0.0,
		"content": "res://src/popups/content/survey_content.gd",
	},
	"update": {
		"title": "Update Available",
		"size": Vector2(340, 170),
		"ram_cost": 10,
		"dismiss_reward": 1,
		"complete_reward": 6,
		"imp_complete_time": 3.0,
		"min_wave": 2,
		"weight": 6,
		"lifetime": 0.0,
		"on_timeout": {"kind": "none"},
		"x_lock": 0.0,
		"content": "res://src/popups/content/update_content.gd",
	},
	"newsletter": {
		"title": "Join our Newsletter",
		"size": Vector2(320, 210),
		"ram_cost": 10,
		"dismiss_reward": 1,
		"complete_reward": 6,
		"imp_complete_time": 3.0,
		"min_wave": 3,
		"weight": 6,
		"lifetime": 0.0,
		"on_timeout": {"kind": "none"},
		"x_lock": 0.0,
		"content": "res://src/popups/content/newsletter_content.gd",
	},
	"captcha": {
		"title": "Security Check",
		"size": Vector2(320, 180),
		"ram_cost": 12,
		"dismiss_reward": 1,
		"complete_reward": 8,
		"imp_complete_time": 3.5,
		"min_wave": 3,
		"weight": 5,
		"lifetime": 20.0,
		"on_timeout": {"kind": "escalate", "count": 4},
		"x_lock": 0.0,
		"content": "res://src/popups/content/captcha_content.gd",
	},
	"toolbar": {
		"title": "Searchy Toolbar Setup",
		"size": Vector2(360, 220),
		"ram_cost": 14,
		"dismiss_reward": 1,
		"complete_reward": 7,
		"imp_complete_time": 4.0,
		"min_wave": 4,
		"weight": 5,
		"lifetime": 0.0,
		"on_timeout": {"kind": "none"},
		"x_lock": 0.0,
		"content": "res://src/popups/content/toolbar_content.gd",
	},
	"virus": {
		"title": "!!! WARNING !!!",
		"size": Vector2(340, 200),
		"ram_cost": 16,
		"dismiss_reward": 2,
		"complete_reward": 10,
		"imp_complete_time": 3.0,
		"min_wave": 5,
		"weight": 4,
		"lifetime": 15.0,
		"on_timeout": {"kind": "spawn", "type": "error", "count": 2},
		"x_lock": 3.0,
		"content": "res://src/popups/content/virus_content.gd",
	},
}


const TUNABLE_INT := ["ram_cost", "dismiss_reward", "complete_reward"]
const TUNABLE_FLOAT := ["lifetime", "weight", "imp_complete_time"]


static func get_def(id: String) -> Dictionary:
	assert(DEFS.has(id), "Unknown popup type: " + id)
	var d: Dictionary = DEFS[id].duplicate(true)
	d["id"] = id
	for f: String in TUNABLE_INT:
		d[f] = Tuning.inum("popup.%s.%s" % [id, f], int(d[f]))
	for f: String in TUNABLE_FLOAT:
		d[f] = Tuning.num("popup.%s.%s" % [id, f], float(d[f]))
	return d


## Spawn weight after tuning (the schedule reads this, not DEFS directly).
static func weight(id: String) -> float:
	return Tuning.num("popup.%s.weight" % id, float(DEFS[id]["weight"]))


static func ids() -> Array[String]:
	var out: Array[String] = []
	for k: String in DEFS.keys():
		out.append(k)
	return out


static func available_on_wave(wave: int) -> Array[String]:
	var out: Array[String] = []
	for k: String in DEFS.keys():
		if int(DEFS[k]["min_wave"]) <= wave:
			out.append(k)
	return out
