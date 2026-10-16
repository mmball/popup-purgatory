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
	add_child(taskbar)

	start_menu = StartMenu.new()
	start_menu.building_chosen.connect(_begin_place)
	start_menu.shutdown_requested.connect(_ask_shutdown)
	add_child(start_menu)
	start_menu.position = Vector2(2, DESKTOP_H - start_menu.size.y)

	break_dialog = BreakDialog.new()
	break_dialog.upgrade_chosen.connect(_on_upgrade_chosen)
	add_child(break_dialog)
	break_dialog.drag_bounds = Rect2(Vector2.ZERO, Vector2(1280, DESKTOP_H))

	spawner = PopupSpawner.new()
	spawner.setup(run, rng, popup_layer)
	spawner.popup_spawned.connect(_wire_popup)
	add_child(spawner)

	imp_manager = ImpManager.new()
	imp_manager.setup(run, rng, imp_layer, popup_layer)
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
	_log("popup_spawned", {"type": popup.type_id, "ram_cost": popup.ram_cost, "clustered": popup.spawned_near, "ram_used": run.ram_used})


func _on_popup_closed(popup: PopupBase, completed: bool, by_imp: bool) -> void:
	var reward := run.reward_for(popup.def, completed)
	if not by_imp:
		reward += run.click_bonus
	run.popup_closed(popup.ram_cost, completed, by_imp)
	run.add_bytes(reward)
	imp_manager.on_popup_closed(popup)
	_log("popup_closed", {"type": popup.type_id, "completed": completed, "by_imp": by_imp, "age": snappedf(popup.total_age, 0.01), "reward": reward, "ram_used": run.ram_used})
	var at := popup.global_position + Vector2(popup.size.x * 0.5, 10)
	var col := Color("7CFC00") if completed else Color.WHITE
	_float("+%d" % reward, at, col, clampi(12 + reward * 2, 13, 30))
	if completed:
		Sfx.play("chime_big" if reward >= 8 else "chime", 1.0 + minf(reward, 10) * 0.02)
	else:
		Sfx.play("click", 1.0 if not by_imp else 1.25)
	if not completed and popup.dismiss_spawns() > 0:
		# Consent fatigue: X-ing a cookie banner brings two more.
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
			popup.queue_free()
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
	start_menu.visible = false
	_banner("5:00 PM", Color("ffd700"))
	_clockout = ConfirmDialog.new("It's 5:00 PM", "You survived the workday. Clock out now, or stay for Overtime?\n\nOvertime keeps going until the machine crashes. Your score only goes up.")
	_clockout.set_window_size(Vector2(360, 150))
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
	_float("Hour %d done: +%d bytes" % [run.wave, earned], Vector2(640, 240), Color("ffd700"), 22)
	Sfx.play("chime_big", 0.9, 0.0, 0.0)
	var choices := UpgradeCatalog.roll(rng, run, 3)
	var offered: Array[String] = []
	for c: Dictionary in choices:
		offered.append(str(c["id"]))
	_log("upgrade_offered", {"ids": offered})
	break_dialog.show_choices(run.wave, choices)
	break_dialog.center_in_parent()
	village.cancel_place()
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
	village.begin_place(id, run.bytes >= building_cost(id, village.count(id)))


func building_cost(id: String, owned: int) -> int:
	return BuildingCatalog.cost(id, owned, run.building_cost_mult)


func _on_place_requested(id: String, cell: Vector2i) -> void:
	var owned := village.count(id)
	var cost := building_cost(id, owned)
	if owned >= BuildingCatalog.max_count(id):
		village.cancel_place()
		return
	if not run.spend(cost):
		_float("need %d bytes" % cost, village.cell_center(cell), Color("ff6060"), 12)
		return
	_build(id, cell, cost)
	# stay in placement mode while another copy is possible and affordable
	var next_owned := village.count(id)
	if next_owned >= BuildingCatalog.max_count(id) or run.bytes < building_cost(id, next_owned):
		village.cancel_place()
	else:
		village.set_affordable(true)


func _build(id: String, cell: Vector2i, cost: int) -> void:
	village.add_building(id, cell)
	run.buildings_built += 1
	run.buildings_list.append(id)
	_log("build", {"id": id, "cell": [cell.x, cell.y], "cost": cost, "bytes_after": run.bytes, "owned_after": village.count(id)})
	var at := village.cell_center(cell)
	match id:
		"hut":
			imp_manager.spawn_imp(at + Vector2(0, 18))
		"dojo":
			imp_manager.add_training_slots(2)
		"coffee":
			run.imp_speed_mult *= 1.25
		"ram":
			run.set_ram_max(run.ram_max + 32)
		"firewall":
			run.interval_mult *= 1.15
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


func _on_icon_activated(kind: String) -> void:
	match kind:
		"imps":
			_toggle_start_menu()
		"computer":
			_float("RAM %d/%d  Imps %d  Score %d" % [run.ram_used, run.ram_max, imp_manager.imps.size(), run.score], Vector2(640, 200), Color.WHITE, 14)
		"bin":
			_float("Nothing to recycle. Yet.", Vector2(640, 200), Color.WHITE, 14)


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
	if _ended or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: InputEventKey = event
	if key.keycode == KEY_ESCAPE:
		if village.is_placing():
			village.cancel_place()
		start_menu.visible = false
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_B:
		_toggle_start_menu()
		get_viewport().set_input_as_handled()
	elif key.keycode >= KEY_1 and key.keycode <= KEY_9:
		var idx := int(key.keycode - KEY_1)
		var avail := BuildingCatalog.available(run.unlocked_buildings)
		if idx < avail.size() and not run.in_break:
			_begin_place(avail[idx])
			get_viewport().set_input_as_handled()


# ---------- helpers ----------

func _float(text: String, at: Vector2, color: Color, font_size: int) -> void:
	FloatText.spawn(float_layer, at, text, color, font_size)


func _banner(text: String, color: Color) -> void:
	FloatText.spawn(float_layer, Vector2(640, 300), text, color, 48, 60.0, 1.8)
