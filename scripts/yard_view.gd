extends Control
## Картинка проекта, нарисованная кодом. Она меняется от сезона, выбранного места,
## проведённых акций, купленного оборудования, команды и уровня организации.

var st: Dictionary = {}
var do_flash := false
var t := 0.0

const TREE_X: Array = [0.07, 0.20, 0.33, 0.62, 0.74, 0.86, 0.95, 0.14, 0.90, 0.27, 0.56, 0.45, 0.04, 0.80]
const LITTER_X: Array = [0.10, 0.28, 0.38, 0.52, 0.64, 0.76, 0.90, 0.45, 0.18]
const FLOWER_COLORS: Array = [Color(0.95, 0.45, 0.65), Color(1, 0.85, 0.3), Color(1, 1, 1), Color(0.7, 0.5, 0.9)]
const SHIRTS: Array = [Color(0.22, 0.48, 0.82), Color(0.93, 0.55, 0.15), Color(0.85, 0.30, 0.30), Color(0.55, 0.38, 0.78), Color(0.18, 0.62, 0.40)]
const BALLOONS: Array = [Color(0.9, 0.3, 0.3), Color(0.95, 0.75, 0.2), Color(0.3, 0.6, 0.9), Color(0.6, 0.4, 0.8), Color(0.3, 0.75, 0.5)]
const SKIES: Array = [Color(0.62, 0.83, 0.97), Color(0.45, 0.78, 1.0), Color(0.78, 0.82, 0.88), Color(0.82, 0.88, 0.94)]
const CROWNS: Array = [Color(0.30, 0.66, 0.32), Color(0.18, 0.54, 0.26), Color(0.88, 0.52, 0.14), Color(0.90, 0.94, 0.98)]


func _init() -> void:
	custom_minimum_size = Vector2(0, 230)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true


func set_state(state: Dictionary, flash := false) -> void:
	st = state
	do_flash = flash
	queue_redraw()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _ready() -> void:
	if do_flash:
		self_modulate = Color(1.6, 1.6, 1.6)
		var tw := create_tween()
		tw.tween_property(self, "self_modulate", Color.WHITE, 0.9)


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(24):
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _tree(x: float, y: float, season: int, i: int) -> void:
	draw_rect(Rect2(x - 3, y - 18, 6, 18), Color(0.45, 0.30, 0.18))
	if season == 3:
		draw_circle(Vector2(x, y - 26), 11.0, CROWNS[3])
		return
	var col: Color = CROWNS[season]
	if i % 2 == 1:
		col = col.darkened(0.08)
	draw_circle(Vector2(x, y - 26), 15.0, col)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 20.0:
		return
	var kpi := int(st.get("kpi", 0))
	var level := int(st.get("level", 1))
	var tired := int(st.get("tired", 0))
	var month := int(st.get("month", 1))
	var scn := str(st.get("scenario", "yard"))
	var spec := str(st.get("spec", ""))
	var acts: Dictionary = st.get("acts", {})
	var items: Array = st.get("items", [])
	var staff := int(st.get("staff", 0))
	var season := clampi(int((month - 1) / 3.0), 0, 3)

	# небо
	var tt := clampf((tired - 50) / 50.0, 0.0, 1.0)
	var sky: Color = SKIES[season]
	sky = sky.lerp(Color(0.55, 0.58, 0.64), tt)
	draw_rect(Rect2(0, 0, w, h), sky)
	if season != 3:
		draw_circle(Vector2(w * 0.86, h * 0.20), 22.0 + sin(t * 2.0) * 1.5, Color(1.0, 0.86, 0.35))
	var cl := fmod(w * 0.18 + t * 8.0, w + 90.0) - 45.0
	draw_circle(Vector2(cl, h * 0.20), 14.0, Color(1, 1, 1, 0.9))
	draw_circle(Vector2(cl + 16.0, h * 0.23), 18.0, Color(1, 1, 1, 0.9))
	draw_circle(Vector2(cl + 34.0, h * 0.20), 13.0, Color(1, 1, 1, 0.9))
	var cl2 := fmod(w * 0.62 + t * 5.0, w + 90.0) - 45.0
	draw_circle(Vector2(cl2, h * 0.12), 11.0, Color(1, 1, 1, 0.8))
	draw_circle(Vector2(cl2 + 14.0, h * 0.14), 15.0, Color(1, 1, 1, 0.8))

	var gy := h * 0.64

	# холмы вдали (берег реки и школа)
	if scn != "yard":
		var hill := Color(0.50, 0.70, 0.48)
		if season == 2:
			hill = Color(0.75, 0.62, 0.35)
		elif season == 3:
			hill = Color(0.90, 0.93, 0.97)
		draw_colored_polygon(PackedVector2Array([Vector2(0, gy), Vector2(w * 0.22, gy - 46.0), Vector2(w * 0.5, gy)]), hill)
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.4, gy), Vector2(w * 0.72, gy - 34.0), Vector2(w, gy)]), hill.darkened(0.08))

	# земля
	var grass := Color(0.58, 0.58, 0.38).lerp(Color(0.25, 0.72, 0.35), clampf(kpi / 100.0, 0.0, 1.0))
	if season == 2:
		grass = grass.lerp(Color(0.72, 0.58, 0.28), 0.45)
	elif season == 3:
		grass = grass.lerp(Color(0.93, 0.96, 1.0), 0.85)
	draw_rect(Rect2(0, gy, w, h - gy), grass)

	# фон по месту
	if scn == "yard":
		var x := 0.0
		while x < w:
			draw_rect(Rect2(x, gy - 14.0, 8.0, 18.0), Color(0.82, 0.66, 0.45))
			x += 18.0
		draw_rect(Rect2(0, gy - 8.0, w, 4.0), Color(0.72, 0.56, 0.38))
	elif scn == "river":
		var ry := h - 34.0
		var water := Color(0.35, 0.65, 0.88) if season != 3 else Color(0.75, 0.88, 0.95)
		draw_rect(Rect2(0, ry, w, 34.0), water)
		for i in range(6):
			var wx := w * (0.08 + i * 0.17)
			draw_line(Vector2(wx, ry + 12.0), Vector2(wx + 24.0, ry + 12.0), Color(1, 1, 1, 0.6), 2.0)
		draw_rect(Rect2(w * 0.68, ry - 6.0, 80.0, 8.0), Color(0.60, 0.42, 0.28))
	else:
		draw_rect(Rect2(0, gy - 6.0, w, 10.0), Color(0.22, 0.52, 0.28).lerp(Color(0.9, 0.95, 1.0), 0.8 if season == 3 else 0.0))

	# здание
	var cx := w * 0.5
	var win := Color(0.99, 0.90, 0.50) if items.has("laptop") else Color(0.70, 0.88, 0.96)
	if scn == "school":
		draw_rect(Rect2(cx - 85.0, gy - 62.0, 170.0, 62.0), Color(0.93, 0.74, 0.54))
		draw_rect(Rect2(cx - 90.0, gy - 70.0, 180.0, 10.0), Color(0.55, 0.30, 0.25))
		for i in range(4):
			draw_rect(Rect2(cx - 72.0 + i * 38.0, gy - 48.0, 22.0, 20.0), win)
		draw_rect(Rect2(cx - 11.0, gy - 34.0, 22.0, 34.0), Color(0.55, 0.38, 0.25))
		draw_rect(Rect2(cx + 60.0, gy - 104.0, 3.0, 36.0), Color(0.4, 0.4, 0.4))
		draw_colored_polygon(PackedVector2Array([Vector2(cx + 63.0, gy - 104.0), Vector2(cx + 90.0, gy - 96.0), Vector2(cx + 63.0, gy - 88.0)]), Color(0.85, 0.30, 0.30))
	else:
		var hx := cx - 55.0
		var hy := gy - 66.0
		draw_rect(Rect2(hx, hy, 110, 66), Color(0.96, 0.88, 0.72))
		draw_colored_polygon(PackedVector2Array([Vector2(hx - 8, hy), Vector2(hx + 55, hy - 34), Vector2(hx + 118, hy)]), Color(0.78, 0.36, 0.30))
		draw_rect(Rect2(hx + 44, hy + 28, 22, 38), Color(0.55, 0.38, 0.25))
		draw_rect(Rect2(hx + 10, hy + 14, 22, 20), win)
		draw_rect(Rect2(hx + 78, hy + 14, 22, 20), win)
		if level >= 3:
			draw_rect(Rect2(hx + 130.0, gy - 92.0, 3, 92), Color(0.4, 0.4, 0.4))
			draw_colored_polygon(PackedVector2Array([Vector2(hx + 133.0, gy - 92.0), Vector2(hx + 165.0, gy - 82.0), Vector2(hx + 133.0, gy - 72.0)]), Color(0.18, 0.62, 0.40))

	# мусор: убирается субботниками
	var litter := maxi(0, 9 - int(acts.get("cleanup", 0)) * 3 - int(kpi / 15.0))
	for i in range(litter):
		var lx: float = w * LITTER_X[i]
		var ly: float = gy + 24.0 + (i % 3) * 14.0
		draw_rect(Rect2(lx, ly, 9, 6), Color(0.45, 0.42, 0.40))

	# грядки школьного сада
	if scn == "school":
		for i in range(3):
			var bx := w * (0.12 + i * 0.10)
			draw_rect(Rect2(bx, gy + 14.0, 46, 12), Color(0.50, 0.34, 0.22))
			if kpi >= 10:
				for j in range(4):
					draw_circle(Vector2(bx + 8.0 + j * 10.0, gy + 18.0), 4.0, Color(0.25, 0.70, 0.30))

	# цветы
	if season != 3:
		var flowers := mini(int(kpi / 6.0) + int(acts.get("workshop", 0)), 24)
		for i in range(flowers):
			var fx := fmod(24.0 + i * 47.0, maxf(w - 30.0, 10.0))
			var fy := gy + 30.0 + float((i * 13) % 28)
			draw_circle(Vector2(fx, fy), 4.0, FLOWER_COLORS[i % 4])

	# деревья: растут от результата и посадок
	var trees := mini(TREE_X.size(), int(kpi / 20.0) + int(acts.get("trees", 0)) * 3)
	for i in range(trees):
		var tx: float = w * TREE_X[i]
		var ty: float = gy + 8.0 + (i % 3) * 8.0
		_tree(tx, ty, season, i)

	# теплица или уличный класс (после выбора профиля)
	if level >= 2 and spec == "green":
		var gx := w * 0.20
		draw_rect(Rect2(gx, gy - 34.0, 70, 34), Color(0.78, 0.93, 0.96))
		draw_colored_polygon(PackedVector2Array([Vector2(gx, gy - 34.0), Vector2(gx + 35.0, gy - 54.0), Vector2(gx + 70.0, gy - 34.0)]), Color(0.70, 0.88, 0.92))
		draw_line(Vector2(gx + 35.0, gy - 54.0), Vector2(gx + 35.0, gy), Color(0.5, 0.6, 0.62), 2.0)
		for j in range(4):
			draw_circle(Vector2(gx + 10.0 + j * 16.0, gy - 8.0), 6.0, Color(0.25, 0.70, 0.30))
	elif level >= 2 and spec == "edu":
		var ex := w * 0.20
		draw_rect(Rect2(ex, gy - 36.0, 64, 34), Color(0.20, 0.42, 0.32))
		draw_line(Vector2(ex + 8.0, gy - 26.0), Vector2(ex + 40.0, gy - 26.0), Color(1, 1, 1), 2.0)
		draw_line(Vector2(ex + 8.0, gy - 16.0), Vector2(ex + 52.0, gy - 16.0), Color(1, 1, 1), 2.0)
		draw_rect(Rect2(ex + 6.0, gy - 2.0, 4, 14), Color(0.4, 0.3, 0.2))
		draw_rect(Rect2(ex + 54.0, gy - 2.0, 4, 14), Color(0.4, 0.3, 0.2))
		for j in range(3):
			draw_rect(Rect2(ex + j * 24.0, gy + 16.0, 20, 5), Color(0.62, 0.45, 0.30))

	# столы мастер-классов
	var tables := mini(int(acts.get("workshop", 0)), 3)
	for i in range(tables):
		var tbx := w * (0.40 + i * 0.12)
		draw_rect(Rect2(tbx, gy + 32.0, 44, 7), Color(0.65, 0.48, 0.32))
		draw_rect(Rect2(tbx + 4.0, gy + 39.0, 3, 10), Color(0.4, 0.3, 0.2))
		draw_rect(Rect2(tbx + 37.0, gy + 39.0, 3, 10), Color(0.4, 0.3, 0.2))
		draw_circle(Vector2(tbx + 10.0, gy + 29.0), 4.0, BALLOONS[i % 5])
		draw_circle(Vector2(tbx + 24.0, gy + 29.0), 4.0, BALLOONS[(i + 2) % 5])

	# мольберт после лекции
	if int(acts.get("lecture", 0)) >= 1:
		var lx2 := w * 0.76
		draw_rect(Rect2(lx2, gy + 4.0, 38, 28), Color(1, 1, 1))
		draw_line(Vector2(lx2 + 6.0, gy + 12.0), Vector2(lx2 + 30.0, gy + 12.0), Color(0.3, 0.6, 0.4), 2.0)
		draw_line(Vector2(lx2 + 6.0, gy + 20.0), Vector2(lx2 + 22.0, gy + 20.0), Color(0.3, 0.5, 0.8), 2.0)
		draw_line(Vector2(lx2 + 8.0, gy + 32.0), Vector2(lx2 + 4.0, gy + 46.0), Color(0.4, 0.3, 0.2), 3.0)
		draw_line(Vector2(lx2 + 30.0, gy + 32.0), Vector2(lx2 + 34.0, gy + 46.0), Color(0.4, 0.3, 0.2), 3.0)

	# проектор: экран на улице
	if items.has("projector"):
		var px0 := w * 0.04
		draw_rect(Rect2(px0, gy - 30.0, 56, 36), Color(0.95, 0.95, 0.95))
		draw_rect(Rect2(px0 + 4.0, gy - 26.0, 48, 28), Color(0.45, 0.75, 0.55))
		draw_rect(Rect2(px0 + 26.0, gy + 6.0, 4, 18), Color(0.5, 0.5, 0.5))

	# палатка
	if items.has("tent"):
		var tex := w * 0.90
		var tey := gy + 40.0
		draw_colored_polygon(PackedVector2Array([Vector2(tex - 30.0, tey), Vector2(tex, tey - 34.0), Vector2(tex + 30.0, tey)]), Color(0.93, 0.55, 0.15))
		draw_colored_polygon(PackedVector2Array([Vector2(tex - 8.0, tey), Vector2(tex, tey - 18.0), Vector2(tex + 8.0, tey)]), Color(0.35, 0.22, 0.12))

	# пруд с фонтаном (уровень 3)
	if level >= 3:
		var pc := Vector2(w * 0.30, gy + 56.0)
		_ellipse(pc, 42.0, 12.0, Color(0.35, 0.68, 0.90))
		draw_line(pc, pc + Vector2(0, -22.0), Color(1, 1, 1, 0.9), 2.0)
		draw_line(pc + Vector2(0, -22.0), pc + Vector2(-10.0, -10.0), Color(1, 1, 1, 0.7), 2.0)
		draw_line(pc + Vector2(0, -22.0), pc + Vector2(10.0, -10.0), Color(1, 1, 1, 0.7), 2.0)

	# сцена фестиваля
	var fc := int(acts.get("festival", 0))
	if fc >= 1:
		var sx := w * 0.58
		draw_rect(Rect2(sx, gy + 6.0, 96, 30), Color(0.85, 0.35, 0.45))
		draw_rect(Rect2(sx - 4.0, gy + 36.0, 104, 10), Color(0.65, 0.45, 0.35))
		draw_circle(Vector2(sx + 48.0, gy + 20.0), 8.0, Color(1, 0.9, 0.4))

	# люди: больше людей - больше жизни. Помощники в жёлтых жилетах
	var people := mini(1 + level * 2 + (4 if fc > 0 else 0) + mini(int(acts.get("workshop", 0)), 2), 12)
	for i in range(people):
		var ppx := w * (0.08 + i * 0.075)
		var ppy := gy + (26.0 if scn == "river" else 40.0) + (i % 3) * 9.0 + sin(t * 3.0 + i) * 2.0
		var shirt: Color = SHIRTS[i % 5]
		if i < staff:
			shirt = Color(0.98, 0.85, 0.15)
		draw_rect(Rect2(ppx - 5.0, ppy - 12.0, 10, 14), shirt)
		draw_circle(Vector2(ppx, ppy - 18.0), 6.0, Color(0.96, 0.80, 0.65))

	# праздничные гирлянды и шарики
	if fc >= 1:
		draw_line(Vector2(0, 12), Vector2(w, 12), Color(0.4, 0.3, 0.3), 2.0)
		var gxx := 0.0
		var gi := 0
		while gxx < w:
			var col: Color = BALLOONS[gi % 5]
			draw_colored_polygon(PackedVector2Array([Vector2(gxx, 12), Vector2(gxx + 16.0, 12), Vector2(gxx + 8.0, 28)]), col)
			gxx += 26.0
			gi += 1
		for i in range(6):
			var bx2 := w * (0.56 + i * 0.07)
			var by2 := gy - 20.0 - (i % 2) * 16.0 + sin(t * 1.5 + i) * 4.0
			draw_line(Vector2(bx2, by2), Vector2(bx2, by2 + 34.0), Color(0.5, 0.5, 0.5), 1.0)
			draw_circle(Vector2(bx2, by2), 9.0, BALLOONS[i % 5])

	# сезонные детали: листопад и снег
	if season == 2:
		for i in range(14):
			draw_rect(Rect2(fmod(i * 41.0 + sin(t + i) * 10.0, w), fmod(i * 29.0 + t * 20.0, h * 0.8), 5, 3), Color(0.90, 0.55, 0.15))
	elif season == 3:
		for i in range(36):
			draw_circle(Vector2(fmod(i * 37.0 + sin(t + i) * 8.0, w), fmod(i * 53.0 + t * 25.0, h * 0.9)), 2.5, Color(1, 1, 1, 0.9))
