class_name Tuning
extends RefCounted
## Runtime overrides of balance numbers, for parameter sweeps and quick experiments.
## Keys are dotted paths; values are numbers. Loaded once per process from
## `--tune=key=value,key=value`. Catalogs and RunState consult `num()`/`inum()`
## with their built-in value as the default, so with no overrides nothing changes.
##
## Known keys (defaults in parentheses):
##   run.base_ram (100)  run.overload_grace (3.0)  run.wave_base (40)  run.wave_step (5)
##   spawn.first_interval (2.8)  spawn.step (0.25)  spawn.min_interval (0.7)
##   popup.<id>.ram_cost | dismiss_reward | complete_reward | lifetime | weight | imp_complete_time
##   building.<id>.cost | max      building.cost_growth (0.5)
##   upgrade.more_ram.amount (24)  imp.base_speed (90)  imp.dismiss_time (0.6)

static var overrides: Dictionary = {}
static var spec := ""


static func load_from_string(p_spec: String) -> void:
	overrides.clear()
	spec = p_spec.strip_edges()
	if spec == "":
		return
	for pair: String in spec.split(",", false):
		var eq := pair.find("=")
		if eq <= 0:
			push_warning("Tuning: ignoring malformed override '%s'" % pair)
			continue
		var key := pair.substr(0, eq).strip_edges()
		var val := pair.substr(eq + 1).strip_edges()
		if not val.is_valid_float():
			push_warning("Tuning: ignoring non-numeric override '%s'" % pair)
			continue
		overrides[key] = float(val)


static func clear() -> void:
	overrides.clear()
	spec = ""


static func num(key: String, base: float) -> float:
	return float(overrides.get(key, base))


static func inum(key: String, base: int) -> int:
	return int(round(float(overrides.get(key, base))))


static func has(key: String) -> bool:
	return overrides.has(key)
