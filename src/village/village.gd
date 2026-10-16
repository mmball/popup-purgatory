class_name Village
extends Control
## The wallpaper is the town. A grid of cells holds buildings; placement mode
## shows the grid and a ghost under the cursor.

signal place_requested(building_id: String, cell: Vector2i)
signal demolish_requested(cell: Vector2i)
signal relocate_requested(from: Vector2i, to: Vector2i)
signal placement_changed(active: bool)
signal icon_activated(kind: String)

const CELL := 64
const COLS := 20
const ROWS := 10
const ORIGIN := Vector2(0, 14)

var buildings := {}            ## Vector2i -> Building
var placing_id := ""
var demolishing := false
var relocate_enabled := false  ## true during breaks: drag a building to move it
var show_rings := false:       ## radius rings while the Start menu is open
	set(v):
		show_rings = v
		queue_redraw()
var refund_preview: Callable   ## (cell) -> int, set by Desktop for the demolish label
var _drag_from := Vector2i(-1, -1)
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
	for i: DesktopIcon in _icons:
		i.deselect()


func is_placing() -> bool:
	return placing_id != ""


func is_demolishing() -> bool:
	return demolishing


## Any modal interaction on the grid (placement, demolish, a relocate drag).
func is_busy() -> bool:
	return placing_id != "" or demolishing or _drag_from.x >= 0


func begin_demolish() -> void:
	cancel_place()
	demolishing = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	placement_changed.emit(true)
	queue_redraw()


func cancel_demolish() -> void:
	if not demolishing:
		return
	demolishing = false
	if not relocate_enabled:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	placement_changed.emit(false)
	queue_redraw()


func set_relocate_enabled(on: bool) -> void:
	relocate_enabled = on
	_drag_from = Vector2i(-1, -1)
	mouse_filter = Control.MOUSE_FILTER_STOP if (on or placing_id != "" or demolishing) else Control.MOUSE_FILTER_IGNORE
	queue_redraw()


## Chebyshev distance in cells (rings are square, like the grid).
static func cell_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## Buildings of `id` whose cell is within `radius` cells of `cell`.
func buildings_within(cell: Vector2i, radius: int, id: String = "") -> Array[Building]:
	var out: Array[Building] = []
	for c: Vector2i in buildings.keys():
		if cell_distance(c, cell) <= radius and (id == "" or buildings[c].id == id):
			out.append(buildings[c])
	return out


## Number of carts in range of a hut cell (stray imps with no hut get none).
func carts_in_range(home: Vector2i) -> int:
	if not in_bounds(home):
		return 0
	return buildings_within(home, BuildingCatalog.radius("coffee"), "coffee").size()


## Pixel-space no-spawn zones: one circle per firewall.
func firewall_zones() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Vector2i in buildings.keys():
		if buildings[c].id == "firewall":
			out.append({"center": cell_center(c), "radius": BuildingCatalog.radius("firewall") * CELL})
	return out


## A sensible free cell for `id`: carts and dojos go where they cover the most
## huts; firewalls go to the free cell farthest from other firewalls near the
## middle of the desk; everything else next to existing buildings. Used by the
## bots; a player picks by hand.
func suggest_cell(id: String) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score := -INF
	var r := BuildingCatalog.radius(id)
	for y in range(ROWS):
		for x in range(1, COLS):
			var c := Vector2i(x, y)
			if not cell_free(c):
				continue
			var score := 0.0
			match id:
				"coffee", "dojo":
					score = float(buildings_within(c, r, "hut").size()) * 10.0 - float(buildings_within(c, r, id).size()) * 4.0
				"firewall":
					var d := INF
					for other: Building in buildings_within(c, COLS, "firewall"):
						d = minf(d, float(cell_distance(c, other.cell)))
					score = minf(d, 8.0) - absf(float(x) - COLS * 0.5) * 0.2 - absf(float(y) - ROWS * 0.5) * 0.2
				_:
					score = float(buildings_within(c, 1).size()) * 2.0 - float(y) * 0.5 - float(x) * 0.05
			if score > best_score:
				best_score = score
				best = c
	return best


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
	if not relocate_enabled and not demolishing:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	placement_changed.emit(false)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover_cell = pos_to_cell(event.position)
		queue_redraw()
		return
	if not (event is InputEventMouseButton):
		return
	var cell := pos_to_cell(event.position)
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cancel_place()
		cancel_demolish()
		_drag_from = Vector2i(-1, -1)
		queue_redraw()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if placing_id != "":
		if event.pressed and cell_free(cell):
			place_requested.emit(placing_id, cell)
	elif demolishing:
		if event.pressed and buildings.has(cell):
			demolish_requested.emit(cell)
	elif relocate_enabled:
		if event.pressed and buildings.has(cell):
			_drag_from = cell
			queue_redraw()
		elif not event.pressed and _drag_from.x >= 0:
			if cell_free(cell):
				relocate_requested.emit(_drag_from, cell)
			_drag_from = Vector2i(-1, -1)
			queue_redraw()


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
	for b: Building in buildings.values():
		if b.id == id:
			n += 1
	return n


func add_building(id: String, cell: Vector2i, price_paid: int = 0) -> Building:
	var b := Building.new(id)
	b.cell = cell
	b.price_paid = price_paid
	b.position = cell_center(cell) + Vector2(0, 8)
	add_child(b)
	buildings[cell] = b
	queue_redraw()
	return b


func remove_building(cell: Vector2i) -> Building:
	var b: Building = buildings.get(cell)
	if b == null:
		return null
	buildings.erase(cell)
	remove_child(b)
	b.queue_free()
	queue_redraw()
	return b


func move_building(from: Vector2i, to: Vector2i) -> bool:
	if not buildings.has(from) or not cell_free(to):
		return false
	var b: Building = buildings[from]
	buildings.erase(from)
	buildings[to] = b
	b.cell = to
	b.position = cell_center(to) + Vector2(0, 8)
	queue_redraw()
	return true


## First free cell scanning left-to-right, top-to-bottom, skipping the icon column.
func first_free_cell() -> Vector2i:
	for y in range(ROWS):
		for x in range(1, COLS):
			var c := Vector2i(x, y)
			if cell_free(c):
				return c
	return Vector2i(-1, -1)


func _draw_rings() -> void:
	for c: Vector2i in buildings.keys():
		var b: Building = buildings[c]
		var r := BuildingCatalog.radius(b.id)
		if r <= 0:
			continue
		var col: Color = b.def["color"]
		var rect := Rect2(ORIGIN + Vector2((c.x - r) * CELL, (c.y - r) * CELL), Vector2((2 * r + 1) * CELL, (2 * r + 1) * CELL))
		draw_rect(rect, Color(col, 0.10))
		draw_rect(rect, Color(col, 0.6), false, 2.0)


func _draw() -> void:
	if not is_busy() and not relocate_enabled and not show_rings:
		return
	_draw_rings()
	if demolishing:
		var hint := "Demolish: click a building to sell it for half what you paid (three quarters on a break).  Esc or right-click cancels."
		var hs := Win98.text_size(hint, 13)
		var hx := (size.x - hs.x) * 0.5
		draw_rect(Rect2(hx - 8, 8, hs.x + 16, hs.y + 8), Color(0, 0, 0, 0.55))
		Win98.draw_text(self, Vector2(hx, 12), hint, Color.WHITE, 13)
		if buildings.has(_hover_cell):
			var r := Rect2(ORIGIN + Vector2(_hover_cell.x * CELL, _hover_cell.y * CELL), Vector2(CELL, CELL))
			draw_rect(r, Color(1.0, 0.2, 0.2, 0.35))
			draw_rect(r, Color(1.0, 0.3, 0.3, 0.9), false, 2.0)
			var refund := int(refund_preview.call(_hover_cell)) if refund_preview.is_valid() else 0
			Win98.draw_text(self, r.position + Vector2(2, 2), "Sell for %d" % refund, Color.WHITE, 10)
		return
	if relocate_enabled and placing_id == "":
		var hint := "Coffee break: drag a building to move it for free."
		var hs := Win98.text_size(hint, 13)
		var hx := (size.x - hs.x) * 0.5
		draw_rect(Rect2(hx - 8, 8, hs.x + 16, hs.y + 8), Color(0, 0, 0, 0.55))
		Win98.draw_text(self, Vector2(hx, 12), hint, Color.WHITE, 13)
		if _drag_from.x >= 0:
			var fr := Rect2(ORIGIN + Vector2(_drag_from.x * CELL, _drag_from.y * CELL), Vector2(CELL, CELL))
			draw_rect(fr, Color(1, 1, 1, 0.25))
			if in_bounds(_hover_cell):
				var ok := cell_free(_hover_cell)
				var tr := Rect2(ORIGIN + Vector2(_hover_cell.x * CELL, _hover_cell.y * CELL), Vector2(CELL, CELL))
				draw_rect(tr, Color(0.3, 1.0, 0.3, 0.35) if ok else Color(1.0, 0.3, 0.3, 0.35))
		return
	if placing_id == "":
		return
	var grid_col := Color(1, 1, 1, 0.18)
	for x in range(COLS + 1):
		var px := ORIGIN.x + x * CELL
		draw_line(Vector2(px, ORIGIN.y), Vector2(px, ORIGIN.y + ROWS * CELL), grid_col, 1.0)
	for y in range(ROWS + 1):
		var py := ORIGIN.y + y * CELL
		draw_line(Vector2(ORIGIN.x, py), Vector2(ORIGIN.x + COLS * CELL, py), grid_col, 1.0)
	var pdef := BuildingCatalog.get_def(placing_id)
	var hint := "Placing %s: click a free cell.  Esc or right-click cancels." % str(pdef["name"])
	var hs := Win98.text_size(hint, 13)
	var hx := (size.x - hs.x) * 0.5
	draw_rect(Rect2(hx - 8, 8, hs.x + 16, hs.y + 8), Color(0, 0, 0, 0.55))
	Win98.draw_text(self, Vector2(hx, 12), hint, Color.WHITE, 13)
	if in_bounds(_hover_cell):
		var ok := cell_free(_hover_cell) and _can_afford
		var col := Color(0.3, 1.0, 0.3, 0.35) if ok else Color(1.0, 0.3, 0.3, 0.35)
		var r := Rect2(ORIGIN + Vector2(_hover_cell.x * CELL, _hover_cell.y * CELL), Vector2(CELL, CELL))
		draw_rect(r, col)
		draw_rect(r, col.lightened(0.3), false, 2.0)
		var def := BuildingCatalog.get_def(placing_id)
		Win98.draw_text(self, r.position + Vector2(2, 2), str(def["name"]), Color.WHITE, 10)
		var pr := BuildingCatalog.radius(placing_id)
		if pr > 0:
			var ring := Rect2(ORIGIN + Vector2((_hover_cell.x - pr) * CELL, (_hover_cell.y - pr) * CELL), Vector2((2 * pr + 1) * CELL, (2 * pr + 1) * CELL))
			draw_rect(ring, Color(col, 0.6), false, 2.0)
