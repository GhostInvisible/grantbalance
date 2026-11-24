extends Control
## Прозрачный слой поверх картинки двора. Фон, дом и забор берутся из картинки,
## а здесь рисуется только прогресс: деревья, цветы, люди, оборудование, сезон.

var st: Dictionary = {}
var do_flash := false
var t := 0.0

const TREE_X: Array = [0.60, 0.70, 0.80, 0.90, 0.66, 0.86, 0.95, 0.56, 0.74, 0.50, 0.30, 0.22]
const FLOWER_COLORS: Array = [Color(0.95, 0.45, 0.65), Color(1, 0.85, 0.3), Color(1, 1, 1), Color(0.7, 0.5, 0.9)]
const SHIRTS: Array = [Color(0.22, 0.48, 0.82), Color(0.93, 0.55, 0.15), Color(0.85, 0.30, 0.30), Color(0.55, 0.38, 0.78), Color(0.18, 0.62, 0.40)]
const BALLOONS: Array = [Color(0.9, 0.3, 0.3), Color(0.95, 0.75, 0.2), Color(0.3, 0.6, 0.9), Color(0.6, 0.4, 0.8), Color(0.3, 0.75, 0.5)]
const CROWNS: Array = [Color(0.30, 0.66, 0.32), Color(0.18, 0.54, 0.26), Color(0.88, 0.52, 0.14), Color(0.90, 0.94, 0.98)]


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_state(state: Dictionary, flash := false) -> void:
	st = state
	do_flash = flash
	queue_redraw()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _ready() -> void:
	if do_flash:
		self_modulate = Color(1.7, 1.7, 1.7)
		var tw := create_tween()
		tw.tween_property(self, "self_modulate", Color.WHITE, 0.9)


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(24):
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _tree(x: float, y: float, season: int, i: int, s: float) -> void:
	draw_circle(Vector2(x + 2.0 * s, y + 1.0), 11.0 * s, Color(0, 0, 0, 0.18))
	draw_rect(Rect2(x - 3.0 * s, y - 16.0 * s, 6.0 * s, 16.0 * s), Color(0.42, 0.28, 0.17))
	if season == 3:
		draw_circle(Vector2(x, y - 24.0 * s), 11.0 * s, CROWNS[3])
		return
	var col: Color = CROWNS[season]
	if i % 2 == 1:
		col = col.darkened(0.08)
	draw_circle(Vector2(x, y - 24.0 * s), 15.0 * s, col.darkened(0.18))
	draw_circle(Vector2(x - 2.0 * s, y - 26.0 * s), 12.0 * s, col)
	draw_circle(Vector2(x - 5.0 * s, y - 30.0 * s), 5.0 * s, col.lightened(0.25))


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 20.0:
		return
	var kpi := int(st.get("kpi", 0))
	var level := int(st.get("level", 1))
	var tired := int(st.get("tired", 0))
	var month := int(st.get("month", 1))
	var acts: Dictionary = st.get("acts", {})
	var items: Array = st.get("items", [])
	var staff := int(st.get("staff", 0))
	var season := clampi(int((month - 1) / 3.0), 0, 3)
	var gy := h * 0.68

	# зимой трава под снегом
	if season == 3:
		draw_rect(Rect2(0, h * 0.64, w, h * 0.36), Color(0.95, 0.97, 1.0, 0.55))

	# цветы растут вместе с результатом
	if season != 3:
		var flowers := mini(int(kpi / 6.0) + int(acts.get("workshop", 0)), 26)
		for i in range(flowers):
			var fx := w * fposmod(0.07 + i * 0.113, 0.92)
			var fy := gy + h * (0.05 + float((i * 7) % 20) / 100.0 * 1.3)
			draw_circle(Vector2(fx, fy), 3.0, FLOWER_COLORS[i % 4])

	# столы мастер-классов
	var tables := mini(int(acts.get("workshop", 0)), 3)
	for i in range(tables):
		var tbx := w * (0.30 + i * 0.12)
		var tby := gy + h * 0.24
		draw_rect(Rect2(tbx, tby, 44, 7), Color(0.65, 0.48, 0.32))
		draw_rect(Rect2(tbx + 4.0, tby + 7.0, 3, 10), Color(0.4, 0.3, 0.2))
		draw_rect(Rect2(tbx + 37.0, tby + 7.0, 3, 10), Color(0.4, 0.3, 0.2))
		draw_circle(Vector2(tbx + 10.0, tby - 3.0), 4.0, BALLOONS[i % 5])
		draw_circle(Vector2(tbx + 24.0, tby - 3.0), 4.0, BALLOONS[(i + 2) % 5])

	# мольберт после лекции
	if int(acts.get("lecture", 0)) >= 1:
		var lx := w * 0.12
		var ly := gy + h * 0.10
		draw_rect(Rect2(lx, ly, 38, 28), Color(1, 1, 1))
		draw_line(Vector2(lx + 6.0, ly + 8.0), Vector2(lx + 30.0, ly + 8.0), Color(0.3, 0.6, 0.4), 2.0)
		draw_line(Vector2(lx + 6.0, ly + 16.0), Vector2(lx + 22.0, ly + 16.0), Color(0.3, 0.5, 0.8), 2.0)
		draw_line(Vector2(lx + 8.0, ly + 28.0), Vector2(lx + 4.0, ly + 42.0), Color(0.4, 0.3, 0.2), 3.0)
		draw_line(Vector2(lx + 30.0, ly + 28.0), Vector2(lx + 34.0, ly + 42.0), Color(0.4, 0.3, 0.2), 3.0)

	# проектор: экран во дворе
	if items.has("projector"):
		var px := w * 0.05
		var py := gy - h * 0.08
		draw_rect(Rect2(px, py, 54, 34), Color(0.95, 0.95, 0.95))
		draw_rect(Rect2(px + 4.0, py + 4.0, 46, 26), Color(0.45, 0.75, 0.55))
		draw_rect(Rect2(px + 25.0, py + 34.0, 4, 16), Color(0.5, 0.5, 0.5))

	# палатка
	if items.has("tent"):
		var tex := w * 0.90
		var tey := gy + h * 0.20
		draw_colored_polygon(PackedVector2Array([Vector2(tex - 30.0, tey), Vector2(tex, tey - 34.0), Vector2(tex + 30.0, tey)]), Color(0.93, 0.55, 0.15))
		draw_colored_polygon(PackedVector2Array([Vector2(tex - 8.0, tey), Vector2(tex, tey - 18.0), Vector2(tex + 8.0, tey)]), Color(0.35, 0.22, 0.12))

	# деревья: растут от результата и посадок
	var trees := mini(TREE_X.size(), int(kpi / 15.0) + int(acts.get("trees", 0)) * 3)
	for i in range(trees):
		var tx: float = w * TREE_X[i]
		var ty: float = gy + h * (0.09 + (i % 4) * 0.055)
		_tree(tx, ty, season, i, 0.8 + (ty / h - 0.7) * 1.4)

	# пруд с фонтаном на высоком уровне
	if level >= 3:
		var pc := Vector2(w * 0.40, gy + h * 0.28)
		_ellipse(pc, 42.0, 11.0, Color(0.35, 0.68, 0.90, 0.9))
		draw_line(pc, pc + Vector2(0, -22.0), Color(1, 1, 1, 0.9), 2.0)
		draw_line(pc + Vector2(0, -22.0), pc + Vector2(-10.0, -10.0), Color(1, 1, 1, 0.7), 2.0)
		draw_line(pc + Vector2(0, -22.0), pc + Vector2(10.0, -10.0), Color(1, 1, 1, 0.7), 2.0)

	# сцена фестиваля
	var fc := int(acts.get("festival", 0))
	if fc >= 1:
		var sx := w * 0.58
		var sy := gy + h * 0.14
		draw_rect(Rect2(sx, sy, 90, 26), Color(0.85, 0.35, 0.45))
		draw_rect(Rect2(sx - 4.0, sy + 26.0, 98, 9), Color(0.65, 0.45, 0.35))
		draw_circle(Vector2(sx + 45.0, sy + 13.0), 7.0, Color(1, 0.9, 0.4))

	# люди: помощники в жёлтых жилетах
	var people := mini(1 + level * 2 + (4 if fc > 0 else 0) + mini(int(acts.get("workshop", 0)), 2), 12)
	for i in range(people):
		var ppx := w * (0.52 + i * 0.045)
		var ppy := gy + h * 0.17 + (i % 3) * h * 0.05 + sin(t * 3.0 + i) * 2.0
		var shirt: Color = SHIRTS[i % 5]
		if i < staff:
			shirt = Color(0.98, 0.85, 0.15)
		draw_rect(Rect2(ppx - 5.0, ppy - 12.0, 10, 14), shirt)
		draw_circle(Vector2(ppx, ppy - 18.0), 6.0, Color(0.96, 0.80, 0.65))

	# праздничные гирлянды и шарики
	if fc >= 1:
		draw_line(Vector2(0, h * 0.06), Vector2(w, h * 0.06), Color(0.4, 0.3, 0.3), 2.0)
		var gxx := 0.0
		var gi := 0
		while gxx < w:
			var col: Color = BALLOONS[gi % 5]
			draw_colored_polygon(PackedVector2Array([Vector2(gxx, h * 0.06), Vector2(gxx + 16.0, h * 0.06), Vector2(gxx + 8.0, h * 0.06 + 16.0)]), col)
			gxx += 26.0
			gi += 1
		for i in range(6):
			var bx := w * (0.60 + i * 0.06)
			var by := gy - h * 0.05 - (i % 2) * 14.0 + sin(t * 1.5 + i) * 4.0
			draw_line(Vector2(bx, by), Vector2(bx, by + 30.0), Color(0.5, 0.5, 0.5), 1.0)
			draw_circle(Vector2(bx, by), 9.0, BALLOONS[i % 5])

	# усталость: картинка тускнеет
	if tired >= 55:
		draw_rect(Rect2(0, 0, w, h), Color(0.18, 0.2, 0.28, clampf((tired - 55) / 45.0, 0.0, 1.0) * 0.4))

	# сезонные детали: листопад и снег
	if season == 2:
		for i in range(14):
			draw_rect(Rect2(fposmod(i * 41.0 + sin(t + i) * 10.0, w), fposmod(i * 29.0 + t * 20.0, h * 0.9), 5, 3), Color(0.90, 0.55, 0.15))
	elif season == 3:
		for i in range(36):
			draw_circle(Vector2(fposmod(i * 37.0 + sin(t + i) * 8.0, w), fposmod(i * 53.0 + t * 25.0, h * 0.95)), 2.5, Color(1, 1, 1, 0.9))
