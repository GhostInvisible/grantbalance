extends "res://scripts/base_ui.gd"
## Игровой поток: проектирование, операции проекта, согласование с фондом,
## проверки, события и концовки. Общие элементы интерфейса лежат в base_ui.gd.

var in_game := false
var month_note := ""
var tut_page := 0
var current_event: Dictionary = {}
var current_who := "vera"
var current_after: Callable = Callable()

# проектирование
var design_btns: Dictionary = {}
var design_summary: Label

# операция проекта
var op_pid := ""
var op_variant: Dictionary = {}
var op_mode := "none"
var op_docs_sel: Array = []

# выбор документов
var dp_sel: Dictionary = {}
var dp_btns: Dictionary = {}
var dp_cb: Callable = Callable()

# тренировка комплекта
var set_purpose: Dictionary = {}

# проверка
var audit_kind := ""
var acc_cases: Array = []
var acc_idx := 0
var audit_tranche_text := ""

const KIND_TEXT: Dictionary = {
	"doc_gap": "Нет документов. При проверке вернут часть суммы.",
	"misclass": "Ошибка в учёте. Замечание проверки.",
	"wrong_contract": "Неверный договор. Возврат части суммы и потеря доверия.",
	"unreported": "ОПАСНО: изменение без согласования. Если найдёт проверка, это проигрыш.",
	"late_notice": "Фонд узнал поздно. Замечание останется.",
	"bad_choice": "Расход вопреки правилам. Вернут часть суммы.",
}


func _ready() -> void:
	_build_ui()
	go_game = _go_game
	GameState.reset()
	show_intro()


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
	content.add_child(_label("Вы директор новой НКО. Спроектируйте проект и смету, получите грант и доведите проект до конца: оформляйте документы и договоры, согласовывайте изменения с фондом. Проиграть можно в любой момент.", 19))
	var play := _button("Новая игра", _tutorial_start)
	content.add_child(play)
	_pulse(play)
	var last := GameState.latest_slot()
	var cont := _button("Продолжить", _on_load_slot.bind(last), C_BLUE)
	cont.disabled = last == ""
	content.add_child(cont)
	content.add_child(_button("Сохранения", show_saves, C_TEAL))
	content.add_child(_button("Профиль и награды", show_profile, C_PURPLE))
	content.add_child(_button("Рейтинг и концовки", show_leaderboard, C_ORANGE))
	content.add_child(_button("Глоссарий", show_glossary, C_GRAY))


func _tutorial_start() -> void:
	GameState.reset()
	prev_stats = {}
	month_note = ""
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
		content.add_child(_button("Составить проект и смету", show_design))
	else:
		content.add_child(_button("Дальше", _tut_next))


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


# ---------------------------------------------------------------- проектирование

func _tranche_card() -> void:
	var c := _card(content, C_ORANGE, C_CREAM)
	c.add_child(_plain("График траншей: " + GameState.tranche_name, 18, C_ORANGE))
	for l in GameState.tranche_schedule():
		c.add_child(_label(str(l), 16))
	c.add_child(_label("Транш приходит после проверки, если нарушений нет. Фонд может задержать перевод или удержать часть суммы. Проверка без замечаний даёт бонус.", 15, C_MUTED))
	if float(GameState.tranche_shares[0]) <= 0.2:
		c.add_child(_label("Денег на старте немного: не тратьте всё сразу.", 15, C_RED))


func show_design() -> void:
	hud.hide()
	_screen(BG_BUDGET)
	_banner("Проект и смета", C_BLUE, "coin")
	_say("vera", "Выберите, что войдёт в проект. Каждая строка потом станет реальной операцией, и её придётся оформить документами. Берите только то, что сможете подтвердить.")
	_tranche_card()
	var rules := _card(content, C_PURPLE)
	rules.add_child(_plain("Правила фонда", 18, C_PURPLE))
	rules.add_child(_label("Смета от 540 000 до 600 000 руб.\nАдмин. расходы не больше 90 000, оборудование не больше 150 000, оплата труда не больше 270 000, мероприятия не меньше 150 000.\nНужны: не меньше трёх мероприятий, ответственный за проект и бухгалтерское сопровождение.", 15))
	design_btns = {}
	for cat in Data.LINES:
		content.add_child(_plain(str(Data.LINES[cat]), 22, line_colors[cat].darkened(0.2)))
		for p in Data.POSITIONS:
			if str(p["cat"]) != str(cat):
				continue
			var b := _button("", _design_toggle.bind(str(p["id"])), line_colors[cat])
			design_btns[str(p["id"])] = b
			content.add_child(b)
	var sc := _card(content, C_YELLOW, C_CREAM)
	design_summary = _label("", 16)
	sc.add_child(design_summary)
	content.add_child(_button("Отправить заявку в фонд", _submit_plan, C_GREEN))
	_design_refresh()


func _design_toggle(id: String) -> void:
	GameState.plan_toggle(id)
	_design_refresh()


func _design_refresh() -> void:
	for id in design_btns:
		var b: Button = design_btns[id]
		var p := GameState.pos(str(id))
		var on := GameState.plan_has(str(id))
		var base: Color = line_colors[str(p["cat"])]
		var col := C_GREEN if on else base
		b.text = "%s%s  (%s)\n%s" % ["В проекте: " if on else "", p["name"], GameState.fmt(int(p["cost"])), p["desc"]]
		b.add_theme_stylebox_override("normal", _button_box(col))
		b.add_theme_stylebox_override("hover", _button_box(col.lightened(0.1)))
		b.add_theme_stylebox_override("pressed", _button_box(col.darkened(0.15), true))
	var g := GameState.GRANT_TOTAL
	design_summary.text = "Смета: %s из %s\nОплата труда: %s (до %s)\nМероприятия: %s (от %s), штук: %d\nОборудование: %s (до %s)\nАренда и связь: %s\nАдмин. расходы: %s (до %s)" % [
		GameState.fmt(GameState.plan_total()), GameState.fmt(g),
		GameState.fmt(GameState.plan_cat_total("salary")), GameState.fmt(int(g * GameState.MAX_SALARY_PCT)),
		GameState.fmt(GameState.plan_cat_total("activities")), GameState.fmt(int(g * GameState.MIN_EVENTS_PCT)), GameState.plan_events_count(),
		GameState.fmt(GameState.plan_cat_total("equipment")), GameState.fmt(int(g * GameState.MAX_EQUIPMENT_PCT)),
		GameState.fmt(GameState.plan_cat_total("rent")),
		GameState.fmt(GameState.plan_cat_total("admin")), GameState.fmt(int(g * GameState.MAX_ADMIN_PCT))]


func _submit_plan() -> void:
	var probs: Array = GameState.plan_problems()
	if probs.is_empty():
		_plan_approved()
		return
	GameState.plan_attempts += 1
	GameState.trust = maxi(GameState.trust - 2, 0)
	GameState.log_decision("bad", "Заявка возвращена на доработку", "; ".join(probs), "planning")
	_screen(BG_BAD)
	_flash(C_RED)
	_banner("Заявка возвращена", C_RED, "fire")
	_say("igor", "Заявку я вернуть обязан. Вот замечания. Исправьте смету и отправьте снова. Каждый возврат снижает доверие.")
	for p in probs:
		var c := _card(content, C_RED)
		c.add_child(_label(str(p), 18))
	content.add_child(_button("Доработать смету", show_design, C_BLUE))


func _plan_approved() -> void:
	GameState.approve_plan()
	GameState.add_comp("plan", 4 if GameState.plan_attempts == 0 else 2)
	GameState.log_decision("good", "Смета утверждена", "Вы сами спроектировали проект и уложились в правила фонда.", "planning")
	_screen(BG_GOOD)
	_confetti(50)
	_banner("Смета утверждена!", C_GREEN, "cup")
	_say("igor", "Хорошая заявка. Деньги пойдут по траншам. Все изменения сметы согласовывайте со мной заранее.")
	var c := _card(content, C_GREEN)
	c.add_child(_label("Первый транш: %s" % GameState.fmt(int(GameState.GRANT_TOTAL * float(GameState.tranche_shares[0]))), 20, C_GREEN))
	c.add_child(_label("Теперь каждая строка сметы - это дело, которое нужно выполнить и правильно оформить.", 17))
	content.add_child(_button("Начать проект", _start_project))


func _start_project() -> void:
	in_game = true
	hud.show()
	month_note = "Смета утверждена. Первый транш: %s" % GameState.fmt(int(GameState.GRANT_TOTAL * float(GameState.tranche_shares[0])))
	_autosave()
	show_month(month_note)


# ---------------------------------------------------------------- месяц

func _hint() -> Array:
	var left := 3 - ((GameState.month - 1) % 3)
	var todo := 0
	for id in GameState.ops:
		if GameState.op_status(str(id)) == "todo":
			todo += 1
	if GameState.month == 1:
		return ["vera", "Начните с дел проекта: оформите людей и закупки. Каждую операцию нужно проводить с документами."]
	if left == 1:
		return ["igor", "В этом месяце проверка. Сверьте журнал с бухгалтером, пока не поздно что-то исправить."]
	if GameState.open_issue_count() >= 2:
		return ["vera", "В журнале накапливаются вопросы. Давайте сверим его до проверки."]
	if GameState.burnout >= 60:
		return ["misha", "Мы устали. Можно отдохнуть?"]
	if GameState.cash < 30000:
		return ["vera", "На счёте мало денег. До транша ещё есть расходы, следите за кассой."]
	if todo > 0 and GameState.month >= 7:
		return ["igor", "Часть дел проекта не выполнена, а срок идёт. Результат проекта пока ниже ожидаемого."]
	return ["misha", "Работаем. Что делаем дальше?"]


func _budget_card() -> void:
	var c := _card(content, C_PURPLE)
	c.add_child(_plain("Расход по статьям: факт и план", 18, C_PURPLE))
	for cat in Data.LINES:
		var plan := int(GameState.budget.get(cat, 0))
		if plan <= 0 and int(GameState.spent.get(cat, 0)) <= 0:
			continue
		var sp := int(GameState.spent.get(cat, 0))
		var over := plan > 0 and float(sp) > float(plan) * GameState.OVERSPEND_LIMIT
		c.add_child(_plain("%s: %s из %s" % [Data.LINES[cat], GameState.fmt(sp), GameState.fmt(plan)], 15, C_RED if over else C_DARK))
		var bar := _make_bar(C_RED if over else line_colors[cat])
		bar.max_value = maxi(plan, 1)
		bar.value = mini(sp, maxi(plan, 1))
		c.add_child(bar)


func _money_card() -> void:
	var mf: Dictionary = GameState.money_flow()
	var c := _card(content, C_ORANGE, C_CREAM)
	c.add_child(_plain("Деньги: что уходит со счёта в месяц", 18, C_ORANGE))
	c.add_child(_label("Зарплаты по договорам: %s" % GameState.fmt(-int(mf["team"])), 16))
	c.add_child(_label("Аренда, связь, админ. расходы: %s" % GameState.fmt(-int(mf["fixed"])), 16))
	var net: int = int(mf["net"])
	c.add_child(_label("Итого в месяц: %s" % GameState.fmt(net), 20, C_ORANGE))
	if int(mf["tranche"]) > 0:
		c.add_child(_label("Ближайший транш: +%s через %d мес. (если проверка пройдена)" % [GameState.fmt(int(mf["tranche"])).replace(" руб.", ""), int(mf["left"])], 16, C_GREEN))
	if int(mf["incoming"]) > 0:
		c.add_child(_label("Транш уже в пути: +%s" % GameState.fmt(int(mf["incoming"])).replace(" руб.", ""), 16, C_GREEN))
	if int(mf["runway"]) >= 0:
		c.add_child(_label("Без новых доходов денег хватит на %d мес." % int(mf["runway"]), 15, C_MUTED))


func _drift_card() -> void:
	var c := _card(content, C_BLUE)
	c.add_child(_plain("Что меняется само каждый месяц", 18, C_BLUE))
	var t: Dictionary = GameState.drift_forecast()
	_chips(c, {"kpi": t["kpi"], "docs": t["docs"], "burnout": t["burnout"], "trust": t["trust"]})
	var names: Array = []
	for l in GameState.drift_lines(true):
		names.append(str(l["name"]))
	c.add_child(_label("Источники: " + ", ".join(names), 15, C_MUTED))


func _goal_card() -> void:
	var expected := int(80.0 * GameState.month / float(GameState.max_month))
	var c := _card(content, C_TEAL)
	c.add_child(_plain("Ход проекта", 18, C_TEAL))
	c.add_child(_plain("Результат: %d%%, к этому месяцу ожидается около %d%%" % [GameState.kpi, expected], 16))
	var bar := _make_bar(C_GREEN if GameState.kpi >= expected else C_ORANGE)
	bar.max_value = 100
	bar.value = GameState.kpi
	c.add_child(bar)
	c.add_child(_plain("Мероприятий проведено: %d из %d" % [GameState.events_done(), GameState.plan_events_count()], 16))


func _grid_button(grid: GridContainer, text: String, cb: Callable, color: Color, disabled := false) -> void:
	var b := _button(text, cb, color)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = disabled
	grid.add_child(b)


func show_month(note := "") -> void:
	in_game = true
	hud.show()
	update_hud()
	_screen(BG_MONTH)
	_set_nav(true)
	_add_yard()
	_banner("Месяц %d из %d" % [GameState.month, GameState.max_month], C_ORANGE, "leaf")
	_goal_card()
	_budget_card()
	_money_card()
	_drift_card()
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
	_grid_button(grid, "Дела проекта", show_ops, C_GREEN, false)
	_grid_button(grid, "Согласования с фондом", show_requests, C_BLUE, false)
	_grid_button(grid, "Бухгалтерия", show_books, C_TEAL, false)
	_grid_button(grid, "Консультация у куратора", _do_consult, C_PURPLE, no_ap or GameState.consulted)
	_grid_button(grid, "Отдохнуть командой", _do_rest, C_PINK, no_ap)
	var endb := _button("Завершить месяц", _end_month, C_DARK)
	content.add_child(endb)
	if no_ap:
		_pulse(endb)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 8)
	content.add_child(brow)
	var sb := _button("Сохранения", show_saves, C_TEAL)
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brow.add_child(sb)
	var gb := _button("Глоссарий", show_glossary, C_GRAY)
	gb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brow.add_child(gb)


func _after_action(msg: String) -> void:
	month_note += msg + "\n"
	if GameState.check_game_over() != "":
		update_hud()
		_game_over()
		return
	show_month(month_note)


func _do_rest() -> void:
	_after_action(GameState.do_rest())


func _do_consult() -> void:
	var tip := GameState.consult()
	update_hud()
	_screen(BG_REPORT)
	_set_nav(true)
	_banner("Консультация у куратора", C_PURPLE, "doc")
	_say("igor", tip)
	content.add_child(_button("Спасибо", show_month.bind(month_note), C_PURPLE))


# ---------------------------------------------------------------- дела проекта

func show_ops() -> void:
	hud.show()
	update_hud()
	_screen(BG_MONTH)
	_set_nav(true)
	_banner("Дела проекта", C_GREEN, "leaf")
	_say("vera", "Это строки вашей сметы. Каждое дело нужно выполнить и оформить: выбрать вариант, собрать документы и записать в журнал. Каждое дело - одно действие.")
	var groups: Array = [["staff", "Люди и договоры"], ["equip", "Закупки оборудования"], ["event", "Мероприятия"]]
	var any := false
	for g in groups:
		var header_added := false
		for id in GameState.plan_ids:
			var p := GameState.pos(str(id))
			if str(p["kind"]) != str(g[0]):
				continue
			if not header_added:
				content.add_child(_plain(str(g[1]), 22))
				header_added = true
			any = true
			var st := GameState.op_status(str(id))
			var label := "%s  (%s)" % [p["name"], GameState.fmt(int(p["cost"]))]
			match st:
				"done":
					var c := _card(content, C_GREEN)
					c.add_child(_label("Выполнено: " + str(p["name"]), 18, C_GREEN))
				"waiting":
					var c2 := _card(content, C_BLUE)
					c2.add_child(_label("Ждёт ответа фонда: " + str(p["name"]), 18, C_BLUE))
				"approved":
					var b := _button(label + "\nСогласовано фондом: можно выполнять", _start_op.bind(str(id)), C_TEAL)
					b.disabled = GameState.ap <= 0
					content.add_child(b)
				_:
					var b2 := _button(label + "\n" + str(p["desc"]), _start_op.bind(str(id)), line_colors[str(p["cat"])])
					b2.disabled = GameState.ap <= 0
					content.add_child(b2)
	if not any:
		content.add_child(_label("В смете нет дел.", 18, C_MUTED))
	content.add_child(_button("Назад", show_month.bind(month_note), C_GRAY))


func _start_op(pid: String) -> void:
	op_pid = pid
	op_mode = "none"
	if GameState.op_status(pid) == "approved":
		var vid := str(GameState.ops[pid]["variant"])
		for v in GameState.variants_for(pid):
			if str(v["id"]) == vid:
				op_variant = v
		op_mode = "approved"
		_op_docs()
	else:
		_op_variants()


func _op_variants() -> void:
	var p := GameState.pos(op_pid)
	hud.show()
	_screen(BG_EVENT)
	_banner(str(p["name"]), C_ORANGE, "doc")
	var prompt := "Как действуем?"
	var who := "vera"
	match str(p["kind"]):
		"staff":
			prompt = "Нужно оформить отношения с исполнителем. %s Какой договор заключаем?" % str(p["desc"])
		"equip":
			prompt = "Закупка по смете: %s Как покупаем?" % str(p["desc"])
		"event":
			prompt = "Мероприятие по смете: %s Как проводим?" % str(p["desc"])
			who = "misha"
	_say(who, prompt)
	var denied: Array = GameState.ops[op_pid]["denied"]
	var i := 0
	for v in GameState.variants_for(op_pid):
		var txt := str(v["text"])
		var off := false
		if denied.has(str(v["id"])):
			txt += "\nФонд уже отказал в этом варианте"
			off = true
		var b := _button(txt, _op_pick.bind(v), choice_colors[i % choice_colors.size()])
		b.disabled = off
		content.add_child(b)
		i += 1
	content.add_child(_button("Назад", show_ops, C_GRAY))


func _op_pick(v: Dictionary) -> void:
	op_variant = v
	op_mode = "none"
	if bool(v["appr"]):
		_op_approval()
	else:
		_op_docs()


func _op_approval() -> void:
	hud.show()
	_screen(BG_REPORT)
	_banner("Изменение сметы", C_PURPLE, "doc")
	_say("vera", "Этот вариант отличается от утверждённой сметы. Как поступим с фондом?")
	content.add_child(_button("Написать фонду с обоснованием (коммерческие предложения, письмо) и дождаться ответа", _op_request.bind(true), C_GREEN))
	content.add_child(_button("Написать фонду коротким письмом и дождаться ответа", _op_request.bind(false), C_BLUE))
	content.add_child(_button("Сделать сразу, а фонду сообщить потом", _op_go.bind("late"), C_ORANGE))
	content.add_child(_button("Сделать сразу и никому не говорить", _op_go.bind("silent"), C_RED))
	content.add_child(_button("Назад", _op_variants, C_GRAY))


func _op_request(strong: bool) -> void:
	GameState.send_request(op_pid, str(op_variant["id"]), strong)
	update_hud()
	_after_action("Письмо в фонд отправлено: «%s». Ответ придёт в начале следующего месяца." % GameState.pos(op_pid)["name"])


func _op_go(mode: String) -> void:
	op_mode = mode
	_op_docs()


func _op_docs() -> void:
	var required: Array = op_variant["docs"].duplicate()
	if op_mode == "approved":
		required.append("approval_letter")
	_docs_picker("Комплект документов", C_TEAL, "vera",
		"Соберите комплект для операции «%s». Отметьте только те документы, которые действительно нужны и у вас есть." % GameState.pos(op_pid)["name"],
		required, _op_after_docs, _op_variants)


func _op_after_docs(sel: Array) -> void:
	op_docs_sel = sel
	hud.show()
	_screen(BG_BUDGET)
	_banner("Запись в журнал", C_BLUE, "coin")
	_say("vera", "Куда записываем операцию в журнале учёта? Статья должна соответствовать смете.")
	for cat in Data.LINES:
		content.add_child(_button(str(Data.LINES[cat]), _op_finish.bind(str(cat)), line_colors[cat]))


func _op_finish(cat: String) -> void:
	var msg := GameState.finish_op(op_pid, op_variant, op_mode, op_docs_sel, cat)
	update_hud()
	_after_action(msg)


# ---------------------------------------------------------------- выбор документов

func _docs_picker(title: String, color: Color, who: String, say_text: String, required: Array, cb: Callable, back: Callable) -> void:
	dp_cb = cb
	dp_sel = {}
	dp_btns = {}
	var opts: Array = required.duplicate()
	var pool: Array = []
	for k in Data.DOC_TYPES:
		if not required.has(k):
			pool.append(k)
	pool.shuffle()
	for i in range(mini(4, pool.size())):
		opts.append(pool[i])
	var has_noise := false
	for k in opts:
		if Data.DOC_NOISE.has(k):
			has_noise = true
	if not has_noise:
		var n: String = str(Data.DOC_NOISE.pick_random())
		if not opts.has(n):
			opts.append(n)
	opts.shuffle()
	hud.show()
	_screen(BG_REPORT)
	_banner(title, color, "doc")
	_say(who, say_text)
	for k in opts:
		var b := _button(str(Data.DOC_TYPES[k]), _dp_toggle.bind(str(k)), C_BLUE)
		b.custom_minimum_size = Vector2(0, 50)
		dp_btns[str(k)] = b
		content.add_child(b)
	content.add_child(_button("Готово", _dp_done, C_GREEN))
	if back.is_valid():
		content.add_child(_button("Назад", back, C_GRAY))


func _dp_toggle(k: String) -> void:
	var on := not dp_sel.has(k)
	if on:
		dp_sel[k] = true
	else:
		dp_sel.erase(k)
	var b: Button = dp_btns[k]
	var col := C_ORANGE if on else C_BLUE
	b.add_theme_stylebox_override("normal", _button_box(col))
	b.add_theme_stylebox_override("hover", _button_box(col.lightened(0.1)))
	b.add_theme_stylebox_override("pressed", _button_box(col.darkened(0.15), true))
	b.text = ("Приложить: " if on else "") + str(Data.DOC_TYPES[k])


func _dp_done() -> void:
	var sel: Array = dp_sel.keys()
	dp_cb.call(sel)


# ---------------------------------------------------------------- согласования

func show_requests() -> void:
	hud.show()
	update_hud()
	_screen(BG_REPORT)
	_set_nav(true)
	_banner("Согласования с фондом", C_BLUE, "doc")
	_say("igor", "Все изменения сметы согласуют заранее. Ответ приходит в начале следующего месяца. Письмо с обоснованием одобряют чаще.")
	if GameState.requests.is_empty():
		content.add_child(_label("Писем пока не было.", 18, C_MUTED))
	for r in GameState.requests:
		var st := str(r["status"])
		var col := C_BLUE if st == "waiting" else (C_GREEN if st == "approved" else C_RED)
		var word := "Ждёт ответа" if st == "waiting" else ("Согласовано" if st == "approved" else "Отказано")
		var c := _card(content, col)
		c.add_child(_label("%s: %s" % [word, GameState.pos(str(r["pos"]))["name"]], 18, col))
		c.add_child(_label("Письмо с обоснованием" if bool(r["strong"]) else "Короткое письмо", 15, C_MUTED))
	content.add_child(_button("Назад", show_month.bind(month_note), C_GRAY))


# ---------------------------------------------------------------- бухгалтерия

func show_books() -> void:
	hud.show()
	update_hud()
	_screen(BG_BUDGET)
	_set_nav(true)
	_banner("Бухгалтерия", C_TEAL, "coin")
	_say("vera", "Могу сверить журнал операций с документами и помочь исправить ошибки до проверки. Или потренируем комплекты документов.")
	var b1 := _button("Сверка журнала с бухгалтером\n1 действие: покажу, что не так, и помогу исправить", _start_reconcile, C_TEAL)
	b1.disabled = GameState.ap <= 0
	content.add_child(b1)
	var b2 := _button("Тренировка: комплект документов\n1 действие", _start_docset, C_BLUE)
	b2.disabled = GameState.ap <= 0
	content.add_child(b2)
	content.add_child(_button("Назад", show_month.bind(month_note), C_GRAY))


func _start_reconcile() -> void:
	GameState.ap -= 1
	update_hud()
	show_reconcile()


func show_reconcile() -> void:
	hud.show()
	_screen(BG_BUDGET)
	_banner("Сверка журнала", C_TEAL, "coin")
	var open := 0
	for i in range(GameState.issues.size()):
		var it: Dictionary = GameState.issues[i]
		if str(it["status"]) != "open":
			continue
		open += 1
		var fatal := str(it["kind"]) == "unreported"
		var c := _card(content, C_RED if fatal else C_ORANGE)
		c.add_child(_label(str(it["title"]), 18, C_RED if fatal else C_DARK))
		c.add_child(_label(str(KIND_TEXT.get(str(it["kind"]), "")), 15, C_MUTED))
		c.add_child(_plain("Сумма операции: %s" % GameState.fmt(int(it["amount"])), 15, C_MUTED))
		if GameState.can_fix(it):
			var cost := GameState.fix_cost(it)
			var txt := "Исправить" if cost == 0 else "Исправить (%s)" % GameState.fmt(cost)
			if str(it["kind"]) == "unreported":
				txt = "Сообщить фонду сейчас"
			c.add_child(_button(txt, _on_fix.bind(i), C_GREEN))
	if open == 0:
		_say("vera", "Журнал в порядке: замечаний не нашла. Так держать!")
	else:
		_say("vera", "Нашла %d замечаний. Исправленное до проверки не попадёт в акт проверки." % open)
	content.add_child(_button("Готово", show_month.bind(month_note), C_GRAY))


func _on_fix(i: int) -> void:
	var msg := GameState.fix_issue(i)
	update_hud()
	_toast("Исправлено", msg, C_GREEN)
	show_reconcile()


func _start_docset() -> void:
	set_purpose = Data.DOC_SETS.pick_random()
	_docs_picker("Комплект документов", C_BLUE, "vera",
		"Задача: %s. Какие документы нужны? Отметьте только нужные." % str(set_purpose["title"]),
		set_purpose["docs"], _docset_done, show_books)


func _docset_done(sel: Array) -> void:
	var res: Dictionary = GameState.docset_result(set_purpose, sel)
	update_hud()
	var ok: bool = res["ok"]
	_screen(BG_GOOD if ok else BG_BAD)
	_banner("Верно!" if ok else "Есть ошибки", C_GREEN if ok else C_RED, "doc")
	_say("vera", str(res["text"]))
	if ok:
		_confetti(30)
	content.add_child(_button("Дальше", show_month.bind(month_note)))


# ---------------------------------------------------------------- конец месяца и события

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
		var net: int = int(l.get("kpi", 0)) + int(l.get("docs", 0)) + int(l.get("trust", 0)) - int(l.get("burnout", 0))
		var c := _card(content, C_GREEN if net >= 0 else C_RED)
		c.add_child(_label(str(l["name"]), 18))
		_chips(c, d)
	var tc := _card(content, C_BLUE, C_CREAM)
	tc.add_child(_label("Всего за месяц", 20, C_BLUE))
	_chips(tc, {"kpi": total["kpi"], "docs": total["docs"], "burnout": total["burnout"], "trust": total["trust"]})
	content.add_child(_button("Дальше", _after_summary))


func _after_summary() -> void:
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
		content.add_child(_button(str(ch["text"]), _on_choice.bind(ch), choice_colors[i % choice_colors.size()]))
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
		show_event(Data.CASH_GAP, "Счёт: %s" % GameState.fmt(GameState.cash), Callable())
		return
	var kind := GameState.audit_due()
	if kind != "":
		start_audit(kind)
		return
	_next_month()


func _next_month() -> void:
	GameState.next_month()
	month_note = ""
	var msgs: Array = GameState.resolve_requests()
	if not msgs.is_empty():
		_show_replies(msgs)
		return
	_after_replies()


func _show_replies(msgs: Array) -> void:
	hud.show()
	update_hud()
	_screen(BG_REPORT)
	_banner("Ответ фонда", C_PURPLE, "doc")
	for m in msgs:
		_say("igor", str(m))
		month_note += str(m) + "\n"
	content.add_child(_button("Дальше", _after_replies))


func _after_replies() -> void:
	var ce := GameState.chapter_event()
	if not ce.is_empty():
		show_event(ce, "Новая глава истории", _after_chapter)
		return
	_after_chapter()


func _after_chapter() -> void:
	if GameState.check_game_over() != "":
		_game_over()
		return
	_autosave()
	show_month(month_note)


# ---------------------------------------------------------------- проверка фонда

func start_audit(kind: String) -> void:
	audit_kind = kind
	audit_tranche_text = ""
	if kind == "surprise":
		GameState.surprise_done += 1
	acc_cases = Data.ACCEPT_CASES.duplicate()
	acc_cases.shuffle()
	acc_cases = acc_cases.slice(0, 6)
	acc_idx = 0
	hud.show()
	update_hud()
	_screen(BG_REPORT)
	_flash(C_PURPLE)
	_banner("Внезапная проверка!" if kind == "surprise" else "Плановая проверка", C_PURPLE, "doc")
	if kind == "surprise":
		_say("igor", "Здравствуйте, я без предупреждения. Показывайте отчёт и журнал операций.")
	else:
		_say("igor", "Пришло время проверки. Сначала решим, что включаем в отчёт, потом проверим журнал операций.")
	var c := _card(content, C_BLUE)
	c.add_child(_label("Шпаргалка Веры:", 19, C_BLUE))
	c.add_child(_label("Включаем: расход по смете, с полным комплектом документов.\nНе включаем: личное, штрафы, подарки, алкоголь, расходы вне сметы и без согласования, дубли.\nДорабатываем: расход допустимый, но документы неполные.", 17))
	content.add_child(_button("Начать", _acc_show, C_PURPLE))


func _acc_show() -> void:
	var c: Dictionary = acc_cases[acc_idx]
	_screen(BG_REPORT)
	_banner("Что включаем в отчёт? %d из %d" % [acc_idx + 1, acc_cases.size()], C_PURPLE, "doc")
	var card := _card(content, C_YELLOW, Color(1, 0.98, 0.88))
	card.add_child(_label(str(c["text"]), 22))
	content.add_child(_button("Включить в отчёт", _acc_answer.bind("include"), C_GREEN))
	content.add_child(_button("Не включать в отчёт", _acc_answer.bind("exclude"), C_RED))
	content.add_child(_button("Доработать документы", _acc_answer.bind("fix"), C_ORANGE))


func _acc_answer(choice: String) -> void:
	var c: Dictionary = acc_cases[acc_idx]
	var res: Dictionary = GameState.accept_result(c, choice)
	update_hud()
	var ok: bool = res["ok"]
	_screen(BG_GOOD if ok else BG_BAD)
	_flash(C_GREEN if ok else C_RED)
	_banner("Верно!" if ok else "Ошибка", C_GREEN if ok else C_RED, "heart" if ok else "fire")
	_say("vera", str(res["text"]))
	acc_idx += 1
	if acc_idx < acc_cases.size():
		content.add_child(_button("Дальше", _acc_show, C_PURPLE))
	else:
		content.add_child(_button("Проверка журнала операций", _audit_journal, C_PURPLE))


func _audit_journal() -> void:
	var findings: Array = GameState.audit_findings()
	var verdict := GameState.apply_findings(findings)
	if audit_kind == "scheduled" and verdict == "":
		audit_tranche_text = GameState.pay_tranche(findings)
	update_hud()
	var clean := findings.is_empty()
	_screen(BG_GOOD if clean else BG_BAD)
	_banner("Журнал проверен", C_GREEN if clean else C_RED, "cup" if clean else "fire")
	if clean:
		_confetti(50)
		_say("igor", "Замечаний нет. Отличная работа.")
	else:
		_say("igor", "Я нашёл замечания. Вот что вам предъявляется.")
	var total_refund := 0
	for f in findings:
		var c := _card(content, C_RED if bool(f["fatal"]) else C_ORANGE)
		c.add_child(_label(str(f["title"]), 18, C_RED if bool(f["fatal"]) else C_DARK))
		var parts: Array = []
		if int(f["refund"]) > 0:
			parts.append("вернуть %s" % GameState.fmt(int(f["refund"])))
			total_refund += int(f["refund"])
		parts.append("доверие %+d" % int(f["trust"]))
		if bool(f["fatal"]):
			parts.append("нецелевое использование")
		c.add_child(_label(", ".join(parts), 16, C_MUTED))
	if total_refund > 0:
		var tc := _card(content, C_RED, Color(1, 0.93, 0.92))
		tc.add_child(_label("К возврату фонду: %s" % GameState.fmt(total_refund), 20, C_RED))
	if audit_tranche_text != "":
		var sc := _card(content, C_YELLOW, C_CREAM)
		sc.add_child(_label(audit_tranche_text, 18))
	content.add_child(_button("Дальше", _audit_continue.bind(verdict)))


func _audit_continue(verdict: String) -> void:
	if verdict != "":
		show_ending(verdict)
		return
	if GameState.check_game_over() != "":
		_game_over()
		return
	if audit_kind == "scheduled" and GameState.month >= GameState.max_month:
		_finish_project()
		return
	_next_month()


func _finish_project() -> void:
	var id := GameState.final_ending()
	GameState.best_score = maxi(GameState.best_score, GameState.final_score())
	GameState.save_meta()
	show_ending(id)


# ---------------------------------------------------------------- сохранения

func _autosave() -> void:
	GameState.save_to("auto", month_note)


func _small_button(text: String, cb: Callable, color: Color) -> Button:
	var b := _button(text, cb, color)
	b.custom_minimum_size = Vector2(0, 46)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 16)
	return b


func show_saves() -> void:
	if in_game:
		hud.show()
		update_hud()
	else:
		hud.hide()
	_screen(BG_BUDGET)
	_set_nav(in_game)
	_banner("Сохранения", C_BLUE, "doc")
	if in_game:
		_say("vera", "Сохраняйте игру в любой слот. Автосохранение делается в начале каждого месяца.")
	else:
		content.add_child(_label("Здесь можно загрузить игру или удалить старое сохранение.", 18, C_MUTED))
	for slot in GameState.SAVE_SLOTS:
		var sl: String = str(slot)
		var info := GameState.slot_info(sl)
		var has := not info.is_empty()
		var title := "Автосохранение" if sl == "auto" else "Слот " + sl
		var c := _card(content, C_BLUE if has else C_GRAY)
		c.add_child(_label(title, 20, C_BLUE if has else C_GRAY))
		if has:
			c.add_child(_label("Месяц %d из 12, счёт %s, результат %d%%, доверие %d" % [info["month"], GameState.fmt(int(info["cash"])), info["kpi"], info["trust"]], 16))
			c.add_child(_plain(str(info["date"]), 14, C_MUTED))
		else:
			c.add_child(_label("Пусто", 16, C_MUTED))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		c.add_child(row)
		if in_game and sl != "auto":
			row.add_child(_small_button("Сохранить", _on_save_slot.bind(sl), C_GREEN))
		if has:
			row.add_child(_small_button("Загрузить", _on_load_slot.bind(sl), C_BLUE))
			row.add_child(_small_button("Удалить", _on_delete_slot.bind(sl), C_RED))
	content.add_child(_button("Назад", _go_game, C_GRAY))


func _on_save_slot(sl: String) -> void:
	if GameState.save_to(sl, month_note):
		_toast("Игра сохранена", "Слот " + sl, C_GREEN)
	else:
		_toast("Не удалось сохранить", "Проверьте права на запись", C_RED)
	show_saves()


func _on_load_slot(sl: String) -> void:
	var note := GameState.load_from(sl)
	if note == "?":
		_toast("Не удалось загрузить", "Сохранение повреждено, пустое или от старой версии игры", C_RED)
		return
	prev_stats = {}
	in_game = true
	month_note = note
	_toast("Игра загружена", "Продолжаем с месяца %d" % GameState.month, C_BLUE)
	show_month(month_note)


func _on_delete_slot(sl: String) -> void:
	GameState.delete_slot(sl)
	show_saves()


# ---------------------------------------------------------------- концовки и итоговый отчёт

func _game_over() -> void:
	show_ending(GameState.game_over_ending())


func show_ending(id: String) -> void:
	GameState.unlock_ending(id)
	GameState.best_score = maxi(GameState.best_score, GameState.final_score())
	GameState.save_meta()
	in_game = false
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

	# почему такой итог
	content.add_child(_plain("Почему такой итог", 24))
	var fc := _card(content, C_BLUE)
	for f in GameState.ending_facts():
		fc.add_child(_label(str(f), 17))
	if id == "lose_unreported":
		fc.add_child(_label("Главная причина: изменение сметы без согласования с фондом.", 18, C_RED))
	elif id == "lose_refund":
		fc.add_child(_label("Главная причина: слишком много денег пришлось вернуть из-за нарушений.", 18, C_RED))
	elif id == "lose_results":
		fc.add_child(_label("Главная причина: проект не выполнен, мероприятия не проведены вовремя.", 18, C_RED))

	var bad: Array = []
	var good: Array = []
	for j in GameState.journal:
		if str(j["kind"]) == "bad":
			bad.append(j)
		else:
			good.append(j)
	content.add_child(_plain("Какие действия привели к этому", 24))
	if bad.is_empty():
		var oc := _card(content, C_GREEN)
		oc.add_child(_label("Серьёзных ошибок не было.", 18, C_GREEN))
	var shown := 0
	for j in bad:
		if shown >= 10:
			break
		var lc := _card(content, C_RED)
		lc.add_child(_label("Месяц %d: %s" % [j["m"], j["title"]], 17, C_RED))
		if str(j["lesson"]) != "":
			lc.add_child(_label(str(j["lesson"]), 15, C_MUTED))
		shown += 1
	content.add_child(_plain("Что получилось хорошо", 24))
	shown = 0
	for j in good:
		if shown >= 6:
			break
		var gc := _card(content, C_GREEN)
		gc.add_child(_label("Месяц %d: %s" % [j["m"], j["title"]], 17, C_GREEN))
		shown += 1
	if good.is_empty():
		content.add_child(_label("Хороших решений в журнале пока нет.", 16, C_MUTED))

	content.add_child(_plain("Навыки", 24))
	var sc := _card(content, C_PURPLE)
	for k in Data.COMPETENCIES:
		sc.add_child(_label("%s: %d" % [Data.COMPETENCIES[k], int(GameState.comp[k])], 17))
	sc.add_child(_label("Статус: " + GameState.rank_name(), 18, C_PURPLE))

	var topics: Array = GameState.mistakes.keys()
	topics.sort_custom(func(a, b): return GameState.mistakes[a] > GameState.mistakes[b])
	if not topics.is_empty():
		content.add_child(_plain("Над чем поработать", 24))
		var tc := _card(content, C_ORANGE)
		for t in topics:
			tc.add_child(_label("%s: %d" % [Data.TOPICS.get(t, t), GameState.mistakes[t]], 18))

	content.add_child(_button("Играть снова", _restart))
	content.add_child(_button("Профиль и награды", show_profile, C_PURPLE))
	content.add_child(_button("Коллекция концовок", show_leaderboard, C_BLUE))


func _restart() -> void:
	GameState.attempts += 1
	GameState.save_meta()
	GameState.reset()
	prev_stats = {}
	month_note = ""
	show_intro()
