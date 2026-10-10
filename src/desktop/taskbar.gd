class_name Taskbar
extends Control
## Bottom bar: Start button, run readouts, and a clock in the tray.

signal start_pressed

var start_button: Win98Button
var _bytes: Label
var _ram: Label
var _wave: Label
var _imps: Label
var _clock: Label
var _tray: BevelPanel
var _blink := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 30)


func _ready() -> void:
	start_button = Win98Button.new("Start", Vector2(62, 22))
	start_button.position = Vector2(2, 4)
	start_button.extra_draw = _draw_flag
	start_button.pressed.connect(func() -> void: start_pressed.emit())
	add_child(start_button)

	var box := HBoxContainer.new()
	box.position = Vector2(72, 4)
	box.size = Vector2(size.x - 72 - 120, 22)
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	_bytes = _readout(box, "Bytes: 0", 110)
	_ram = _readout(box, "RAM: 0/100", 130)
	_wave = _readout(box, "Wave 1  0:40", 120)
	_imps = _readout(box, "Imps: 0", 120)

	_tray = BevelPanel.new(true)
	_tray.size = Vector2(72, 22)
	add_child(_tray)
	_clock = Label.new()
	_clock.add_theme_font_size_override("font_size", 12)
	_clock.position = Vector2(8, 2)
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


func _process(delta: float) -> void:
	_blink += delta
	var t := Time.get_time_dict_from_system()
	_clock.text = "%d:%02d %s" % [((int(t["hour"]) + 11) % 12) + 1, int(t["minute"]), "AM" if int(t["hour"]) < 12 else "PM"]


func update_from(run: RunState, imp_count: int, trained: int) -> void:
	_bytes.text = "Bytes: %d" % run.bytes
	_ram.text = "RAM: %d/%d" % [run.ram_used, run.ram_max]
	if run.overloaded:
		_ram.text = "RAM: LOW! %.1fs" % maxf(0.0, RunState.OVERLOAD_GRACE - run.overload_timer)
		_ram.add_theme_color_override("font_color", Color("ff0000") if fmod(_blink, 0.4) < 0.2 else Win98.BLACK)
	elif run.ram_fraction() > 0.8:
		_ram.add_theme_color_override("font_color", Color("c00000"))
	else:
		_ram.add_theme_color_override("font_color", Win98.BLACK)
	if run.in_break:
		_wave.text = "Wave %d  break" % run.wave
	else:
		var s := int(ceil(run.wave_time_left))
		_wave.text = "Wave %d  %d:%02d" % [run.wave, s / 60, s % 60]
	_imps.text = "Imps: %d (%d trained)" % [imp_count, trained]
