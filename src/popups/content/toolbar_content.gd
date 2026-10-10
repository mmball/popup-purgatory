extends PopupContent
## A three-step installer with a bundled extra on page two.

var _step := 0
var _pages: Array[Control] = []
var _bundle: CheckBox
var _back: Win98Button
var _next: Win98Button


func build() -> void:
	var p1 := VBoxContainer.new()
	p1.add_child(_label("Welcome to the Searchy Toolbar Setup Wizard."))
	p1.add_child(_label("This wizard will install Searchy Toolbar and improve your browsing experience whether you want it to or not."))
	var p2 := VBoxContainer.new()
	p2.add_child(_label("Choose optional components:"))
	_bundle = make_check("Also install Searchy Weather Buddy (recommended)", true)
	p2.add_child(_bundle)
	var p3 := VBoxContainer.new()
	p3.add_child(_label("Setup is ready to finish."))
	p3.add_child(_label("Click Finish to exit the wizard."))
	_pages = [p1, p2, p3]
	for p in _pages:
		p.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(p)
	var row := make_row(BoxContainer.ALIGNMENT_END)
	_back = make_button("< Back")
	_back.pressed.connect(func() -> void: _goto(_step - 1))
	row.add_child(_back)
	_next = make_button("Next >")
	_next.bold_border = true
	_next.pressed.connect(_on_next)
	row.add_child(_next)
	_goto(0)


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 12)
	return l


func _goto(step: int) -> void:
	_step = clampi(step, 0, _pages.size() - 1)
	for i in range(_pages.size()):
		_pages[i].visible = i == _step
	_back.disabled = _step == 0
	_next.label = "Finish" if _step == _pages.size() - 1 else "Next >"


func _on_next() -> void:
	if _step < _pages.size() - 1:
		_goto(_step + 1)
		return
	if _bundle.button_pressed:
		misclick.emit("bundled")
	completed.emit()
