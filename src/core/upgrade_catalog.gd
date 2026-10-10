class_name UpgradeCatalog
extends RefCounted
## Between-wave picks. `apply` mutates the RunState; the desktop handles the few
## upgrades that need scene access by reading the returned effect tag.

const DEFS := {
	"bigger_x": {"name": "Bigger X Buttons", "desc": "Close buttons grow by 8px. Easier to hit.", "max": 2},
	"more_ram": {"name": "Memory Upgrade", "desc": "+24 system resources.", "max": 5},
	"fast_imps": {"name": "Espresso Shots", "desc": "Imps move 25% faster.", "max": 4},
	"quick_hands": {"name": "Quick Hands", "desc": "Imps finish their work 25% faster.", "max": 3},
	"dismiss_bonus": {"name": "Reflex Clicking", "desc": "Dismissing (X) pays double.", "max": 2},
	"complete_bonus": {"name": "Thoroughness", "desc": "Completing a pop-up pays 50% more.", "max": 3},
	"spawn_slower": {"name": "Ad Blocker (trial)", "desc": "Pop-ups spawn 15% slower.", "max": 3},
	"free_imp": {"name": "Stray Imp", "desc": "An imp wanders in and starts working for free.", "max": 99},
	"lean_popups": {"name": "Lean Windows", "desc": "Every pop-up uses 2 less RAM.", "max": 3},
	"click_bonus": {"name": "Mouse Blessing", "desc": "+1 byte per pop-up you close yourself.", "max": 3},
	"antivirus_patch": {"name": "Hotfix KB98", "desc": "Timed-out pop-ups no longer multiply.", "max": 1},
	"bytes_now": {"name": "Found Change", "desc": "+40 bytes right now.", "max": 99},
	"consent_manager": {"name": "Consent Manager", "desc": "Cookie banners come pre-rejected: one click completes them.", "max": 1, "unlock": "clock_out"},
	"do_not_disturb": {"name": "Do Not Disturb", "desc": "Live Chat widgets appear half as often.", "max": 1, "unlock": "hundred_closed"},
	"garbage_collector": {"name": "Garbage Collector", "desc": "Memory leaks grow half as fast.", "max": 1, "unlock": "dojo_built"},
}


static func get_def(id: String) -> Dictionary:
	assert(DEFS.has(id), "Unknown upgrade: " + id)
	var d: Dictionary = DEFS[id].duplicate(true)
	d["id"] = id
	return d


static func eligible(run: RunState) -> Array[String]:
	var out: Array[String] = []
	for id: String in DEFS.keys():
		var picked: int = int(run.upgrade_counts.get(id, 0))
		if picked >= int(DEFS[id]["max"]):
			continue
		if id == "antivirus_patch" and not run.timeouts_multiply:
			continue
		if DEFS[id].has("unlock") and not (str(DEFS[id]["unlock"]) in run.unlocked_upgrades):
			continue
		out.append(id)
	return out


## Returns `count` distinct eligible upgrade definitions.
static func roll(rng: RandomNumberGenerator, run: RunState, count: int = 3) -> Array[Dictionary]:
	var pool := eligible(run)
	var out: Array[Dictionary] = []
	while out.size() < count and pool.size() > 0:
		var i := rng.randi_range(0, pool.size() - 1)
		out.append(get_def(pool[i]))
		pool.remove_at(i)
	return out


## Applies the upgrade to the run. Returns an effect tag the desktop may act on
## ("spawn_imp", "resize_x", or "").
static func apply(id: String, run: RunState) -> String:
	run.upgrade_counts[id] = int(run.upgrade_counts.get(id, 0)) + 1
	match id:
		"bigger_x":
			run.close_button_size += 8
			return "resize_x"
		"more_ram":
			run.set_ram_max(run.ram_max + Tuning.inum("upgrade.more_ram.amount", 24))
		"fast_imps":
			run.imp_speed_mult *= 1.25
		"quick_hands":
			run.imp_work_mult *= 0.75
		"dismiss_bonus":
			run.dismiss_mult *= 2.0
		"complete_bonus":
			run.complete_mult *= 1.5
		"spawn_slower":
			run.interval_mult *= 1.18
		"free_imp":
			return "spawn_imp"
		"lean_popups":
			run.ram_cost_reduction += 2
		"click_bonus":
			run.click_bonus += 1
		"antivirus_patch":
			run.timeouts_multiply = false
		"bytes_now":
			run.add_bytes(40)
		"consent_manager":
			run.consent_manager = true
		"do_not_disturb":
			run.chat_spawn_mult *= 0.5
		"garbage_collector":
			run.leak_growth_mult *= 0.5
	return ""
