extends Control
## Общие элементы интерфейса: тема, помощники, анимации, HUD, нижнее меню,
## экраны профиля, наград и рейтинга. Игровая логика экранов лежит в main.gd.

const Data = preload("res://data/game_data.gd")
const YardView = preload("res://scripts/yard_view.gd")
const IconView = preload("res://scripts/icon_view.gd")
const YARD_TEX = preload("res://assets/yard.png")
const PORT_VERA = preload("res://assets/portrait_vera.png")
const PORT_IGOR = preload("res://assets/portrait_igor.png")
const PORT_MISHA = preload("res://assets/portrait_misha.png")
const NAV_GAME = preload("res://assets/nav_game.png")
const NAV_PROFILE = preload("res://assets/nav_profile.png")
const NAV_AWARDS = preload("res://assets/nav_awards.png")
const NAV_RANK = preload("res://assets/nav_rank.png")
const CHECK_ON = preload("res://assets/check_on.png")
const CHECK_OFF = preload("res://assets/check_off.png")

# Палитра
const C_PANEL := Color(1, 1, 1)
const C_GREEN := Color(0.18, 0.62, 0.40)
const C_BLUE := Color(0.22, 0.48, 0.82)
const C_PURPLE := Color(0.55, 0.38, 0.78)
const C_ORANGE := Color(0.93, 0.55, 0.15)
const C_RED := Color(0.85, 0.30, 0.30)
const C_PINK := Color(0.82, 0.38, 0.60)
const C_YELLOW := Color(0.95, 0.75, 0.20)
const C_TEAL := Color(0.12, 0.62, 0.65)
const C_DARK := Color(0.18, 0.20, 0.24)
const C_MUTED := Color(0.42, 0.48, 0.52)
const C_GRAY := Color(0.65, 0.67, 0.68)
const C_CREAM := Color(1, 0.97, 0.85)

# Фоны экранов
const BG_INTRO := Color(0.90, 0.91, 0.93)
const BG_BUDGET := Color(0.90, 0.91, 0.94)
const BG_MONTH := Color(0.92, 0.92, 0.93)
const BG_EVENT := Color(0.94, 0.92, 0.91)
const BG_REPORT := Color(0.92, 0.91, 0.94)
const BG_GOOD := Color(0.89, 0.94, 0.90)
const BG_BAD := Color(0.95, 0.90, 0.89)
const BG_END := Color(0.94, 0.93, 0.88)

var bg: ColorRect
var content: VBoxContainer
var scroll: ScrollContainer
var hud: PanelContainer
var nav: HBoxContainer
var fx: Control
var hud_month: Label
var hud_cash: Label
var hud_flow: Label
var bars: Dictionary = {}
var bar_labels: Dictionary = {}
var bar_titles: Dictionary = {}
var prev_stats: Dictionary = {}
var shown_cash := 0
var toast_slot := 0
var go_game: Callable = Callable()

var characters: Dictionary = {
	"vera": {"name": "Вера", "role": "бухгалтер", "color": C_BLUE},
	"igor": {"name": "Игорь", "role": "куратор фонда", "color": C_PURPLE},
	"misha": {"name": "Миша", "role": "волонтёр", "color": C_ORANGE},
}
var line_colors: Dictionary = {
	"salary": C_BLUE, "activities": C_GREEN, "equipment": C_PURPLE, "rent": C_ORANGE, "admin": C_PINK,
}
var option_colors: Dictionary = {
	"Мероприятия": C_GREEN, "Оплата труда и налоги": C_BLUE, "Оборудование": C_PURPLE,
	"Аренда и связь": C_ORANGE, "Не принимать к отчёту": C_RED,
}
var comp_colors: Dictionary = {"plan": C_BLUE, "acc": C_PINK, "docs": C_TEAL, "contr": C_PURPLE, "appr": C_ORANGE}
var color_names: Dictionary = {
	"green": C_GREEN, "blue": C_BLUE, "purple": C_PURPLE, "orange": C_ORANGE,
	"pink": C_PINK, "teal": C_TEAL, "yellow": C_YELLOW, "red": C_RED,
}
var donor_titles: Dictionary = {"strict": "Строгий", "normal": "Обычный", "kind": "Лояльный"}
var choice_colors: Array = [C_BLUE, C_TEAL, C_PURPLE, C_PINK]


# ---------------------------------------------------------------- построение интерфейса

func _build_ui() -> void:
	theme = _make_theme()
	bg = ColorRect.new()
	bg.color = BG_INTRO
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	_build_hud(root)

	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var inner := MarginContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("margin_left", 8)
	inner.add_theme_constant_override("margin_right", 8)
	inner.add_theme_constant_override("margin_top", 6)
	inner.add_theme_constant_override("margin_bottom", 22)
	scroll.add_child(inner)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	inner.add_child(content)

	_build_nav(root)

	fx = Control.new()
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx)


# ---------------------------------------------------------------- тема и виджеты

func _box(col: Color, radius := 12, pad := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb


func _card_box(tint: Color, accent: Color) -> StyleBoxFlat:
	var sb := _box(tint, 22, 14)
	sb.border_width_left = 6
	sb.border_color = accent
	sb.shadow_color = Color(0, 0, 0, 0.14)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 5)
	return sb


func _button_box(col: Color, pressed := false) -> StyleBoxFlat:
	var sb := _box(col, 24, 12)
	sb.border_width_bottom = 0 if pressed else 5
	sb.border_color = col.darkened(0.32)
	sb.shadow_color = Color(0, 0, 0, 0.10 if pressed else 0.22)
	sb.shadow_size = 3 if pressed else 9
	sb.shadow_offset = Vector2(0, 2 if pressed else 6)
	return sb


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 21
	t.set_stylebox("normal", "Button", _button_box(C_GREEN))
	t.set_stylebox("hover", "Button", _button_box(C_GREEN.lightened(0.1)))
	t.set_stylebox("pressed", "Button", _button_box(C_GREEN.darkened(0.15), true))
	t.set_stylebox("disabled", "Button", _button_box(C_GRAY))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for n in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
		t.set_color(n, "Button", Color.WHITE)
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = 0.35
	t.set_font("font", "Button", fv)
	t.set_color("font_shadow_color", "Button", Color(0, 0, 0, 0.35))
	t.set_constant("shadow_offset_x", "Button", 0)
	t.set_constant("shadow_offset_y", "Button", 2)
	t.set_color("font_color", "Label", C_DARK)
	var pb := _box(C_PANEL, 22, 14)
	pb.shadow_color = Color(0, 0, 0, 0.14)
	pb.shadow_size = 10
	pb.shadow_offset = Vector2(0, 5)
	t.set_stylebox("panel", "PanelContainer", pb)
	t.set_stylebox("background", "ProgressBar", _box(Color(0.82, 0.84, 0.86), 7, 0))
	t.set_stylebox("fill", "ProgressBar", _box(C_GREEN, 7, 0))
	return t


var _gloss_cache: GradientTexture2D = null


## Мягкий блик сверху: делает кнопки и плашки глянцевыми
func _gloss_texture() -> GradientTexture2D:
	if _gloss_cache == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0.30))
		g.set_color(1, Color(1, 1, 1, 0.03))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill_from = Vector2(0.5, 0.0)
		tex.fill_to = Vector2(0.5, 1.0)
		tex.width = 4
		tex.height = 64
		_gloss_cache = tex
	return _gloss_cache


func _gloss_rect() -> TextureRect:
	var gl := TextureRect.new()
	gl.texture = _gloss_texture()
	gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gl.stretch_mode = TextureRect.STRETCH_SCALE
	return gl


func _label(text: String, size := 20, color := C_DARK) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _plain(text: String, size := 20, color := C_DARK) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _icon(kind: String, col: Color, px := 26) -> Control:
	var ic = IconView.new()
	ic.setup(kind, col, px)
	return ic


func _button(text: String, cb: Callable, color := C_GREEN) -> Button:
	var b := Button.new()
	b.text = text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, 62)
	b.pressed.connect(cb)
	b.add_theme_stylebox_override("normal", _button_box(color))
	b.add_theme_stylebox_override("hover", _button_box(color.lightened(0.1)))
	b.add_theme_stylebox_override("pressed", _button_box(color.darkened(0.15), true))
	b.resized.connect(_btn_pivot.bind(b))
	b.button_down.connect(_btn_scale.bind(b, 0.95))
	b.button_up.connect(_btn_scale.bind(b, 1.0))
	b.mouse_entered.connect(_btn_scale.bind(b, 1.03))
	b.mouse_exited.connect(_btn_scale.bind(b, 1.0))
	var gl := _gloss_rect()
	gl.anchor_right = 1.0
	gl.anchor_bottom = 0.5
	gl.offset_left = 12.0
	gl.offset_right = -12.0
	gl.offset_top = 7.0
	gl.offset_bottom = 0.0
	b.add_child(gl)
	return b


func _btn_pivot(b: Button) -> void:
	b.pivot_offset = b.size / 2.0


func _btn_scale(b: Button, s: float) -> void:
	if not is_instance_valid(b) or b.disabled or not b.is_inside_tree():
		return
	if b.has_meta("tw"):
		var old: Tween = b.get_meta("tw")
		if old.is_valid():
			old.kill()
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(s, s), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	b.set_meta("tw", tw)


func _card(parent: Control, accent := C_GREEN, tint := C_PANEL) -> VBoxContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", _card_box(tint, accent))
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	return v


func _banner(text: String, color: Color, icon := "") -> void:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := _box(color, 28, 14)
	sb.border_width_bottom = 5
	sb.border_color = color.darkened(0.32)
	sb.shadow_color = Color(0, 0, 0, 0.28)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 7)
	p.add_theme_stylebox_override("panel", sb)
	content.add_child(p)
	p.add_child(_gloss_rect())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	p.add_child(row)
	if icon != "":
		row.add_child(_icon(icon, color.darkened(0.3), 50))
	var l := _label(text, 30, Color.WHITE)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	l.add_theme_constant_override("shadow_offset_y", 2)
	row.add_child(l)


func _portrait(who: String) -> Texture2D:
	match who:
		"igor":
			return PORT_IGOR
		"misha":
			return PORT_MISHA
	return PORT_VERA


func _nav_icon(which: String) -> Texture2D:
	match which:
		"profile":
			return NAV_PROFILE
		"ach":
			return NAV_AWARDS
		"rank":
			return NAV_RANK
	return NAV_GAME


func _make_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	var fill := _box(color, 8, 0)
	fill.border_width_bottom = 2
	fill.border_color = color.darkened(0.3)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _screen(bg_color: Color) -> void:
	var tw := create_tween()
	tw.tween_property(bg, "color", bg_color, 0.35)
	nav.hide()
	_clear()
	_fade_in.call_deferred()


func _set_nav(on: bool) -> void:
	nav.visible = on


func _clear() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	scroll.scroll_vertical = 0


func _fade_in() -> void:
	var i := 0
	for c in content.get_children():
		if not c is Control:
			continue
		var ctl: Control = c
		ctl.modulate.a = 0.0
		var tw := ctl.create_tween()
		tw.tween_property(ctl, "modulate:a", 1.0, 0.3).set_delay(minf(i * 0.05, 0.45))
		i += 1


func _season_tint(month: int) -> Color:
	var season := clampi(int((month - 1) / 3.0), 0, 3)
	match season:
		1:
			return Color(1.05, 1.03, 0.95)
		2:
			return Color(1.0, 0.86, 0.72)
		3:
			return Color(0.82, 0.90, 1.0)
	return Color(1, 1, 1)


func _add_yard() -> void:
	var sig := GameState.scene_sig()
	var flash := sig != GameState.last_sig and GameState.last_sig != ""
	GameState.last_sig = sig
	var frame := PanelContainer.new()
	var fb := _box(Color.WHITE, 20, 5)
	fb.shadow_color = Color(0, 0, 0, 0.25)
	fb.shadow_size = 12
	fb.shadow_offset = Vector2(0, 7)
	frame.add_theme_stylebox_override("panel", fb)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(frame)
	var ar := AspectRatioContainer.new()
	ar.ratio = 1024.0 / 523.0
	ar.custom_minimum_size = Vector2(0, 250)
	frame.add_child(ar)
	var stack := Control.new()
	ar.add_child(stack)
	var state: Dictionary = GameState.scene_state()
	var img := TextureRect.new()
	img.texture = YARD_TEX
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_SCALE
	img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	img.self_modulate = _season_tint(int(state["month"]))
	stack.add_child(img)
	var y = YardView.new()
	y.set_state(state, flash)
	y.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(y)


func _say(who: String, text: String) -> void:
	var ch: Dictionary = characters[who]
	var col: Color = ch["color"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)
	var av := PanelContainer.new()
	av.custom_minimum_size = Vector2(78, 78)
	av.pivot_offset = Vector2(39, 39)
	av.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var pb := StyleBoxEmpty.new()
	av.add_theme_stylebox_override("panel", pb)
	row.add_child(av)
	var pic := TextureRect.new()
	pic.texture = _portrait(who)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(78, 78)
	av.add_child(pic)
	var tw := av.create_tween().set_loops()
	tw.tween_property(av, "rotation", 0.09, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(av, "rotation", -0.09, 0.9).set_trans(Tween.TRANS_SINE)
	var bubble := PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.add_theme_stylebox_override("panel", _card_box(C_PANEL, col))
	row.add_child(bubble)
	var v := VBoxContainer.new()
	bubble.add_child(v)
	v.add_child(_plain("%s, %s" % [ch["name"], ch["role"]], 15, col))
	v.add_child(_label(text, 20))


func _pips(parent: Control, filled: int, total: int, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	for i in range(total):
		var p := Panel.new()
		p.custom_minimum_size = Vector2(22, 22)
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		p.add_theme_stylebox_override("panel", _box(color if i < filled else Color(0.82, 0.84, 0.85), 11, 0))
		row.add_child(p)


func _chips(parent: Control, ch: Dictionary) -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 6)
	parent.add_child(flow)
	var pairs := [["money", "Деньги"], ["trust", "Доверие"], ["docs", "Документы"], ["burnout", "Выгорание"], ["kpi", "Результат"]]
	for p in pairs:
		var key: String = p[0]
		var v: int = int(ch.get(key, 0))
		if v == 0:
			continue
		var txt := ""
		var col := C_GREEN
		if key == "money":
			txt = "%s %s" % [p[1], ("+" if v > 0 else "") + GameState.fmt(v)]
			col = C_GREEN if v > 0 else C_ORANGE
		else:
			txt = "%s %+d" % [p[1], v]
			var good: bool = (v > 0) != (key == "burnout")
			col = C_GREEN if good else C_RED
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", _box(col, 12, 6))
		pill.add_child(_plain(txt, 16, Color.WHITE))
		flow.add_child(pill)


# ---------------------------------------------------------------- анимации

func _float_text(txt: String, col: Color, at: Vector2) -> void:
	var l := _plain(txt, 22, col)
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 6)
	l.position = at
	fx.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", at.y - 70.0, 1.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)


func _confetti(n := 60) -> void:
	var pal: Array = [C_GREEN, C_ORANGE, C_BLUE, C_PINK, C_YELLOW, C_PURPLE]
	for i in range(n):
		var r := ColorRect.new()
		r.color = pal.pick_random()
		r.size = Vector2(8, 12)
		r.position = Vector2(randf() * size.x, -20.0)
		r.rotation = randf() * TAU
		fx.add_child(r)
		var d := 1.6 + randf() * 1.4
		var tw := r.create_tween().set_parallel(true)
		tw.tween_property(r, "position:y", size.y + 30.0, d).set_delay(randf() * 0.5)
		tw.tween_property(r, "position:x", r.position.x + randf_range(-80.0, 80.0), d)
		tw.tween_property(r, "rotation", r.rotation + randf_range(-6.0, 6.0), d)
		tw.chain().tween_callback(r.queue_free)


func _flash(col: Color) -> void:
	var r := ColorRect.new()
	r.color = Color(col.r, col.g, col.b, 0.30)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.add_child(r)
	var tw := r.create_tween()
	tw.tween_property(r, "modulate:a", 0.0, 0.5)
	tw.tween_callback(r.queue_free)


func _toast(title: String, text: String, col: Color) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(col, 16, 12))
	p.custom_minimum_size = Vector2(size.x - 40.0, 0)
	p.position = Vector2(20, -140)
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(_plain(title, 20, Color.WHITE))
	v.add_child(_label(text, 15, Color.WHITE))
	fx.add_child(p)
	var y := 16.0 + toast_slot * 84.0
	toast_slot += 1
	var tw := p.create_tween()
	tw.tween_property(p, "position:y", y, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_toast_done)
	tw.tween_callback(p.queue_free)


func _toast_done() -> void:
	toast_slot = maxi(toast_slot - 1, 0)


func _check_toasts() -> void:
	if GameState.new_unlocks.is_empty():
		return
	for id in GameState.new_unlocks:
		for a in Data.ACHIEVEMENTS:
			if a["id"] == id:
				var col: Color = color_names[str(a["color"])]
				_toast("Награда: " + str(a["name"]), str(a["desc"]), col)
	GameState.new_unlocks = []


# ---------------------------------------------------------------- HUD и нижнее меню

func _build_hud(parent: Control) -> void:
	hud = PanelContainer.new()
	parent.add_child(hud)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	hud.add_child(v)

	var top := HBoxContainer.new()
	v.add_child(top)
	hud_month = _plain("", 20, C_BLUE)
	hud_month.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(hud_month)
	hud_cash = _plain("", 20, C_GREEN)
	hud_cash.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(hud_cash)
	hud_flow = _plain("", 15, C_MUTED)
	v.add_child(hud_flow)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)

	var defs := [
		["trust", "Доверие", C_GREEN, "heart"],
		["docs", "Документы", C_BLUE, "doc"],
		["burnout", "Выгорание", C_RED, "fire"],
		["kpi", "Результат", C_ORANGE, "leaf"],
	]
	for d in defs:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cell)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		cell.add_child(row)
		row.add_child(_icon(str(d[3]), d[2], 20))
		var l := _plain("", 15, d[2].darkened(0.25))
		row.add_child(l)
		var bar := _make_bar(d[2])
		bar.max_value = 100
		cell.add_child(bar)
		bars[d[0]] = bar
		bar_labels[d[0]] = l
		bar_titles[d[0]] = d[1]
	hud.hide()


func _build_nav(parent: Control) -> void:
	nav = HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	parent.add_child(nav)
	var defs := [["Игра", C_GREEN, "go"], ["Профиль", C_PURPLE, "profile"], ["Награды", C_ORANGE, "ach"], ["Рейтинг", C_BLUE, "rank"]]
	for d in defs:
		var b := _button(str(d[0]), _nav_press.bind(d[2]), d[1])
		b.custom_minimum_size = Vector2(0, 76)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 15)
		b.icon = _nav_icon(str(d[2]))
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 28)
		b.add_theme_constant_override("h_separation", 0)
		nav.add_child(b)
	nav.hide()


func _nav_press(which: String) -> void:
	match which:
		"go":
			go_game.call()
		"profile":
			show_profile()
		"ach":
			show_achievements()
		"rank":
			show_leaderboard()


func _set_cash_text(v: float) -> void:
	hud_cash.text = "Счёт: " + GameState.fmt(int(v))


func update_hud() -> void:
	hud_month.text = "Месяц %d из %d" % [GameState.month, GameState.max_month]
	var first := prev_stats.is_empty()
	if first:
		shown_cash = GameState.cash
		_set_cash_text(float(shown_cash))
	elif shown_cash != GameState.cash:
		var old_cash := shown_cash
		shown_cash = GameState.cash
		var tw := create_tween()
		tw.tween_method(_set_cash_text, float(old_cash), float(shown_cash), 0.5)
		if absi(shown_cash - old_cash) >= 500:
			var col := C_GREEN if shown_cash > old_cash else C_ORANGE
			_float_text(GameState.fmt(shown_cash - old_cash), col, Vector2(size.x - 230.0, 70.0))
	hud_cash.add_theme_color_override("font_color", C_RED if GameState.cash < 0 else C_GREEN)
	var mf: Dictionary = GameState.money_flow()
	if GameState.budget.is_empty():
		hud_flow.text = ""
	else:
		var net: int = int(mf["net"])
		var txt := "В месяц: %s%s" % [("+" if net > 0 else ""), GameState.fmt(net)]
		if int(mf["tranche"]) > 0:
			txt += "  |  транш +%s через %d мес." % [GameState.fmt(int(mf["tranche"])).replace(" руб.", ""), int(mf["left"])]
		if int(mf["incoming"]) > 0:
			txt += "  |  в пути +%s" % GameState.fmt(int(mf["incoming"])).replace(" руб.", "")
		hud_flow.text = txt
		hud_flow.add_theme_color_override("font_color", C_ORANGE if net < 0 else C_GREEN)

	var fc: Dictionary = GameState.drift_forecast()
	var cur: Dictionary = {"trust": GameState.trust, "docs": GameState.docs, "burnout": GameState.burnout, "kpi": GameState.kpi}
	var n := 0
	for k in cur:
		var key: String = k
		var v: int = int(cur[key])
		var fd: int = int(fc[key])
		bar_labels[key].text = "%s: %d%s" % [bar_titles[key], v, ("  %+d/мес" % fd) if fd != 0 else ""]
		var bar: ProgressBar = bars[key]
		var tw2 := bar.create_tween()
		tw2.tween_property(bar, "value", float(v), 0.45).set_trans(Tween.TRANS_CUBIC)
		if not first and v != int(prev_stats[key]):
			var d: int = v - int(prev_stats[key])
			var good: bool = (d > 0) != (key == "burnout")
			_float_text("%+d %s" % [d, bar_titles[key]], C_GREEN if good else C_RED, Vector2(30.0 + n * 6.0, 150.0 + n * 26.0))
			n += 1
	prev_stats = cur
	_check_toasts()


# ---------------------------------------------------------------- профиль, награды, рейтинг

func show_profile() -> void:
	_screen(BG_REPORT)
	_set_nav(true)
	_banner("Профиль кандидата", C_PURPLE, "star")
	var c := _card(content, C_PURPLE)
	c.add_child(_label(GameState.rank_name(), 28, C_PURPLE))
	var need := GameState.rank_next_need()
	if need > 0:
		c.add_child(_plain("До следующего статуса: %d из %d баллов навыков" % [GameState.comp_total(), need], 16, C_MUTED))
		var bar := _make_bar(C_PURPLE)
		bar.max_value = need
		bar.value = GameState.comp_total()
		c.add_child(bar)
	else:
		c.add_child(_label("Высший статус достигнут!", 18, C_GREEN))

	content.add_child(_plain("Навыки", 24))
	for k in Data.COMPETENCIES:
		var key: String = k
		var pts: int = int(GameState.comp[key])
		var lvl: int = int(pts / 6.0) + 1
		var col: Color = comp_colors[key]
		var cc := _card(content, col)
		var row := HBoxContainer.new()
		cc.add_child(row)
		row.add_child(_label(str(Data.COMPETENCIES[key]), 20, col.darkened(0.2)))
		row.add_child(_plain("уровень %d" % lvl, 18, col))
		var b2 := _make_bar(col)
		b2.max_value = 6
		b2.value = pts % 6
		cc.add_child(b2)

	content.add_child(_plain("Путь к званию", 24))
	var lc := _card(content, C_TEAL)
	var cur_i := GameState.rank_index()
	for i in range(Data.RANKS.size()):
		var done := i <= cur_i
		var txt := "%s%s  (от %d баллов)" % ["> " if i == cur_i else "", Data.RANKS[i][0], Data.RANKS[i][1]]
		lc.add_child(_label(txt, 17, C_GREEN if done else C_GRAY))

	var ic := _card(content, C_BLUE)
	ic.add_child(_label("Проект: «Эко-двор», грант %s" % GameState.fmt(GameState.GRANT_TOTAL), 17))
	ic.add_child(_label("График траншей: " + GameState.tranche_name, 17))
	ic.add_child(_label("Нарушений исправлено до проверки: %d" % _fixed_count(), 17))


func _fixed_count() -> int:
	var n := 0
	for it in GameState.issues:
		if str(it["status"]) == "fixed":
			n += 1
	return n


func show_achievements() -> void:
	_screen(BG_END)
	_set_nav(true)
	var got := 0
	for a in Data.ACHIEVEMENTS:
		if GameState.ach.has(a["id"]):
			got += 1
	_banner("Награды: %d из %d" % [got, Data.ACHIEVEMENTS.size()], C_ORANGE, "cup")
	for a in Data.ACHIEVEMENTS:
		var open: bool = GameState.ach.has(a["id"])
		var col: Color = color_names[str(a["color"])]
		var c := _card(content, col if open else C_GRAY, C_PANEL if open else Color(0.94, 0.95, 0.95))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		c.add_child(row)
		row.add_child(_icon(str(a["icon"]) if open else "lock", col if open else C_GRAY, 44))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		v.add_child(_label(str(a["name"]) if open else "???", 20, col.darkened(0.2) if open else C_GRAY))
		v.add_child(_label(str(a["desc"]), 16, C_MUTED))


func show_leaderboard() -> void:
	_screen(BG_BUDGET)
	_set_nav(true)
	_banner("Рейтинг и концовки", C_BLUE, "cup")
	var c := _card(content, C_GREEN)
	c.add_child(_label("Лучший результат кампании: %d из 100" % GameState.best_score, 22, C_GREEN))
	c.add_child(_label("Попыток: %d" % GameState.attempts, 17, C_MUTED))
	var seen := GameState.endings_seen.size()
	content.add_child(_plain("Концовки: %d из %d" % [seen, Data.ENDINGS.size()], 24))
	for id in Data.ENDINGS:
		var e: Dictionary = Data.ENDINGS[id]
		var open: bool = GameState.endings_seen.has(id)
		var kind := str(e["kind"])
		var col := C_GREEN if kind == "win" else (C_ORANGE if kind == "mid" else C_RED)
		var ec := _card(content, col if open else C_GRAY, C_PANEL if open else Color(0.94, 0.95, 0.95))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		ec.add_child(row)
		var ico := "lock"
		if open:
			ico = "cup" if kind == "win" else ("star" if kind == "mid" else "fire")
		row.add_child(_icon(ico, col if open else C_GRAY, 36))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		v.add_child(_label(str(e["title"]) if open else "???", 19, col.darkened(0.2) if open else C_GRAY))
		if open:
			v.add_child(_label(str(e["text"]), 15, C_MUTED))
