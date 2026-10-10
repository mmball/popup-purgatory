class_name BuildingCatalog
extends RefCounted
## Structures the player places on the wallpaper. Costs rise with each copy owned.

const COST_GROWTH := 0.5

const DEFS := {
	"hut": {
		"name": "Imp Hut",
		"desc": "Hires one imp. Imps walk to pop-ups and X them out.",
		"cost": 20,
		"max": 12,
		"color": Color("a0522d"),
	},
	"dojo": {
		"name": "Imp Dojo",
		"desc": "Trains two imps to complete pop-ups instead of dismissing them.",
		"cost": 50,
		"max": 6,
		"color": Color("b22222"),
	},
	"coffee": {
		"name": "Coffee Cart",
		"desc": "All imps move 25% faster.",
		"cost": 40,
		"max": 4,
		"color": Color("6f4e37"),
	},
	"ram": {
		"name": "RAM Stick",
		"desc": "+32 system resources before the machine crashes.",
		"cost": 35,
		"max": 6,
		"color": Color("2e8b57"),
	},
	"firewall": {
		"name": "Firewall",
		"desc": "Pop-ups spawn 15% slower.",
		"cost": 70,
		"max": 3,
		"color": Color("ff8c00"),
	},
	"antivirus": {
		"name": "Antivirus Shrine",
		"desc": "Pop-ups that time out no longer multiply.",
		"cost": 60,
		"max": 1,
		"color": Color("ffd700"),
	},
	"shrine": {
		"name": "Pointer Shrine",
		"desc": "+1 byte every time you close a pop-up yourself.",
		"cost": 60,
		"max": 3,
		"color": Color("4169e1"),
	},
}

## Order shown in the build menu and bound to number keys 1..n.
const ORDER: Array[String] = ["hut", "dojo", "coffee", "ram", "firewall", "antivirus", "shrine"]


static func get_def(id: String) -> Dictionary:
	assert(DEFS.has(id), "Unknown building: " + id)
	var d: Dictionary = DEFS[id].duplicate(true)
	d["id"] = id
	return d


static func cost(id: String, owned: int) -> int:
	var base := Tuning.num("building.%s.cost" % id, float(DEFS[id]["cost"]))
	var growth := Tuning.num("building.cost_growth", COST_GROWTH)
	return int(round(base * (1.0 + growth * owned)))


static func max_count(id: String) -> int:
	return Tuning.inum("building.%s.max" % id, int(DEFS[id]["max"]))
