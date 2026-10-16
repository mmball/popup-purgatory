class_name Imp
extends Node2D
## A little worker. Idles near its home, walks to a pop-up, stands on its X
## button for a moment, then closes it. Trained imps complete instead of dismiss.

enum State { IDLE, SEEK, WORK, TRAIN, LEAVE }

const BASE_SPEED := 90.0
const DISMISS_TIME := 0.6
const ARRIVE_DIST := 4.0
const TRAIN_TIME := 6.0
const XP_STEP := 0.02        ## speed per close
const XP_CAP := 15           ## closes that count
const VETERAN_CLOSES := 10
const DESK_SIZE := Vector2(1280, 720)
const LEAVE_MARGIN := 30.0   ## px past the desk edge where a fired imp is gone

var manager: Node          ## ImpManager
var run: RunState
var rng: RandomNumberGenerator   ## the run's RNG, handed down by ImpManager
var home := Vector2.ZERO
var home_cell := Vector2i(-1, -1)   ## the hut this imp came from; strays (upgrades) keep (-1, -1)
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
var hop_y := 0.0          ## animated by Juice.hop; added to the drawing offset
var closes := 0           ## experience: each close speeds the imp up a little
var dojo: Node2D          ## the dojo being walked to / trained in (TRAIN state)
var _train_left := 0.0
var _alert_t := 0.0       ## seconds left to draw the "!" after acquiring a target
var _sulk_t := 0.0        ## seconds left to draw the frown after being dodged
var _leave_target := Vector2.ZERO   ## off-screen point walked to in LEAVE state


func _ready() -> void:
	_t = rng.randf() * 10.0
	_wander_target = home
	z_index = 5


## Base speed times the run-wide multiplier (upgrades, meta perks), the local
## coffee-cart multiplier for this imp's hut, and experience.
func speed() -> float:
	var m := run.imp_speed_mult if run != null else 1.0
	var local: float = manager.speed_mult_for(self) if manager != null else 1.0
	return Tuning.num("imp.base_speed", BASE_SPEED) * m * local * xp_mult()


## Fired (its hut was demolished): drop whatever it was doing and walk off the
## nearest desk edge. The manager is told once it is gone.
func leave() -> void:
	if state == State.LEAVE:
		return
	if state == State.SEEK or state == State.WORK:
		if manager != null:
			manager.release(self)
		target = null
	elif state == State.TRAIN:
		_clear_dojo()
	visible = true
	state = State.LEAVE
	var to_left := position.x
	var to_right := DESK_SIZE.x - position.x
	var to_top := position.y
	var to_bottom := DESK_SIZE.y - position.y
	var nearest := minf(minf(to_left, to_right), minf(to_top, to_bottom))
	if nearest == to_left:
		_leave_target = Vector2(-LEAVE_MARGIN, position.y)
	elif nearest == to_right:
		_leave_target = Vector2(DESK_SIZE.x + LEAVE_MARGIN, position.y)
	elif nearest == to_top:
		_leave_target = Vector2(position.x, -LEAVE_MARGIN)
	else:
		_leave_target = Vector2(position.x, DESK_SIZE.y + LEAVE_MARGIN)


func _leave(delta: float) -> void:
	if _move_toward(_leave_target, speed(), delta) <= ARRIVE_DIST:
		if manager != null:
			manager.call("on_imp_left", self)
		queue_free()


## The dojo was demolished mid-training: step back out untrained and idle.
func abort_training() -> void:
	if state != State.TRAIN:
		return
	if is_instance_valid(dojo) and not visible:
		position = dojo.position + Vector2(0, 14)
	_clear_dojo()
	visible = true
	state = State.IDLE
	_retarget_timer = 0.0


func _clear_dojo() -> void:
	if is_instance_valid(dojo) and dojo.get("trainee") == self:
		dojo.set("trainee", null)
		dojo.set("train_progress", 0.0)
	dojo = null
	_train_left = 0.0


func xp_mult() -> float:
	return 1.0 + XP_STEP * mini(closes, XP_CAP)


func is_veteran() -> bool:
	return closes >= VETERAN_CLOSES


## Sent to a dojo with a free slot. The imp walks there, disappears inside for
## TRAIN_TIME, and comes out trained.
func start_training(p_dojo: Node2D) -> void:
	if state == State.WORK or state == State.SEEK:
		_drop_target()
	dojo = p_dojo
	dojo.set("trainee", self)
	dojo.set("train_progress", 0.0)
	state = State.TRAIN
	_train_left = -1.0  # walking; becomes TRAIN_TIME on arrival


func _train(delta: float) -> void:
	if not is_instance_valid(dojo):
		state = State.IDLE
		visible = true
		return
	if _train_left < 0.0:
		if _move_toward(dojo.position + Vector2(0, 4), speed(), delta) <= ARRIVE_DIST:
			_train_left = TRAIN_TIME
			visible = false
		return
	_train_left -= delta
	dojo.set("train_progress", 1.0 - _train_left / TRAIN_TIME)
	if _train_left <= 0.0:
		visible = true
		position = dojo.position + Vector2(0, 14)
		home = position
		trained = true
		dojo.set("graduates", int(dojo.get("graduates")) + 1)
		dojo.set("trainee", null)
		dojo.set("train_progress", 0.0)
		var d := dojo
		dojo = null
		state = State.IDLE
		Juice.hop(self, 18.0)
		manager.call("on_imp_trained", self, d)


func _process(delta: float) -> void:
	if run != null and run.frozen:
		return  # Ctrl+Alt+Del: imps freeze with everything else
	_t += delta
	_alert_t = maxf(0.0, _alert_t - delta)
	_sulk_t = maxf(0.0, _sulk_t - delta)
	match state:
		State.IDLE:
			_idle(delta)
		State.SEEK:
			_seek(delta)
		State.WORK:
			_work(delta)
		State.TRAIN:
			_train(delta)
		State.LEAVE:
			_leave(delta)
	queue_redraw()


func _idle(delta: float) -> void:
	_retarget_timer -= delta
	if _retarget_timer <= 0.0:
		_retarget_timer = 0.3
		var t: PopupBase = manager.request_target(self)
		if t != null:
			target = t
			state = State.SEEK
			_alert_t = 0.6
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
		if target.is_imp_proof() and not (run != null and run.helpdesk):
			# Live Chat dodges imps unless a Help Desk taught them the trick.
			var parent := target.get_parent()
			var bounds := Rect2(Vector2.ZERO, parent.size) if parent is Control else Rect2(0, 0, 1280, 690)
			target.hop(bounds)
			_sulk_t = 1.2
			_drop_target()
			return
		state = State.WORK
		Juice.squash(self)
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
		closes += 1
		Juice.hop(self)
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
	var bob := sin(_t * 10.0) * (1.5 if walking else 0.5) + hop_y
	var c := body_color
	# feet
	draw_circle(Vector2(-4, 1), 2.5, c.darkened(0.4))
	draw_circle(Vector2(4, 1), 2.5, c.darkened(0.4))
	# body (trained imps are a touch bigger)
	var bc := Vector2(0, -9 + bob)
	var r := 9.0 if trained else 8.0
	draw_circle(bc, r, c)
	if trained:
		# black belt
		draw_rect(Rect2(bc + Vector2(-r + 1, 3), Vector2(2 * r - 2, 3)), Color("111111"))
		draw_rect(Rect2(bc + Vector2(1, 3), Vector2(3, 3)), Color("ffd700"))
	if is_veteran():
		# service stripe
		draw_rect(Rect2(bc + Vector2(-r + 1, -2), Vector2(4, 2)), Color("ffd700"))
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
	# grin, or a frown while sulking after a dodge or walking off fired
	if _sulk_t > 0.0 or state == State.LEAVE:
		draw_arc(bc + Vector2(0, 5), 3.5, PI + 0.2, TAU - 0.2, 8, Color.BLACK, 1.0)
	else:
		draw_arc(bc + Vector2(0, 2), 3.5, 0.2, PI - 0.2, 8, Color.BLACK, 1.0)
	if _alert_t > 0.0:
		var ay := bc.y - 22 - (0.6 - _alert_t) * 6.0
		draw_rect(Rect2(-1.5, ay, 3, 7), Color("ffd700"))
		draw_rect(Rect2(-1.5, ay + 9, 3, 3), Color("ffd700"))
	if trained:
		# mortarboard
		draw_rect(Rect2(bc + Vector2(-7, -15), Vector2(14, 3)), Color("222222"))
		draw_rect(Rect2(bc + Vector2(-4, -18), Vector2(8, 3)), Color("222222"))
		draw_line(bc + Vector2(7, -14), bc + Vector2(9, -9), Color("ffd700"), 1.0)
	if state == State.WORK:
		var py := -24 + bob * 2.0
		if trained:
			# a little book: trained imps read the pop-up instead of just clicking
			draw_rect(Rect2(-5, py, 10, 8), Color.WHITE)
			draw_rect(Rect2(-5, py, 10, 8), Color.BLACK, false, 1.0)
			draw_line(Vector2(0, py + 1), Vector2(0, py + 7), Color.BLACK, 1.0)
			draw_line(Vector2(-3, py + 3), Vector2(-1, py + 3), Color("808080"), 1.0)
			draw_line(Vector2(1, py + 3), Vector2(3, py + 3), Color("808080"), 1.0)
		else:
			# pointer bouncing above the head
			var pts := PackedVector2Array([Vector2(0, py), Vector2(0, py + 10), Vector2(3, py + 7), Vector2(7, py + 8)])
			draw_polygon(pts, PackedColorArray([Color.WHITE]))
			draw_polyline(pts, Color.BLACK, 1.0)
		var frac := 1.0 - clampf(_work_left / maxf(0.01, _work_total), 0.0, 1.0)
		draw_arc(bc, 11, -PI / 2, -PI / 2 + TAU * frac, 16, Color("ffd700"), 2.0)
