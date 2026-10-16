class_name BuildingCatalog
extends RefCounted
## Structures the player places on the wallpaper. Costs rise with each copy owned.

const COST_GROWTH := 0.5

const DEFS := {
	"hut": {
		"name": "Imp Hut",
		"desc": "Hires one imp. Untrained imps walk to pop-ups and X them out (small reward).",
		"cost": 20,
		"max": 12,
		"color": Color("a0522d"),
	},
	"dojo": {
		"name": "Imp Dojo",
		"desc": "Trains two imps from huts within 2 cells: they walk in, train for 6 s, and come out completing pop-ups for the full reward.",
		"cost": 50,
		"max": 6,
		"color": Color("b22222"),
		"radius": 2,
	},
	"coffee": {
		"name": "Coffee Cart",
		"desc": "Imps from huts within 2 cells move 25% faster (carts stack).",
		"cost": 40,
		"max": 4,
		"color": Color("6f4e37"),
		"radius": 2,
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
		"desc": "No pop-up spawns within 3 cells of it. Put it where the windows hurt most.",
		"cost": 70,
		"max": 3,
		"color": Color("ff8c00"),
		"radius": 3,
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
	"helpdesk": {
		"name": "Help Desk",
		"desc": "Imps learn to close Live Chat widgets, which otherwise dodge them.",
		"cost": 45,
		"max": 1,
		"color": Color("20b2aa"),
		"unlock": "hundred_closed",
	},
	"screensaver": {
		"name": "Screensaver",
		"desc": "Every 30 seconds, no pop-ups spawn for 6 seconds.",
		"cost": 55,
		"max": 1,
		"color": Color("9932cc"),
		"unlock": "clock_out",
	},
}

## Order shown in the build menu and bound to number keys 1..n.
const ORDER: Array[String] = ["hut", "dojo", "coffee", "ram", "firewall", "antivirus", "shrine", "helpdesk", "screensaver"]


## Buildings a run may build: base ones plus unlocked ones, in ORDER.
static func available(unlocked: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for id: String in ORDER:
		if DEFS[id].has("unlock") and not (str(DEFS[id]["unlock"]) in unlocked):
			continue
		out.append(id)
	return out


static func get_def(id: String) -> Dictionary:
	assert(DEFS.has(id), "Unknown building: " + id)
	var d: Dictionary = DEFS[id].duplicate(true)
	d["id"] = id
	return d


static func cost(id: String, owned: int, mult: float = 1.0) -> int:
	var base := Tuning.num("building.%s.cost" % id, float(DEFS[id]["cost"]))
	var growth := Tuning.num("building.cost_growth", COST_GROWTH)
	return int(round(base * (1.0 + growth * owned) * mult))


static func max_count(id: String) -> int:
	return Tuning.inum("building.%s.max" % id, int(DEFS[id]["max"]))


## Effect radius in cells (0 = global).
static func radius(id: String) -> int:
	return Tuning.inum("building.%s.radius" % id, int(DEFS[id].get("radius", 0)))


const REFUND := 0.5
const REFUND_ON_BREAK := 0.75


## Bytes returned when a building is demolished: half what was paid, three
## quarters during a coffee break.
static func refund(price_paid: int, in_break: bool) -> int:
	return int(floor(price_paid * (REFUND_ON_BREAK if in_break else REFUND)))
