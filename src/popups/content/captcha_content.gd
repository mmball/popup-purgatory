extends PopupContent
## Type the word. Wrong answers reroll the word.

const LETTERS := "ABCDEFGHJKLMNPQRSTUVWXYZ"

var word := ""
var _word_label: Label
var _input: LineEdit
var _hint: Label


func build() -> void:
	make_label("Prove you are a human (or an imp). Type the characters below:", 12)
	_word_label = make_label("", 20, Win98.TITLE_A, true)
	var row := make_row()
	_input = LineEdit.new()
	_input.custom_minimum_size = Vector2(140, 24)
	_input.placeholder_text = "type here"
	_input.text_submitted.connect(func(_t: String) -> void: _verify())
	row.add_child(_input)
	var verify := make_button("Verify")
	verify.bold_border = true
	verify.pressed.connect(_verify)
	row.add_child(verify)
	_hint = make_label("", 10, Color("c00000"), true)
	_reroll()


func _reroll() -> void:
	word = ""
	for i in range(5):
		word += LETTERS[rng.randi_range(0, LETTERS.length() - 1)]
	var spaced := ""
	for ch: String in word:
		spaced += ch + " "
	_word_label.text = spaced.strip_edges()
	_input.text = ""


func _verify() -> void:
	if _input.text.strip_edges().to_upper() == word:
		completed.emit()
	else:
		_hint.text = "Incorrect. Try again."
		misclick.emit("captcha_fail")
		_reroll()
