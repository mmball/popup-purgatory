class_name Autoplay
extends Node
## Dev bot: drives the real GUI with synthetic mouse events so smoke tests,
## screenshots and balance batches exercise closing, building, wave breaks and
## upgrades. Lives under Main so it survives screen changes and can chain runs.
##
## Flags (after `--`):
##   --autoplay=1          enable
##   --policy=greedy|random|external
##                         greedy: oldest pop-up, prefer completion, buy the
##                         first affordable building, first upgrade (default)
##                         random: uniformly random legal clicks
##                         external: ask a driver process (tools/policy_driver.py)
##                         through files in --policy-dir; see _step_external
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

# external policy state
var _policy_dir := ""
var _decision_seq := 0
var _decision_interval := 1.0
var _decision_timeout := 120.0
var _pending := false
var _since_decision := 0.0


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
	if policy == "external":
		_policy_dir = str(dev.get("policy_dir", "runs/policy"))
		_decision_interval = float(dev.get("decision_interval", "1.0"))
		_decision_timeout = float(dev.get("decision_timeout", "120"))
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_policy_dir))
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
		# --bsod-linger=S keeps the end screen up for S seconds so screenshots can see it.
		if screen._t >= maxf(BsodScreen.ACCEPT_DELAY, float(Game.dev.get("bsod_linger", "0"))):
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
	if desktop._clockout != null:
		# 5 PM: batches clock out unless --overtime=1 asks to keep going.
		var choice := "Overtime" if Game.dev.has("overtime") else "Clock out"
		var b := _find_button(desktop._clockout, choice)
		if b != null:
			_click(_center(b))
		return
	match policy:
		"random":
			_step_random(desktop)
		"external":
			_step_external(desktop)
		_:
			_step_greedy(desktop)


# ---------- external ----------
## Protocol: the bot writes <dir>/state_<seq>.json with the game state and the
## legal moves, then blocks (game time pauses with --fixed-fps) until the driver
## writes <dir>/move_<seq>.json {"move": "<id>"}. Menus, placement and the break
## dialog are handled by the greedy rules; the driver only decides the strategic
## moves: which pop-up to work on and how, what to build or sell, which upgrade to take.

func _step_external(desktop: Desktop) -> void:
	var run := desktop.run
	# Mechanical sub-steps the driver should not have to micro-manage.
	if desktop._confirm != null:
		_click(_center(_find_button(desktop._confirm, "No")))
		return
	if desktop.village.is_placing():
		var cell := desktop.village.suggest_cell(desktop.village.placing_id)
		if cell.x >= 0:
			_click(desktop.village.cell_center(cell))
		else:
			desktop.village.cancel_place()
		return
	_since_decision += TICK
	if _since_decision < _decision_interval and not desktop.break_dialog.visible:
		return
	_since_decision = 0.0
	var state := _external_state(desktop)
	var moves: Array = state["legal_moves"]
	if moves.size() <= 1:
		return  # only "wait": nothing to decide
	var move_id := _ask_driver(state)
	_apply_external_move(desktop, move_id, moves)


func _external_state(desktop: Desktop) -> Dictionary:
	var run := desktop.run
	var moves: Array[Dictionary] = [{"id": "wait", "kind": "wait", "desc": "do nothing this second"}]
	var popups: Array[Dictionary] = []
	if desktop.break_dialog.visible:
		for b: Win98Button in _find_all(desktop.break_dialog, _is_win98_button):
			var card := b.get_parent().get_parent()
			var name_l: Label = card.get_child(0).get_child(0) if card.get_child(0).get_child_count() > 0 else null
			var upgrade_name := name_l.text if name_l != null else "?"
			var uid := ""
			for d: String in UpgradeCatalog.DEFS.keys():
				if UpgradeCatalog.DEFS[d]["name"] == upgrade_name:
					uid = d
			moves.append({"id": "pick:" + uid, "kind": "pick_upgrade", "upgrade": uid, "desc": str(UpgradeCatalog.DEFS[uid]["desc"]) if uid != "" else upgrade_name})
	else:
		for p: PopupBase in desktop.imp_manager.live_popups():
			var pid := p.get_instance_id()
			var entry := {"id": pid, "type": p.type_id, "age": snappedf(p.total_age, 0.1), "ram_cost": p.ram_cost,
				"dismiss_reward": run.reward_for(p.def, false), "complete_reward": run.reward_for(p.def, true),
				"x_locked": p.x_locked(), "lifetime": float(p.def.get("lifetime", 0.0)), "age_since_timeout": snappedf(p.age, 0.1),
				"timeout_kind": str(p.def.get("on_timeout", {}).get("kind", "none")), "cheap_complete": _completion_control(p) != null,
				"dismiss_spawns": p.dismiss_spawns(), "imp_proof": p.is_imp_proof(), "leak": p.def.has("leak")}
			popups.append(entry)
			if not p.x_locked():
				moves.append({"id": "dismiss:%d" % pid, "kind": "dismiss", "popup": pid, "desc": "X the %s (+%d bytes)" % [p.type_id, entry["dismiss_reward"]]})
			if _completion_control(p) != null:
				moves.append({"id": "complete:%d" % pid, "kind": "complete", "popup": pid, "desc": "complete the %s in one click (+%d bytes)" % [p.type_id, entry["complete_reward"]]})
		for id: String in BuildingCatalog.available(run.unlocked_buildings):
			var owned := desktop.village.count(id)
			var cost := desktop.building_cost(id, owned)
			if owned < BuildingCatalog.max_count(id) and run.bytes >= cost and desktop.village.suggest_cell(id).x >= 0:
				moves.append({"id": "build:" + id, "kind": "build", "building": id, "cost": cost, "desc": "%s (%d bytes): %s" % [BuildingCatalog.DEFS[id]["name"], cost, BuildingCatalog.DEFS[id]["desc"]]})
	var owned_buildings := {}
	for c: Vector2i in desktop.village.buildings.keys():
		var b: Building = desktop.village.buildings[c]
		owned_buildings[b.id] = int(owned_buildings.get(b.id, 0)) + 1
		var refund := BuildingCatalog.refund(b.price_paid, run.in_break)
		moves.append({"id": "sell:%d,%d" % [c.x, c.y], "kind": "sell", "building": b.id, "cell": [c.x, c.y], "refund": refund,
			"desc": "sell the %s at %d,%d for %d bytes" % [BuildingCatalog.DEFS[b.id]["name"], c.x, c.y, refund]})
	var buildings := {}
	for id: String in BuildingCatalog.ORDER:
		buildings[id] = desktop.village.count(id)
	return {
		"seq": _decision_seq, "seed": run.seed, "t": snappedf(run.elapsed, 0.1), "wave": run.wave, "tier": run.tier,
		"workday_waves": RunState.WORKDAY_WAVES, "overtime": run.overtime,
		"wave_time_left": snappedf(run.wave_time_left, 0.1), "in_break": run.in_break,
		"bytes": run.bytes, "score": run.score, "ram_used": run.ram_used, "ram_max": run.ram_max,
		"overloaded": run.overloaded, "imps": desktop.imp_manager.imps.size(), "trained": desktop.imp_manager.count_trained(),
		"buildings": buildings, "owned_buildings": owned_buildings, "upgrades": run.upgrades_picked, "popups": popups, "legal_moves": moves,
	}


## Writes the state, blocks until the move file appears, returns the move id
## (or "wait" on timeout so a dead driver degrades to idling, not hanging).
func _ask_driver(state: Dictionary) -> String:
	var base := ProjectSettings.globalize_path(_policy_dir)
	var state_path := "%s/state_%d.json" % [base, _decision_seq]
	var move_path := "%s/move_%d.json" % [base, _decision_seq]
	var f := FileAccess.open(state_path + ".tmp", FileAccess.WRITE)
	if f == null:
		push_error("Autoplay: cannot write " + state_path)
		return "wait"
	f.store_string(JSON.stringify(state))
	f.close()
	DirAccess.rename_absolute(state_path + ".tmp", state_path)  # atomic publish
	var waited := 0.0
	while not FileAccess.file_exists(move_path):
		OS.delay_msec(20)
		waited += 0.02
		if waited >= _decision_timeout:
			push_warning("Autoplay: driver timed out on decision %d" % _decision_seq)
			_decision_seq += 1
			return "wait"
	OS.delay_msec(5)  # let the writer finish
	var mf := FileAccess.open(move_path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(mf.get_as_text()) if mf != null else null
	if mf != null:
		mf.close()
	_decision_seq += 1
	if parsed is Dictionary and parsed.has("move"):
		return str(parsed["move"])
	push_warning("Autoplay: malformed move file " + move_path)
	return "wait"


func _apply_external_move(desktop: Desktop, move_id: String, moves: Array) -> void:
	var legal := false
	for m: Dictionary in moves:
		if m["id"] == move_id:
			legal = true
	if not legal:
		push_warning("Autoplay: driver chose illegal move '%s'; waiting" % move_id)
		return
	var parts := move_id.split(":", true, 1)
	match parts[0]:
		"wait":
			pass
		"dismiss", "complete":
			var p := instance_from_id(int(parts[1])) as PopupBase
			if p == null or p.is_closing:
				return
			var btn: Control = p.close_button if parts[0] == "dismiss" else _completion_control(p)
			if btn != null:
				_click(_center(btn))
		"build":
			var idx := BuildingCatalog.ORDER.find(parts[1])
			if idx >= 0:
				desktop._begin_place(BuildingCatalog.ORDER[idx])  # placement is finished by the mechanical rules
		"sell":
			var xy := parts[1].split(",")
			if xy.size() == 2:
				desktop.call("demolish", Vector2i(int(xy[0]), int(xy[1])))  # call(): Desktop.demolish lands with the desktop change
		"pick":
			for b: Win98Button in _find_all(desktop.break_dialog, _is_win98_button):
				var card := b.get_parent().get_parent()
				var name_l: Label = card.get_child(0).get_child(0)
				if UpgradeCatalog.DEFS.has(parts[1]) and name_l.text == UpgradeCatalog.DEFS[parts[1]]["name"]:
					_click(_center(b))
					return


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
		var cell := desktop.village.suggest_cell(desktop.village.placing_id)
		if cell.x >= 0:
			_click(desktop.village.cell_center(cell))
		else:
			desktop.village.cancel_place()
		return
	if desktop.start_menu.visible:
		var avail := BuildingCatalog.available(run.unlocked_buildings)
		for i in range(avail.size()):
			var id: String = avail[i]
			var owned := desktop.village.count(id)
			if owned < BuildingCatalog.max_count(id) and run.bytes >= desktop.building_cost(id, owned) and i < desktop.start_menu._items.size():
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
	if btn == null or (rng.randf() < 0.3 and p.dismiss_spawns() == 0):
		if p.x_locked() or (p.dismiss_spawns() > 0 and btn != null):
			return
		btn = p.close_button if p.dismiss_spawns() == 0 else btn
	if btn != null:
		_click(_center(btn))


## The control that advances a pop-up toward completion, or null if the bot
## has no recipe for it. Multi-step types return the next step's control.
func _completion_control(p: PopupBase) -> Control:
	match p.type_id:
		"error":
			return _find_button(p, "OK")
		"update":
			return _find_button(p, "Install")
		"ad", "virus":
			return _find_link(p)
		"leak":
			for b: Control in _find_all(p.content, _is_win98_button):
				return b  # the single step button (3 clicks)
		"chat":
			var edit := _find_line_edit(p)
			if edit != null:
				edit.text = "hello"
			return _find_button(p, "Send")
		"cookie":
			# Page 1: Manage (or Reject all with Consent Manager). Page 2: uncheck, then Confirm/Reject all.
			var manage := _find_button(p, "Manage...")
			if manage != null and manage.is_visible_in_tree():
				return manage
			var reject := _find_button(p, "Reject all")
			if reject != null and reject.is_visible_in_tree():
				return reject
			for c: Control in _find_all(p.content, _is_base_button):
				if c is CheckBox and c.button_pressed and not c.disabled:
					return c
			return _find_button(p, "Confirm")
	return null


# ---------- random ----------

func _step_random(desktop: Desktop) -> void:
	if desktop.break_dialog.visible:
		var picks := _find_all(desktop.break_dialog, _is_win98_button)
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
	if not p.x_locked() and p.dismiss_spawns() == 0:
		targets.append(p.close_button)
	for c: Control in _find_all(p.content, _is_base_button):
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


## Collects visible controls matching `pred` (a Callable taking a Node). Uses a
## predicate because Object.is_class() only knows native classes, not class_name scripts.
func _find_all(root: Node, pred: Callable) -> Array[Control]:
	var out: Array[Control] = []
	if root is Control and pred.call(root) and root.is_visible_in_tree():
		out.append(root)
	for c: Node in root.get_children():
		out.append_array(_find_all(c, pred))
	return out


static func _is_win98_button(n: Node) -> bool:
	return n is Win98Button


static func _is_base_button(n: Node) -> bool:
	return n is BaseButton


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
