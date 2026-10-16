class_name MainMenu
extends Control
## Boot text, then a desktop with the welcome window and the unlock shop.

const BOOT_LINES := [
	"Popup Purgatory 98",
	"Copyright (C) 1998 Imp Software Inc.",
	"",
	"Checking system resources... 100/100 OK",
	"Loading pop-up drivers... 8 found",
	"Counting imps... 0",
	"",
	"Starting Popup Purgatory 98...",
]
const BOOT_TIME := 1.6

var _boot := true
var _boot_t := 0.0
var _welcome: WindowFrame
var _shop: WindowFrame
var _stats: Label
var _tier_label: Label
var _tier_desc: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if Game.dev.has("noboot") or Game.dev.has("screenshot"):
		_boot = false
		_build_desktop()
	else:
		Sfx.play("dialup", 1.0, 0.0, 0.0)


func _process(delta: float) -> void:
	if not _boot:
		return
	_boot_t += delta
	queue_redraw()
	if _boot_t >= BOOT_TIME:
		_boot = false
		_build_desktop()


func _unhandled_input(event: InputEvent) -> void:
	if _boot and (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		_boot_t = BOOT_TIME


func _draw() -> void:
	if _boot:
		draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
		var shown := int(_boot_t / BOOT_TIME * BOOT_LINES.size()) + 1
		for i in range(mini(shown, BOOT_LINES.size())):
			Win98.draw_text(self, Vector2(40, 40 + i * 20), BOOT_LINES[i], Color("c0c0c0"), 14)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Win98.DESKTOP)


func _build_desktop() -> void:
	queue_redraw()
	var meta: MetaSave = Game.meta

	_welcome = WindowFrame.new()
	_welcome.window_title = "Welcome to Popup Purgatory 98"
	_welcome.closable = false
	_welcome.set_window_size(Vector2(440, 420))
	add_child(_welcome)
	_welcome.position = Vector2(420, 140)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_welcome.content.add_child(box)

	var title := Label.new()
	title.text = "POPUP PURGATORY"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Win98.TITLE_A)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var blurb := Label.new()
	blurb.text = "One workday: 9 AM to 5 PM, one wave an hour. Close the pop-ups; completing one pays more than X-ing it. Spend bytes on imps who close them for you. Run out of RAM and the machine crashes. Make it to 5 PM and you clock out."
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.add_theme_font_size_override("font_size", 12)
	box.add_child(blurb)

	_stats = Label.new()
	_stats.add_theme_font_size_override("font_size", 12)
	box.add_child(_stats)
	_refresh_stats()

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	var tier_row := HBoxContainer.new()
	tier_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tier_row.add_theme_constant_override("separation", 6)
	box.add_child(tier_row)
	var less := Win98Button.new("<", Vector2(24, 22))
	less.pressed.connect(func() -> void: _set_tier(Game.requested_tier - 1))
	tier_row.add_child(less)
	_tier_label = Label.new()
	_tier_label.custom_minimum_size = Vector2(120, 0)
	_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tier_label.add_theme_font_size_override("font_size", 12)
	tier_row.add_child(_tier_label)
	var more := Win98Button.new(">", Vector2(24, 22))
	more.pressed.connect(func() -> void: _set_tier(Game.requested_tier + 1))
	tier_row.add_child(more)
	_tier_desc = Label.new()
	_tier_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tier_desc.add_theme_font_size_override("font_size", 10)
	_tier_desc.add_theme_color_override("font_color", Win98.GRAY_DARK)
	box.add_child(_tier_desc)
	_set_tier(Game.requested_tier)

	var seed_row := HBoxContainer.new()
	seed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	seed_row.add_theme_constant_override("separation", 6)
	box.add_child(seed_row)
	var seed_label := Label.new()
	seed_label.text = "Seed (blank = random):"
	seed_label.add_theme_font_size_override("font_size", 11)
	seed_row.add_child(seed_label)
	var seed_edit := LineEdit.new()
	seed_edit.custom_minimum_size = Vector2(120, 22)
	seed_edit.placeholder_text = "e.g. 42"
	seed_edit.add_theme_font_size_override("font_size", 11)
	if Game.requested_seed >= 0:
		seed_edit.text = str(Game.requested_seed)
	seed_row.add_child(seed_edit)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var start := Win98Button.new("Start Run", Vector2(110, 26))
	start.bold_border = true
	start.pressed.connect(func() -> void:
		var typed := seed_edit.text.strip_edges()
		Game.requested_seed = int(typed) if typed.is_valid_int() and int(typed) >= 0 else -1
		Game.start_run())
	row.add_child(start)
	var shop := Win98Button.new("Unlocks", Vector2(110, 26))
	shop.pressed.connect(_toggle_shop)
	row.add_child(shop)
	var quit := Win98Button.new("Quit", Vector2(110, 26))
	quit.pressed.connect(func() -> void: get_tree().quit())
	row.add_child(quit)

	if str(Game.dev.get("ui", "")) == "unlocks":
		_toggle_shop()
	var hint := Label.new()
	hint.text = "Controls: mouse. B or Start button opens the build menu, 1-7 picks a building, Esc cancels."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Win98.GRAY_DARK)
	box.add_child(hint)


func _refresh_stats() -> void:
	var meta: MetaSave = Game.meta
	_stats.text = "High score: %d    Best hour: %d    Runs: %d    Clock-outs: %d\nBank: %d bytes    Unlocked content: %d / %d" % [meta.high_score, meta.best_wave, meta.runs, meta.wins, meta.bank, meta.achievements.size(), MetaSave.ACHIEVEMENTS.size()]


func _set_tier(t: int) -> void:
	var meta: MetaSave = Game.meta
	Game.requested_tier = clampi(t, 0, meta.max_tier_unlocked)
	var def := Ladder.get_def(Game.requested_tier)
	_tier_label.text = str(def["name"])
	var locked_hint := "" if meta.max_tier_unlocked > Game.requested_tier or Game.requested_tier == Ladder.max_tier() else "  (clock out here to unlock SP%d)" % (Game.requested_tier + 1)
	_tier_desc.text = str(def["desc"]) + locked_hint


func _toggle_shop() -> void:
	if _shop != null:
		_shop.queue_free()
		_shop = null
		return
	_shop = WindowFrame.new()
	_shop.window_title = "Unlocks"
	_shop.set_window_size(Vector2(480, 420))
	_shop.close_requested.connect(_toggle_shop)
	add_child(_shop)
	_shop.position = Vector2(440, 100)
	_shop.raise()
	_fill_shop()


func _fill_shop() -> void:
	for c: Node in _shop.content.get_children():
		c.queue_free()
	var meta: MetaSave = Game.meta
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_shop.content.add_child(box)
	var h1 := Label.new()
	h1.text = "Content unlocks (earned by playing; they widen the pools, never your stats)"
	h1.add_theme_font_size_override("font_size", 11)
	h1.add_theme_color_override("font_color", Win98.TITLE_A)
	box.add_child(h1)
	for aid: String in MetaSave.ACHIEVEMENTS.keys():
		var ach: Dictionary = MetaSave.ACHIEVEMENTS[aid]
		var l := Label.new()
		var done := meta.has_achievement(aid)
		l.text = "%s %s: %s  [%s]\n    adds: %s" % ["[x]" if done else "[ ]", ach["name"], ach["desc"], "done" if done else meta.achievement_progress(aid), ach["adds"]]
		l.add_theme_font_size_override("font_size", 11)
		if not done:
			l.add_theme_color_override("font_color", Win98.GRAY_DARK)
		box.add_child(l)
	var h2 := Label.new()
	h2.text = "Starting perks (bought with banked bytes; small and one-time)"
	h2.add_theme_font_size_override("font_size", 11)
	h2.add_theme_color_override("font_color", Win98.TITLE_A)
	box.add_child(h2)
	for id: String in MetaSave.PERKS.keys():
		var perk: Dictionary = MetaSave.PERKS[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var l := Label.new()
		l.text = "%s\n%s" % [perk["name"], perk["desc"]]
		l.add_theme_font_size_override("font_size", 11)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var b := Win98Button.new("", Vector2(96, 24))
		if meta.has(id):
			b.label = "Owned"
			b.disabled = true
		else:
			b.label = "Buy (%d)" % int(perk["cost"])
			b.disabled = not meta.can_buy(id)
			b.pressed.connect(func() -> void:
				if meta.buy(id):
					meta.save_to_disk()
					_refresh_stats()
					_fill_shop())
		row.add_child(b)
