class_name Desktop
extends Control
## The gameplay screen: wallpaper village, pop-up layer, imps, taskbar, menus.

const DESKTOP_H := 690
const TASKBAR_H := 30

var run: RunState
var rng := RandomNumberGenerator.new()
var village: Village
var popup_layer: Control
var imp_layer: Node2D
var float_layer: Control
var taskbar: Taskbar
var start_menu: StartMenu
var break_dialog: BreakDialog
var spawner: PopupSpawner
var imp_manager: ImpManager
var telemetry := Telemetry.new()

var _ended := false
var _confirm: ConfirmDialog
var _overload_logged := false
var _clockout: ConfirmDialog
var trauma := 0.0           ## screen shake, decays each frame (Juice.add_trauma)
var _wall: ColorRect
var _rise_timer := 0.0
var _wave_score_start := 0
var _shake_rng := RandomNumberGenerator.new()  # cosmetic only; seeded so screenshots are stable
var task_manager: TaskManager       ## open Task Manager window, or null
var _freeze_overlay: Control        ## dimmer shown while Ctrl+Alt+Del is held
var _freeze_auto := -1.0            ## bots: release the freeze after this many seconds


func _ready() -> void:
	run = Game.run
	assert(run.seed >= 0, "Game.start_run() must assign a seed before the desktop opens")
	rng.seed = run.seed
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var wall := ColorRect.new()
	wall.color = Win98.DESKTOP
	wall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wall)
	_wall = wall
	_shake_rng.seed = 98

	village = Village.new()
	village.size = Vector2(1280, DESKTOP_H)
	village.place_requested.connect(_on_place_requested)
	village.placement_changed.connect(func(active: bool) -> void:
		if active:
			start_menu.visible = false)
	village.icon_activated.connect(_on_icon_activated)
	village.demolish_requested.connect(func(cell: Vector2i) -> void: demolish(cell))
	village.relocate_requested.connect(_relocate)
	village.refund_preview = func(cell: Vector2i) -> int:
		return BuildingCatalog.refund(village.buildings[cell].price_paid, run.in_break)
	add_child(village)

	popup_layer = Control.new()
	popup_layer.name = "Popups"
	popup_layer.size = Vector2(1280, DESKTOP_H)
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup_layer)

	imp_layer = Node2D.new()
	imp_layer.name = "Imps"
	add_child(imp_layer)

	float_layer = Control.new()
	float_layer.name = "FloatText"
	float_layer.size = Vector2(1280, 720)
	float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(float_layer)

	taskbar = Taskbar.new()
	taskbar.position = Vector2(0, DESKTOP_H)
	taskbar.size = Vector2(1280, TASKBAR_H)
	taskbar.start_pressed.connect(_toggle_start_menu)
	taskbar.tooltip_text = "Run seed: %d" % run.seed
	taskbar.ability_pressed.connect(func(id: String) -> void: use_ability(id))
	taskbar.ability_released.connect(func(id: String) -> void:
		if id == "ctrl_alt_del":
			_end_freeze())
	add_child(taskbar)

	start_menu = StartMenu.new()
	start_menu.building_chosen.connect(_begin_place)
	start_menu.demolish_requested.connect(_begin_demolish)
	start_menu.shutdown_requested.connect(_ask_shutdown)
	start_menu.visibility_changed.connect(func() -> void: village.show_rings = start_menu.visible)
	add_child(start_menu)
	start_menu.position = Vector2(2, DESKTOP_H - start_menu.size.y)

	break_dialog = BreakDialog.new()
	break_dialog.upgrade_chosen.connect(_on_upgrade_chosen)
	add_child(break_dialog)
	break_dialog.drag_bounds = Rect2(Vector2.ZERO, Vector2(1280, DESKTOP_H))

	spawner = PopupSpawner.new()
	spawner.setup(run, rng, popup_layer)
	spawner.popup_spawned.connect(_wire_popup)
	spawner.village = village
	add_child(spawner)

	imp_manager = ImpManager.new()
	imp_manager.setup(run, rng, imp_layer, popup_layer)
	imp_manager.village = village
	imp_manager.training_started.connect(func(imp: Imp, dojo: Node2D) -> void:
		_log("train_start", {"imp": imp.get_instance_id(), "closes": imp.closes})
		_float("off to the dojo", imp.position + Vector2(0, -28), Color.WHITE, 11))
	imp_manager.imp_trained.connect(_on_imp_trained)
	add_child(imp_manager)

	run.crashed.connect(_on_crashed)
	run.overload_changed.connect(_on_overload_changed)
	_open_telemetry()
	run.start_wave(1)
	_place_starting_buildings()
	if Game.dev.has("demo"):
		_demo_setup()
	match str(Game.dev.get("ui", "")):
		"start":
			_toggle_start_menu()
		"break":
			_start_break()
		"place":
			_begin_place("hut")
		"gallery0", "gallery1", "gallery2":
			_gallery(int(str(Game.dev["ui"]).substr(7)))
		"taskman":
			use_ability("task_manager")
		"freeze":
			use_ability("ctrl_alt_del")
			freeze_for(2.0)


## Dev: lay out one of each pop-up type on a grid with the spawner off, for
## visual review. Page 2 shows the multi-step types advanced to their later pages.
func _gallery(page: int) -> void:
	spawner.active = false
	var ids: Array[String] = []
	for id: String in PopupCatalog.DEFS.keys():
		ids.append(id)
	ids.sort()
	var chosen: Array[String] = []
	if page == 2:
		chosen = ["cookie", "toolbar", "leak", "update", "captcha", "chat"]
	else:
		for i in range(ids.size()):
			if i / 6 == page:
				chosen.append(ids[i])
	run.unlocked_popups = ["clock_out", "hundred_closed", "dojo_built"]
	for i in range(chosen.size()):
		var p := spawner.spawn(chosen[i])
		p.position = Vector2(12 + (i % 3) * 424, 12 + (i / 3) * 340)
		if page == 2:
			var c: Node = p.content_node
			match chosen[i]:
				"cookie", "toolbar":
					c.call("_goto", 1)
				"leak":
					c.call("_advance")
				"update":
					c.set("_installing", true)
					c.get("_bar").visible = true
				"captcha":
					c.get("_hint").text = "Incorrect. Try again."
				"chat":
					c.get("_input").text = "help me"
	_banner("HOUR 1", Color("ffd700"))


## Per-frame cosmetics: shake decay, overload darkening, the rising RAM tone.
func _feel(delta: float) -> void:
	if not Juice.enabled:
		return
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - delta * 1.6)
		position = Juice.shake_offset(trauma, 14.0, _shake_rng)
	elif position != Vector2.ZERO:
		position = Vector2.ZERO
	var fill := run.ram_fraction()
	var dark := clampf((fill - 0.7) / 0.3, 0.0, 1.0) * 0.45
	_wall.color = Win98.DESKTOP.darkened(dark)
	if fill > 0.75 and not run.in_break:
		_rise_timer -= delta
		if _rise_timer <= 0.0:
			_rise_timer = lerpf(1.2, 0.35, clampf((fill - 0.75) / 0.35, 0.0, 1.0))
			Sfx.play("rise", lerpf(0.8, 1.6, clampf((fill - 0.75) / 0.35, 0.0, 1.0)), -4.0, 0.0)


var _graduation_hint_shown := false


func _on_imp_trained(imp: Imp, dojo: Node2D) -> void:
	_log("train_done", {"imp": imp.get_instance_id(), "trained_total": imp_manager.count_trained()})
	_float("graduated!", imp.position + Vector2(0, -30), Color("7CFC00"), 14)
	Sfx.play("chime_big", 1.1, 0.0, 0.0)
	if not _graduation_hint_shown:
		_graduation_hint_shown = true
		_float("Trained imps complete pop-ups for the full reward.", Vector2(640, 150), Color.WHITE, 15, 30.0, 3.0)


func _open_telemetry() -> void:
	if not Game.dev.has("no_telemetry"):
		var dir := str(Game.dev.get("telemetry_dir", "user://telemetry"))
		telemetry.open_sink("%s/%d_%d.jsonl" % [dir, Time.get_unix_time_from_system(), run.seed])
	var perks: Array[String] = Game.meta.unlocks.duplicate()
	_log("run_start", {"seed": run.seed, "tier": run.tier, "policy": str(Game.dev.get("policy", "greedy")) if Game.dev.has("autoplay") else "human", "perks": perks, "unlocked": run.unlocked_popups, "tune": Tuning.spec})


func _log(ev: String, fields: Dictionary = {}) -> void:
	telemetry.event(ev, run.elapsed, run.wave, fields)


func _on_overload_changed(active: bool, seconds_left: float) -> void:
	if active != _overload_logged:
		_overload_logged = active
		_log("overload", {"active": active, "seconds_left": snappedf(seconds_left, 0.01)})
		if active:
			Sfx.play("warn", 1.0, 0.0, 0.0)
			Juice.add_trauma(self, 0.3)


func _place_starting_buildings() -> void:
	for id: String in run.starting_buildings:
		var cell := village.first_free_cell()
		if cell.x >= 0:
			_build(id, cell, 0)


## Fills the desk for screenshots and smoke tests.
func _demo_setup() -> void:
	run.add_bytes(400)
	for id: String in ["hut", "hut", "hut", "dojo", "coffee", "ram"]:
		var cell := village.first_free_cell()
		if cell.x >= 0:
			_build(id, cell, 0)
	for t: String in ["ad", "error", "survey", "update", "captcha", "virus"]:
		spawner.spawn(t)


func _process(delta: float) -> void:
	if _ended:
		return
	run.tick(delta)
	_feel(delta)
	if _freeze_overlay != null:
		if run.frozen:
			_freeze_overlay.queue_redraw()
			if _freeze_auto >= 0.0 and run.freeze_time >= _freeze_auto:
				_end_freeze()
		else:
			_end_freeze()  # the tick ended it: held too long, the machine reset
	if run.workday_over():
		_workday_end()
	elif run.wave_finished():
		_start_break()
	# Dev run limits so bot batches finish: end after N waves or N seconds.
	if Game.dev.has("max_wave") and run.wave > int(Game.dev["max_wave"]):
		_end("MAX_WAVE")
		return
	if Game.dev.has("max_seconds") and run.elapsed >= float(Game.dev["max_seconds"]):
		_end("MAX_SECONDS")
		return
	_tick_bin(delta)
	taskbar.update_from(run, imp_manager.imps.size(), imp_manager.count_trained())


# ---------- pop-ups ----------

func _wire_popup(popup: PopupBase) -> void:
	popup.closed.connect(_on_popup_closed)
	popup.timed_out.connect(_on_popup_timed_out)
	popup.trap_hit.connect(_on_trap_hit)
	popup.leaked.connect(_on_popup_leaked)
	popup.hopped.connect(func(p: PopupBase) -> void:
		_log("hop", {"type": p.type_id})
		_float("nope!", p.global_position + Vector2(p.size.x * 0.5, 10), Color("ff6060"), 12))
	popup.drag_moved.connect(func(pos: Vector2) -> void: _on_popup_drag_moved(popup, pos))
	popup.drag_ended.connect(func(pos: Vector2) -> void: _on_popup_dropped(popup, pos))
	_log("popup_spawned", {"type": popup.type_id, "ram_cost": popup.ram_cost, "clustered": popup.spawned_near, "ram_used": run.ram_used})


func _on_popup_closed(popup: PopupBase, completed: bool, by_imp: bool) -> void:
	var reward := run.reward_for(popup.def, completed, not by_imp)
	if not by_imp:
		reward += run.click_bonus
	var streak_before := run.streak
	run.popup_closed(popup.ram_cost, completed, by_imp)
	run.add_bytes(reward)
	if not by_imp:
		run.note_manual_close(completed)
		if completed and run.streak >= 3 and run.streak <= RunState.STREAK_CAP:
			_float("streak x%d" % run.streak, popup.global_position + Vector2(popup.size.x * 0.5, -8), Color("ffd700"), 13)
		elif not completed and streak_before >= 3:
			_float("streak lost", popup.global_position + Vector2(popup.size.x * 0.5, -8), Color("ff6060"), 12)
	imp_manager.on_popup_closed(popup)
	_log("popup_closed", {"type": popup.type_id, "completed": completed, "by_imp": by_imp, "age": snappedf(popup.total_age, 0.01), "reward": reward, "ram_used": run.ram_used, "streak": run.streak})
	var at := popup.global_position + Vector2(popup.size.x * 0.5, 10)
	var col := Color("7CFC00") if completed else Color.WHITE
	if reward > 0:
		_float("+%d" % reward, at, col, clampi(12 + reward * 2, 13, 30))
	else:
		_float("leak stopped" if popup.def.has("leak") else "closed", at, Color("c0c0c0"), 12)
	if completed:
		Sfx.play("chime_big" if reward >= 8 else "chime", 1.0 + minf(reward, 10) * 0.02 + (0.05 * mini(run.streak, RunState.STREAK_CAP) if not by_imp else 0.0))
	else:
		Sfx.play("click", 1.0 if not by_imp else 1.25)
	if not completed and popup.dismiss_spawns() > 0 and not popup.killed:
		# Consent fatigue: X-ing a cookie banner brings two more (End Task kills the process instead).
		var spawn_type := str(popup.def["on_dismiss"].get("type", popup.type_id))
		for i in range(popup.dismiss_spawns()):
			spawner.spawn(spawn_type, popup.global_position + popup.size * 0.5)
		_log("dismiss_penalty", {"type": popup.type_id, "count": popup.dismiss_spawns()})
		_float("consent fatigue", at + Vector2(0, 20), Color("ff6060"), 12)
		Sfx.play("multiply", 0.8)
	Juice.pop_out(popup, popup.queue_free)


func _on_popup_leaked(popup: PopupBase, grow: int) -> void:
	var extra := maxi(1, int(round(grow * run.leak_growth_mult)))
	popup.ram_cost += extra
	run.add_ram_cost(extra)
	Juice.flash(popup, Color(1.5, 0.6, 0.6), 0.4)
	Sfx.play("multiply", 0.6, -6.0)
	_log("leak_grow", {"type": popup.type_id, "grow": extra, "ram_cost": popup.ram_cost})
	_float("+%d RAM" % extra, popup.global_position + Vector2(popup.size.x * 0.5, 10), Color("ff6060"), 12)


func _on_popup_timed_out(popup: PopupBase) -> void:
	var ot: Dictionary = popup.def.get("on_timeout", {"kind": "none"})
	var near := popup.global_position + popup.size * 0.5
	_log("popup_timeout", {"type": popup.type_id, "kind": str(ot.get("kind", "none")), "timeouts": popup.timeouts})
	if str(ot.get("kind", "none")) != "none":
		Sfx.play("multiply")
		Juice.add_trauma(self, 0.18)
	match str(ot.get("kind", "none")):
		"multiply":
			if run.timeouts_multiply:
				for i in range(int(ot.get("count", 1)) * run.timeout_multiplier):
					spawner.spawn(popup.type_id, near)
				_float("multiplied!", near, Color("ff6060"), 12)
		"spawn":
			if run.timeouts_multiply:
				for i in range(int(ot.get("count", 1))):
					spawner.spawn(str(ot.get("type", "error")), near)
				_float("spawned errors!", near, Color("ff6060"), 12)
		"escalate":
			var extra := int(ot.get("count", 4))
			popup.ram_cost += extra
			run.add_ram_cost(extra)
			_float("+%d RAM" % extra, near, Color("ff6060"), 12)


func _on_trap_hit(popup: PopupBase, kind: String) -> void:
	var near := popup.global_position + popup.size * 0.5
	_log("remind_later" if kind == "remind" else "trap", {"type": popup.type_id, "kind": kind})
	if kind != "remind":
		Sfx.play("error")
		Juice.flash(popup, Color(1.5, 0.6, 0.6), 0.4)
		Juice.add_trauma(self, 0.25)
	match kind:
		"trap":
			for i in range(2):
				spawner.spawn("ad", near)
			_float("it was a trap", near, Color("ff6060"), 12)
		"scan":
			for i in range(2):
				spawner.spawn("error", near)
			_float("'scan' found more errors", near, Color("ff6060"), 12)
		"remind":
			# No reward, and it comes back.
			run.popup_closed(popup.ram_cost, false, false)
			imp_manager.on_popup_closed(popup)
			popup.is_closing = true
			Juice.pop_out(popup, popup.queue_free)
			spawner.queue("update", 8.0, near)
			_float("later...", near, Color.WHITE, 12)
		"subscribed":
			for i in range(2):
				spawner.spawn("ad", near)
			_float("subscribed to spam", near, Color("ff6060"), 12)
		"bundled":
			spawner.spawn("ad", near)
			_float("Weather Buddy installed", near, Color("ff6060"), 12)
		"accept_all":
			for i in range(2):
				spawner.spawn("ad", near)
			_float("847 partners notified", near, Color("ff6060"), 12)
		_:
			pass


# ---------- waves ----------

## 5 PM: the workday is survived. Clock out (win) or keep going (overtime).
func _workday_end() -> void:
	if _clockout != null:
		return
	run.log_wave_end(imp_manager.imps.size(), imp_manager.count_trained())
	_log("wave_end", run.wave_log[run.wave_log.size() - 1])
	run.begin_break()
	run.clock_out()
	_log("clock_out", {"score": run.score, "tier": run.tier})
	Sfx.play("fanfare", 1.0, 2.0, 0.0)
	village.cancel_place()
	village.cancel_demolish()
	start_menu.visible = false
	_banner("5:00 PM", Color("ffd700"))
	_clockout = ConfirmDialog.new("It's 5:00 PM", "You survived the workday with %d bytes banked.\n\nOvertime pays 1.5x but spawns 10%% faster every hour, breaks offer one card, and if the machine crashes you keep the banked %d plus half of what you earned after." % [run.score, run.score])
	_clockout.set_window_size(Vector2(400, 190))
	var yes := _find_button(_clockout, "Yes")
	var no := _find_button(_clockout, "No")
	if yes != null:
		yes.label = "Clock out"
		yes.custom_minimum_size = Vector2(95, 23)
	if no != null:
		no.label = "Overtime"
		no.custom_minimum_size = Vector2(95, 23)
	_clockout.answered.connect(func(clock_out: bool) -> void:
		_clockout.queue_free()
		_clockout = null
		if clock_out:
			_end("CLOCKED_OUT")
		else:
			_log("overtime", {})
			run.start_overtime()
			village.set_relocate_enabled(false)
			_banner("OVERTIME", Color("ff6060")))
	add_child(_clockout)
	_clockout.center_in_parent()


func _find_button(root: Node, label: String) -> Win98Button:
	if root is Win98Button and root.label == label:
		return root
	for c: Node in root.get_children():
		var f := _find_button(c, label)
		if f != null:
			return f
	return null


func _start_break() -> void:
	run.log_wave_end(imp_manager.imps.size(), imp_manager.count_trained())
	_log("wave_end", run.wave_log[run.wave_log.size() - 1])
	run.begin_break()
	var earned := run.score - _wave_score_start
	_wave_score_start = run.score
	_float("Hour %d done: +%d bytes" % [run.wave, earned], Vector2(640, 190), Color("ffd700"), 22)
	Sfx.play("chime_big", 0.9, 0.0, 0.0)
	var choices := UpgradeCatalog.roll(rng, run, 1 if run.overtime else 3)
	var offered: Array[String] = []
	for c: Dictionary in choices:
		offered.append(str(c["id"]))
	_log("upgrade_offered", {"ids": offered})
	break_dialog.show_choices(run.wave, choices)
	break_dialog.center_in_parent()
	_close_task_manager()
	_end_freeze()
	village.cancel_place()
	village.cancel_demolish()
	village.set_relocate_enabled(true)  # drag buildings around for free until the break ends
	start_menu.visible = false


func _on_upgrade_chosen(id: String) -> void:
	run.upgrades_picked.append(id)
	_log("upgrade_picked", {"id": id})
	var effect := UpgradeCatalog.apply(id, run)
	match effect:
		"spawn_imp":
			imp_manager.spawn_imp(Vector2(rng.randf_range(200, 1000), rng.randf_range(100, 600)))
		"resize_x":
			for p: Node in popup_layer.get_children():
				if p is PopupBase:
					p.set_close_button_size(run.close_button_size)
	break_dialog.visible = false
	run.end_break()
	village.set_relocate_enabled(false)
	_banner("HOUR %d" % run.wave, Color("ffd700"))


# ---------- building ----------

func _toggle_start_menu() -> void:
	if start_menu.visible:
		start_menu.visible = false
		return
	start_menu.refresh(run, village)
	start_menu.position = Vector2(2, DESKTOP_H - start_menu.size.y)
	start_menu.visible = true
	start_menu.move_to_front()


func _begin_place(id: String) -> void:
	start_menu.visible = false
	if not (id in BuildingCatalog.available(run.unlocked_buildings)):
		return
	if village.count(id) >= BuildingCatalog.max_count(id):
		_float("maxed out", Vector2(640, 300), Color("ff6060"), 14)
		return
	var cost := building_cost(id, village.count(id))
	if run.bytes < cost:
		_need_bytes(cost, Vector2(640, 300))
		return
	village.begin_place(id, true)


var _last_need_float := -10.0


## "need N bytes", at most once per second so a held click cannot spam it.
func _need_bytes(cost: int, at: Vector2) -> void:
	if run.elapsed - _last_need_float < 1.0:
		return
	_last_need_float = run.elapsed
	_float("need %d bytes" % cost, at, Color("ff6060"), 12)


func building_cost(id: String, owned: int) -> int:
	return BuildingCatalog.cost(id, owned, run.building_cost_mult)


func _on_place_requested(id: String, cell: Vector2i) -> void:
	var owned := village.count(id)
	var cost := building_cost(id, owned)
	if owned >= BuildingCatalog.max_count(id):
		village.cancel_place()
		return
	if not run.spend(cost):
		_need_bytes(cost, village.cell_center(cell))
		return
	_build(id, cell, cost)
	# stay in placement mode while another copy is possible and affordable
	var next_owned := village.count(id)
	if next_owned >= BuildingCatalog.max_count(id) or run.bytes < building_cost(id, next_owned):
		village.cancel_place()
	else:
		village.set_affordable(true)


## Places a building and applies its effect. Coffee carts and firewalls have no
## global effect any more: carts speed imps per hut (ImpManager.speed_mult_for)
## and firewalls are no-spawn zones the spawner reads from the village.
func _build(id: String, cell: Vector2i, cost: int) -> void:
	village.add_building(id, cell, cost)
	run.buildings_built += 1
	run.buildings_list.append(id)
	_log("build", {"id": id, "cell": [cell.x, cell.y], "cost": cost, "bytes_after": run.bytes, "owned_after": village.count(id)})
	var at := village.cell_center(cell)
	match id:
		"hut":
			imp_manager.spawn_imp(at + Vector2(0, 18), cell)
		"dojo":
			imp_manager.add_dojo(village.buildings[cell])
		"ram":
			run.set_ram_max(run.ram_max + 32)
		"antivirus":
			run.timeouts_multiply = false
		"shrine":
			run.click_bonus += 1
		"helpdesk":
			run.helpdesk = true
		"screensaver":
			spawner.screensaver = true
	if cost > 0:
		_float("-%d" % cost, at, Color("ffd700"), 13)
		Sfx.play("chime", 0.7)


var _demolish_hint_shown := false


func _begin_demolish() -> void:
	start_menu.visible = false
	if _ended or village.buildings.is_empty():
		return
	village.begin_demolish()
	if not _demolish_hint_shown:
		_demolish_hint_shown = true
		_float("Click a building to sell it. Right-click to stop.", Vector2(640, 150), Color.WHITE, 15, 30.0, 3.0)


## Sells the building at `cell`, reversing _build's effect and refunding part of
## the price (BuildingCatalog.refund). Public: the bot's external policy calls it.
## Returns false, with a float saying why, when nothing was sold.
func demolish(cell: Vector2i) -> bool:
	if _ended or run.crashed_flag:
		return false
	var b: Building = village.buildings.get(cell)
	var at := village.cell_center(cell)
	if b == null:
		_float("nothing to sell there", at, Color("ff6060"), 12)
		return false
	var id := b.id
	if id == "ram" and run.ram_used > run.ram_max - 32:
		_float("would crash!", at, Color("ff6060"), 13)
		return false
	match id:
		"hut":
			var fired := imp_manager.fire_from_hut(cell)
			if fired != null:
				_float("fired", fired.position + Vector2(0, -28), Color("ff6060"), 11)
		"dojo":
			imp_manager.remove_dojo(b)
		"coffee", "firewall":
			pass  # local effects go with the building
		"ram":
			run.set_ram_max(run.ram_max - 32)
		"antivirus":
			run.timeouts_multiply = not ("antivirus_patch" in run.upgrades_picked)
		"shrine":
			run.click_bonus -= 1
		"helpdesk":
			run.helpdesk = false
		"screensaver":
			spawner.screensaver = false
	var refund := BuildingCatalog.refund(b.price_paid, run.in_break)
	run.bytes += refund  # a refund is not score, so not add_bytes
	run.bytes_changed.emit(run.bytes)
	run.buildings_list.erase(id)
	village.remove_building(cell)
	_log("demolish", {"id": id, "cell": [cell.x, cell.y], "refund": refund, "bytes_after": run.bytes, "owned_after": village.count(id)})
	_float("+%d" % refund, at, Color("ffd700"), 13)
	Sfx.play("chime", 0.5)
	if village.buildings.is_empty():
		village.cancel_demolish()
	return true


## A building was dragged to a free cell during a break (Village handles the
## drag; relocation is free). Huts take their imps with them.
func _relocate(from: Vector2i, to: Vector2i) -> void:
	var b: Building = village.buildings.get(from)
	if b == null or not village.move_building(from, to):
		return
	if b.id == "hut":
		imp_manager.rehome(from, to, village.cell_center(to) + Vector2(0, 18))
	_log("relocate", {"id": b.id, "from": [from.x, from.y], "to": [to.x, to.y]})
	_float("moved", village.cell_center(to), Color.WHITE, 12)


func _on_icon_activated(kind: String) -> void:
	match kind:
		"imps":
			_toggle_start_menu()
		"computer":
			_float("RAM %d/%d  Imps %d  Score %d" % [run.ram_used, run.ram_max, imp_manager.imps.size(), run.score], Vector2(640, 200), Color.WHITE, 14)
		"bin":
			if run.bin_items > 0:
				empty_bin()
			else:
				_float("Nothing to recycle. Yet.", Vector2(640, 200), Color.WHITE, 14)


# ---------- recycle bin ----------
## Drag a pop-up onto the Recycle Bin icon to delete it: no reward, no penalty
## (no cookie spawn, no remind-later, no streak change), RAM freed. The bin holds
## RunState.BIN_CAPACITY windows; "Empty Recycle Bin" (double-click the icon)
## takes BIN_EMPTY_SECONDS of game time. Imps never use it.

const BIN_EMPTY_SECONDS := 2.0

var _bin_emptying := false
var _bin_empty_t := 0.0


func _on_popup_drag_moved(popup: PopupBase, pos: Vector2) -> void:
	village.bin_icon().highlight = not popup.is_closing and village.bin_rect().has_point(pos)


## A pop-up was released after a drag. Public: the bot's external policy calls it
## with the bin centre instead of simulating a drag. Returns true when recycled.
func _on_popup_dropped(popup: PopupBase, pos: Vector2) -> bool:
	village.bin_icon().highlight = false
	if _ended or popup.is_closing or not village.bin_rect().has_point(pos):
		return false
	var at := popup.global_position + Vector2(popup.size.x * 0.5, 10)
	if _bin_emptying or not run.bin_has_room():
		_float("Recycle Bin is emptying..." if _bin_emptying else "Recycle Bin is full", at, Color("ff6060"), 13)
		popup.global_position.x += 40.0  # off the icon so the next drag starts clean
		return false
	run.recycle_popup(popup.ram_cost)
	imp_manager.on_popup_closed(popup)
	popup.recycle()
	village.bin_icon().bin_items = run.bin_items
	_log("recycled", {"type": popup.type_id, "age": snappedf(popup.total_age, 0.01), "ram_used": run.ram_used, "bin_items": run.bin_items})
	_float("recycled", at, Color("c0c0c0"), 12)
	Sfx.play("click", 0.7)
	return true


## Starts "Empty Recycle Bin" (double-click, or the bot). Returns false if there
## is nothing to empty or it is already running.
func empty_bin() -> bool:
	if _ended or _bin_emptying or run.bin_items <= 0:
		return false
	_bin_emptying = true
	_bin_empty_t = 0.0
	village.bin_icon().emptying = 0.001  # the bar appears at once
	_float("Emptying Recycle Bin...", Vector2(640, 200), Color.WHITE, 13)
	return true


func _tick_bin(delta: float) -> void:
	if not _bin_emptying or run.in_break:
		return
	_bin_empty_t += delta
	var icon := village.bin_icon()
	icon.emptying = clampf(_bin_empty_t / BIN_EMPTY_SECONDS, 0.001, 1.0)
	if _bin_empty_t < BIN_EMPTY_SECONDS:
		return
	_bin_emptying = false
	run.empty_bin()
	icon.bin_items = 0
	icon.emptying = 0.0
	_log("bin_emptied", {})
	_float("Recycle Bin emptied", Vector2(640, 200), Color.WHITE, 13)
	Sfx.play("crunch", 1.0, 0.0, 0.0)


# ---------- ending ----------

func _ask_shutdown() -> void:
	start_menu.visible = false
	if _confirm != null:
		return
	_confirm = ConfirmDialog.new("Shut Down Windows", "Are you sure you want to end this run?\nYour score will be recorded.")
	_confirm.answered.connect(func(yes: bool) -> void:
		_confirm.queue_free()
		_confirm = null
		if yes:
			_end("SHUTDOWN"))
	add_child(_confirm)
	_confirm.center_in_parent()


func _on_crashed(reason: String) -> void:
	if Juice.enabled and not _ended:
		# Half a second of static and a big shake, then the BSOD.
		_ended = true
		set_process(false)
		spawner.active = false
		Sfx.play("crash", 1.0, 4.0, 0.0)
		var static_layer := Control.new()
		static_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		static_layer.mouse_filter = Control.MOUSE_FILTER_STOP
		var srng := RandomNumberGenerator.new()
		srng.seed = 1998
		static_layer.draw.connect(func() -> void:
			for i in range(900):
				var p := Vector2(srng.randf() * 1280.0, srng.randf() * 720.0)
				static_layer.draw_rect(Rect2(p, Vector2(srng.randf_range(2, 40), srng.randf_range(1, 3))), Color(srng.randf(), srng.randf(), srng.randf(), 0.8)))
		add_child(static_layer)
		var tw := create_tween()
		tw.tween_interval(0.08)
		for i in range(5):
			tw.tween_callback(static_layer.queue_redraw)
			tw.tween_callback(func() -> void: position = Juice.shake_offset(1.0, 18.0, _shake_rng))
			tw.tween_interval(0.08)
		tw.tween_callback(func() -> void:
			_ended = false
			_end(reason))
		return
	_end(reason)


func _end(reason: String) -> void:
	if _ended:
		return
	_ended = true
	set_process(false)
	spawner.active = false
	_close_task_manager()
	village.cancel_demolish()
	village.set_relocate_enabled(false)
	run.crash_reason = reason
	var summary := run.summary()
	summary.erase("waves")
	_log("run_end", summary)
	telemetry.close()
	Game.call_deferred("end_run", reason)


func _exit_tree() -> void:
	# One line per run for log-diffing seeded replays (see CLAUDE.md, Determinism).
	if run != null:
		print("seed=%d state wave=%d bytes=%d score=%d ram=%d/%d spawned=%d closed=%d completed=%d imps=%d buildings=%d" % [
			run.seed, run.wave, run.bytes, run.score, run.ram_used, run.ram_max,
			run.popups_spawned, run.popups_closed, run.popups_completed, imp_manager.imps.size(), run.buildings_built])


# ---------- input ----------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		start_menu.visible = false
		village.deselect_icons()


func _unhandled_input(event: InputEvent) -> void:
	if _ended or not (event is InputEventKey):
		return
	var key: InputEventKey = event
	if not key.pressed:
		# Letting go of any key of the chord ends a Ctrl+Alt+Del freeze.
		if run.frozen and (key.keycode == KEY_DELETE or key.keycode == KEY_CTRL or key.keycode == KEY_ALT):
			_end_freeze()
		return
	if key.echo:
		return
	if key.keycode == KEY_DELETE and key.ctrl_pressed and key.alt_pressed:
		use_ability("ctrl_alt_del")
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE and key.ctrl_pressed and key.shift_pressed:
		use_ability("task_manager")
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_F4 and key.alt_pressed:
		use_ability("alt_f4")
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE:
		if village.is_busy():
			village.cancel_place()
			village.cancel_demolish()
		start_menu.visible = false
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_B:
		_toggle_start_menu()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_D:
		_begin_demolish()
		get_viewport().set_input_as_handled()
	elif key.keycode >= KEY_1 and key.keycode <= KEY_9:
		var idx := int(key.keycode - KEY_1)
		var avail := BuildingCatalog.available(run.unlocked_buildings)
		if idx < avail.size() and not run.in_break:
			_begin_place(avail[idx])
			get_viewport().set_input_as_handled()


# ---------- abilities (docs/FEATURES.md item 5) ----------

## The front-most live pop-up (the one Alt+F4 would close), or null.
func front_popup() -> PopupBase:
	var kids := popup_layer.get_children()
	for i in range(kids.size() - 1, -1, -1):
		if kids[i] is PopupBase and not (kids[i] as PopupBase).is_closing:
			return kids[i]
	return null


## Uses an ability by id (keyboard chord, tray icon, or a bot). Returns false,
## with a float saying why, when it was not ready or had nothing to act on.
func use_ability(id: String) -> bool:
	if _ended:
		return false
	var at := Vector2(1100, DESKTOP_H - 40)
	if not run.ability_ready(id):
		var why := "spent this hour" if id == "ctrl_alt_del" else "recharging"
		_float("%s: %s" % [RunState.ABILITIES[id]["name"], why], at, Color("ff6060"), 12)
		return false
	match id:
		"alt_f4":
			var front := front_popup()
			if front == null:
				_float("Alt+F4: nothing to close", at, Color("ff6060"), 12)
				return false
			if front.x_locked():
				_float("Alt+F4: that X is locked", front.global_position + Vector2(front.size.x * 0.5, 10), Color("ff6060"), 12)
				return false
			run.use_ability(id)
			_log("ability", {"id": id, "type": front.type_id})
			front.dismiss(false)
		"task_manager":
			if task_manager != null:
				task_manager.raise()
				return false
			run.use_ability(id)
			_log("ability", {"id": id, "ends": run.task_manager_ends})
			_open_task_manager()
		"ctrl_alt_del":
			run.use_ability(id)
			_log("ability", {"id": id})
			_show_freeze()
	return true


## Bots cannot hold a key: release the freeze after `seconds` of game time.
func freeze_for(seconds: float) -> void:
	_freeze_auto = seconds


func _open_task_manager() -> void:
	task_manager = TaskManager.new(popup_layer, run.task_manager_ends)
	task_manager.drag_bounds = Rect2(Vector2.ZERO, Vector2(1280, DESKTOP_H))
	task_manager.end_task_requested.connect(func(p: PopupBase) -> void:
		_log("task_ended", {"type": p.type_id, "ends_left": task_manager.ends_left if task_manager != null else 0})
		p.killed = true
		p.dismiss(false))
	task_manager.close_requested.connect(_close_task_manager)
	add_child(task_manager)
	task_manager.position = Vector2(450, 190)
	Sfx.play("warn", 1.1)


func _close_task_manager() -> void:
	if task_manager == null:
		return
	var tm := task_manager
	task_manager = null
	Juice.pop_out(tm, tm.queue_free)


func _show_freeze() -> void:
	_freeze_overlay = Control.new()
	_freeze_overlay.size = Vector2(1280, DESKTOP_H)
	_freeze_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # nothing under it takes clicks
	_freeze_overlay.z_index = 6  # imps draw at z 5; the dimmer covers them too
	_freeze_overlay.draw.connect(_draw_freeze.bind(_freeze_overlay))
	add_child(_freeze_overlay)
	move_child(_freeze_overlay, taskbar.get_index())  # above the desk, under the taskbar
	Sfx.play("warn", 0.7)


func _draw_freeze(o: Control) -> void:
	o.draw_rect(Rect2(Vector2.ZERO, o.size), Color(0, 0, 0.1, 0.5))
	var limit := Tuning.num("ability.freeze_max", RunState.FREEZE_MAX)
	var frac := clampf(run.freeze_time / limit, 0.0, 1.0)
	var msg := "Ctrl+Alt+Del: the desk is frozen. Let go before the bar fills or the machine resets."
	var ts := Win98.text_size(msg, 16)
	o.draw_rect(Rect2(Vector2(400, 282), Vector2(480, 104)), Color(0, 0, 0.25))
	o.draw_rect(Rect2(Vector2(400, 282), Vector2(480, 104)), Win98.WHITE, false, 1.0)
	Win98.draw_text(o, Vector2((o.size.x - ts.x) * 0.5, 300), msg, Color.WHITE, 16)
	var bar := Rect2(Vector2(440, 340), Vector2(400, 18))
	o.draw_rect(bar, Win98.GRAY)
	o.draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Color(1.0, 1.0 - frac, 0.2))
	o.draw_rect(bar, Win98.BLACK, false, 1.0)
	Win98.draw_text(o, Vector2(640 - 20, 366), "%.1f s" % run.freeze_time, Color.WHITE, 12)


func _end_freeze() -> void:
	if _freeze_overlay == null:
		return
	var held := run.freeze_time
	if run.frozen:
		run.end_freeze()
	_freeze_auto = -1.0
	_log("freeze", {"held": snappedf(held, 0.01), "reset": run.crashed_flag})
	_freeze_overlay.queue_free()
	_freeze_overlay = null


# ---------- helpers ----------

func _float(text: String, at: Vector2, color: Color, font_size: int, rise: float = 40.0, duration: float = 0.9) -> void:
	FloatText.spawn(float_layer, at, text, color, font_size, rise, duration)


func _banner(text: String, color: Color) -> void:
	FloatText.spawn(float_layer, Vector2(640, 300), text, color, 48, 60.0, 1.8)
