class_name MetaSave
extends RefCounted
## Meta-progression that survives between runs: records, a bank of lifetime bytes,
## and perks bought with it. Stored as JSON in user://.

const PATH := "user://meta.json"

const PERKS := {
	"starter_hut": {"name": "Company Imp", "desc": "Every run starts with an Imp Hut already built.", "cost": 60},
	"extra_ram": {"name": "Factory RAM", "desc": "Every run starts with +20 system resources.", "cost": 40},
	"pocket_change": {"name": "Pocket Change", "desc": "Every run starts with 15 bytes.", "cost": 30},
	"veteran_imps": {"name": "Veteran Imps", "desc": "Imps start every run 20% faster.", "cost": 80},
}

## Sideways unlocks: each achievement adds content to the pools, never stats.
const ACHIEVEMENTS := {
	"clock_out": {"name": "Clocked Out", "desc": "Survive until 5 PM once.", "adds": "Cookie banners, the Screensaver, Consent Manager"},
	"hundred_closed": {"name": "Inbox Zero", "desc": "Close 100 pop-ups across all runs.", "adds": "Live Chat widgets, the Help Desk, Do Not Disturb"},
	"dojo_built": {"name": "Sensei", "desc": "Build an Imp Dojo in any run.", "adds": "Memory leaks, Garbage Collector"},
	"sp2_win": {"name": "Patched", "desc": "Clock out on Service Pack 2 or higher.", "adds": "Bragging rights (and SP3 to SP6)"},
}

var high_score := 0
var best_wave := 0
var runs := 0
var wins := 0
var lifetime_bytes := 0
var bank := 0
var lifetime_closed := 0
var lifetime_completed := 0
var dojos_built := 0
var max_tier_unlocked := 0
var best_tier_won := -1
var unlocks: Array[String] = []        ## perks bought with bank
var achievements: Array[String] = []   ## sideways unlocks earned


## Records a finished run and returns the achievement ids newly earned.
func record_run(run: RunState) -> Array[String]:
	runs += 1
	var worth := run.final_score()
	high_score = maxi(high_score, worth)
	best_wave = maxi(best_wave, run.wave)
	lifetime_bytes += worth
	bank += worth
	lifetime_closed += run.popups_closed
	lifetime_completed += run.popups_completed
	dojos_built += run.buildings_list.count("dojo")
	if run.won:
		wins += 1
		best_tier_won = maxi(best_tier_won, run.tier)
		max_tier_unlocked = clampi(maxi(max_tier_unlocked, run.tier + 1), 0, Ladder.max_tier())
	var earned: Array[String] = []
	if run.won:
		earned.append_array(_earn("clock_out"))
	if lifetime_closed >= 100:
		earned.append_array(_earn("hundred_closed"))
	if dojos_built > 0:
		earned.append_array(_earn("dojo_built"))
	if run.won and run.tier >= 2:
		earned.append_array(_earn("sp2_win"))
	return earned


func _earn(id: String) -> Array[String]:
	if id in achievements:
		return []
	achievements.append(id)
	return [id]


func has_achievement(id: String) -> bool:
	return id in achievements


## Progress text for the unlocks window.
func achievement_progress(id: String) -> String:
	match id:
		"clock_out":
			return "%d win(s)" % wins
		"hundred_closed":
			return "%d / 100 closed" % mini(lifetime_closed, 100)
		"dojo_built":
			return "%d dojo(s) built" % dojos_built
		"sp2_win":
			return "best win: SP%d" % best_tier_won if best_tier_won >= 0 else "no wins yet"
	return ""


func has(perk: String) -> bool:
	return perk in unlocks


func can_buy(perk: String) -> bool:
	return PERKS.has(perk) and not has(perk) and bank >= int(PERKS[perk]["cost"])


func buy(perk: String) -> bool:
	if not can_buy(perk):
		return false
	bank -= int(PERKS[perk]["cost"])
	unlocks.append(perk)
	return true


## Writes the perks and the unlocked content pools into a fresh run.
func apply_to_run(run: RunState) -> void:
	run.unlocked_popups = achievements.duplicate()
	run.unlocked_buildings = achievements.duplicate()
	run.unlocked_upgrades = achievements.duplicate()
	if has("starter_hut"):
		run.starting_buildings.append("hut")
	if has("extra_ram"):
		run.set_ram_max(run.ram_max + 20)
	if has("pocket_change"):
		run.add_bytes(15)
		run.score = 0  # starting cash is not a score
	if has("veteran_imps"):
		run.imp_speed_mult *= 1.2


func to_dict() -> Dictionary:
	return {
		"high_score": high_score,
		"best_wave": best_wave,
		"runs": runs,
		"lifetime_bytes": lifetime_bytes,
		"bank": bank,
		"unlocks": unlocks,
		"wins": wins,
		"lifetime_closed": lifetime_closed,
		"lifetime_completed": lifetime_completed,
		"dojos_built": dojos_built,
		"max_tier_unlocked": max_tier_unlocked,
		"best_tier_won": best_tier_won,
		"achievements": achievements,
	}


func from_dict(d: Dictionary) -> void:
	high_score = int(d.get("high_score", 0))
	best_wave = int(d.get("best_wave", 0))
	runs = int(d.get("runs", 0))
	lifetime_bytes = int(d.get("lifetime_bytes", 0))
	bank = int(d.get("bank", 0))
	wins = int(d.get("wins", 0))
	lifetime_closed = int(d.get("lifetime_closed", 0))
	lifetime_completed = int(d.get("lifetime_completed", 0))
	dojos_built = int(d.get("dojos_built", 0))
	max_tier_unlocked = clampi(int(d.get("max_tier_unlocked", 0)), 0, Ladder.max_tier())
	best_tier_won = int(d.get("best_tier_won", -1))
	unlocks.clear()
	for u: Variant in d.get("unlocks", []):
		if PERKS.has(str(u)):
			unlocks.append(str(u))
	achievements.clear()
	for a: Variant in d.get("achievements", []):
		if ACHIEVEMENTS.has(str(a)):
			achievements.append(str(a))


func save_to_disk(path: String = PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("MetaSave: could not open %s for writing" % path)
		return false
	f.store_string(JSON.stringify(to_dict(), "  "))
	f.close()
	return true


func load_from_disk(path: String = PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("MetaSave: %s is not valid JSON; ignoring" % path)
		return false
	from_dict(parsed)
	return true
