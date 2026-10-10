class_name PopupBase
extends WindowFrame
## A pop-up window on the desktop. Tracks its age for timeouts, hosts a
## PopupContent body, and reports how it was closed.

signal closed(popup: PopupBase, completed: bool, by_imp: bool)
signal timed_out(popup: PopupBase)
signal trap_hit(popup: PopupBase, kind: String)

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


func setup(p_def: Dictionary, p_rng: RandomNumberGenerator, close_size: int) -> void:
	def = p_def
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

	var script: GDScript = load(str(def["content"]))
	content_node = script.new()
	content_node.popup = self
	content_node.rng = rng
	content.add_child(content_node)
	content_node.build()
	content_node.completed.connect(func() -> void: complete(false))
	content_node.misclick.connect(func(kind: String) -> void: trap_hit.emit(self, kind))
	close_requested.connect(func() -> void: dismiss(false))


func _process(delta: float) -> void:
	if is_closing:
		return
	age += delta
	total_age += delta
	if x_locked_until > 0.0 and age >= x_locked_until:
		x_locked_until = 0.0
		close_button.disabled = false
	if lifetime > 0.0 and age >= lifetime:
		age = 0.0
		timeouts += 1
		timed_out.emit(self)


func x_locked() -> bool:
	return x_locked_until > 0.0


func dismiss(by_imp: bool) -> void:
	_close(false, by_imp)


func complete(by_imp: bool) -> void:
	_close(true, by_imp)


func _close(completed: bool, by_imp: bool) -> void:
	if is_closing:
		return
	is_closing = true
	closed.emit(self, completed, by_imp)


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
