extends "res://scripts/base_ui.gd"
## Игровой поток: кампания, мини-игры, главы, турнир и концовки.
## Общие элементы интерфейса лежат в base_ui.gd.

var in_game := false
var month_note := ""
var tut_page := 0
var current_event: Dictionary = {}
var current_who := "vera"
var current_after: Callable = Callable()

# чеки
var receipts: Array = []
var receipt_idx := 0
var receipt_correct := 0
var receipt_streak := 0
var best_streak := 0
var quarter := 0
var receipt_active := false
var receipt_time := 0.0
var receipt_bar: ProgressBar
var receipt_mode := "report"
var receipt_done: Callable = Callable()

# субботник
var cleanup_active := false
var cleanup_time := 0.0
var cleanup_spawn := 0.0
var cleanup_score := 0
var cleanup_area: Control
var cleanup_bar: ProgressBar
var cleanup_label: Label
var cleanup_activity: Dictionary = {}

# поиск нарушений
var eh_rows: Array = []
var eh_sel: Dictionary = {}
var eh_btns: Array = []
var eh_time := 0.0
var eh_active := false
var eh_bar: ProgressBar
var eh_cb: Callable = Callable()

# питч донору
var pitch_set: Array = []
var pitch_i := 0
var pitch_pts := 0
var pitch_cb: Callable = Callable()

# бюджет
var budget_sliders: Dictionary = {}
var budget_value_labels: Dictionary = {}
var budget_remaining_label: Label
var budget_errors_label: Label


func _ready() -> void:
	_build_ui()
	go_game = _go_game
	GameState.reset()
	show_intro()


func _process(delta: float) -> void:
	if cleanup_active:
		_tick_cleanup(delta)
	if receipt_active:
		_tick_receipt(delta)
	if eh_active:
		_tick_eh(delta)


func _go_game() -> void:
	if in_game:
		show_month(month_note)
	else:
		show_intro()


func _pulse(n: Control) -> void:
	var tw := n.create_tween().set_loops()
	tw.tween_property(n, "self_modulate", Color(1.2, 1.2, 1.2), 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "self_modulate", Color.WHITE, 0.7).set_trans(Tween.TRANS_SINE)


# ---------------------------------------------------------------- вступление

func show_intro() -> void:
	in_game = false
	hud.hide()
	_screen(BG_INTRO)
	_add_yard()
	_banner("Грантовый баланс", C_GREEN, "leaf")
	content.add_child(_label("Отбор в Школу НКО: ведите проект, играйте в турнире и получите место без экзаменов. Мини-игры, награды и 12 концовок ждут вас.", 20))
	var play := _button("Играть", _tutorial_start)
	content.add_child(play)
	_pulse(play)
	content.add_child(_button("Профиль и награды", show_profile, C_PURPLE))
	content.add_child(_button("Рейтинг и концовки", show_leaderboard, C_BLUE))
	content.add_child(_button("Глоссарий", show_glossary, C_GRAY))


func _tutorial_start() -> void:
	tut_page = 0
	show_tutorial()


func _tut_next() -> void:
	tut_page += 1
	show_tutorial()


func show_tutorial() -> void:
	var pg: Array = Data.TUTORIAL[tut_page]
	_screen(BG_INTRO)
	_add_yard()
	_say(str(pg[0]), str(pg[1]))
	var last: bool = tut_page >= Data.TUTORIAL.size() - 1
	if last:
		content.add_child(_button("Выбрать проект", show_scenarios))
	else:
		content.add_child(_button("Дальше", _tut_next))


func show_scenarios() -> void:
	hud.hide()
	_screen(BG_INTRO)
	_banner("Какой проект?", C_GREEN, "leaf")
	content.add_child(_label("Выберите место. От этого зависят старт и сложность.", 19, C_MUTED))
	if GameState.mentor_next:
		_say("igor", "Бонус наставника: вы начнёте с доверием на 8 выше.")
	content.add_child(_plain("Сложность", 20, C_MUTED))
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 8)
	content.add_child(drow)
	var dnames: Array = ["Лёгкая", "Обычная", "Сложная"]
	for d in range(3):
		var db := _button(str(dnames[d]), _set_difficulty.bind(d), C_GREEN if GameState.difficulty == d else C_GRAY)
		db.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		drow.add_child(db)
	var i := 0
	for sc in Data.SCENARIOS:
		var col: Color = choice_colors[i % choice_colors.size()]
		content.add_child(_button("%s\n%s" % [sc["name"], sc["desc"]], _on_scenario.bind(sc), col))
		i += 1


func _set_difficulty(d: int) -> void:
	GameState.difficulty = d
	show_scenarios()


func _on_scenario(sc: Dictionary) -> void:
	GameState.start_scenario(sc)
	show_budget()


func show_glossary() -> void:
	_screen(BG_REPORT)
	_banner("Глоссарий", C_PURPLE, "doc")
	var i := 0
	for item in Data.GLOSSARY:
		var col: Color = choice_colors[i % choice_colors.size()]
		var c := _card(content, col)
		c.add_child(_label(str(item[0]), 21, col))
		c.add_child(_label(str(item[1]), 18))
		i += 1
	content.add_child(_button("Назад", _go_game, C_GRAY))


# ---------------------------------------------------------------- бюджет

func _line_hint(line: String) -> String:
	var g := GameState.GRANT_TOTAL
	match line:
		"salary":
			return "не меньше " + GameState.fmt(int(g * GameState.MIN_SALARY_PCT))
		"activities":
			return "не меньше " + GameState.fmt(int(g * GameState.MIN_ACTIVITIES_PCT))
		"equipment":
			return "не больше " + GameState.fmt(int(g * GameState.MAX_EQUIPMENT_PCT))
		"rent":
			return "не меньше " + GameState.fmt(GameState.MIN_RENT)
		"admin":
			return "не больше " + GameState.fmt(int(g * GameState.MAX_ADMIN_PCT))
	return ""


func _line_ok(line: String, v: int) -> bool:
	var g := GameState.GRANT_TOTAL
	match line:
		"salary":
			return v >= g * GameState.MIN_SALARY_PCT
		"activities":
			return v >= g * GameState.MIN_ACTIVITIES_PCT
		"equipment":
			return v <= g * GameState.MAX_EQUIPMENT_PCT
		"rent":
			return v >= GameState.MIN_RENT
		"admin":
			return v <= g * GameState.MAX_ADMIN_PCT
	return true


func show_budget() -> void:
	hud.hide()
	_screen(BG_BUDGET)
	_banner("Бюджет гранта", C_BLUE, "coin")
	_say("igor", str(GameState.donor["line"]))
	_say("vera", "Разделите 300 000 руб. по статьям: все ползунки сейчас на нуле. Уложитесь в лимиты донора и подумайте о зарплатах помощников.")

	budget_sliders.clear()
	budget_value_labels.clear()
	for line in Data.LINES:
		var col: Color = line_colors[line]
		var c := _card(content, col)
		var row := HBoxContainer.new()
		c.add_child(row)
		row.add_child(_label(str(Data.LINES[line]), 20, col.darkened(0.2)))
		var val := _plain("", 20, col)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.custom_minimum_size = Vector2(150, 0)
		row.add_child(val)
		c.add_child(_plain(_line_hint(line), 15, C_MUTED))
		var sl := HSlider.new()
		sl.min_value = 0
		sl.max_value = 150000
		sl.step = 5000
		sl.value = 0
		sl.custom_minimum_size = Vector2(0, 36)
		sl.add_theme_stylebox_override("slider", _box(col.lightened(0.5), 4, 3))
		sl.add_theme_stylebox_override("grabber_area", _box(col, 4, 3))
		sl.add_theme_stylebox_override("grabber_area_highlight", _box(col.lightened(0.15), 4, 3))
		sl.value_changed.connect(_on_budget_changed)
		c.add_child(sl)
		budget_sliders[line] = sl
		budget_value_labels[line] = val

	var rc := _card(content, C_YELLOW, C_CREAM)
	budget_remaining_label = _plain("", 22)
	budget_remaining_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rc.add_child(budget_remaining_label)
	budget_errors_label = _label("", 18, C_RED)
	content.add_child(budget_errors_label)
	content.add_child(_button("Утвердить бюджет", _confirm_budget))
	_on_budget_changed(0.0)


func _budget_total() -> int:
	var t := 0
	for line in budget_sliders:
		t += int(budget_sliders[line].value)
	return t


func _on_budget_changed(_v: float) -> void:
	for line in budget_sliders:
		var v := int(budget_sliders[line].value)
		var lbl: Label = budget_value_labels[line]
		lbl.text = GameState.fmt(v)
		lbl.add_theme_color_override("font_color", C_MUTED if v == 0 else (line_colors[line] if _line_ok(line, v) else C_RED))
	var left := GameState.GRANT_TOTAL - _budget_total()
	budget_remaining_label.text = "Осталось: %s" % GameState.fmt(left)
	budget_remaining_label.add_theme_color_override("font_color", C_GREEN if left == 0 else C_RED)


func _confirm_budget() -> void:
	var b := {}
	for line in budget_sliders:
		b[line] = int(budget_sliders[line].value)
	var errs: Array = []
	if _budget_total() != GameState.GRANT_TOTAL:
		errs.append("Сумма должна быть ровно 300 000 руб.")
	for line in b:
		if not _line_ok(line, b[line]):
			errs.append("%s: %s" % [Data.LINES[line], _line_hint(line)])
	if not errs.is_empty():
		GameState.mistakes["budget"] = GameState.mistakes.get("budget", 0) + 1
		budget_errors_label.text = "Донор не утвердил:\n" + "\n".join(errs)
		_flash(C_RED)
		return
	GameState.start_project(b)
	GameState.roll_quest()
	month_note = "Бюджет утверждён! Первый транш: %s" % GameState.fmt(int(GameState.GRANT_TOTAL * GameState.TRANCHES[0]))
	var pm := roundi((GameState.price_mult - 1.0) * 100.0)
	if pm != 0:
		month_note += "\nЦены на акции и закупки в этом году: %+d%%" % pm
	_confetti(30)
	show_month(month_note)


# ---------------------------------------------------------------- игровой месяц

func _hint() -> Array:
	var left := 3 - ((GameState.month - 1) % 3)
	var fc: Dictionary = GameState.drift_forecast()
	if GameState.month == 1 and GameState.kpi == 0:
		return ["vera", "Начните с акции: она даёт результат. Но помните: показатели сами меняются каждый месяц, смотрите на цифры «в месяц»."]
	if int(fc["docs"]) <= -4:
		return ["vera", "Документы падают на %d в месяц. Купите сканер, наймите бухгалтера или оформите архив." % absi(int(fc["docs"]))]
	if int(fc["kpi"]) < 0:
		return ["igor", "Результат сам по себе падает. Запустите постоянную программу или наймите помощника."]
	if GameState.docs < GameState.docs_need - 10:
		return ["vera", "Документов маловато. Скоро проверка, оформите их."]
	if GameState.burnout >= 60:
		return ["misha", "Мы все устали... Можно выходной?"]
	if GameState.cash < 25000:
		return ["vera", "На счёте мало денег. Следите за кассой!"]
	if left == 1:
		return ["igor", "В этом месяце проверка отчёта. Вы готовы?"]
	return ["misha", "Двор уже меняется! Что делаем дальше?"]


func _goal_row(parent: Control, text: String, value: int, maxv: int, color: Color) -> void:
	var done := value >= maxv
	parent.add_child(_plain(text + ("  - готово!" if done else ""), 17, C_GREEN if done else C_DARK))
	var bar := _make_bar(C_GREEN if done else color)
	bar.max_value = maxv
	bar.value = mini(value, maxv)
	parent.add_child(bar)


func _grid_button(grid: GridContainer, text: String, cb: Callable, color: Color, disabled := false) -> void:
	var b := _button(text, cb, color)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = disabled
	grid.add_child(b)


func _money_card() -> void:
	var mf: Dictionary = GameState.money_flow()
	var c := _card(content, C_ORANGE, C_CREAM)
	c.add_child(_plain("Деньги: что уходит со счёта в месяц", 18, C_ORANGE))
	c.add_child(_label("Зарплаты, аренда, админ. расходы: %s" % GameState.fmt(-int(mf["fixed"])), 16))
	if int(mf["team"]) > 0:
		c.add_child(_label("Команда: %s" % GameState.fmt(-int(mf["team"])), 16))
	if int(mf["mods"]) != 0:
		c.add_child(_label("Программы, покупки, сервисы: %s" % GameState.fmt(int(mf["mods"])), 16))
	var net: int = int(mf["net"])
	c.add_child(_label("Итого в месяц: %s" % GameState.fmt(net), 20, C_RED if GameState.cash + net * int(mf["left"]) < 0 else C_ORANGE))
	if int(mf["tranche"]) > 0:
		c.add_child(_label("Ближайший транш: +%s через %d мес. (если отчёт примут)" % [GameState.fmt(int(mf["tranche"])).replace(" руб.", ""), int(mf["left"])], 16, C_GREEN))
	if int(mf["runway"]) >= 0:
		c.add_child(_label("Без новых доходов денег хватит на %d мес." % int(mf["runway"]), 15, C_MUTED))


func _drift_card() -> void:
	var c := _card(content, C_BLUE)
	c.add_child(_plain("Что меняется само каждый месяц", 18, C_BLUE))
	var t: Dictionary = GameState.drift_forecast()
	var fx_d: Dictionary = {"kpi": t["kpi"], "docs": t["docs"], "burnout": t["burnout"], "trust": t["trust"], "money": t["cash"]}
	_chips(c, fx_d)
	var names: Array = []
	for l in GameState.drift_lines(true):
		if str(l["name"]) != "Естественный спад":
			names.append(str(l["name"]))
	if not names.is_empty():
		c.add_child(_label("Источники: " + ", ".join(names), 15, C_MUTED))
	else:
		c.add_child(_label("Пока только естественный спад. Покупки, команда и программы изменят эти цифры.", 15, C_MUTED))


func _quest_card() -> void:
	if GameState.quest.is_empty():
		return
	var done := GameState.q_done
	var c := _card(content, C_GREEN if done else C_PINK, Color(0.93, 1, 0.95) if done else Color(1, 0.95, 0.97))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	c.add_child(row)
	row.add_child(_icon("star", C_GREEN if done else C_PINK, 28))
	row.add_child(_label("Поручение: " + str(GameState.quest["text"]), 18))
	if done:
		c.add_child(_plain("Выполнено!", 16, C_GREEN))
	else:
		c.add_child(_plain("Награда: " + GameState.quest_reward_text(), 15, C_MUTED))


func show_month(note := "") -> void:
	if GameState.level_up_pending > 0:
		_show_levelup(GameState.take_level_up(), note)
		return
	in_game = true
	hud.show()
	update_hud()
	_screen(BG_MONTH)
	_set_nav(true)
	_add_yard()
	_banner("Месяц %d  |  %s" % [GameState.month, Data.LEVEL_TITLES[GameState.level() - 1]], C_ORANGE, "leaf")

	var q := int(ceil(GameState.month / 3.0))
	var plan := GameState.plan_for(q)
	var left := 3 - ((GameState.month - 1) % 3)
	var gc := _card(content, C_TEAL)
	gc.add_child(_plain("Цель к отчёту через %d мес." % left, 18, C_TEAL))
	_goal_row(gc, "Результат: %d из %d" % [mini(GameState.kpi, plan), plan], GameState.kpi, plan, C_ORANGE)
	_goal_row(gc, "Документы: %d из %d" % [mini(GameState.docs, GameState.docs_need), GameState.docs_need], GameState.docs, GameState.docs_need, C_BLUE)

	_money_card()
	_drift_card()
	_quest_card()
	var h: Array = _hint()
	_say(str(h[0]), str(h[1]))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)
	row.add_child(_plain("Действия:", 20, C_MUTED))
	_pips(row, GameState.ap, GameState.AP_PER_MONTH, C_ORANGE)

	if note != "":
		var nc := _card(content, C_YELLOW, C_CREAM)
		nc.add_child(_label(note.strip_edges(), 17))

	var no_ap := GameState.ap <= 0
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)
	_grid_button(grid, "Акции", show_activities, C_GREEN, no_ap)
	_grid_button(grid, "Закупки", show_shop, C_PURPLE, no_ap)
	_grid_button(grid, "Команда", show_team, C_BLUE, no_ap)
	_grid_button(grid, "Документы", show_docs, C_TEAL, no_ap)
	_grid_button(grid, "Найти нарушения", _on_report_prep, C_PINK, no_ap)
	_grid_button(grid, "Встреча с донором", _on_meeting, C_ORANGE, no_ap)
	var endb := _button("Завершить месяц", _end_month, C_DARK)
	content.add_child(endb)
	if no_ap:
		_pulse(endb)
	content.add_child(_button("Глоссарий", show_glossary, C_GRAY))


func _show_levelup(lv: int, note: String) -> void:
	hud.show()
	update_hud()
	_screen(BG_END)
	_add_yard()
	_banner("Новый уровень!", C_ORANGE, "cup")
	_confetti(70)
	_flash(C_YELLOW)
	var c := _card(content, C_ORANGE, C_CREAM)
	c.add_child(_label(str(Data.LEVEL_TITLES[lv - 1]), 28, C_ORANGE))
	c.add_child(_label(str(Data.LEVEL_UNLOCKS[lv - 1]), 20))
	_say("misha", "Ура! Про нас уже знают в районе!")
	if GameState.spec == "" and lv >= 2:
		_say("vera", "Пора выбрать профиль организации. От него зависит, какие акции получаются лучше всего.")
		var si := 0
		for k in Data.SPECS:
			var sp: Dictionary = Data.SPECS[k]
			content.add_child(_button("%s\n%s" % [sp["name"], sp["desc"]], _on_spec.bind(k, note), [C_TEAL, C_PURPLE][si]))
			si += 1
	else:
		content.add_child(_button("Продолжить", show_month.bind(note)))


func _on_spec(k: String, note: String) -> void:
	GameState.spec = k
	show_month(note)


func _after_action(msg: String) -> void:
	month_note += msg + "\n"
	if GameState.check_game_over() != "":
		update_hud()
		_game_over()
		return
	show_month(month_note)


func _do_simple(id: String) -> void:
	_after_action(GameState.do_simple(id))


# ---------------------------------------------------------------- акции и субботник

func show_activities() -> void:
	hud.show()
	update_hud()
	_screen(BG_MONTH)
	_set_nav(true)
	_banner("Акции", C_GREEN, "leaf")
	content.add_child(_plain("На акции осталось: %s" % GameState.fmt(GameState.activities_left()), 17, C_MUTED))
	content.add_child(_label("Повторы одной акции дают всё меньше результата. Постоянные программы запускаются один раз и работают каждый месяц.", 15, C_MUTED))
	var colors: Array = [C_GREEN, C_TEAL, C_BLUE, C_PURPLE, C_PINK, C_ORANGE]
	var i := 0
	for a in Data.ACTIVITIES:
		var txt := ""
		var off := false
		if GameState.level() < int(a["level"]):
			txt = "%s\nоткроется на уровне %d" % [a["name"], a["level"]]
			off = true
		elif GameState.is_done_once(a):
			txt = "%s\nуже запущено" % a["name"]
			off = true
		elif not GameState.has_budget_for(a):
			txt = "%s\nне хватает денег в статье" % a["name"]
			off = true
		else:
			var prof := "  [+2 по профилю]" if GameState.spec != "" and str(a.get("tag", "")) == GameState.spec else ""
			var n := int(GameState.acts.get(a["id"], 0))
			var rep_note := "  (повтор слабее)" if n >= 1 and not a.has("program") else ""
			txt = "%s  (-%s)\n%s%s%s" % [a["name"], GameState.fmt(GameState.act_cost(a)), a["desc"], prof, rep_note]
		var b := _button(txt, _on_activity.bind(a), colors[i % colors.size()])
		b.disabled = off or GameState.ap <= 0
		content.add_child(b)
		i += 1
	content.add_child(_button("Назад", show_month.bind(month_note), C_GRAY))


func _on_activity(a: Dictionary) -> void:
	if a.get("mini", false):
		cleanup_activity = a
		_cleanup_intro()
	else:
		_after_action(GameState.do_activity(a, 0))


func _cleanup_intro() -> void:
	_screen(BG_GOOD)
	_banner("Субботник!", C_GREEN, "leaf")
	_say("misha", "Нажимайте на мусор, пока он не пропал! Чем больше соберём, тем лучше результат.")
	content.add_child(_button("Поехали!", _cleanup_start))


func _cleanup_start() -> void:
	_screen(BG_GOOD)
	cleanup_bar = _make_bar(C_ORANGE)
	cleanup_bar.max_value = 10.0
	cleanup_bar.value = 10.0
	content.add_child(cleanup_bar)
	cleanup_label = _plain("Собрано: 0", 24, C_GREEN)
	content.add_child(cleanup_label)
	cleanup_area = Control.new()
	cleanup_area.custom_minimum_size = Vector2(0, 460)
	cleanup_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cleanup_area.clip_contents = true
	var field := ColorRect.new()
	field.color = Color(0.70, 0.88, 0.62)
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cleanup_area.add_child(field)
	content.add_child(cleanup_area)
	cleanup_time = 10.0
	cleanup_spawn = 0.3
	cleanup_score = 0
	cleanup_active = true


func _tick_cleanup(delta: float) -> void:
	cleanup_time -= delta
	cleanup_bar.value = maxf(cleanup_time, 0.0)
	cleanup_spawn -= delta
	if cleanup_spawn <= 0.0 and cleanup_time > 0.0:
		cleanup_spawn = 0.45
		_spawn_trash()
	if cleanup_time <= 0.0:
		cleanup_active = false
		_cleanup_finish()


func _spawn_trash() -> void:
	var b := Button.new()
	b.text = ["Бутылка", "Пакет", "Банка", "Коробка"].pick_random()
	b.size = Vector2(120, 52)
	b.custom_minimum_size = Vector2(120, 52)
	b.add_theme_font_size_override("font_size", 17)
	var col: Color = [Color(0.55, 0.40, 0.28), Color(0.45, 0.50, 0.55), Color(0.70, 0.35, 0.30)].pick_random()
	b.add_theme_stylebox_override("normal", _button_box(col))
	b.add_theme_stylebox_override("hover", _button_box(col.lightened(0.1)))
	b.add_theme_stylebox_override("pressed", _button_box(col.darkened(0.15), true))
	var w := maxf(cleanup_area.size.x - 130.0, 20.0)
	var h := maxf(cleanup_area.size.y - 60.0, 20.0)
	b.position = Vector2(randf() * w, randf() * h)
	b.pressed.connect(_on_trash.bind(b))
	cleanup_area.add_child(b)
	b.pivot_offset = Vector2(60, 26)
	b.scale = Vector2(0.2, 0.2)
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(1, 1), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(1.6).timeout.connect(_trash_expired.bind(b))


func _on_trash(b: Button) -> void:
	cleanup_score += 1
	cleanup_label.text = "Собрано: %d" % cleanup_score
	_float_text("+1", C_GREEN, b.get_global_position())
	b.queue_free()


func _trash_expired(b: Button) -> void:
	if is_instance_valid(b):
		b.queue_free()


func _cleanup_finish() -> void:
	var bonus := mini(int(cleanup_score / 4.0), 3)
	var msg := GameState.do_activity(cleanup_activity, bonus)
	var good := cleanup_score >= 8
	update_hud()
	_screen(BG_GOOD if good else BG_END)
	_banner("Собрано: %d" % cleanup_score, C_GREEN if good else C_ORANGE, "leaf")
	if good:
		_confetti(40)
	_say("misha", "Отлично поработали!" if good else "Могли бы и больше, но двор стал чище!")
	var c := _card(content, C_GREEN)
	c.add_child(_label(msg, 20))
	content.add_child(_button("Дальше", _finish_cleanup.bind(msg)))


func _finish_cleanup(msg: String) -> void:
	month_note += msg + "\n"
	if GameState.check_game_over() != "":
		_game_over()
		return
	show_month(month_note)


# ---------------------------------------------------------------- закупки и команда

func show_docs() -> void:
	hud.show()
	update_hud()
	_screen(BG_MONTH)
	_set_nav(true)
	_banner("Документы", C_TEAL, "doc")
	_say("vera", "Выберите, как навести порядок в бумагах. Способы стоят по-разному и работают по-разному: одни разово, другие дают постоянный плюс.")
	var left := int(GameState.budget["admin"]) - int(GameState.spent["admin"])
	content.add_child(_plain("Документы: %d, нужно %d. Админ. расходов осталось: %s" % [GameState.docs, GameState.docs_need, GameState.fmt(left)], 15, C_MUTED))
	var colors: Array = [C_TEAL, C_BLUE, C_PURPLE, C_PINK, C_GREEN, C_ORANGE]
	var i := 0
	for d in Data.DOC_ACTIONS:
		if bool(d.get("once", false)) and GameState.done_once.has(d["id"]):
			var dc := _card(content, C_GREEN)
			dc.add_child(_label("Уже сделано: " + str(d["name"]), 18, C_GREEN))
			continue
		var cost := ""
		if int(d["cost"]) > 0:
			cost = "  (-%s)" % GameState.fmt(roundi(float(d["cost"]) * GameState.price_mult))
		var b := _button("%s%s\n%s" % [d["name"], cost, d["desc"]], _on_doc.bind(d), colors[i % colors.size()])
		b.disabled = not GameState.can_do_doc(d)
		content.add_child(b)
		i += 1
	content.add_child(_button("Назад", show_month.bind(month_note), C_GRAY))


func _on_doc(d: Dictionary) -> void:
	_after_action(GameState.do_doc(d))


func show_shop() -> void:
	hud.show()
	update_hud()
	_screen(BG_MONTH)
	_set_nav(true)
	_banner("Закупки", C_PURPLE, "coin")
	_say("vera", "Каждая покупка даёт плюс и обычно минус где-то ещё, и так каждый месяц. Минус можно перекрыть другой покупкой. Выйдете за бюджет статьи больше чем на 10% - донор заметит.")
	var left := int(GameState.budget["equipment"]) - int(GameState.spent["equipment"])
	content.add_child(_plain("Осталось в статье: %s" % GameState.fmt(left), 17, C_MUTED))
	var i := 0
	var colors: Array = [C_PURPLE, C_BLUE, C_TEAL, C_PINK, C_ORANGE]
	for it in Data.ITEMS:
		if GameState.has_item(str(it["id"])):
			var c := _card(content, C_GREEN)
			c.add_child(_label("Куплено: " + str(it["name"]), 18, C_GREEN))
			continue
		var txt := "%s  (-%s)\n%s" % [it["name"], GameState.fmt(GameState.item_cost(it)), it["desc"]]
		if GameState.buy_would_overspend(it):
			txt += "\nВыше бюджета статьи!"
		var b := _button(txt, _on_buy.bind(it), colors[i % colors.size()])
		b.disabled = GameState.ap <= 0
		content.add_child(b)
		i += 1
	content.add_child(_button("Назад", show_month.bind(month_note), C_GRAY))


func _on_buy(it: Dictionary) -> void:
	_after_action(GameState.buy_item(it))


func show_team() -> void:
	hud.show()
	update_hud()
	_screen(BG_MONTH)
	_set_nav(true)
	_banner("Команда", C_BLUE, "people")
	_say("misha", "Сотрудники приносят пользу каждый месяц, но стоят денег и тоже дают побочные эффекты.")
	content.add_child(_plain("Сотрудников: %d из %d" % [GameState.team.size(), GameState.STAFF_MAX], 18, C_MUTED))
	for r in Data.STAFF:
		if GameState.team.has(r["id"]):
			var c := _card(content, C_GREEN)
			c.add_child(_label("В команде: " + str(r["name"]), 18, C_GREEN))
			continue
		var txt := "%s\n%s в месяц с налогами\n%s" % [r["name"], GameState.fmt(int(r["cost"])), r["desc"]]
		if GameState.can_hire() and GameState.salary_short_after_hire(r):
			txt += "\nБюджета на зарплаты не хватит!"
		var hb := _button(txt, _on_hire.bind(r), C_BLUE)
		hb.disabled = not GameState.can_hire()
		content.add_child(hb)
	content.add_child(_button("Выходной команде\nвыгорание -15", _do_simple.bind("rest"), C_PURPLE))
	content.add_child(_button("Командный выезд  (-4 000 руб.)\nвыгорание -25, документы -2", _do_simple.bind("retreat"), C_PINK))
	content.add_child(_button("Позвать волонтёров\nрезультат +3, выгорание -4, документы -3", _do_simple.bind("volunteers"), C_ORANGE))
	content.add_child(_button("Назад", show_month.bind(month_note), C_GRAY))


func _on_hire(r: Dictionary) -> void:
	_after_action(GameState.hire(r))


# ---------------------------------------------------------------- мини-игра: питч донору

func _on_meeting() -> void:
	start_pitch(_pitch_campaign_done)


func _pitch_campaign_done(pts: int, mx: int) -> void:
	if pts >= mx:
		_confetti(50)
	_after_action(GameState.pitch_done(pts, mx))


func start_pitch(done: Callable) -> void:
	pitch_cb = done
	pitch_set = Data.PITCHES.pick_random()
	pitch_i = 0
	pitch_pts = 0
	_pitch_round()


func _pitch_round() -> void:
	var rd: Dictionary = pitch_set[pitch_i]
	_screen(BG_REPORT)
	_banner("Питч донору: вопрос %d из %d" % [pitch_i + 1, pitch_set.size()], C_PURPLE, "heart")
	var meter := _make_bar(C_GREEN)
	meter.max_value = 9
	meter.value = pitch_pts
	content.add_child(meter)
	_say("igor", str(rd["q"]))
	var opts: Array = rd["opts"].duplicate()
	opts.shuffle()
	var i := 0
	for o in opts:
		content.add_child(_button(str(o[0]), _on_pitch.bind(int(o[1])), choice_colors[i % choice_colors.size()]))
		i += 1


func _on_pitch(pts: int) -> void:
	var before := pitch_pts
	pitch_pts += pts
	_screen(BG_GOOD if pts >= 3 else (BG_END if pts >= 1 else BG_BAD))
	_banner("Ответ принят: +%d" % pts, C_GREEN if pts >= 3 else (C_ORANGE if pts >= 1 else C_RED), "heart")
	var meter := _make_bar(C_GREEN)
	meter.max_value = 9
	meter.value = before
	content.add_child(meter)
	var tw := meter.create_tween()
	tw.tween_property(meter, "value", float(pitch_pts), 0.7).set_trans(Tween.TRANS_CUBIC)
	var reactions: Array = ["Это меня не убедило.", "Хм, можно было точнее.", "Неплохо, но есть куда расти.", "Отличный ответ! Вот так и надо."]
	_say("igor", str(reactions[pts]))
	if pts >= 3:
		_flash(C_GREEN)
	elif pts == 0:
		_flash(C_RED)
	pitch_i += 1
	if pitch_i < pitch_set.size():
		content.add_child(_button("Дальше", _pitch_round, C_PURPLE))
	else:
		content.add_child(_button("Завершить встречу", _pitch_finish, C_PURPLE))


func _pitch_finish() -> void:
	pitch_cb.call(pitch_pts, 9)


# ---------------------------------------------------------------- мини-игра: поиск нарушений

func _on_report_prep() -> void:
	start_errorhunt(_eh_campaign_done)


func _eh_campaign_done(found: int, wrong: int, total_bad: int) -> void:
	if found >= total_bad and wrong == 0:
		_confetti(40)
	_after_action(GameState.report_prep_done(found, wrong))


func start_errorhunt(done: Callable) -> void:
	eh_cb = done
	var table: Array = Data.ERROR_TABLES.pick_random()
	eh_rows = table.duplicate()
	eh_rows.shuffle()
	eh_sel = {}
	eh_btns = []
	_screen(BG_REPORT)
	_banner("Найди нарушения", C_PURPLE, "doc")
	_say("vera", "В таблице расходов есть записи, которые донор не примет. Отметьте их, пока идёт время!")
	eh_bar = _make_bar(C_ORANGE)
	eh_bar.max_value = 25.0
	eh_bar.value = 25.0
	content.add_child(eh_bar)
	for i in range(eh_rows.size()):
		var r: Dictionary = eh_rows[i]
		var b := _button(str(r["text"]), _eh_toggle.bind(i), C_BLUE)
		eh_btns.append(b)
		content.add_child(b)
	content.add_child(_button("Проверить", _eh_check, C_GREEN))
	eh_time = 25.0
	eh_active = true


func _tick_eh(delta: float) -> void:
	eh_time -= delta
	eh_bar.value = maxf(eh_time, 0.0)
	if eh_time <= 0.0:
		_eh_check()


func _eh_toggle(i: int) -> void:
	var b: Button = eh_btns[i]
	var on := not eh_sel.has(i)
	if on:
		eh_sel[i] = true
	else:
		eh_sel.erase(i)
	var col := C_ORANGE if on else C_BLUE
	b.add_theme_stylebox_override("normal", _button_box(col))
	b.add_theme_stylebox_override("hover", _button_box(col.lightened(0.1)))
	b.add_theme_stylebox_override("pressed", _button_box(col.darkened(0.15), true))
	b.text = ("Подозрительно: " if on else "") + str(eh_rows[i]["text"])


func _eh_check() -> void:
	if not eh_active:
		return
	eh_active = false
	var found := 0
	var wrong := 0
	var total_bad := 0
	for i in range(eh_rows.size()):
		var bad: bool = eh_rows[i]["bad"]
		var sel := eh_sel.has(i)
		if bad:
			total_bad += 1
		if bad and sel:
			found += 1
		elif sel and not bad:
			wrong += 1
	_screen(BG_GOOD if found >= total_bad and wrong == 0 else BG_END)
	_banner("Найдено %d из %d" % [found, total_bad], C_GREEN if wrong == 0 else C_ORANGE, "doc")
	for i in range(eh_rows.size()):
		var r: Dictionary = eh_rows[i]
		var bad: bool = r["bad"]
		var sel := eh_sel.has(i)
		var c: VBoxContainer
		if bad and sel:
			c = _card(content, C_GREEN)
			c.add_child(_label("Нашли: " + str(r["text"]), 17, C_GREEN))
			c.add_child(_label(str(r["why"]), 15, C_MUTED))
		elif bad:
			c = _card(content, C_RED)
			c.add_child(_label("Пропустили: " + str(r["text"]), 17, C_RED))
			c.add_child(_label(str(r["why"]), 15, C_MUTED))
		elif sel:
			c = _card(content, C_ORANGE)
			c.add_child(_label("Лишнее: " + str(r["text"]), 17, C_ORANGE))
			c.add_child(_label("Этот расход в порядке.", 15, C_MUTED))
		else:
			c = _card(content, C_GRAY)
			c.add_child(_label(str(r["text"]), 16, C_MUTED))
	if found >= total_bad and wrong == 0:
		_flash(C_GREEN)
	content.add_child(_button("Дальше", _eh_finish.bind(found, wrong, total_bad), C_PURPLE))


func _eh_finish(found: int, wrong: int, total_bad: int) -> void:
	eh_cb.call(found, wrong, total_bad)


# ---------------------------------------------------------------- конец месяца, главы и события

func _end_month() -> void:
	var summary := GameState.end_month()
	update_hud()
	if GameState.check_game_over() != "":
		_game_over()
		return
	_show_month_summary(summary)


func _show_month_summary(summary: String) -> void:
	hud.show()
	_screen(BG_BUDGET)
	_banner("Итоги месяца %d" % GameState.month, C_BLUE, "leaf")
	content.add_child(_label(summary, 17, C_MUTED))
	var mc := _card(content, C_ORANGE, C_CREAM)
	mc.add_child(_label("Со счёта за месяц: %s" % GameState.fmt(GameState.last_cash_delta), 20, C_ORANGE))
	content.add_child(_plain("Что изменилось само", 22))
	var total: Dictionary = GameState.drift_totals(GameState.last_drift)
	for l in GameState.last_drift:
		var d: Dictionary = l.duplicate()
		d["money"] = int(l.get("cash", 0))
		var good: bool = true
		var net: int = int(l.get("kpi", 0)) + int(l.get("docs", 0)) + int(l.get("trust", 0)) - int(l.get("burnout", 0))
		good = net >= 0
		var c := _card(content, C_GREEN if good else C_RED)
		c.add_child(_label(str(l["name"]), 18))
		_chips(c, d)
	var tc := _card(content, C_BLUE, C_CREAM)
	tc.add_child(_label("Всего за месяц", 20, C_BLUE))
	_chips(tc, {"kpi": total["kpi"], "docs": total["docs"], "burnout": total["burnout"], "trust": total["trust"]})
	content.add_child(_button("Дальше", _after_summary.bind(summary)))


func _after_summary(summary: String) -> void:
	var ev := GameState.draw_event()
	if ev.is_empty():
		_after_event()
	else:
		show_event(ev, "", Callable())


func show_event(ev: Dictionary, intro := "", after := Callable()) -> void:
	current_event = ev
	current_after = after
	current_who = str(Data.TOPIC_SPEAKER.get(str(ev.get("topic", "budget")), "vera"))
	hud.show()
	update_hud()
	var chapter := ev.has("chapter")
	_screen(BG_REPORT if chapter else BG_EVENT)
	if intro != "":
		content.add_child(_label(intro, 16, C_MUTED))
	var icon := str(Data.TOPIC_ICON.get(str(ev.get("topic", "budget")), "doc"))
	_banner(str(ev["title"]), C_PURPLE if chapter else C_ORANGE, icon)
	_say(current_who, str(ev["text"]))
	var i := 0
	for ch in ev["choices"]:
		var need := str(ch.get("need_flag", ""))
		if need != "" and not GameState.flags.has(need):
			continue
		var label := str(ch["text"])
		if need != "":
			label = "[Открыто вашим путём] " + label
		content.add_child(_button(label, _on_choice.bind(ch), choice_colors[i % choice_colors.size()]))
		i += 1


func _on_choice(ch: Dictionary) -> void:
	var eff: Dictionary = GameState.apply_choice(current_event, ch)
	update_hud()
	var ok: bool = eff.get("ok", true)
	_screen(BG_GOOD if ok else BG_BAD)
	_flash(C_GREEN if ok else C_RED)
	_banner("Хороший ход!" if ok else "Можно было лучше", C_GREEN if ok else C_RED, "heart" if ok else "fire")
	_say(current_who, str(eff.get("lesson", "")))
	var c := _card(content, C_GREEN if ok else C_RED)
	_chips(c, eff)
	var cb: Callable = current_after if current_after.is_valid() else _after_event
	content.add_child(_button("Дальше", cb))


func _after_event() -> void:
	if GameState.check_game_over() != "":
		_game_over()
		return
	if GameState.cash < 0:
		GameState.cash_gaps += 1
		if GameState.check_game_over() != "":
			_game_over()
			return
		show_event(Data.CASH_GAP, "Счёт: %s" % GameState.fmt(GameState.cash))
		return
	if GameState.month % 3 == 0:
		start_report()
		return
	_next_month()


func _next_month() -> void:
	GameState.next_month()
	month_note = ""
	GameState.roll_quest()
	var ce := GameState.chapter_event()
	if not ce.is_empty():
		show_event(ce, "Новая глава истории", _after_chapter)
		return
	_after_chapter()


func _after_chapter() -> void:
	if GameState.check_game_over() != "":
		_game_over()
		return
	if GameState.month == GameState.offer_month and not GameState.season2:
		show_grant_offers()
	else:
		show_month()


func show_grant_offers() -> void:
	hud.show()
	update_hud()
	_screen(BG_END)
	_banner("Новый грант", C_ORANGE, "coin")
	_say("igor", "Другой фонд ищет партнёров. Выберите грант. Эти деньги можно тратить только на акции. Чем крупнее грант, тем выше планка.")
	var offers: Array = Data.GRANT_OFFERS.duplicate()
	offers.append_array(Data.GRANT_OFFERS_EXTRA)
	offers.shuffle()
	for o in offers.slice(0, 3):
		var ok: bool = GameState.trust >= int(o["need_trust"])
		var txt := "%s\n%s\n+%s" % [o["name"], o["desc"], GameState.fmt(int(o["money"]))]
		if not ok:
			txt = "%s\nнужно доверие донора: %d" % [o["name"], o["need_trust"]]
		var b := _button(txt, _on_offer.bind(o), C_GREEN)
		b.disabled = not ok
		content.add_child(b)
	content.add_child(_button("Пропустить", show_month, C_GRAY))


func _on_offer(o: Dictionary) -> void:
	GameState.take_offer(o)
	month_note = "Получен грант: %s" % GameState.fmt(int(o["money"]))
	_confetti(40)
	show_month(month_note)


# ---------------------------------------------------------------- квартальный отчёт

func start_report() -> void:
	quarter = int(GameState.month / 3.0)
	receipt_mode = "report"
	receipt_done = _show_report_result
	receipts = Data.RECEIPTS.duplicate()
	receipts.shuffle()
	receipts = receipts.slice(0, 5)
	receipt_idx = 0
	receipt_correct = 0
	receipt_streak = 0
	best_streak = 0
	hud.show()
	update_hud()
	_screen(BG_REPORT)
	_banner("Проверка за квартал %d" % quarter, C_PURPLE, "doc")
	_say("igor", "Показывайте документы. Разнесите чеки по статьям, лишнее отклоните. Времени немного!")
	var c := _card(content, C_BLUE)
	c.add_child(_label("Шпаргалка Веры:", 19, C_BLUE))
	c.add_child(_label("Принимаем: чек с датой, связь с проектом, верная статья.\nОтклоняем: личное, штрафы, подарки, чеки без даты и подписи.", 18))
	content.add_child(_button("Начать", _show_receipt, C_PURPLE))


func _show_receipt() -> void:
	var r: Dictionary = receipts[receipt_idx]
	_screen(BG_REPORT)
	_banner("Документ %d из %d" % [receipt_idx + 1, receipts.size()], C_PURPLE, "doc")
	var tmax := 7.0 if receipt_mode == "tour" else float(maxi(12 - quarter, 7))
	receipt_time = tmax
	receipt_bar = _make_bar(C_ORANGE)
	receipt_bar.max_value = tmax
	receipt_bar.value = tmax
	content.add_child(receipt_bar)
	if receipt_streak >= 2:
		content.add_child(_plain("Серия: %d подряд!" % receipt_streak, 20, C_ORANGE))
	var c := _card(content, C_YELLOW, Color(1, 0.98, 0.88))
	c.add_child(_label(str(r["text"]), 22))
	for opt in Data.RECEIPT_OPTIONS:
		content.add_child(_button(str(opt), _on_receipt_answer.bind(opt), option_colors[opt]))
	receipt_active = true


func _tick_receipt(delta: float) -> void:
	receipt_time -= delta
	receipt_bar.value = maxf(receipt_time, 0.0)
	if receipt_time <= 0.0:
		_on_receipt_answer("")


func _on_receipt_answer(opt: String) -> void:
	if not receipt_active:
		return
	receipt_active = false
	var r: Dictionary = receipts[receipt_idx]
	var ok: bool = opt == r["answer"]
	if ok:
		receipt_correct += 1
		receipt_streak += 1
		best_streak = maxi(best_streak, receipt_streak)
	else:
		receipt_streak = 0
	if receipt_mode == "report":
		GameState.receipt_result(ok, str(r["topic"]), str(r["why"]), "Документ: " + str(r["text"]).left(45) + "...")
		GameState.best_streak_total = maxi(GameState.best_streak_total, best_streak)
		update_hud()
	_screen(BG_GOOD if ok else BG_BAD)
	_flash(C_GREEN if ok else C_RED)
	_banner("Верно!" if ok else ("Время вышло!" if opt == "" else "Ошибка"), C_GREEN if ok else C_RED, "heart" if ok else "fire")
	_say("vera", ("Правильно: " + str(r["answer"]) + ". " if not ok else "") + str(r["why"]))
	receipt_idx += 1
	if receipt_idx < receipts.size():
		content.add_child(_button("Дальше", _show_receipt, C_PURPLE))
	else:
		content.add_child(_button("Готово", _receipt_finish, C_PURPLE))


func _receipt_finish() -> void:
	receipt_done.call()


func _show_report_result() -> void:
	var bonus := ""
	if best_streak >= 3:
		GameState.trust = mini(100, GameState.trust + 2)
		bonus = "Серия %d подряд: доверие +2" % best_streak
	var res := GameState.evaluate_report(quarter, receipt_correct, receipts.size())
	update_hud()
	var passed: int = res["passed"]
	_screen(BG_GOOD if passed >= 3 else BG_BAD)
	if passed == 4:
		_confetti(50)
	_banner("Решение донора", C_GREEN if passed >= 3 else C_RED, "cup")
	_say("igor", str(res["text"]))
	for ch in res["checks"]:
		var ok: bool = ch["ok"]
		var c := _card(content, C_GREEN if ok else C_RED)
		c.add_child(_label(("Да: " if ok else "Нет: ") + str(ch["name"]), 20, C_GREEN if ok else C_RED))
		c.add_child(_label(str(ch["detail"]), 17, C_MUTED))
	var s := _card(content, C_YELLOW, C_CREAM)
	s.add_child(_label("Доверие донора: %+d" % int(res["trust_delta"]), 18))
	if bonus != "":
		s.add_child(_label(bonus, 17, C_GREEN))
	content.add_child(_button("Продолжить", _after_report))


func _after_report() -> void:
	if GameState.check_game_over() != "":
		_game_over()
		return
	if GameState.month >= GameState.max_month:
		_campaign_end()
		return
	_next_month()


# ---------------------------------------------------------------- вердикт кампании

func _campaign_end() -> void:
	var v: Dictionary = GameState.campaign_verdict()
	GameState.best_score = maxi(GameState.best_score, int(v["score"]))
	GameState.save_meta()
	show_verdict(v)


func show_verdict(v: Dictionary) -> void:
	in_game = false
	hud.show()
	update_hud()
	_screen(BG_END)
	_add_yard()
	var kind := str(v["kind"])
	var score := int(v["score"])
	_banner("Итоги кампании", C_ORANGE, "cup")
	var c := _card(content, C_ORANGE, C_CREAM)
	c.add_child(_label("Баллы: %d из 100" % score, 28, C_ORANGE))
	c.add_child(_label("Доверие %d, результат %d%%, документы %d%%, навыки %d" % [GameState.trust, GameState.kpi, GameState.docs, GameState.comp_total()], 17, C_MUTED))
	match kind:
		"qualified":
			_say("igor", "Вы прошли отбор! Осталось показать себя в турнире кандидатов со всей страны.")
			_confetti(50)
			if score >= 92 and not GameState.season2:
				content.add_child(_button("Принять зачисление сразу", show_ending.bind("win_perfect"), C_GREEN))
			content.add_child(_button("Играть в турнире", start_tournament, C_ORANGE))
		"reserve":
			if GameState.season2:
				_say("igor", "Баллов немного не хватило, но мы берём вас условно.")
				content.add_child(_button("Дальше", show_ending.bind("mid_probation"), C_ORANGE))
			else:
				_say("igor", "Баллов почти хватило. Можно продлить проект на 6 месяцев и набрать недостающее или остаться в резерве.")
				content.add_child(_button("Продлить на 6 месяцев (+130 000 руб.)", _start_extension, C_GREEN))
				content.add_child(_button("Остаться в резерве", show_ending.bind("mid_waitlist"), C_ORANGE))
		_:
			_say("igor", "К сожалению, баллов не хватило.")
			content.add_child(_button("Дальше", show_ending.bind("lose_final" if GameState.season2 else "lose_not_enrolled"), C_RED))


func _start_extension() -> void:
	GameState.start_extension()
	month_note = "Проект продлён: +%s" % GameState.fmt(GameState.EXTENSION_CASH)
	in_game = true
	_confetti(40)
	_next_month()


# ---------------------------------------------------------------- турнир кандидатов

func start_tournament() -> void:
	GameState.tour_rivals = GameState.make_rivals()
	GameState.tour_scores = []
	GameState.tour_round = 0
	_tour_intro()


func _tour_intro() -> void:
	hud.hide()
	_screen(BG_END)
	_banner("Турнир кандидатов", C_ORANGE, "cup")
	var names: Array = ["Блиц-чеки", "Поиск нарушений", "Питч жюри"]
	_say("igor", "Раунд %d из 3: %s. Побеждает лучший по сумме баллов." % [GameState.tour_round + 1, names[GameState.tour_round]])
	_standings(content)
	content.add_child(_button("Начать раунд", _tour_play, C_ORANGE))


func _tour_play() -> void:
	match GameState.tour_round:
		0:
			_tour_blitz()
		1:
			start_errorhunt(_tour_eh_done)
		_:
			start_pitch(_tour_pitch_done)


func _tour_blitz() -> void:
	receipt_mode = "tour"
	receipt_done = _tour_blitz_done
	receipts = Data.RECEIPTS.duplicate()
	receipts.shuffle()
	receipts = receipts.slice(0, 6)
	receipt_idx = 0
	receipt_correct = 0
	receipt_streak = 0
	best_streak = 0
	_show_receipt()


func _tour_blitz_done() -> void:
	_tour_done(int(100.0 * receipt_correct / float(receipts.size())))


func _tour_eh_done(found: int, wrong: int, total_bad: int) -> void:
	var raw := (found - 0.5 * wrong) / maxf(float(total_bad), 1.0)
	_tour_done(clampi(int(raw * 100.0), 0, 100))


func _tour_pitch_done(pts: int, mx: int) -> void:
	_tour_done(int(100.0 * pts / float(mx)))


func _tour_done(score: int) -> void:
	GameState.tour_scores.append(score)
	for r in GameState.tour_rivals:
		var s := clampi(int(r["skill"]) + randi_range(-15, 15), 20, 100)
		r["total"] = int(r["total"]) + s
	GameState.tour_round += 1
	_screen(BG_END)
	_banner("Итоги раунда %d" % GameState.tour_round, C_ORANGE, "cup")
	_say("igor", "Ваш результат в раунде: %d баллов." % score)
	_standings(content)
	if GameState.tour_round < 3:
		content.add_child(_button("Следующий раунд", _tour_intro, C_ORANGE))
	else:
		content.add_child(_button("Итоги турнира", _tour_finish, C_GREEN))


func _tour_finish() -> void:
	var place := GameState.tour_place()
	if place == 1:
		show_ending("win_champion")
	elif place <= 3:
		show_ending("win_prize")
	elif place <= 5:
		_tour_middle(place)
	else:
		show_ending("lose_eliminated")


func _tour_middle(place: int) -> void:
	_screen(BG_END)
	_banner("Вы на %d месте" % place, C_ORANGE, "star")
	_say("igor", "Совсем немного не хватило до тройки. Можно сыграть дополнительный раунд-питч или принять платное место.")
	_standings(content)
	content.add_child(_button("Дополнительный раунд", start_pitch.bind(_tour_extra_done), C_ORANGE))
	content.add_child(_button("Принять платное место", show_ending.bind("mid_paid"), C_GRAY))


func _tour_extra_done(pts: int, mx: int) -> void:
	var score := int(100.0 * pts / float(mx))
	show_ending("win_prize" if score >= 70 else "mid_paid")


# ---------------------------------------------------------------- концовки

func _game_over() -> void:
	show_ending(GameState.game_over_ending())


func show_ending(id: String) -> void:
	GameState.unlock_ending(id)
	in_game = false
	cleanup_active = false
	receipt_active = false
	eh_active = false
	hud.hide()
	var e: Dictionary = Data.ENDINGS[id]
	var kind := str(e["kind"])
	var col := C_GREEN if kind == "win" else (C_ORANGE if kind == "mid" else C_RED)
	_screen(BG_GOOD if kind == "win" else (BG_END if kind == "mid" else BG_BAD))
	_add_yard()
	var ico := "cup" if kind == "win" else ("star" if kind == "mid" else "fire")
	_banner("Концовка: " + str(e["title"]), col, ico)
	var c := _card(content, col, C_CREAM)
	c.add_child(_label(str(e["text"]), 21))
	if kind == "win":
		_confetti(90)
		_flash(C_GREEN)
	elif kind == "lose":
		_flash(C_RED)
	_check_toasts()

	var sc := _card(content, C_BLUE)
	sc.add_child(_label("Статус: " + GameState.rank_name(), 19, C_BLUE))
	sc.add_child(_label("Баллы кампании: %d из 100. Концовок открыто: %d из %d" % [GameState.final_score(), GameState.endings_seen.size(), Data.ENDINGS.size()], 16, C_MUTED))

	var topics: Array = GameState.mistakes.keys()
	topics.sort_custom(func(a, b): return GameState.mistakes[a] > GameState.mistakes[b])
	content.add_child(_plain("Над чем поработать", 24))
	if topics.is_empty():
		var oc := _card(content, C_GREEN)
		oc.add_child(_label("Ошибок нет. Отлично!", 20, C_GREEN))
	else:
		var tc := _card(content, C_ORANGE)
		for t in topics:
			tc.add_child(_label("%s: %d" % [Data.TOPICS.get(t, t), GameState.mistakes[t]], 20))
		var i := 0
		for item in GameState.failed_lessons.slice(0, 4):
			var lcol: Color = choice_colors[i % choice_colors.size()]
			var lc := _card(content, lcol)
			lc.add_child(_label(str(item["title"]), 18, lcol))
			lc.add_child(_label(str(item["lesson"]), 17))
			i += 1

	if kind == "lose":
		content.add_child(_button("Попробовать снова (бонус наставника)", _restart.bind(true)))
	else:
		content.add_child(_button("Играть снова", _restart.bind(false)))
	content.add_child(_button("Профиль и награды", show_profile, C_PURPLE))
	content.add_child(_button("Коллекция концовок", show_leaderboard, C_BLUE))


func _restart(bonus: bool) -> void:
	GameState.attempts += 1
	GameState.save_meta()
	GameState.reset()
	GameState.mentor_next = bonus
	prev_stats = {}
	month_note = ""
	show_intro()
