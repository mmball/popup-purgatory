class_name PopupBase
extends WindowFrame
## A pop-up window on the desktop. Tracks its age for timeouts, hosts a
## PopupContent body, and reports how it was closed.

signal closed(popup: PopupBase, completed: bool, by_imp: bool)
signal timed_out(popup: PopupBase)
signal trap_hit(popup: PopupBase, kind: String)
signal leaked(popup: PopupBase, grow: int)
signal hopped(popup: PopupBase)

var def: Dictionary
var type_id := ""
var ram_cost := 0           ## RAM this window currently occupies (may escalate)
var age := 0.0          ## seconds since spawn or last timeout
var total_age := 0.0    ## seconds since spawn
var spawned_near := false
var lifetime := 0.0
var timeouts := 0
var is_closing := false
var x_locked_until := 0.0
var content_node: PopupContent
var rng: RandomNumberGenerator
var run: RunState
var imp_cooldown := 0.0   ## seconds imps ignore this window after it hopped
var _leak_timer := 0.0


func setup(p_def: Dictionary, p_rng: RandomNumberGenerator, close_size: int, p_run: RunState = null) -> void:
	def = p_def
	run = p_run
	type_id = str(def["id"])
	rng = p_rng
	lifetime = float(def.get("lifetime", 0.0))
	x_locked_until = float(def.get("x_lock", 0.0))
	window_title = str(def["title"])
	icon_color = _icon_color_for(type_id)
	set_close_button_size(close_size)
	set_window_size(def["size"])
	if x_locked_until > 0.0:
		close_button.disabled = true
		close_button.font_size = 10
		_show_lock_countdown()

	var script: GDScript = load(str(def["content"]))
	content_node = script.new()
	content_node.popup = self
	content_node.rng = rng
	content_node.run = run
	content.add_child(content_node)
	content_node.build()
	content_node.completed.connect(func() -> void: complete(false))
	content_node.misclick.connect(func(kind: String) -> void: trap_hit.emit(self, kind))
	close_requested.connect(func() -> void: dismiss(false))


func _process(delta: float) -> void:
	if is_closing or (run != null and run.frozen):
		return  # Ctrl+Alt+Del holds every window still
	age += delta
	total_age += delta
	if x_locked_until > 0.0:
		if age >= x_locked_until:
			x_locked_until = 0.0
			close_button.disabled = false
			close_button.label = ""
			close_button.tooltip_text = ""
		else:
			_show_lock_countdown()
	if lifetime > 0.0 and age >= lifetime:
		age = 0.0
		timeouts += 1
		Juice.flash(self, Color(1.5, 0.6, 0.6), 0.4)
		timed_out.emit(self)
	if imp_cooldown > 0.0:
		imp_cooldown -= delta
	if def.has("leak"):
		_leak_timer += delta
		var every := float(def["leak"].get("every", 5.0))
		if _leak_timer >= every:
			_leak_timer -= every
			leaked.emit(self, int(def["leak"].get("grow", 3)))


func x_locked() -> bool:
	return x_locked_until > 0.0


## While the X is locked the button shows the seconds left, so the grey glyph
## reads as "wait" rather than "broken".
func _show_lock_countdown() -> void:
	var left := int(ceil(x_locked_until - age))
	var text := str(maxi(left, 1))
	if close_button.label != text:
		close_button.label = text
		close_button.tooltip_text = "Unlocks in %d s" % left


func is_imp_proof() -> bool:
	return bool(def.get("imp_proof", false))


## Pop-ups punished for dismissal (cookie banner) spawn more when X-ed.
func dismiss_spawns() -> int:
	return int(def.get("on_dismiss", {}).get("count", 0))


## Jump to a new spot inside `bounds` (imp-proof windows dodge imps).
func hop(bounds: Rect2) -> void:
	var max_x := maxf(8.0, bounds.size.x - size.x - 8.0)
	var max_y := maxf(8.0, bounds.size.y - size.y - 8.0)
	var p := Vector2(rng.randf_range(8.0, max_x), rng.randf_range(8.0, max_y))
	for i in range(4):  # prefer somewhere actually far away
		var q := Vector2(rng.randf_range(8.0, max_x), rng.randf_range(8.0, max_y))
		if q.distance_to(position) > p.distance_to(position):
			p = q
	position = p.round()
	imp_cooldown = 8.0
	Juice.pop_in(self, 0.12)
	Sfx.play("hop", 1.3)
	hopped.emit(self)


func dismiss(by_imp: bool) -> void:
	_close(false, by_imp)


func complete(by_imp: bool) -> void:
	_close(true, by_imp)


func _close(completed: bool, by_imp: bool) -> void:
	if is_closing:
		return
	is_closing = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	close_button.disabled = true
	closed.emit(self, completed, by_imp)


## Dropped into the Recycle Bin: the window goes away with no reward and no
## penalty, so `closed` is never emitted (Desktop handles RAM and the imps).
## State changes first; the fold-away is cosmetic.
func recycle() -> void:
	if is_closing:
		return
	is_closing = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	close_button.disabled = true
	Juice.pop_out(self, queue_free)


## Where an imp stands to work on this window: the middle of the X button.
func imp_close_point() -> Vector2:
	return close_button.global_position + close_button.size * 0.5 + Vector2(0, 10)


func imp_complete_time() -> float:
	return float(def.get("imp_complete_time", 2.0))


static func _icon_color_for(id: String) -> Color:
	match id:
		"error", "virus":
			return Color("d00000")
		"ad":
			return Color("ffcc00")
		"update", "toolbar":
			return Color("2e8b57")
		_:
			return Win98.TITLE_B
