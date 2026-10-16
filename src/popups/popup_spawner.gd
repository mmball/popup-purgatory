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
var village: Village        ## set by Desktop for firewall no-spawn zones; null in tests
var active := true
var screensaver := false     ## Screensaver building: periodic spawn pause
const SCREENSAVER_PERIOD := 30.0
const SCREENSAVER_PAUSE := 6.0
const ZONE_TRIES := 12      ## redraws before a spawn is pushed out of a firewall zone

var _timer := 1.5
var _queued: Array[Dictionary] = []
var _saver_clock := 0.0


func screensaver_active() -> bool:
	return screensaver and fmod(_saver_clock, SCREENSAVER_PERIOD) >= SCREENSAVER_PERIOD - SCREENSAVER_PAUSE


func setup(p_run: RunState, p_rng: RandomNumberGenerator, p_layer: Control) -> void:
	run = p_run
	rng = p_rng
	schedule = SpawnSchedule.new(rng)
	layer = p_layer


func _process(delta: float) -> void:
	if run == null or run.crashed_flag or run.in_break or run.frozen or not active:
		return
	var i := _queued.size() - 1
	while i >= 0:
		_queued[i]["delay"] = float(_queued[i]["delay"]) - delta
		if float(_queued[i]["delay"]) <= 0.0:
			var q := _queued[i]
			_queued.remove_at(i)
			spawn(str(q["type"]), q["near"])
		i -= 1
	_saver_clock += delta
	if screensaver_active():
		return  # the Screensaver is on: the timer holds
	_timer -= delta
	if _timer <= 0.0:
		spawn(schedule.pick_type(run.wave, run.unlocked_popups, {"chat": run.chat_spawn_mult}))
		_timer = schedule.next_interval(run.wave, run.interval_mult, run.overtime_hours())


## Spawn later. `near` is a desktop position to cluster around (or null).
func queue(type_id: String, delay: float, near: Variant = null) -> void:
	_queued.append({"type": type_id, "delay": delay, "near": near})


func spawn(type_id: String, near: Variant = null) -> PopupBase:
	var def := PopupCatalog.get_def(type_id)
	var popup := PopupBase.new()
	popup.setup(def, rng, run.close_button_size, run)
	popup.ram_cost = run.popup_cost(def)
	popup.drag_bounds = Rect2(Vector2.ZERO, layer.size)
	popup.spawned_near = near is Vector2
	popup.position = _pick_position(popup.size, near)
	layer.add_child(popup)
	run.popup_opened(popup.ram_cost)
	popup_spawned.emit(popup)
	return popup


func _pick_position(win_size: Vector2, near: Variant) -> Vector2:
	var max_x := maxf(MARGIN, layer.size.x - win_size.x - MARGIN)
	var max_y := maxf(MARGIN, layer.size.y - win_size.y - MARGIN)
	var zones: Array[Dictionary] = []
	if village != null:
		zones = village.firewall_zones()
	# With no zones the first candidate is always taken, so the rng draws are
	# exactly what they were before firewalls had a radius (seeded layouts hold).
	var p: Vector2
	for _i in range(ZONE_TRIES):
		p = _draw_candidate(win_size, near, max_x, max_y)
		if position_allowed(Rect2(p, win_size), zones):
			return p
	# Every try landed on a firewall: shove the last one out of the nearest zone.
	p = push_outside(Rect2(p, win_size), zones)
	p.x = clampf(p.x, MARGIN, max_x)
	p.y = clampf(p.y, MARGIN, max_y)
	return p.round()


## One random window position (two rng draws), clamped to the layer.
func _draw_candidate(win_size: Vector2, near: Variant, max_x: float, max_y: float) -> Vector2:
	var p: Vector2
	if near is Vector2:
		p = near + Vector2(rng.randf_range(-60, 60), rng.randf_range(-40, 40))
	else:
		p = Vector2(rng.randf_range(MARGIN, max_x), rng.randf_range(MARGIN, max_y))
	p.x = clampf(p.x, MARGIN, max_x)
	p.y = clampf(p.y, MARGIN, max_y)
	return p.round()


## Point of `rect` closest to `c` (c itself when it lies inside).
static func _closest_point(rect: Rect2, c: Vector2) -> Vector2:
	return Vector2(clampf(c.x, rect.position.x, rect.end.x), clampf(c.y, rect.position.y, rect.end.y))


## True when a window at `rect` overlaps none of the zone circles
## ({"center": Vector2, "radius": float}, pixels). Touching the edge is allowed.
static func position_allowed(rect: Rect2, zones: Array[Dictionary]) -> bool:
	for z: Dictionary in zones:
		var c: Vector2 = z["center"]
		if _closest_point(rect, c).distance_to(c) < float(z["radius"]):
			return false
	return true


## Position for `rect` moved just outside the zone it overlaps most, along the
## vector from that zone's centre. Unchanged when it overlaps nothing.
static func push_outside(rect: Rect2, zones: Array[Dictionary]) -> Vector2:
	var worst := -INF
	var centre := Vector2.ZERO
	var radius := 0.0
	for z: Dictionary in zones:
		var c: Vector2 = z["center"]
		var r := float(z["radius"])
		var depth := r - _closest_point(rect, c).distance_to(c)
		if depth > worst:
			worst = depth
			centre = c
			radius = r
	if worst <= 0.0:
		return rect.position
	var q := _closest_point(rect, centre)
	var dir := q - centre
	var shift := worst + 1.0
	if dir.length_squared() == 0.0:
		# the centre lies inside the window: leave along the window's own centre
		dir = rect.get_center() - centre
		if dir.length_squared() == 0.0:
			dir = Vector2.RIGHT
		shift = radius + 1.0 + rect.size.length()
	return rect.position + dir.normalized() * shift
