class_name SpawnSchedule
extends RefCounted
## Decides when the next pop-up appears and which type it is. Pure logic, seeded.

const MIN_INTERVAL := 0.7
const FIRST_WAVE_INTERVAL := 2.8
const INTERVAL_STEP := 0.25   ## seconds removed from the base interval per wave

var rng: RandomNumberGenerator


func _init(p_rng: RandomNumberGenerator = null) -> void:
	if p_rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	else:
		rng = p_rng


static func base_interval(wave: int) -> float:
	var first := Tuning.num("spawn.first_interval", FIRST_WAVE_INTERVAL)
	var step := Tuning.num("spawn.step", INTERVAL_STEP)
	var floor_v := Tuning.num("spawn.min_interval", MIN_INTERVAL)
	return maxf(floor_v, first - step * (wave - 1))


## Seconds until the next spawn. interval_mult > 1 slows the schedule down.
func next_interval(wave: int, interval_mult: float = 1.0) -> float:
	var jitter := rng.randf_range(0.7, 1.3)
	return base_interval(wave) * maxf(0.1, interval_mult) * jitter


## Weighted pick among the types unlocked by this wave.
func pick_type(wave: int) -> String:
	var ids := PopupCatalog.available_on_wave(wave)
	assert(ids.size() > 0, "No popup types available on wave %d" % wave)
	var total := 0.0
	for id: String in ids:
		total += PopupCatalog.weight(id)
	var roll := rng.randf() * total
	for id: String in ids:
		roll -= PopupCatalog.weight(id)
		if roll <= 0.0:
			return id
	return ids[ids.size() - 1]
