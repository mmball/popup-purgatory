extends PopupContent
## Scareware. The X is locked for a few seconds; the real exit is the small link.

var _head: Label
var _t := 0.0


func build() -> void:
	_head = make_label("WARNING! 37 VIRUSES DETECTED!", 15, Color("ff0000"), true)
	make_label("Your computer is infected. Your files WILL be deleted unless you act now. Scan is 100% free (shipping and handling not included).", 12)
	make_spacer()
	var scan := make_button("SCAN NOW (FREE!)", Vector2(0, 30))
	scan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scan.bold_border = true
	scan.pressed.connect(func() -> void: misclick.emit("scan"))
	add_child(scan)
	var link := make_link("ignore warning", 9)
	link.size_flags_horizontal = Control.SIZE_SHRINK_END
	link.pressed.connect(func() -> void: completed.emit())
	add_child(link)


func _process(delta: float) -> void:
	_t += delta
	_head.add_theme_color_override("font_color", Color("ff0000") if fmod(_t, 0.4) < 0.2 else Color("000000"))
