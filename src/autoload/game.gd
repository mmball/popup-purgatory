extends Node
## Autoload "Game": owns the current run, meta progression, screen flow, and the
## developer options parsed from the command line (see README, "Dev tooling").

signal screen_requested(screen_id: String)

var run: RunState
var meta: MetaSave
var last_run: RunState
var dev: Dictionary = {}
## Seed typed on the main menu for the next run; -1 means draw a random one.
var requested_seed := -1
## Service Pack chosen on the main menu (clamped to what meta has unlocked).
var requested_tier := 0
## Achievements earned by the run that just ended (for the end screen).
var last_earned: Array[String] = []


func _ready() -> void:
	meta = MetaSave.new()
	dev = _parse_dev_args()
	if not dev.has("fresh_meta"):  # --fresh-meta: ignore the save file (screenshot regression)
		meta.load_from_disk()
	if dev.has("tune"):
		Tuning.load_from_string(str(dev["tune"]))
		print("tune=%s" % Tuning.spec)


func start_run() -> void:
	run = RunState.new()
	if requested_seed >= 0:
		run.seed = requested_seed
	elif dev.has("seed"):
		run.seed = int(dev["seed"])
	else:
		var r := RandomNumberGenerator.new()
		r.randomize()
		run.seed = r.randi_range(0, 999_999_999)
	meta.apply_to_run(run)
	if dev.has("unlock_all"):  # --unlock-all: every content unlock, for batches on the full pool
		var all_ids: Array[String] = []
		for a: String in MetaSave.ACHIEVEMENTS.keys():
			all_ids.append(a)
		run.unlocked_popups = all_ids.duplicate()
		run.unlocked_buildings = all_ids.duplicate()
		run.unlocked_upgrades = all_ids.duplicate()
	var tier := int(dev["tier"]) if dev.has("tier") else requested_tier
	Ladder.apply(clampi(tier, 0, meta.max_tier_unlocked if not dev.has("tier") else Ladder.max_tier()), run)
	print("seed=%d tier=%d run started" % [run.seed, run.tier])
	screen_requested.emit("desktop")


func end_run(reason: String) -> void:
	if run != null:
		run.crash_reason = reason
		print("seed=%d run ended: %s wave=%d score=%d won=%s" % [run.seed, reason, run.wave, run.score, run.won])
		last_earned = meta.record_run(run)
		meta.save_to_disk()
		last_run = run
	run = null
	screen_requested.emit("bsod")


func go_to_menu() -> void:
	screen_requested.emit("menu")


## Parses `-- --key=value --flag` user arguments into a dictionary.
static func _parse_dev_args() -> Dictionary:
	var out := {}
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var body := arg.substr(2)
		var eq := body.find("=")
		# Keys accept - or _ (--max-wave and --max_wave are the same key); values are untouched.
		if eq == -1:
			out[body.replace("-", "_")] = "1"
		else:
			out[body.substr(0, eq).replace("-", "_")] = body.substr(eq + 1)
	return out
