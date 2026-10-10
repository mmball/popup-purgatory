extends PopupContent
## The classic banner. The giant button is the trap; the tiny link is the exit.

var _head: Label
var _t := 0.0


func build() -> void:
	_head = make_label("*** CONGRATULATIONS!!! ***", 15, Color("ff0000"), true)
	make_label("You are the 1,000,000th visitor! Click below to claim your FREE prize.", 12)
	make_spacer()
	var claim := make_button("CLAIM YOUR PRIZE >>>", Vector2(0, 30))
	claim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	claim.bold_border = true
	claim.pressed.connect(func() -> void: misclick.emit("trap"))
	add_child(claim)
	var link := make_link("no thanks", 9)
	link.size_flags_horizontal = Control.SIZE_SHRINK_END
	link.pressed.connect(func() -> void: completed.emit())
	add_child(link)


func _process(delta: float) -> void:
	_t += delta
	_head.add_theme_color_override("font_color", Color("ff0000") if fmod(_t, 0.6) < 0.3 else Color("0000ff"))
