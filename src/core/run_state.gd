class_name RunState
extends RefCounted
## Pure state for a single run (one "session" at the desk). No scene dependencies,
## so it can be unit tested headless. Nodes observe it through signals.

signal bytes_changed(bytes: int)
signal score_changed(score: int)
signal ram_changed(used: int, maximum: int)
signal wave_changed(wave: int)
signal break_changed(in_break: bool)
signal overload_changed(active: bool, seconds_left: float)
signal crashed(reason: String)

const BASE_RAM := 100
const OVERLOAD_GRACE := 3.0
const BASE_CLOSE_BUTTON := 16
const WORKDAY_WAVES := 8        ## 9 AM to 5 PM, one wave per hour
const WORKDAY_START_HOUR := 9

## Seed for the run's RNG. -1 means randomize.
var seed := -1

# --- resources ---
var bytes := 0            ## spendable currency
var score := 0            ## total bytes ever earned this run
var ram_max := Tuning.inum("run.base_ram", BASE_RAM)
var ram_used := 0

# --- wave clock ---
var wave := 1
var wave_time_left := 0.0
var in_break := false
var elapsed := 0.0
var won := false             ## clocked out at 5 PM
var overtime := false        ## kept working after the win
var tier := 0                ## Service Pack level (Ladder)

# --- content pools unlocked for this run (ids); empty means catalog default ---
var unlocked_popups: Array[String] = []
var unlocked_buildings: Array[String] = []
var unlocked_upgrades: Array[String] = []

# --- crash state ---
var overload_timer := 0.0
var overloaded := false
var crashed_flag := false
var crash_reason := ""

# --- modifiers (upgrades / buildings write these) ---
var dismiss_mult := 1.0
var complete_mult := 1.0
var interval_mult := 1.0      ## >1 means pop-ups spawn slower
var imp_speed_mult := 1.0
var imp_work_mult := 1.0      ## <1 means imps finish work faster
var ram_cost_reduction := 0
var close_button_size := BASE_CLOSE_BUTTON
var click_bonus := 0          ## extra bytes per manual close
var timeouts_multiply := true
var timeout_multiplier := 1      ## clones per multiply timeout (ladder raises it)
var building_cost_mult := 1.0
var overload_grace_override := -1.0
var helpdesk := false            ## imps may work on imp-proof pop-ups
var leak_growth_mult := 1.0      ## Garbage Collector halves it
var consent_manager := false     ## cookie banners complete in one click
var chat_spawn_mult := 1.0       ## Do Not Disturb lowers chat widget weight
var starting_buildings: Array[String] = []
var upgrade_counts := {}      ## upgrade id -> times picked

# --- stats ---
var popups_spawned := 0
var popups_closed := 0
var popups_completed := 0
var player_closes := 0
var imp_closes := 0
var imps_hired := 0
var buildings_built := 0
var buildings_list: Array[String] = []   ## building ids in build order
var upgrades_picked: Array[String] = []  ## upgrade ids in pick order
var wave_log: Array[Dictionary] = []     ## one snapshot per completed wave


## Snapshot the run at the end of a wave (called when the break begins).
func log_wave_end(imps: int, trained: int) -> void:
	wave_log.append({
		"wave": wave, "score": score, "bytes": bytes, "ram_max": ram_max, "ram_used": ram_used,
		"spawned": popups_spawned, "closed": popups_closed, "completed": popups_completed,
		"player_closes": player_closes, "imp_closes": imp_closes, "imps": imps, "trained": trained,
		"buildings": buildings_built, "elapsed": snappedf(elapsed, 0.01),
	})


## Flat summary of the run for logs and JSONL.
func summary() -> Dictionary:
	return {
		"seed": seed, "reason": crash_reason, "wave": wave, "score": score, "bytes": bytes,
		"elapsed": snappedf(elapsed, 0.01), "spawned": popups_spawned, "closed": popups_closed,
		"completed": popups_completed, "player_closes": player_closes, "imp_closes": imp_closes,
		"imps_hired": imps_hired, "buildings_built": buildings_built, "buildings": buildings_list,
		"upgrades": upgrades_picked, "ram_max": ram_max, "waves": wave_log, "tune": Tuning.spec,
		"tier": tier, "won": won, "overtime": overtime,
	}


static func wave_duration(w: int) -> float:
	return Tuning.num("run.wave_base", 50.0) + Tuning.num("run.wave_step", 5.0) * (w - 1)


func overload_grace() -> float:
	if overload_grace_override > 0.0:
		return overload_grace_override
	return Tuning.num("run.overload_grace", OVERLOAD_GRACE)


## True when the wave that just finished was the last hour of the workday.
func workday_over() -> bool:
	return not overtime and wave >= WORKDAY_WAVES and wave_time_left <= 0.0


## Hour and minute of the in-game clock for the taskbar: wave w is hour 9+w-1.
func clock() -> Dictionary:
	var hour := WORKDAY_START_HOUR + wave - 1
	var dur := wave_duration(wave)
	var frac := 1.0 - clampf(wave_time_left / maxf(0.001, dur), 0.0, 1.0)
	if in_break:
		frac = 1.0
	return {"hour": hour, "minute": int(floor(frac * 59.0))}


func clock_out() -> void:
	won = true


func start_overtime() -> void:
	overtime = true
	start_wave(wave + 1)


func start_wave(w: int) -> void:
	wave = w
	wave_time_left = wave_duration(w)
	in_break = false
	wave_changed.emit(wave)
	break_changed.emit(false)


func tick(delta: float) -> void:
	if crashed_flag:
		return
	elapsed += delta
	if in_break:
		return
	wave_time_left = maxf(0.0, wave_time_left - delta)
	_check_overload(delta)


func wave_finished() -> bool:
	return not in_break and wave_time_left <= 0.0


func begin_break() -> void:
	in_break = true
	_set_overloaded(false)
	break_changed.emit(true)


func end_break() -> void:
	start_wave(wave + 1)


func add_bytes(n: int) -> void:
	if n == 0:
		return
	bytes += n
	if n > 0:
		score += n
		score_changed.emit(score)
	bytes_changed.emit(bytes)


func spend(n: int) -> bool:
	if n > bytes:
		return false
	bytes -= n
	bytes_changed.emit(bytes)
	return true


## Reward for closing a pop-up with the given definition.
func reward_for(def: Dictionary, completed: bool) -> int:
	var base: int = def.get("complete_reward", 5) if completed else def.get("dismiss_reward", 1)
	var mult := complete_mult if completed else dismiss_mult
	var r := int(round(base * mult))
	return maxi(r, 1) if base > 0 else 0


## RAM a pop-up of this definition occupies while open, after modifiers.
func popup_cost(def: Dictionary) -> int:
	return maxi(1, int(def.get("ram_cost", 8)) - ram_cost_reduction)


func popup_opened(cost: int) -> void:
	ram_used += cost
	popups_spawned += 1
	ram_changed.emit(ram_used, ram_max)


func popup_closed(cost: int, completed: bool, by_imp: bool) -> void:
	ram_used = maxi(0, ram_used - cost)
	popups_closed += 1
	if completed:
		popups_completed += 1
	if by_imp:
		imp_closes += 1
	else:
		player_closes += 1
	ram_changed.emit(ram_used, ram_max)


func add_ram_cost(extra: int) -> void:
	ram_used += extra
	ram_changed.emit(ram_used, ram_max)


func set_ram_max(value: int) -> void:
	ram_max = value
	ram_changed.emit(ram_used, ram_max)


func ram_fraction() -> float:
	return float(ram_used) / float(maxi(1, ram_max))


func _check_overload(delta: float) -> void:
	if ram_used > ram_max:
		overload_timer += delta
		_set_overloaded(true)
		if overload_timer >= overload_grace():
			crash("OUT_OF_MEMORY")
	else:
		overload_timer = 0.0
		_set_overloaded(false)


func _set_overloaded(active: bool) -> void:
	var changed := active != overloaded
	overloaded = active
	if not active:
		overload_timer = 0.0
	if changed or active:
		overload_changed.emit(active, maxf(0.0, overload_grace() - overload_timer))


func crash(reason: String) -> void:
	if crashed_flag:
		return
	crashed_flag = true
	crash_reason = reason
	crashed.emit(reason)
