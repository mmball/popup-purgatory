class_name Juice
extends RefCounted
## Animation helpers: the "feel" layer. Everything here is cosmetic and must never
## change game state. `enabled` is false under --no-juice so bots, determinism and
## unit tests see the same timings with or without it.

static var enabled := true


## Scale-bounce a control in from a little small. Pivot at its centre.
static func pop_in(c: Control, duration: float = 0.18) -> void:
	if not enabled or not c.is_inside_tree():
		return
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(0.7, 0.7)
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, duration * 0.6)


## Fold a control away, then call `done` (which usually frees it). Calls `done`
## immediately when disabled so logic never waits on an animation.
static func pop_out(c: Control, done: Callable, duration: float = 0.14) -> void:
	if not enabled or not c.is_inside_tree():
		done.call()
		return
	c.pivot_offset = c.size * 0.5
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := c.create_tween()
	tw.set_parallel(true)
	tw.tween_property(c, "scale:y", 0.05, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "scale:x", 1.08, duration * 0.5)
	tw.tween_property(c, "modulate:a", 0.0, duration).set_delay(duration * 0.4)
	tw.chain().tween_callback(done)


## Brief colour flash on a canvas item (title bar on raise, red on penalties).
static func flash(ci: CanvasItem, color: Color, duration: float = 0.25) -> void:
	if not enabled or not ci.is_inside_tree():
		return
	ci.modulate = color
	var tw := ci.create_tween()
	tw.tween_property(ci, "modulate", Color.WHITE, duration)


## Squash-and-stretch on a Node2D (imp landing).
static func squash(n: Node2D, amount: float = 0.35, duration: float = 0.22) -> void:
	if not enabled or not n.is_inside_tree():
		return
	n.scale = Vector2(1.0 + amount, 1.0 - amount)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Little vertical hop on a Node2D's drawing (via `offset`-style property `hop_y`).
static func hop(n: Node2D, height: float = 14.0, duration: float = 0.28) -> void:
	if not enabled or not n.is_inside_tree() or not ("hop_y" in n):
		return
	var tw := n.create_tween()
	tw.tween_property(n, "hop_y", -height, duration * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "hop_y", 0.0, duration * 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Trauma-squared screen shake (Nijman / Saltmire style). `holder` is any node with
## a `trauma` float; the owner decays it and applies the offset each frame.
static func add_trauma(holder: Object, amount: float) -> void:
	if not enabled:
		return
	holder.set("trauma", clampf(float(holder.get("trauma")) + amount, 0.0, 1.0))


static func shake_offset(trauma: float, max_px: float, rng: RandomNumberGenerator) -> Vector2:
	var s := trauma * trauma
	return Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * max_px * s
