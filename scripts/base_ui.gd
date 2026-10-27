extends Control
## Общие элементы интерфейса: тема, помощники, анимации, HUD, нижнее меню,
## экраны профиля, наград и рейтинга. Игровая логика экранов лежит в main.gd.

const Data = preload("res://data/game_data.gd")
const YardView = preload("res://scripts/yard_view.gd")
const IconView = preload("res://scripts/icon_view.gd")

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
const C_DARK := Color(0.16, 0.22, 0.28)
const C_MUTED := Color(0.42, 0.48, 0.52)
const C_GRAY := Color(0.65, 0.67, 0.68)
const C_CREAM := Color(1, 0.97, 0.85)

# Фоны экранов
const BG_INTRO := Color(0.88, 0.96, 0.92)
const BG_BUDGET := Color(0.89, 0.93, 0.99)
const BG_MONTH := Color(0.99, 0.96, 0.88)
const BG_EVENT := Color(1.0, 0.92, 0.85)
const BG_REPORT := Color(0.93, 0.90, 0.99)
const BG_GOOD := Color(0.88, 0.97, 0.89)
const BG_BAD := Color(0.99, 0.90, 0.89)
const BG_END := Color(0.99, 0.94, 0.80)

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
var comp_colors: Dictionary = {"comm": C_PINK, "analytics": C_BLUE, "docs": C_TEAL, "lead": C_ORANGE}
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

	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

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
	var sb := _box(tint, 14, 12)
	sb.border_width_left = 8
	sb.border_color = accent
	return sb


func _button_box(col: Color, pressed := false) -> StyleBoxFlat:
	var sb := _box(col, 16, 12)
	sb.border_width_bottom = 0 if pressed else 5
	sb.border_color = col.darkened(0.3)
	return sb


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 20
	t.set_stylebox("normal", "Button", _button_box(C_GREEN))
	t.set_stylebox("hover", "Button", _button_box(C_GREEN.lightened(0.1)))
	t.set_stylebox("pressed", "Button", _button_box(C_GREEN.darkened(0.15), true))
	t.set_stylebox("disabled", "Button", _button_box(C_GRAY))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for n in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
		t.set_color(n, "Button", Color.WHITE)
	t.set_color("font_color", "Label", C_DARK)
	t.set_stylebox("panel", "PanelContainer", _box(C_PANEL, 16, 14))
	t.set_stylebox("background", "ProgressBar", _box(Color(0.85, 0.87, 0.88), 6, 0))
	t.set_stylebox("fill", "ProgressBar", _box(C_GREEN, 6, 0))
	return t


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
	b.custom_minimum_size = Vector2(0, 58)
	b.pressed.connect(cb)
	b.add_theme_stylebox_override("normal", _button_box(color))
	b.add_theme_stylebox_override("hover", _button_box(color.lightened(0.1)))
	b.add_theme_stylebox_override("pressed", _button_box(color.darkened(0.15), true))
	b.resized.connect(_btn_pivot.bind(b))
	b.button_down.connect(_btn_scale.bind(b, 0.95))
	b.button_up.connect(_btn_scale.bind(b, 1.0))
	b.mouse_entered.connect(_btn_scale.bind(b, 1.03))
	b.mouse_exited.connect(_btn_scale.bind(b, 1.0))
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
	p.add_theme_stylebox_override("panel", _box(color, 18, 14))
	content.add_child(p)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	p.add_child(row)
	if icon != "":
		row.add_child(_icon(icon, Color(1, 1, 1, 0.28), 46))
	row.add_child(_label(text, 28, Color.WHITE))


func _make_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.add_theme_stylebox_override("fill", _box(color, 6, 0))
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


func _add_yard() -> void:
	var sig := GameState.scene_sig()
	var flash := sig != GameState.last_sig and GameState.last_sig != ""
	GameState.last_sig = sig
	var y = YardView.new()
	y.set_state(GameState.scene_state(), flash)
	content.add_child(y)


func _say(who: String, text: String) -> void:
	var ch: Dictionary = characters[who]
	var col: Color = ch["color"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)
	var av := PanelContainer.new()
	av.custom_minimum_size = Vector2(64, 64)
	av.pivot_offset = Vector2(32, 32)
	av.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	av.add_theme_stylebox_override("panel", _box(col, 32, 4))
	row.add_child(av)
	var ini := _plain(str(ch["name"]).left(1), 30, Color.WHITE)
	ini.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ini.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	av.add_child(ini)
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
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 16)
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
	var sc_name := "Не выбран"
	for s in Data.SCENARIOS:
		if s["id"] == GameState.scenario_id:
			sc_name = str(s["name"])
	ic.add_child(_label("Проект: " + sc_name, 17))
	ic.add_child(_label("Куратор: " + str(donor_titles.get(str(GameState.donor.get("id", "normal")), "Обычный")), 17))
	if GameState.spec != "":
		ic.add_child(_label("Профиль: " + str(Data.SPECS[GameState.spec]["name"]), 17))


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


func _standings(parent: Control) -> void:
	var rows: Array = []
	rows.append({"name": "Вы", "city": "Школа НКО", "total": GameState.tour_player_total(), "me": true})
	for r in GameState.tour_rivals:
		rows.append({"name": r["name"], "city": r["city"], "total": r["total"], "me": false})
	rows.sort_custom(func(a, b): return a["total"] > b["total"])
	var i := 0
	for r in rows:
		var me: bool = r["me"]
		var c := _card(parent, C_ORANGE if me else C_BLUE, C_CREAM if me else C_PANEL)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		c.add_child(row)
		row.add_child(_plain("%d" % (i + 1), 24, C_ORANGE if me else C_MUTED))
		row.add_child(_label("%s, %s" % [r["name"], r["city"]], 18))
		row.add_child(_plain("%d" % int(r["total"]), 20, C_ORANGE if me else C_DARK))
		var bar := _make_bar(C_ORANGE if me else C_BLUE)
		bar.max_value = 320
		bar.value = 0
		c.add_child(bar)
		var tw := bar.create_tween()
		tw.tween_property(bar, "value", float(int(r["total"])), 0.7).set_delay(i * 0.08).set_trans(Tween.TRANS_CUBIC)
		i += 1


func show_leaderboard() -> void:
	_screen(BG_BUDGET)
	_set_nav(true)
	_banner("Рейтинг и концовки", C_BLUE, "cup")
	var c := _card(content, C_GREEN)
	c.add_child(_label("Лучший результат кампании: %d из 100" % GameState.best_score, 22, C_GREEN))
	c.add_child(_label("Попыток: %d" % GameState.attempts, 17, C_MUTED))
	if not GameState.tour_rivals.is_empty():
		content.add_child(_plain("Турнир кандидатов", 24))
		_standings(content)
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
