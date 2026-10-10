class_name Autoplay
extends Node
## Dev bot: drives the real GUI with synthetic mouse events so smoke tests and
## screenshots exercise closing, building, wave breaks and upgrades.
## Enable with `-- --screen=desktop --autoplay=1`.

const TICK := 0.35

var desktop: Desktop
var rng := RandomNumberGenerator.new()
var _t := 0.0
var _clicks := 0


func _ready() -> void:
	rng.seed = 12345
	# Headless has a 0x0 OS window, and with stretch mode "canvas_items" that
	# collapses the GUI transform to a zero determinant, so hit-testing finds
	# nothing. Giving the root window a real size restores it (Godot 4.3,
	# viewport.cpp _gui_find_control_at_pos).
	if DisplayServer.get_name() == "headless":
		get_tree().root.size = Vector2i(1280, 720)
	print("autoplay: on")


func _process(delta: float) -> void:
	if desktop == null or desktop._ended:
		return
	_t += delta
	if _t < TICK:
		return
	_t = 0.0
	_step()


func _step() -> void:
	var run := desktop.run
	if desktop.break_dialog.visible:
		var pick := _find_button(desktop.break_dialog, "Pick")
		if pick:
			_click(_center(pick))
		return
	if desktop._confirm != null:
		_click(_center(_find_button(desktop._confirm, "No")))
		return
	if desktop.village.is_placing():
		var cell := desktop.village.first_free_cell()
		if cell.x >= 0:
			_click(desktop.village.cell_center(cell))
		else:
			desktop.village.cancel_place()
		return
	if desktop.start_menu.visible:
		# pick the first affordable, non-maxed building
		for i in range(BuildingCatalog.ORDER.size()):
			var id: String = BuildingCatalog.ORDER[i]
			var owned := desktop.village.count(id)
			if owned < BuildingCatalog.max_count(id) and run.bytes >= BuildingCatalog.cost(id, owned):
				_click(_center(desktop.start_menu._items[i]))
				return
		_click(Vector2(640, 400))  # click the desktop to close the menu
		return
	if run.bytes >= 20 and rng.randf() < 0.35:
		_click(_center(desktop.taskbar.start_button))
		return
	var popups := desktop.imp_manager.live_popups()
	if popups.is_empty():
		return
	popups.sort_custom(func(a: PopupBase, b: PopupBase) -> bool: return a.age > b.age)
	var p := popups[0]
	# try to complete the easy ones through their real buttons, else X them
	var btn: Control = null
	match p.type_id:
		"error":
			btn = _find_button(p, "OK")
		"update":
			btn = _find_button(p, "Install")
		"ad", "virus":
			btn = _find_link(p)
	if btn == null or rng.randf() < 0.3:
		if p.x_locked():
			return
		btn = p.close_button
	_click(_center(btn))


func _center(c: Control) -> Vector2:
	return c.global_position + c.size * 0.5


func _find_button(root: Node, label: String) -> Win98Button:
	if root is Win98Button and root.label == label and root.visible:
		return root
	for c: Node in root.get_children():
		var f := _find_button(c, label)
		if f != null and f.is_visible_in_tree():
			return f
	return null


func _find_link(root: Node) -> LinkButton:
	if root is LinkButton:
		return root
	for c: Node in root.get_children():
		var f := _find_link(c)
		if f != null:
			return f
	return null


func _click(pos: Vector2) -> void:
	_clicks += 1
	# push_input delivers straight to the viewport's GUI path, which also works
	# headless; Input.parse_input_event needs a real display server window.
	var vp := get_viewport()
	var mm := InputEventMouseMotion.new()
	mm.position = pos
	mm.global_position = pos
	vp.push_input(mm)
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		vp.push_input(ev)
