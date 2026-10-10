class_name Village
extends Control
## The wallpaper is the town. A grid of cells holds buildings; placement mode
## shows the grid and a ghost under the cursor.

signal place_requested(building_id: String, cell: Vector2i)
signal placement_changed(active: bool)
signal icon_activated(kind: String)

const CELL := 64
const COLS := 20
const ROWS := 10
const ORIGIN := Vector2(0, 14)

var buildings := {}            ## Vector2i -> Building
var placing_id := ""
var reserved: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]

var _hover_cell := Vector2i(-1, -1)
var _icons: Array[DesktopIcon] = []
var _can_afford := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var specs := [["My Computer", "computer"], ["Recycle Bin", "bin"], ["Imp Town", "imps"]]
	for i in range(specs.size()):
		var icon := DesktopIcon.new(specs[i][0], specs[i][1])
		icon.position = ORIGIN + Vector2(2, i * CELL)
		icon.activated.connect(func() -> void: icon_activated.emit(icon.kind))
		add_child(icon)
		_icons.append(icon)


func deselect_icons() -> void:
	for i in _icons:
		i.deselect()


func is_placing() -> bool:
	return placing_id != ""


func begin_place(id: String, can_afford: bool = true) -> void:
	placing_id = id
	_can_afford = can_afford
	mouse_filter = Control.MOUSE_FILTER_STOP
	placement_changed.emit(true)
	queue_redraw()


func set_affordable(v: bool) -> void:
	_can_afford = v
	queue_redraw()


func cancel_place() -> void:
	if placing_id == "":
		return
	placing_id = ""
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	placement_changed.emit(false)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if placing_id == "":
		return
	if event is InputEventMouseMotion:
		_hover_cell = pos_to_cell(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_place()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var cell := pos_to_cell(event.position)
			if cell_free(cell):
				place_requested.emit(placing_id, cell)


func pos_to_cell(p: Vector2) -> Vector2i:
	var rel := p - ORIGIN
	return Vector2i(int(floor(rel.x / CELL)), int(floor(rel.y / CELL)))


func cell_center(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2(cell.x * CELL + CELL * 0.5, cell.y * CELL + CELL * 0.5)


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < COLS and cell.y < ROWS


func cell_free(cell: Vector2i) -> bool:
	return in_bounds(cell) and not (cell in reserved) and not buildings.has(cell)


func count(id: String) -> int:
	var n := 0
	for b in buildings.values():
		if b.id == id:
			n += 1
	return n


func add_building(id: String, cell: Vector2i) -> Building:
	var b := Building.new(id)
	b.position = cell_center(cell) + Vector2(0, 8)
	add_child(b)
	buildings[cell] = b
	queue_redraw()
	return b


## First free cell scanning left-to-right, top-to-bottom, skipping the icon column.
func first_free_cell() -> Vector2i:
	for y in range(ROWS):
		for x in range(1, COLS):
			var c := Vector2i(x, y)
			if cell_free(c):
				return c
	return Vector2i(-1, -1)


func _draw() -> void:
	if placing_id == "":
		return
	var grid_col := Color(1, 1, 1, 0.18)
	for x in range(COLS + 1):
		var px := ORIGIN.x + x * CELL
		draw_line(Vector2(px, ORIGIN.y), Vector2(px, ORIGIN.y + ROWS * CELL), grid_col, 1.0)
	for y in range(ROWS + 1):
		var py := ORIGIN.y + y * CELL
		draw_line(Vector2(ORIGIN.x, py), Vector2(ORIGIN.x + COLS * CELL, py), grid_col, 1.0)
	if in_bounds(_hover_cell):
		var ok := cell_free(_hover_cell) and _can_afford
		var col := Color(0.3, 1.0, 0.3, 0.35) if ok else Color(1.0, 0.3, 0.3, 0.35)
		var r := Rect2(ORIGIN + Vector2(_hover_cell.x * CELL, _hover_cell.y * CELL), Vector2(CELL, CELL))
		draw_rect(r, col)
		draw_rect(r, col.lightened(0.3), false, 2.0)
		var def := BuildingCatalog.get_def(placing_id)
		Win98.draw_text(self, r.position + Vector2(2, 2), str(def["name"]), Color.WHITE, 10)
