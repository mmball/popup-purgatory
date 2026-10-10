class_name PopupSpawner
extends Node
## Creates pop-up windows on a schedule and on request (multiplication,
## "remind me later", traps). The desktop wires up each window's signals.

signal popup_spawned(popup: PopupBase)

const MARGIN := 8

var run: RunState
var rng: RandomNumberGenerator
var schedule: SpawnSchedule
var layer: Control          ## where windows are added; its rect bounds them
var active := true

var _timer := 1.5
var _queued: Array[Dictionary] = []


func setup(p_run: RunState, p_rng: RandomNumberGenerator, p_layer: Control) -> void:
	run = p_run
	rng = p_rng
	schedule = SpawnSchedule.new(rng)
	layer = p_layer


func _process(delta: float) -> void:
	if run == null or run.crashed_flag or run.in_break or not active:
		return
	var i := _queued.size() - 1
	while i >= 0:
		_queued[i]["delay"] = float(_queued[i]["delay"]) - delta
		if float(_queued[i]["delay"]) <= 0.0:
			var q := _queued[i]
			_queued.remove_at(i)
			spawn(str(q["type"]), q["near"])
		i -= 1
	_timer -= delta
	if _timer <= 0.0:
		spawn(schedule.pick_type(run.wave))
		_timer = schedule.next_interval(run.wave, run.interval_mult)


## Spawn later. `near` is a desktop position to cluster around (or null).
func queue(type_id: String, delay: float, near: Variant = null) -> void:
	_queued.append({"type": type_id, "delay": delay, "near": near})


func spawn(type_id: String, near: Variant = null) -> PopupBase:
	var def := PopupCatalog.get_def(type_id)
	var popup := PopupBase.new()
	popup.setup(def, rng, run.close_button_size)
	popup.ram_cost = run.popup_cost(def)
	popup.drag_bounds = Rect2(Vector2.ZERO, layer.size)
	popup.position = _pick_position(popup.size, near)
	layer.add_child(popup)
	run.popup_opened(popup.ram_cost)
	popup_spawned.emit(popup)
	return popup


func _pick_position(win_size: Vector2, near: Variant) -> Vector2:
	var max_x := maxf(MARGIN, layer.size.x - win_size.x - MARGIN)
	var max_y := maxf(MARGIN, layer.size.y - win_size.y - MARGIN)
	var p: Vector2
	if near is Vector2:
		p = near + Vector2(rng.randf_range(-60, 60), rng.randf_range(-40, 40))
	else:
		p = Vector2(rng.randf_range(MARGIN, max_x), rng.randf_range(MARGIN, max_y))
	p.x = clampf(p.x, MARGIN, max_x)
	p.y = clampf(p.y, MARGIN, max_y)
	return p.round()
