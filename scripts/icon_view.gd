extends Control
## Маленькие значки, нарисованные кодом: монета, сердце, документ, огонь, звезда, лист, люди, замок, кубок.

var kind := "coin"
var col := Color(0.2, 0.6, 0.4)


func setup(k: String, c: Color, px := 26) -> void:
	kind = k
	col = c
	custom_minimum_size = Vector2(px, px)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s < 4.0:
		return
	var c := Vector2(size.x / 2.0, size.y / 2.0)
	var r := s * 0.5
	var wh := Color.WHITE
	draw_circle(c, r, col)
	match kind:
		"coin":
			draw_circle(c, r * 0.58, wh)
			draw_circle(c, r * 0.38, col)
			draw_rect(Rect2(c.x - r * 0.06, c.y - r * 0.24, r * 0.12, r * 0.48), wh)
		"heart":
			draw_circle(c + Vector2(-r * 0.24, -r * 0.14), r * 0.32, wh)
			draw_circle(c + Vector2(r * 0.24, -r * 0.14), r * 0.32, wh)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.52, -r * 0.02), c + Vector2(r * 0.52, -r * 0.02), c + Vector2(0, r * 0.58)]), wh)
		"doc":
			draw_rect(Rect2(c.x - r * 0.36, c.y - r * 0.5, r * 0.72, r * 1.0), wh)
			for i in range(3):
				draw_rect(Rect2(c.x - r * 0.22, c.y - r * 0.3 + i * r * 0.28, r * 0.44, r * 0.09), col)
		"fire":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.62), c + Vector2(r * 0.46, r * 0.4), c + Vector2(-r * 0.46, r * 0.4)]), wh)
			draw_circle(c + Vector2(0, r * 0.22), r * 0.3, wh)
			draw_circle(c + Vector2(0, r * 0.26), r * 0.14, col)
		"star":
			var pts := PackedVector2Array()
			for i in range(10):
				var rad := r * 0.62 if i % 2 == 0 else r * 0.26
				var a := -PI / 2.0 + i * PI / 5.0
				pts.append(c + Vector2(cos(a) * rad, sin(a) * rad))
			draw_colored_polygon(pts, wh)
		"leaf":
			var lp := PackedVector2Array()
			for i in range(16):
				var a2 := TAU * i / 16.0
				lp.append(c + Vector2(cos(a2) * r * 0.36, sin(a2) * r * 0.6))
			draw_colored_polygon(lp, wh)
			draw_line(c + Vector2(0, r * 0.5), c + Vector2(0, -r * 0.4), col, 2.0)
		"people":
			draw_circle(c + Vector2(-r * 0.26, -r * 0.2), r * 0.2, wh)
			draw_circle(c + Vector2(r * 0.26, -r * 0.2), r * 0.2, wh)
			draw_rect(Rect2(c.x - r * 0.46, c.y + r * 0.04, r * 0.4, r * 0.46), wh)
			draw_rect(Rect2(c.x + r * 0.06, c.y + r * 0.04, r * 0.4, r * 0.46), wh)
		"lock":
			draw_rect(Rect2(c.x - r * 0.34, c.y - r * 0.04, r * 0.68, r * 0.5), wh)
			draw_arc(c + Vector2(0, -r * 0.06), r * 0.24, PI, TAU, 12, wh, 3.0)
		"cup":
			draw_rect(Rect2(c.x - r * 0.34, c.y - r * 0.46, r * 0.68, r * 0.5), wh)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.34, c.y * 0.0 + r * 0.04), c + Vector2(r * 0.34, r * 0.04), c + Vector2(r * 0.12, r * 0.3), c + Vector2(-r * 0.12, r * 0.3)]), wh)
			draw_rect(Rect2(c.x - r * 0.3, c.y + r * 0.36, r * 0.6, r * 0.12), wh)
