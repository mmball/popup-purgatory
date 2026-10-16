class_name BreakDialog
extends WindowFrame
## Between waves: pick one of three upgrades.

signal upgrade_chosen(id: String)

var _intro: Label
var _cards: HBoxContainer


func _init() -> void:
	super()
	closable = false
	draggable = true
	window_title = "Coffee Break"
	icon_color = Color("6f4e37")
	set_window_size(Vector2(640, 260))
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	content.add_child(box)
	_intro = Label.new()
	_intro.add_theme_font_size_override("font_size", 13)
	box.add_child(_intro)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 10)
	_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_cards)


func show_choices(wave: int, choices: Array[Dictionary], intro: String = "") -> void:
	_intro.text = intro if intro != "" else "Wave %d survived. The pop-ups are regrouping. Pick one upgrade:" % wave
	for c: Node in _cards.get_children():
		c.queue_free()
	for def: Dictionary in choices:
		_cards.add_child(_make_card(def))
	visible = true
	raise()


func _make_card(def: Dictionary) -> Control:
	var panel := BevelPanel.new(false)
	panel.custom_minimum_size = Vector2(196, 170)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.position = Vector2(8, 8)
	box.size = Vector2(180, 154)
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var name_l := Label.new()
	name_l.text = str(def["name"])
	name_l.add_theme_font_size_override("font_size", 14)
	name_l.add_theme_color_override("font_color", Win98.TITLE_A)
	box.add_child(name_l)
	var desc := Label.new()
	desc.text = str(def["desc"])
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("font_size", 12)
	box.add_child(desc)
	var pick := Win98Button.new("Pick", Vector2(80, 24))
	pick.bold_border = true
	pick.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pick.pressed.connect(func() -> void: upgrade_chosen.emit(str(def["id"])))
	box.add_child(pick)
	return panel
