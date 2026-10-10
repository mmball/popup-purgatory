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

var high_score := 0
var best_wave := 0
var runs := 0
var lifetime_bytes := 0
var bank := 0
var unlocks: Array[String] = []


func record_run(run: RunState) -> void:
	runs += 1
	high_score = maxi(high_score, run.score)
	best_wave = maxi(best_wave, run.wave)
	lifetime_bytes += run.score
	bank += run.score


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


## Writes the perks into a fresh run.
func apply_to_run(run: RunState) -> void:
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
	}


func from_dict(d: Dictionary) -> void:
	high_score = int(d.get("high_score", 0))
	best_wave = int(d.get("best_wave", 0))
	runs = int(d.get("runs", 0))
	lifetime_bytes = int(d.get("lifetime_bytes", 0))
	bank = int(d.get("bank", 0))
	unlocks.clear()
	for u: Variant in d.get("unlocks", []):
		if PERKS.has(str(u)):
			unlocks.append(str(u))


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
