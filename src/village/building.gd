class_name Building
extends Node2D
## A structure on the wallpaper. Drawn procedurally per type, centred on origin.

var id := ""
var def: Dictionary
var _t := 0.0

# dojo state (drawn as a sign and a progress bar)
const DOJO_SLOTS := 2
var graduates := 0           ## imps this dojo has trained
var trainee: Node = null     ## the imp inside right now, or null
var train_progress := 0.0    ## 0..1 while a trainee is inside


func has_free_slot() -> bool:
	return id == "dojo" and trainee == null and graduates < DOJO_SLOTS


func _init(p_id: String = "hut") -> void:
	id = p_id
	def = BuildingCatalog.get_def(id)


func _process(delta: float) -> void:
	_t += delta
	if id in ["ram", "antivirus", "coffee"] or (id == "dojo" and trainee != null):
		queue_redraw()


func _draw() -> void:
	var c: Color = def["color"]
	match id:
		"hut":
			draw_rect(Rect2(-14, -12, 28, 20), c)
			draw_polygon(PackedVector2Array([Vector2(-18, -12), Vector2(0, -26), Vector2(18, -12)]), PackedColorArray([Color("b22222")]))
			draw_rect(Rect2(-4, -4, 8, 12), Color("3b1f0e"))
			draw_rect(Rect2(6, -8, 5, 5), Color("ffe680"))
		"dojo":
			draw_rect(Rect2(-16, -10, 32, 18), Color("f3e2c0"))
			draw_polygon(PackedVector2Array([Vector2(-20, -10), Vector2(0, -20), Vector2(20, -10)]), PackedColorArray([c]))
			draw_polygon(PackedVector2Array([Vector2(-13, -20), Vector2(0, -28), Vector2(13, -20)]), PackedColorArray([c]))
			draw_rect(Rect2(-3, -2, 6, 10), Color("3b1f0e"))
			# sign: graduates so far; bar: the trainee inside
			Win98.draw_text(self, Vector2(-16, -36), "%d/%d" % [graduates, DOJO_SLOTS], Color("ffd700"), 10, 32, HORIZONTAL_ALIGNMENT_CENTER)
			if trainee != null:
				draw_rect(Rect2(-16, -42, 32, 5), Color.BLACK)
				draw_rect(Rect2(-15, -41, 30.0 * train_progress, 3), Color("7CFC00"))
		"coffee":
			draw_rect(Rect2(-14, -10, 28, 18), c)
			draw_rect(Rect2(-16, -14, 32, 4), Color("f0f0f0"))
			draw_circle(Vector2(-9, 10), 3, Color("222222"))
			draw_circle(Vector2(9, 10), 3, Color("222222"))
			draw_rect(Rect2(-6, -6, 12, 9), Color("fff8e7"))
			for i in range(3):
				var y := -18 - fmod(_t * 12.0 + i * 6.0, 14.0)
				draw_circle(Vector2(-4 + i * 4, y), 1.5, Color(1, 1, 1, 0.6))
		"ram":
			draw_rect(Rect2(-18, -8, 36, 16), c)
			for i in range(6):
				draw_rect(Rect2(-15 + i * 5.5, -5, 4, 7), Color("111111"))
			for i in range(6):
				var on := fmod(_t * 3.0 + i, 6.0) < 1.0
				draw_rect(Rect2(-15 + i * 5.5, 4, 4, 2), Color("7CFC00") if on else Color("004400"))
		"firewall":
			for row in range(4):
				for col in range(4):
					var x := -18 + col * 9 + (4.5 if row % 2 == 1 else 0.0)
					draw_rect(Rect2(x, -16 + row * 7, 8, 6), c)
			draw_polygon(PackedVector2Array([Vector2(-6, -16), Vector2(0, -28), Vector2(6, -16)]), PackedColorArray([Color("ff4500")]))
		"antivirus":
			draw_rect(Rect2(-16, 2, 32, 6), Color("8a7a3a"))
			draw_rect(Rect2(-12, -14, 4, 16), Color("e8dcb0"))
			draw_rect(Rect2(8, -14, 4, 16), Color("e8dcb0"))
			draw_rect(Rect2(-16, -18, 32, 4), Color("8a7a3a"))
			var glow := 0.6 + 0.4 * sin(_t * 4.0)
			draw_circle(Vector2(0, -6), 6, Color(c, glow))
		"shrine":
			draw_rect(Rect2(-14, 0, 28, 8), Color("708090"))
			draw_rect(Rect2(-8, -10, 16, 10), Color("a9b4c2"))
			var pts := PackedVector2Array([Vector2(0, -26), Vector2(0, -12), Vector2(4, -16), Vector2(9, -14)])
			draw_polygon(pts, PackedColorArray([Color.WHITE]))
			draw_polyline(pts, Color.BLACK, 1.0)
		_:
			draw_rect(Rect2(-12, -12, 24, 24), c)
	Win98.draw_text(self, Vector2(-30, 10), str(def["name"]), Color.WHITE, 9, 60, HORIZONTAL_ALIGNMENT_CENTER)
