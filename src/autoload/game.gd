extends Node
## Autoload "Game": owns the current run, meta progression, screen flow, and the
## developer options parsed from the command line (see README, "Dev tooling").

signal screen_requested(screen_id: String)

var run: RunState
var meta: MetaSave
var last_run: RunState
var dev: Dictionary = {}


func _ready() -> void:
	meta = MetaSave.new()
	meta.load_from_disk()
	dev = _parse_dev_args()


func start_run() -> void:
	run = RunState.new()
	if dev.has("seed"):
		run.seed = int(dev["seed"])
	meta.apply_to_run(run)
	screen_requested.emit("desktop")


func end_run(reason: String) -> void:
	if run != null:
		run.crash_reason = reason
		meta.record_run(run)
		meta.save_to_disk()
		last_run = run
	run = null
	screen_requested.emit("bsod")


func go_to_menu() -> void:
	screen_requested.emit("menu")


## Parses `-- --key=value --flag` user arguments into a dictionary.
static func _parse_dev_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var body := arg.substr(2)
		var eq := body.find("=")
		if eq == -1:
			out[body] = "1"
		else:
			out[body.substr(0, eq)] = body.substr(eq + 1)
	return out
