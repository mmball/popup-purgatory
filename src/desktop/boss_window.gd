class_name BossWindow
extends WindowFrame
## Service Pack Install: a ten-page installer the whole desk works on at noon and
## 4 PM (docs/FEATURES.md item 9). The player clicks through the pages (each one
## has a dark-pattern trap) while up to IMP_SLOTS imps grind steps from the
## bottom-left corner. Runs out of time and it is a lost boss.

signal step_done(step: int, by_imp: bool)   ## a page was completed; step = pages done so far (1..10)
signal misclick(kind: String)              ## a trap on a page was hit (the desktop punishes)
signal finished(won: bool)                 ## all pages done (true) or the time ran out (false); once

const STEPS := 10
const TIME_LIMIT := 75.0                   ## seconds of game time, from setup()
const IMP_SLOTS := 2                       ## imps that may work on it at once
const COPY_SECONDS := 4.0                  ## page 5: how long the fake file copy takes
const LOW_TIME := 15.0                     ## the clock turns red below this
const KEY_LETTERS := "ABCDEFGHJKLMNPQRSTUVWXYZ"
const SIDEBAR_W := 56
const COPY_FILES: Array[String] = [
	"KERNEL32.DLL", "SHELL32.DLL", "COMCTL32.DLL", "WININET.DLL", "MSHTML.DLL",
	"WEATHERBUDDY.EXE", "COUPONS.DLL", "SEARCHBAR.OCX", "TELEMETRY.SYS", "SETUP.LOG",
]
const EULA := "SOFTWARE LICENSE AGREEMENT FOR SERVICE PACK 98\n\n" \
	+ "IMPORTANT-READ CAREFULLY: This End-User License Agreement (\"EULA\") is a legal " \
	+ "agreement between you (either an individual or a single entity) and the Publisher " \
	+ "for the software product identified above, which includes computer software and may " \
	+ "include associated media, printed materials, and \"online\" or electronic documentation.\n\n" \
	+ "1. GRANT OF LICENSE. The Publisher grants you the following rights provided that you " \
	+ "comply with all terms and conditions of this EULA: you may install one copy of the " \
	+ "Software on one computer, one toaster, or one imp.\n\n" \
	+ "2. BUNDLED COMPONENTS. The Software may install additional components of unrelated " \
	+ "value. Removal of said components may require a degree in computer science.\n\n" \
	+ "3. DATA. By continuing, you agree that your clicks, keystrokes, mouse movements, " \
	+ "breathing patterns and lunch preferences may be shared with our 847 partners.\n\n" \
	+ "4. RESTARTS. The Software may restart your computer at any time, including now.\n\n" \
	+ "5. NO WARRANTIES. The Software is provided \"as is\" and \"as was\". The Publisher " \
	+ "disclaims all warranties, express, implied, and whispered.\n\n" \
	+ "6. TERMINATION. This EULA terminates when you close the window, which you cannot.\n\n" \
	+ "7. GOVERNING LAW. Any dispute will be settled by a game of Minesweeper.\n\n" \
	+ "8. ENTIRE AGREEMENT. This is the entire agreement. There is nothing else. Scroll down " \
	+ "for the rest of the entire agreement.\n\n" \
	+ "9. ACKNOWLEDGEMENT. By ticking the box you acknowledge that you did not read this."

var run: RunState
var rng: RandomNumberGenerator
var done := 0                              ## pages completed
var time_left := TIME_LIMIT
var imps_working := 0

var _finished := false
var _sidebar: Control
var _page: VBoxContainer
var _step_label: Label
var _bar: ProgressBar
var _time_label: Label

# Per-page state (reset by _build_page).
var _next: Win98Button          ## the advancing button of the current page, or null
var _checks: Array[CheckBox] = []   ## boxes the bot must untick before Next (pages 2, 3, 8)
var _accept: CheckBox           ## page 2 "I accept"
var _key := ""                  ## page 4
var _key_label: Label
var _input: LineEdit
var _hint: Label
var _copy_t := 0.0              ## page 5 progress, seconds
var _copy_bar: ProgressBar
var _copy_status: Label
var _link: LinkButton           ## page 6
var _browser: ButtonGroup       ## page 7
var _browser_safe: CheckBox     ## page 7: the choice that is not IE
var _browser_ie: CheckBox


func _init() -> void:
	super()
	window_title = "Service Pack 98 Setup"
	closable = false
	draggable = false
	icon_color = Color("2e8b57")
	set_window_size(Vector2(560, 400))
	set_process(false)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	content.add_child(root)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	_sidebar = Control.new()
	_sidebar.custom_minimum_size = Vector2(SIDEBAR_W, 0)
	_sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sidebar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sidebar.draw.connect(_draw_sidebar)
	body.add_child(_sidebar)

	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 8)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_page)

	var rule := Control.new()
	rule.custom_minimum_size = Vector2(0, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.draw.connect(func() -> void:
		rule.draw_rect(Rect2(Vector2.ZERO, Vector2(rule.size.x, 1)), Win98.GRAY_DARK)
		rule.draw_rect(Rect2(Vector2(0, 1), Vector2(rule.size.x, 1)), Win98.WHITE))
	root.add_child(rule)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	root.add_child(bottom)
	_step_label = Label.new()
	_step_label.custom_minimum_size = Vector2(86, 0)
	_step_label.add_theme_font_size_override("font_size", 12)
	bottom.add_child(_step_label)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.max_value = STEPS
	_bar.step = 1
	_bar.custom_minimum_size = Vector2(0, 16)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(_bar)
	_time_label = Label.new()
	_time_label.custom_minimum_size = Vector2(110, 0)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_time_label.add_theme_font_size_override("font_size", 12)
	bottom.add_child(_time_label)
	_refresh_footer()


## Builds page 1 and starts the clock. `p_rng` is the run's generator (product keys).
func setup(p_run: RunState, p_rng: RandomNumberGenerator) -> void:
	run = p_run
	rng = p_rng
	done = 0
	time_left = TIME_LIMIT
	_finished = false
	_build_page(1)
	_refresh_footer()
	set_process(true)


## Global position where an imp stands to work: just outside the bottom-left corner.
func imp_point() -> Vector2:
	return global_position + Vector2(-10, size.y + 6)


## An imp finished a step: completes the current page exactly as the player would.
func imp_step() -> void:
	if _finished:
		return
	match done + 1:
		3, 8:
			for cb in _checks:
				cb.button_pressed = false
		4:
			if _input != null:
				_input.text = _key
		5:
			_copy_t = COPY_SECONDS
			if _copy_bar != null:
				_copy_bar.value = COPY_SECONDS
		7:
			if _browser_safe != null:
				_browser_safe.button_pressed = true
	_advance(true)


## For the greedy bot: the visible controls to click, in order, to finish the
## current page. Empty while a page is waiting on a timer (or the window is done).
func bot_controls() -> Array[Control]:
	var out: Array[Control] = []
	if _finished:
		return out
	match done + 1:
		2:
			if _accept != null and not _accept.button_pressed:
				out.append(_accept)
			out.append(_next)
		3, 8:
			for cb in _checks:
				if cb.button_pressed:
					out.append(cb)
			out.append(_next)
		5:
			if _copy_t >= COPY_SECONDS:
				out.append(_next)
		6:
			out.append(_link)
		7:
			if _browser_ie != null and _browser_ie.button_pressed:
				out.append(_browser_safe)
			out.append(_next)
		_:
			if _next != null:
				out.append(_next)
	return out


## Typing pages: the text to put in the page's LineEdit before clicking Verify.
func bot_text() -> String:
	return _key if done + 1 == 4 and not _finished else ""


## The LineEdit of a typing page, else null.
func bot_line_edit() -> LineEdit:
	return _input if done + 1 == 4 and not _finished else null


func is_finished() -> bool:
	return _finished


func _process(delta: float) -> void:
	if _finished or run == null or run.frozen:
		return
	time_left = maxf(time_left - delta, 0.0)
	if done + 1 == 5 and _copy_t < COPY_SECONDS:
		_copy_t = minf(_copy_t + delta, COPY_SECONDS)
		_copy_bar.value = _copy_t
		var idx := mini(int(_copy_t / COPY_SECONDS * COPY_FILES.size()), COPY_FILES.size() - 1)
		_copy_status.text = "Copying %s..." % COPY_FILES[idx]
		if _copy_t >= COPY_SECONDS:
			_copy_status.text = "Done."
			_next.disabled = false
	_refresh_footer()
	if time_left <= 0.0:
		_fail()


# ---------- flow ----------

func _advance(by_imp: bool) -> void:
	if _finished:
		return
	done += 1
	_refresh_footer()
	step_done.emit(done, by_imp)
	if done >= STEPS:
		_finished = true
		set_process(false)
		Sfx.play("chime", 1.0)
		_build_page(STEPS + 1)
		finished.emit(true)
		return
	Sfx.play("click", 1.0)
	_build_page(done + 1)


func _fail() -> void:
	if _finished:
		return
	_finished = true
	set_process(false)
	Sfx.play("error", 0.8)
	_build_page(-1)
	_refresh_footer()
	finished.emit(false)


func _trap(kind: String) -> void:
	if _finished:
		return
	Sfx.play("error", 1.0)
	Juice.flash(_page, Color(1.4, 0.9, 0.9))
	misclick.emit(kind)


func _refresh_footer() -> void:
	_bar.value = done
	_step_label.text = "Step %d of %d" % [mini(done + 1, STEPS), STEPS]
	_time_label.text = "Time left: %d s" % ceili(time_left)
	var low := time_left < LOW_TIME
	_time_label.add_theme_color_override("font_color", Color("c00000") if low else Win98.BLACK)
	_sidebar.queue_redraw()


# ---------- pages ----------

## Frees the page container and builds page `i` (1..10; STEPS + 1 = installed, -1 = failed).
func _build_page(i: int) -> void:
	for c: Node in _page.get_children():
		_page.remove_child(c)
		c.queue_free()
	_next = null
	_checks = []
	_accept = null
	_key_label = null
	_input = null
	_hint = null
	_copy_bar = null
	_copy_status = null
	_link = null
	_browser = null
	_browser_safe = null
	_browser_ie = null
	match i:
		1:
			_page_welcome()
		2:
			_page_license()
		3:
			_page_components()
		4:
			_page_key()
		5:
			_page_copy()
		6:
			_page_register()
		7:
			_page_browser()
		8:
			_page_newsletter()
		9:
			_page_restart()
		10:
			_page_finish()
		STEPS + 1:
			_heading("Setup complete")
			_text("Service Pack 98 installed.", 14)
			_text("The desk may now resume being interrupted.", 12, Win98.GRAY_DARK)
		-1:
			_heading("Setup failed", Color("c00000"))
			_text("Setup did not complete in time. Service Pack 98 was not installed.", 13, Color("c00000"))
			_text("Error 0x80070057: the desk was not paying attention.", 11, Win98.GRAY_DARK)
		_:
			push_error("BossWindow: no page %d" % i)


func _page_welcome() -> void:
	_heading("Welcome to the Service Pack 98 Setup Wizard")
	_text("This wizard will guide you through the installation of Service Pack 98 on your computer.", 12)
	_text("It is strongly recommended that you exit all Windows programs before running this Setup program, which you cannot do because they keep opening.", 12)
	_text("Click Next to continue.", 12)
	_spacer()
	_next = _nav_button("Next >", _advance.bind(false))


func _page_license() -> void:
	_heading("License Agreement")
	_text("Please read the following license agreement. Press PAGE DOWN to see the rest of the agreement.", 11)
	var box := PanelContainer.new()
	var field := StyleBoxFlat.new()
	field.bg_color = Win98.WHITE
	field.border_color = Win98.GRAY_DARK
	field.set_border_width_all(1)
	field.set_content_margin_all(2)
	box.add_theme_stylebox_override("panel", field)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page.add_child(box)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.custom_minimum_size = Vector2(0, 120)
	box.add_child(scroll)
	var eula := Label.new()
	eula.text = EULA
	eula.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eula.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eula.add_theme_font_size_override("font_size", 10)
	eula.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(eula)
	_accept = _check("I accept the terms of the license agreement", false)
	_accept.toggled.connect(func(on: bool) -> void: _next.disabled = not on)
	_page.add_child(_accept)
	_next = _nav_button("Next >", func() -> void:
		if _accept.button_pressed:
			_advance(false))
	_next.disabled = true


func _page_components() -> void:
	_heading("Select Components")
	_text("Choose the components Setup will install. Recommended extras are selected for you.", 12)
	var core := _check("Service Pack 98 (required)", true)
	core.disabled = true
	_page.add_child(core)
	for text: String in ["Weather Buddy", "Search Toolbar", "Coupon Printer"]:
		var cb := _check(text, true)
		_checks.append(cb)
		_page.add_child(cb)
	_text("Disk space required: 847 MB. Disk space available: 12 MB.", 10, Win98.GRAY_DARK)
	_spacer()
	_next = _nav_button("Next >", func() -> void:
		for cb in _checks:
			if cb.button_pressed:
				_trap("bundled")
				return
		_advance(false))


func _page_key() -> void:
	_heading("Product Key")
	_text("Type the 5-character product key printed on the sticker you lost in 1998. For your convenience it is also shown below:", 12)
	_key_label = _text("", 20, Win98.TITLE_A, true)
	var row := _row()
	_input = LineEdit.new()
	_input.custom_minimum_size = Vector2(160, 24)
	_input.placeholder_text = "XXXXX"
	_input.max_length = 5
	_input.text_submitted.connect(func(_t: String) -> void: _verify_key())
	row.add_child(_input)
	_next = Win98Button.new("Verify", Vector2(90, 23))
	_next.bold_border = true
	_next.pressed.connect(_verify_key)
	row.add_child(_next)
	_hint = _text("", 10, Color("c00000"), true)
	_spacer()
	_new_key()


func _new_key() -> void:
	_key = ""
	for n in range(5):
		_key += KEY_LETTERS[rng.randi_range(0, KEY_LETTERS.length() - 1)]
	var spaced := ""
	for ch: String in _key:
		spaced += ch + " "
	_key_label.text = spaced.strip_edges()
	_input.text = ""


func _verify_key() -> void:
	if _finished or done + 1 != 4:
		return
	if _input.text.strip_edges().to_upper() == _key:
		_advance(false)
	else:
		_hint.text = "The product key is not valid. A new key has been issued."
		_trap("bad_key")
		_new_key()


func _page_copy() -> void:
	_heading("Copying Files")
	_text("Setup is copying files to your computer. This may take several minutes, or four seconds.", 12)
	_copy_t = 0.0
	_copy_bar = ProgressBar.new()
	_copy_bar.show_percentage = false
	_copy_bar.max_value = COPY_SECONDS
	_copy_bar.custom_minimum_size = Vector2(0, 18)
	_page.add_child(_copy_bar)
	_copy_status = _text("Copying %s..." % COPY_FILES[0], 11)
	_spacer()
	_next = _nav_button("Next >", _advance.bind(false))
	_next.disabled = true


func _page_register() -> void:
	_heading("Registering Components")
	_text("Setup is registering the installed components with the system. Please do not interrupt this process.", 12)
	_text("Registered: 847 of 847 components.", 11, Win98.GRAY_DARK)
	var mid := _row()
	var cancel := Win98Button.new("Cancel Setup", Vector2(180, 32))
	cancel.bold_border = true
	cancel.pressed.connect(func() -> void: _trap("cancel"))
	mid.add_child(cancel)
	_spacer()
	var foot := _row(BoxContainer.ALIGNMENT_END)
	_link = LinkButton.new()
	_link.text = "continue"
	_link.add_theme_font_size_override("font_size", 10)
	_link.focus_mode = Control.FOCUS_NONE
	_link.pressed.connect(_advance.bind(false))
	foot.add_child(_link)


func _page_browser() -> void:
	_heading("Default Browser")
	_text("Service Pack 98 includes Internet Explorer 4. Choose how you would like to browse the Web:", 12)
	_browser = ButtonGroup.new()
	var labels: Array[String] = ["Make Internet Explorer 4 my default browser (recommended)", "Keep my current browser", "Ask me every time"]
	for n in range(labels.size()):
		var cb := _check(labels[n], n == 0)
		cb.button_group = _browser
		if n == 0:
			_browser_ie = cb
		elif n == 1:
			_browser_safe = cb
		_page.add_child(cb)
	_spacer()
	_next = _nav_button("Next >", func() -> void:
		if _browser_ie.button_pressed:
			_trap("browser")
		else:
			_advance(false))


func _page_newsletter() -> void:
	_heading("Stay Informed")
	_text("Get the most out of Service Pack 98. We have taken the liberty of signing you up:", 12)
	for text: String in ["Send me tips, tricks and special offers", "Share my data with 847 partners"]:
		var cb := _check(text, true)
		_checks.append(cb)
		_page.add_child(cb)
	_spacer()
	_next = _nav_button("Next >", func() -> void:
		for cb in _checks:
			if cb.button_pressed:
				_trap("newsletter")
				return
		_advance(false))


func _page_restart() -> void:
	_heading("Restart Required")
	_text("Setup must restart your computer to complete the installation. All unsaved work in the 14 open windows will be lost.", 12)
	var mid := _row()
	var now := Win98Button.new("Restart Now", Vector2(200, 36))
	now.bold_border = true
	now.font_size = 16
	now.pressed.connect(func() -> void: _trap("restart"))
	mid.add_child(now)
	_spacer()
	_next = _nav_button("Restart Later", _advance.bind(false), Vector2(110, 23))
	_next.bold_border = false
	_next.font_size = 11


func _page_finish() -> void:
	_heading("Completing the Service Pack 98 Setup Wizard")
	_text("Setup has finished installing Service Pack 98 on your computer. Click Finish to exit the wizard.", 12)
	_text("Setup will now hide the Weather Buddy icon somewhere you will find it later.", 11, Win98.GRAY_DARK)
	_spacer()
	_next = _nav_button("Finish", _advance.bind(false))


# ---------- page-building helpers ----------

func _heading(text: String, color: Color = Win98.TITLE_A) -> Label:
	return _text(text, 15, color)


func _text(text: String, font_size: int = Win98.FONT_SIZE, color: Color = Win98.BLACK, centered: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page.add_child(l)
	return l


func _check(text: String, checked: bool) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = text
	cb.button_pressed = checked
	cb.focus_mode = Control.FOCUS_NONE
	cb.add_theme_font_size_override("font_size", 12)
	return cb


func _row(alignment: int = BoxContainer.ALIGNMENT_CENTER) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = alignment
	h.add_theme_constant_override("separation", 8)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_child(h)
	return h


func _spacer() -> void:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(c)


## A wizard-style default button in a right-aligned row at the bottom of the page.
func _nav_button(text: String, on_pressed: Callable, min_size: Vector2 = Vector2(90, 23)) -> Win98Button:
	var row := _row(BoxContainer.ALIGNMENT_END)
	var b := Win98Button.new(text, min_size)
	b.bold_border = true
	b.pressed.connect(on_pressed)
	row.add_child(b)
	return b


## The InstallShield-style left column: dark-blue gradient, the four-colour flag
## at the top, "Setup" running down the side.
func _draw_sidebar() -> void:
	var s := _sidebar
	var h := s.size.y
	var bands := 24
	for n in range(bands):
		var t := float(n) / float(bands - 1)
		var col := Win98.TITLE_A.lerp(Color("000030"), t)
		var y0 := floorf(h * n / bands)
		var y1 := floorf(h * (n + 1) / bands)
		s.draw_rect(Rect2(Vector2(0, y0), Vector2(s.size.x, y1 - y0)), col)
	# Flag: four waved panes.
	var fx := 10.0
	var fy := 10.0
	var pane := Vector2(16, 12)
	var colours: Array[Color] = [Color("ff4b2b"), Color("29a329"), Color("2b7bff"), Color("ffcc00")]
	for n in range(4):
		var cx := fx + pane.x * (n % 2)
		var cy := fy + pane.y * (n / 2)
		var wave := 3.0
		var pts := PackedVector2Array([
			Vector2(cx, cy + wave), Vector2(cx + pane.x * 0.5, cy), Vector2(cx + pane.x, cy + wave),
			Vector2(cx + pane.x, cy + pane.y + wave), Vector2(cx + pane.x * 0.5, cy + pane.y), Vector2(cx, cy + pane.y + wave),
		])
		s.draw_colored_polygon(pts, colours[n])
	# Vertical caption, bottom to top.
	var caption := "Service Pack 98 Setup"
	var size_px := 15
	var ts := Win98.text_size(caption, size_px)
	var x := floorf((s.size.x - ts.y) * 0.5)
	s.draw_set_transform(Vector2(x, h - 12), -PI * 0.5)
	Win98.draw_text(s, Vector2.ZERO, caption, Win98.WHITE, size_px)
	s.draw_set_transform(Vector2.ZERO, 0.0)
