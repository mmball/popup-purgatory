class_name Taskbar
extends Control
## Bottom bar: Start button, run readouts, and a clock in the tray.

signal start_pressed
signal ability_pressed(id: String)    ## tray icon pressed (Ctrl+Alt+Del holds while pressed)
signal ability_released(id: String)

var start_button: Win98Button
var _bytes: Label
var _ram: Label
var _wave: Label
var _imps: Label
var _streak: Label
var _clock: Label
var _tray: BevelPanel
var _abilities: Control          ## tray icons with cooldown sweeps
var _held_ability := ""
const ICON_W := 22
var _blink := 0.0
var _run: RunState


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 30)


func _ready() -> void:
	start_button = Win98Button.new("Start", Vector2(62, 22))
	start_button.position = Vector2(2, 4)
	start_button.extra_draw = _draw_flag
	start_button.pressed.connect(func() -> void:
		Sfx.play("click", 0.8)
		start_pressed.emit())
	add_child(start_button)

	var box := HBoxContainer.new()
	box.position = Vector2(72, 4)
	box.size = Vector2(size.x - 72 - 120, 22)
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	_bytes = _readout(box, "Bytes: 0", 110)
	_ram = _readout(box, "RAM: 0/100", 130)
	_wave = _readout(box, "Hour 1/8  0:50", 150)
	_imps = _readout(box, "Imps: 0", 120)
	_streak = _readout(box, "Streak: 0", 96)

	_tray = BevelPanel.new(true)
	_tray.size = Vector2(72 + ICON_W * RunState.ABILITY_ORDER.size(), 22)
	add_child(_tray)
	_abilities = Control.new()
	_abilities.position = Vector2(2, 1)
	_abilities.size = Vector2(ICON_W * RunState.ABILITY_ORDER.size(), 20)
	_abilities.mouse_filter = Control.MOUSE_FILTER_STOP
	_abilities.tooltip_text = "Alt+F4: dismiss the front window.  Ctrl+Shift+Esc: Task Manager.  Ctrl+Alt+Del: hold to freeze (once an hour)."
	_abilities.draw.connect(_draw_abilities)
	_abilities.gui_input.connect(_on_abilities_input)
	_tray.add_child(_abilities)
	_clock = Label.new()
	_clock.add_theme_font_size_override("font_size", 12)
	_clock.position = Vector2(8 + ICON_W * RunState.ABILITY_ORDER.size(), 2)
	_tray.add_child(_clock)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	if _tray:
		_tray.position = Vector2(size.x - _tray.size.x - 4, 4)


func _readout(parent: Node, text: String, width: float) -> Label:
	var panel := BevelPanel.new(true)
	panel.custom_minimum_size = Vector2(width, 22)
	parent.add_child(panel)
	var l := Label.new()
	l.text = text
	l.position = Vector2(6, 2)
	l.add_theme_font_size_override("font_size", 12)
	panel.add_child(l)
	return l


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Win98.GRAY)
	draw_rect(Rect2(0, 0, size.x, 1), Win98.GRAY_LIGHT)
	draw_rect(Rect2(0, 1, size.x, 1), Win98.WHITE)


func _draw_flag(btn: Control, off: Vector2) -> void:
	var o := Vector2(6, 5) + off
	var cols := [Color("ff0000"), Color("00a000"), Color("0000ff"), Color("ffff00")]
	for i in range(4):
		var p := o + Vector2((i % 2) * 6, (i / 2) * 6)
		btn.draw_rect(Rect2(p, Vector2(5, 5)), cols[i])


func _on_abilities_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		var i := int(event.position.x / ICON_W)
		if i >= 0 and i < RunState.ABILITY_ORDER.size():
			_held_ability = RunState.ABILITY_ORDER[i]
			ability_pressed.emit(_held_ability)
	elif _held_ability != "":
		ability_released.emit(_held_ability)
		_held_ability = ""


## Three tray glyphs: a key cap (Alt+F4), a little task list (Task Manager)
## and a red reset button (Ctrl+Alt+Del). A grey sweep rises while an ability
## recharges; a spent Ctrl+Alt+Del is greyed until the next hour.
func _draw_abilities() -> void:
	for i in range(RunState.ABILITY_ORDER.size()):
		var id: String = RunState.ABILITY_ORDER[i]
		var o := Vector2(i * ICON_W + 3, 2)
		var ready := _run != null and _run.ability_ready(id)
		var ink := Win98.BLACK if ready else Win98.GRAY_DARK
		match id:
			"alt_f4":
				_abilities.draw_rect(Rect2(o, Vector2(16, 16)), Win98.WHITE if ready else Win98.GRAY_LIGHT)
				_abilities.draw_rect(Rect2(o, Vector2(16, 16)), ink, false, 1.0)
				Win98.draw_text(_abilities, o + Vector2(2, 1), "F4", ink, 9)
			"task_manager":
				_abilities.draw_rect(Rect2(o, Vector2(16, 16)), Win98.WHITE if ready else Win98.GRAY_LIGHT)
				_abilities.draw_rect(Rect2(o, Vector2(16, 3)), Win98.TITLE_A if ready else Win98.GRAY_DARK)
				for r in range(3):
					_abilities.draw_rect(Rect2(o + Vector2(2, 5 + r * 3), Vector2(12 - r * 3, 2)), ink)
				_abilities.draw_rect(Rect2(o, Vector2(16, 16)), ink, false, 1.0)
			"ctrl_alt_del":
				_abilities.draw_rect(Rect2(o, Vector2(16, 16)), Win98.GRAY_LIGHT)
				_abilities.draw_rect(Rect2(o, Vector2(16, 16)), ink, false, 1.0)
				_abilities.draw_circle(o + Vector2(8, 8), 5.0, Color("d00000") if ready else Win98.GRAY_DARK)
				_abilities.draw_circle(o + Vector2(8, 8), 5.0, ink, false, 1.0)
		if _run != null and _run.ability_cooldown_left(id) > 0.0:
			var frac := _run.ability_cooldown_left(id) / maxf(0.001, _run.ability_cooldown(id))
			_abilities.draw_rect(Rect2(o + Vector2(0, 16.0 * (1.0 - frac)), Vector2(16, 16.0 * frac)), Color(0, 0, 0, 0.45))
			Win98.draw_text(_abilities, o + Vector2(1, 3), "%d" % int(ceil(_run.ability_cooldown_left(id))), Win98.WHITE, 10)


func _process(delta: float) -> void:
	_blink += delta
	if _abilities != null:
		_abilities.queue_redraw()
	if Game.dev.has("clock"):
		_clock.text = str(Game.dev["clock"])  # frozen for screenshot regression
		return
	if _run != null:
		# The taskbar clock is the in-game workday: 9 AM to 5 PM, one wave per hour.
		var c := _run.clock()
		var h: int = c["hour"]
		_clock.text = "%d:%02d %s" % [((h + 11) % 12) + 1, int(c["minute"]), "AM" if h < 12 else "PM"]
		return
	var t := Time.get_time_dict_from_system()
	_clock.text = "%d:%02d %s" % [((int(t["hour"]) + 11) % 12) + 1, int(t["minute"]), "AM" if int(t["hour"]) < 12 else "PM"]


func update_from(run: RunState, imp_count: int, trained: int) -> void:
	_run = run
	_bytes.text = "Bytes: %d" % run.bytes
	_ram.text = "RAM: %d/%d" % [run.ram_used, run.ram_max]
	if run.overloaded:
		_ram.text = "RAM: LOW! %.1fs" % maxf(0.0, run.overload_grace() - run.overload_timer)
		_ram.add_theme_color_override("font_color", Color("ff0000") if fmod(_blink, 0.4) < 0.2 else Win98.BLACK)
	elif run.ram_fraction() > 0.8:
		_ram.add_theme_color_override("font_color", Color("c00000"))
	else:
		_ram.add_theme_color_override("font_color", Win98.BLACK)
	var label := "Hour %d/%d" % [run.wave, RunState.WORKDAY_WAVES] if not run.overtime else "Overtime %d" % (run.wave - RunState.WORKDAY_WAVES)
	if run.tier > 0:
		label = "SP%d " % run.tier + label
	if run.boss_active:
		_wave.text = "%s  SETUP" % label
	elif run.in_break:
		_wave.text = "%s  break" % label
	else:
		var s := int(ceil(run.wave_time_left))
		_wave.text = "%s  %d:%02d" % [label, s / 60, s % 60]
	_imps.text = "Imps: %d (%d trained)" % [imp_count, trained]
	_streak.text = "Streak: %d" % run.streak if run.streak < RunState.STREAK_CAP else "Streak: %d MAX" % run.streak
	_streak.add_theme_color_override("font_color", Color("b8860b") if run.streak >= 3 else Win98.BLACK)
