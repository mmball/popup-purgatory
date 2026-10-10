extends PopupContent
## Live chat widget. Imp-proof: the window hops away when an imp reaches it
## (handled by Desktop), so a human has to answer it. Typing any reply and
## pressing Send completes it.

var _input: LineEdit
var _log: Label
var _t := 0.0
var _dots := 0


func build() -> void:
	var head := make_label("Hi there! Need help today?", 13, Win98.TITLE_A)
	head.add_theme_font_size_override("font_size", 13)
	_log = make_label("Agent Clippy is typing", 11, Win98.GRAY_DARK)
	make_spacer()
	var row := make_row()
	_input = LineEdit.new()
	_input.custom_minimum_size = Vector2(130, 24)
	_input.placeholder_text = "type a reply"
	_input.text_submitted.connect(func(_t: String) -> void: _send())
	row.add_child(_input)
	var send := make_button("Send", Vector2(60, 24))
	send.bold_border = true
	send.pressed.connect(_send)
	row.add_child(send)


func _process(delta: float) -> void:
	_t += delta
	var d := int(_t * 2.0) % 4
	if d != _dots:
		_dots = d
		_log.text = "Agent Clippy is typing" + ".".repeat(d)


func _send() -> void:
	if _input.text.strip_edges() == "":
		_log.text = "Please type something first!"
		return
	completed.emit()
