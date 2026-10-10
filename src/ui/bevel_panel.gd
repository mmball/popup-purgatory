class_name BevelPanel
extends Control
## A plain raised or sunken panel. Children are laid out by the caller.

var sunken := false
var fill := Win98.GRAY


func _init(p_sunken: bool = false) -> void:
	sunken = p_sunken
	mouse_filter = Control.MOUSE_FILTER_PASS


func _draw() -> void:
	Win98.draw_bevel(self, Rect2(Vector2.ZERO, size), sunken, fill)
