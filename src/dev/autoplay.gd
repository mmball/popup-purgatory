class_name Autoplay
extends Node
## Dev bot: drives the real GUI with synthetic mouse events so smoke tests,
## screenshots and balance batches exercise closing, building, wave breaks and
## upgrades. Lives under Main so it survives screen changes and can chain runs.
##
## Flags (after `--`):
##   --autoplay=1          enable
##   --policy=greedy|random  greedy: oldest pop-up, prefer completion, buy the
##                         first affordable building, first upgrade (default)
##                         random: uniformly random legal clicks
##   --runs=N              play N runs (seed, seed+1, ...) then quit; default 1
##   --jsonl=path          append one JSON line per finished run (RunState.summary())
##   --max-wave=N / --max-seconds=S  end a run early (handled by Desktop)

const TICK := 0.35

var policy := "greedy"
var runs_wanted := 1
var runs_done := 0
var first_seed := -1
var rng := RandomNumberGenerator.new()

var _t := 0.0
var _clicks := 0
var _jsonl: FileAccess
var _main: Control


func _ready() -> void:
	var dev: Dictionary = Game.dev
	policy = str(dev.get("policy", "greedy"))
	runs_wanted = maxi(1, int(dev.get("runs", "1")))
	first_seed = int(dev.get("seed", "-1"))
	if dev.has("jsonl"):
		_jsonl = FileAccess.open(str(dev["jsonl"]), FileAccess.WRITE)
		if _jsonl == null:
			push_warning("Autoplay: cannot open %s for writing" % dev["jsonl"])
	_main = get_parent() as Control
	# Headless has a 0x0 OS window, and with stretch mode "canvas_items" that
	# collapses the GUI transform to a zero determinant, so hit-testing finds
	# nothing. Giving the root window a real size restores it (Godot 4.x,
	# viewport.cpp _gui_find_control_at_pos).
	if DisplayServer.get_name() == "headless":
		get_tree().root.size = Vector2i(1280, 720)
	Game.screen_requested.connect(_on_screen_requested)
	if Game.run != null:
		_seed_for_run(Game.run)  # the first run started before this node existed
	print("autoplay: on policy=%s runs=%d" % [policy, runs_wanted])


## Per-run bot RNG: same seed and policy -> same clicks.
func _seed_for_run(run: RunState) -> void:
	rng.seed = run.seed * 7919 + (1 if policy == "random" else 0)


func _on_screen_requested(id: String) -> void:
	if id == "bsod" and Game.last_run != null:
		_record(Game.last_run)
	elif id == "desktop" and Game.run != null:
		_seed_for_run(Game.run)


func _record(run: RunState) -> void:
	runs_done += 1
	var row := run.summary()
	row["policy"] = policy
	var line := JSON.stringify(row)
	print("autoplay run %d/%d: %s" % [runs_done, runs_wanted, line])
	if _jsonl != null:
		_jsonl.store_line(line)
		_jsonl.flush()


func _process(delta: float) -> void:
	_t += delta
	if _t < TICK:
		return
	_t = 0.0
	var screen: Node = _main.get("current")
	if screen is Desktop:
		if not screen._ended:
			_step_desktop(screen)
	elif screen is BsodScreen:
		if runs_done >= runs_wanted:
			if _jsonl != null:
				_jsonl.close()
			get_tree().quit()
			return
		if screen._t >= BsodScreen.ACCEPT_DELAY:
			_click(Vector2(640, 360))  # any click leaves the BSOD
	elif screen is MainMenu:
		_step_menu(screen)


func _step_menu(menu: MainMenu) -> void:
	var edit := _find_line_edit(menu)
	var start := _find_button(menu, "Start Run")
	if edit == null or start == null:
		return  # boot text still showing
	if first_seed >= 0:
		edit.text = str(first_seed + runs_done)
	_click(_center(start))


func _step_desktop(desktop: Desktop) -> void:
	if policy == "random":
		_step_random(desktop)
	else:
		_step_greedy(desktop)


# ---------- greedy ----------

func _step_greedy(desktop: Desktop) -> void:
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
	var btn: Control = _completion_control(p)
	if btn == null or rng.randf() < 0.3:
		if p.x_locked():
			return
		btn = p.close_button
	_click(_center(btn))


## The control that completes a pop-up cheaply, or null if it needs more steps.
func _completion_control(p: PopupBase) -> Control:
	match p.type_id:
		"error":
			return _find_button(p, "OK")
		"update":
			return _find_button(p, "Install")
		"ad", "virus":
			return _find_link(p)
	return null


# ---------- random ----------

func _step_random(desktop: Desktop) -> void:
	if desktop.break_dialog.visible:
		var picks := _find_all(desktop.break_dialog, "Win98Button")
		if not picks.is_empty():
			_click(_center(picks[rng.randi_range(0, picks.size() - 1)]))
		return
	if desktop._confirm != null:
		_click(_center(_find_button(desktop._confirm, "No")))
		return
	if desktop.village.is_placing():
		var cell := Vector2i(rng.randi_range(1, Village.COLS - 1), rng.randi_range(0, Village.ROWS - 1))
		if desktop.village.cell_free(cell):
			_click(desktop.village.cell_center(cell))
		return
	if desktop.start_menu.visible:
		var items: Array = desktop.start_menu._items.filter(func(b: Button) -> bool: return not b.disabled)
		if items.is_empty() or rng.randf() < 0.2:
			_click(Vector2(640, 400))
		else:
			_click(_center(items[rng.randi_range(0, items.size() - 1)]))
		return
	var roll := rng.randf()
	if roll < 0.1:
		_click(_center(desktop.taskbar.start_button))
		return
	var popups := desktop.imp_manager.live_popups()
	if popups.is_empty() or roll < 0.2:
		return  # idle tick
	var p := popups[rng.randi_range(0, popups.size() - 1)]
	var targets: Array[Control] = []
	if not p.x_locked():
		targets.append(p.close_button)
	for c: Control in _find_all(p.content, "BaseButton"):
		if c.is_visible_in_tree() and not (c is Button and c.disabled):
			targets.append(c)
	if targets.is_empty():
		return
	_click(_center(targets[rng.randi_range(0, targets.size() - 1)]))


# ---------- helpers ----------

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


func _find_line_edit(root: Node) -> LineEdit:
	if root is LineEdit:
		return root
	for c: Node in root.get_children():
		var f := _find_line_edit(c)
		if f != null:
			return f
	return null


func _find_all(root: Node, cls: String) -> Array[Control]:
	var out: Array[Control] = []
	if root is Control and root.is_class(cls):
		out.append(root)
	for c: Node in root.get_children():
		out.append_array(_find_all(c, cls))
	return out


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
