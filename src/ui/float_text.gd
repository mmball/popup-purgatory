class_name FloatText
extends Label
## Short-lived rising text ("+5", "WAVE 3").


static func spawn(parent: Node, pos: Vector2, text: String, color: Color = Color.WHITE, font_size: int = 14, rise: float = 40.0, duration: float = 0.9) -> FloatText:
	var ft := FloatText.new()
	ft.text = text
	ft.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ft.add_theme_color_override("font_color", color)
	ft.add_theme_color_override("font_outline_color", Color.BLACK)
	ft.add_theme_constant_override("outline_size", 4)
	ft.add_theme_font_size_override("font_size", font_size)
	ft.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ft.position = pos
	parent.add_child(ft)
	# center on pos once the label knows its size
	ft.position = pos - ft.size * 0.5
	var tw := ft.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ft, "position:y", ft.position.y - rise, duration).set_ease(Tween.EASE_OUT)
	tw.tween_property(ft, "modulate:a", 0.0, duration * 0.6).set_delay(duration * 0.4)
	tw.chain().tween_callback(ft.queue_free)
	return ft
