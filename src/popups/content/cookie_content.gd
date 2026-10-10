extends PopupContent
## The cookie banner. "Accept all" is huge and completes nothing. The real exit,
## "Reject all", is three clicks deep: Manage, then uncheck, then Confirm.
## The X is the trap for this one (dismissing spawns two more, see the catalog),
## which is the point: it targets builds that X everything.

var _step := 0
var _pages: Array[Control] = []
var _checks: Array[CheckBox] = []
var _confirm: Win98Button


func build() -> void:
	var consent := run != null and run.consent_manager
	var p1 := VBoxContainer.new()
	p1.add_child(_label("We and our 847 partners use cookies to improve your experience. By continuing you agree to everything."))
	var row1 := HBoxContainer.new()
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.add_theme_constant_override("separation", 8)
	var accept := make_button("ACCEPT ALL", Vector2(150, 30))
	accept.bold_border = true
	accept.pressed.connect(func() -> void: misclick.emit("accept_all"))
	row1.add_child(accept)
	var manage := make_button("Manage..." if not consent else "Reject all", Vector2(90, 23))
	manage.font_size = 11
	if consent:
		manage.pressed.connect(func() -> void: completed.emit())
	else:
		manage.pressed.connect(func() -> void: _goto(1))
	row1.add_child(manage)
	p1.add_child(row1)

	var p2 := VBoxContainer.new()
	p2.add_child(_label("Your preferences (all enabled by default):"))
	for text: String in ["Strictly necessary (required)", "Performance", "Advertising", "Selling your data"]:
		var cb := make_check(text, true)
		cb.add_theme_font_size_override("font_size", 11)
		if text.begins_with("Strictly"):
			cb.disabled = true
		else:
			_checks.append(cb)
			cb.toggled.connect(func(_on: bool) -> void: _refresh())
		p2.add_child(cb)
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_END
	row2.add_theme_constant_override("separation", 8)
	var back := make_button("< Back", Vector2(70, 23))
	back.pressed.connect(func() -> void: _goto(0))
	row2.add_child(back)
	_confirm = make_button("Confirm", Vector2(90, 23))
	_confirm.bold_border = true
	_confirm.pressed.connect(func() -> void:
		for cb in _checks:
			if cb.button_pressed:
				misclick.emit("accept_all")
				completed.emit()
				return
		completed.emit())
	row2.add_child(_confirm)
	p2.add_child(row2)
	_pages = [p1, p2]
	for p in _pages:
		p.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(p)
	_goto(0)


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 12)
	return l


func _goto(step: int) -> void:
	_step = step
	for i in range(_pages.size()):
		_pages[i].visible = i == _step
	_refresh()


func _refresh() -> void:
	if _confirm == null:
		return
	var any_checked := false
	for cb in _checks:
		if cb.button_pressed:
			any_checked = true
	_confirm.label = "Confirm" if any_checked else "Reject all"
