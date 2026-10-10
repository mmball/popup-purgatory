class_name Imp
extends Node2D
## A little worker. Idles near its home, walks to a pop-up, stands on its X
## button for a moment, then closes it. Trained imps complete instead of dismiss.

enum State { IDLE, SEEK, WORK }

const BASE_SPEED := 90.0
const DISMISS_TIME := 0.6
const ARRIVE_DIST := 4.0

var manager: Node          ## ImpManager
var run: RunState
var rng: RandomNumberGenerator   ## the run's RNG, handed down by ImpManager
var home := Vector2.ZERO
var trained := false:
	set(v):
		trained = v
		queue_redraw()
var body_color := Color("8b2fc9")
var state := State.IDLE
var target: PopupBase

var _t := 0.0
var _facing := 1.0
var _wander_target := Vector2.ZERO
var _wander_timer := 0.0
var _retarget_timer := 0.0
var _work_left := 0.0
var _work_total := 1.0


func _ready() -> void:
	_t = rng.randf() * 10.0
	_wander_target = home
	z_index = 5


func speed() -> float:
	var m := run.imp_speed_mult if run != null else 1.0
	return Tuning.num("imp.base_speed", BASE_SPEED) * m


func _process(delta: float) -> void:
	_t += delta
	match state:
		State.IDLE:
			_idle(delta)
		State.SEEK:
			_seek(delta)
		State.WORK:
			_work(delta)
	queue_redraw()


func _idle(delta: float) -> void:
	_retarget_timer -= delta
	if _retarget_timer <= 0.0:
		_retarget_timer = 0.3
		var t: PopupBase = manager.request_target(self)
		if t != null:
			target = t
			state = State.SEEK
			return
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = rng.randf_range(1.0, 2.5)
		_wander_target = home + Vector2(rng.randf_range(-50, 50), rng.randf_range(-30, 30))
	_move_toward(_wander_target, speed() * 0.4, delta)


func _target_valid() -> bool:
	return is_instance_valid(target) and target.is_inside_tree() and not target.is_closing


func _drop_target() -> void:
	manager.release(self)
	target = null
	state = State.IDLE
	_retarget_timer = 0.0


func _seek(delta: float) -> void:
	if not _target_valid():
		_drop_target()
		return
	var dest := target.imp_close_point()
	if _move_toward(dest, speed(), delta) <= ARRIVE_DIST:
		state = State.WORK
		var will_complete := trained
		_work_total = (target.imp_complete_time() if will_complete else Tuning.num("imp.dismiss_time", DISMISS_TIME))
		_work_total *= run.imp_work_mult if run != null else 1.0
		_work_left = _work_total


func _work(delta: float) -> void:
	if not _target_valid():
		_drop_target()
		return
	position = target.imp_close_point()  # ride along if the window is dragged
	_work_left -= delta
	if _work_left <= 0.0:
		var t := target
		target = null
		state = State.IDLE
		manager.release(self)
		if trained:
			t.complete(true)
		else:
			t.dismiss(true)


## Moves toward `dest`; returns remaining distance.
func _move_toward(dest: Vector2, px_per_s: float, delta: float) -> float:
	var diff := dest - position
	var dist := diff.length()
	if dist > 0.5:
		_facing = 1.0 if diff.x >= 0.0 else -1.0
		var step := minf(dist, px_per_s * delta)
		position += diff / dist * step
		return dist - step
	return dist


func _draw() -> void:
	var walking := state != State.WORK
	var bob := sin(_t * 10.0) * (1.5 if walking else 0.5)
	var c := body_color
	# feet
	draw_circle(Vector2(-4, 1), 2.5, c.darkened(0.4))
	draw_circle(Vector2(4, 1), 2.5, c.darkened(0.4))
	# body
	var bc := Vector2(0, -9 + bob)
	draw_circle(bc, 8, c)
	# horns
	var hc := c.darkened(0.25)
	draw_polygon(PackedVector2Array([bc + Vector2(-6, -5), bc + Vector2(-8, -13), bc + Vector2(-2, -7)]), PackedColorArray([hc]))
	draw_polygon(PackedVector2Array([bc + Vector2(6, -5), bc + Vector2(8, -13), bc + Vector2(2, -7)]), PackedColorArray([hc]))
	# eyes
	var eo := Vector2(_facing * 1.0, 0)
	draw_circle(bc + Vector2(-3, -1) + eo, 2.2, Color.WHITE)
	draw_circle(bc + Vector2(3, -1) + eo, 2.2, Color.WHITE)
	draw_circle(bc + Vector2(-3, -1) + eo * 1.8, 1.0, Color.BLACK)
	draw_circle(bc + Vector2(3, -1) + eo * 1.8, 1.0, Color.BLACK)
	# grin
	draw_arc(bc + Vector2(0, 2), 3.5, 0.2, PI - 0.2, 8, Color.BLACK, 1.0)
	if trained:
		# mortarboard
		draw_rect(Rect2(bc + Vector2(-7, -15), Vector2(14, 3)), Color("222222"))
		draw_rect(Rect2(bc + Vector2(-4, -18), Vector2(8, 3)), Color("222222"))
		draw_line(bc + Vector2(7, -14), bc + Vector2(9, -9), Color("ffd700"), 1.0)
	if state == State.WORK:
		# pointer bouncing above the head + progress ring
		var py := -24 + bob * 2.0
		var pts := PackedVector2Array([Vector2(0, py), Vector2(0, py + 10), Vector2(3, py + 7), Vector2(7, py + 8)])
		draw_polygon(pts, PackedColorArray([Color.WHITE]))
		draw_polyline(pts, Color.BLACK, 1.0)
		var frac := 1.0 - clampf(_work_left / maxf(0.01, _work_total), 0.0, 1.0)
		draw_arc(bc, 11, -PI / 2, -PI / 2 + TAU * frac, 16, Color("ffd700"), 2.0)
