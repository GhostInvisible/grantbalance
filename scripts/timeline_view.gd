extends Control
## Шкала года: 12 месяцев, текущий выделен, ромбиками отмечены плановые проверки.

var month := 1
var audits: Array = [3, 6, 9, 12]


func _init() -> void:
	custom_minimum_size = Vector2(0, 62)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_month(m: int, a: Array) -> void:
	month = m
	audits = a
	queue_redraw()


func _draw() -> void:
	var w := size.x
	if w < 60.0:
		return
	var n := 12
	var y := size.y * 0.52
	var x0 := 22.0
	var x1 := w - 22.0
	var green := Color(0.18, 0.62, 0.40)
	var orange := Color(0.93, 0.55, 0.15)
	var grey := Color(0.80, 0.82, 0.85)
	draw_line(Vector2(x0, y), Vector2(x1, y), grey, 6.0)
	var prog := x0 + (x1 - x0) * float(month - 1) / float(n - 1)
	draw_line(Vector2(x0, y), Vector2(prog, y), green, 6.0)
	var font := ThemeDB.fallback_font
	for i in range(n):
		var m := i + 1
		var x := x0 + (x1 - x0) * float(i) / float(n - 1)
		var cur := m == month
		var col := green if m < month else (orange if cur else grey)
		var r := 11.0 if cur else 8.0
		draw_circle(Vector2(x, y + 2.0), r + 1.5, Color(0, 0, 0, 0.12))
		draw_circle(Vector2(x, y), r, col)
		draw_circle(Vector2(x - r * 0.3, y - r * 0.3), r * 0.35, Color(1, 1, 1, 0.35))
		if audits.has(m):
			var d := 6.0
			var top := y - r - 15.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + d, top + 7.0), Vector2(x, top + 14.0), Vector2(x - d, top + 7.0)]), Color(0.55, 0.38, 0.78))
		draw_string(font, Vector2(x - 12.0, y + r + 16.0), str(m), HORIZONTAL_ALIGNMENT_CENTER, 24.0, 12, Color(0.35, 0.38, 0.42))
