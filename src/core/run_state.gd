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
var banked_score := 0        ## score at 5 PM; a crash in overtime keeps it plus half the rest
var tier := 0                ## Service Pack level (Ladder)

# --- streak: consecutive manual completions; any manual X resets it ---
const STREAK_STEP := 0.10
const STREAK_CAP := 5
var streak := 0
var best_streak := 0

# --- overtime terms ---
const OVERTIME_PAY := 1.5
const OVERTIME_SPAWN_STEP := 0.9   ## interval multiplier per overtime hour

# --- abilities: keyboard chords (and tray icons) with cooldowns ---
const ABILITIES := {
	"alt_f4": {"name": "Alt+F4", "cooldown": 0.0, "desc": "Dismiss the front window."},
	"task_manager": {"name": "Task Manager", "cooldown": 45.0, "desc": "Ctrl+Shift+Esc: End Task on a few pop-ups instantly."},
	"ctrl_alt_del": {"name": "Ctrl+Alt+Del", "cooldown": 0.0, "desc": "Hold to freeze the desk for up to 5 s, once an hour. Hold too long and the machine resets."},
}
const ABILITY_ORDER: Array[String] = ["alt_f4", "task_manager", "ctrl_alt_del"]
const FREEZE_MAX := 5.0           ## seconds Ctrl+Alt+Del may be held before the reset
const TASK_MANAGER_ENDS := 3
var ability_cooldowns := {}       ## id -> seconds left
var cooldown_mult := 1.0          ## Keyboard Shortcuts upgrade lowers it
var task_manager_ends := TASK_MANAGER_ENDS
var cad_used_this_hour := false
var frozen := false
var freeze_time := 0.0            ## seconds the current freeze has been held
var abilities_used := {}          ## id -> times used this run

# --- bosses: the Service Pack install at noon and 4 PM (waves 4 and 8) ---
const BOSS_WAVES: Array[int] = [4, 8]
const BOSS_REWARD := 60
var boss_active := false        ## the installer is up: spawns and the wave clock hold
var bosses_won := 0
var bosses_failed := 0

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

# --- recycle bin: drag a pop-up in to delete it, no reward, no penalty ---
const BIN_CAPACITY := 3
var bin_items := 0           ## windows in the bin; a full bin refuses drops until emptied
var popups_recycled := 0     ## never counted as closed or completed


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
		"tier": tier, "won": won, "overtime": overtime, "banked_score": banked_score,
		"final_score": final_score(), "best_streak": best_streak,
		"bin_items": bin_items, "popups_recycled": popups_recycled, "abilities": abilities_used,
		"bosses_won": bosses_won, "bosses_failed": bosses_failed,
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
	banked_score = score


func start_overtime() -> void:
	overtime = true
	start_wave(wave + 1)


func start_wave(w: int) -> void:
	wave = w
	wave_time_left = wave_duration(w)
	in_break = false
	cad_used_this_hour = false
	wave_changed.emit(wave)
	break_changed.emit(false)


func tick(delta: float) -> void:
	if crashed_flag:
		return
	elapsed += delta
	if in_break:
		return
	if frozen:
		# Ctrl+Alt+Del: the clock, the overload timer and (via `frozen`) every
		# pop-up and spawn hold still; hold it past FREEZE_MAX and the box resets.
		freeze_time += delta
		if freeze_time >= Tuning.num("ability.freeze_max", FREEZE_MAX):
			end_freeze()
			crash("RESET")
		return
	if not boss_active:
		wave_time_left = maxf(0.0, wave_time_left - delta)  # the hour waits for the installer
	for id: String in ability_cooldowns.keys():
		ability_cooldowns[id] = maxf(0.0, float(ability_cooldowns[id]) - delta)
	_check_overload(delta)


# ---------- bosses ----------

## Waves that open with a Service Pack install (never in overtime).
static func is_boss_wave(w: int) -> bool:
	return w in BOSS_WAVES


func start_boss() -> void:
	assert(not boss_active, "boss already active")
	boss_active = true


## The installer closed: won pays BOSS_REWARD (Tuning boss.reward); the clock resumes.
func end_boss(won: bool) -> int:
	assert(boss_active, "no boss active")
	boss_active = false
	if won:
		bosses_won += 1
		var reward := Tuning.inum("boss.reward", BOSS_REWARD)
		add_bytes(reward)
		return reward
	bosses_failed += 1
	return 0


# ---------- abilities ----------

## Full cooldown for an ability after modifiers (Tuning key ability.<id>.cooldown).
func ability_cooldown(id: String) -> float:
	assert(ABILITIES.has(id), "Unknown ability: " + id)
	return Tuning.num("ability.%s.cooldown" % id, float(ABILITIES[id]["cooldown"])) * cooldown_mult


func ability_cooldown_left(id: String) -> float:
	return float(ability_cooldowns.get(id, 0.0))


func ability_ready(id: String) -> bool:
	assert(ABILITIES.has(id), "Unknown ability: " + id)
	if crashed_flag or in_break:
		return false
	if id == "ctrl_alt_del":
		return not cad_used_this_hour and not frozen
	return ability_cooldown_left(id) <= 0.0


## Spends the ability: starts its cooldown (or marks the hour's Ctrl+Alt+Del
## used) and counts it. False when it was not ready.
func use_ability(id: String) -> bool:
	if not ability_ready(id):
		return false
	abilities_used[id] = int(abilities_used.get(id, 0)) + 1
	if id == "ctrl_alt_del":
		cad_used_this_hour = true
		frozen = true
		freeze_time = 0.0
	else:
		ability_cooldowns[id] = ability_cooldown(id)
	return true


func end_freeze() -> void:
	frozen = false


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


## Reward for closing a pop-up with the given definition. `manual` closes get
## the streak bonus on completions; overtime hours pay OVERTIME_PAY.
func reward_for(def: Dictionary, completed: bool, manual: bool = false) -> int:
	var base: int = def.get("complete_reward", 5) if completed else def.get("dismiss_reward", 1)
	var mult := complete_mult if completed else dismiss_mult
	if manual and completed:
		mult *= streak_mult()
	if overtime:
		mult *= Tuning.num("run.overtime_pay", OVERTIME_PAY)
	var r := int(round(base * mult))
	return maxi(r, 1) if base > 0 else 0


func streak_mult() -> float:
	return 1.0 + Tuning.num("run.streak_step", STREAK_STEP) * mini(streak, Tuning.inum("run.streak_cap", STREAK_CAP))


## Call after a manual close has been rewarded.
func note_manual_close(completed: bool) -> void:
	if completed:
		streak += 1
		best_streak = maxi(best_streak, streak)
	else:
		streak = 0


func overtime_hours() -> int:
	return maxi(0, wave - WORKDAY_WAVES) if overtime else 0


## What the run is worth when it ends: everything if it ended by clocking out
## or before 5 PM; in overtime the banked 5 PM score plus half of what came after.
func final_score() -> int:
	if overtime and crash_reason != "SHUTDOWN":
		return banked_score + (score - banked_score) / 2
	return score


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


# ---------- recycle bin ----------

func bin_has_room() -> bool:
	return bin_items < Tuning.inum("run.bin_capacity", BIN_CAPACITY)


## A pop-up was dropped into the bin: its RAM is freed like a normal close, but
## nothing is rewarded and nothing counts as closed, completed or a streak.
func recycle_popup(ram_cost: int) -> void:
	assert(bin_has_room(), "recycle_popup: the bin is full; check bin_has_room() first")
	ram_used = maxi(0, ram_used - ram_cost)
	popups_recycled += 1
	bin_items += 1
	ram_changed.emit(ram_used, ram_max)


func empty_bin() -> void:
	bin_items = 0
