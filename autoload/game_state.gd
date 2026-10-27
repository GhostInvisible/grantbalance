extends Node
## Состояние и правила игры. Интерфейса здесь нет.

const Data = preload("res://data/game_data.gd")

const AP_PER_MONTH := 3
const GRANT_TOTAL := 300000
## Доли траншей по кварталам: [старт, Q1, Q2, Q3, Q4, Q5, Q6]
const TRANCHES: Array = [0.30, 0.25, 0.25, 0.20, 0.0, 0.0, 0.0]
const PLAN: Array = [15, 29, 48, 70]
const LEVEL2_KPI := 25
const LEVEL3_KPI := 55
const STAFF_MAX := 3
const EXTENSION_CASH := 130000
const META_PATH := "user://meta.cfg"

# Правила донора для бюджета (учебные, у реального донора свои)
const MAX_ADMIN_PCT := 0.15
const MAX_EQUIPMENT_PCT := 0.20
const MIN_ACTIVITIES_PCT := 0.25
const MIN_SALARY_PCT := 0.30
const MIN_RENT := 12000
const OVERSPEND_LIMIT := 1.10

var month := 1
var max_month := 12
var season2 := false
var ext_base_kpi := 0
var ap := 3
var cash := 0
var trust := 50
var docs := 80
var burnout := 10
var kpi := 0
var budget: Dictionary = {}
var spent: Dictionary = {}
var monthly: Dictionary = {}
var mistakes: Dictionary = {}
var failed_lessons: Array = []
var pending_tranche := 0
var cash_gaps := 0
var events_pool: Array = []
var staff := 0
var team: Array = []
var items: Array = []
var mods: Array = []
var done_once: Dictionary = {}
var last_drift: Array = []
var difficulty := 1
var last_cash_delta := 0
var extra_plan := 0
var extra_burnout := 0
var last_level := 1
var level_up_pending := 0

# вариативность прохождения
var scenario_id := "yard"
var scn_plan := 0
var vol_bonus := 0
var donor: Dictionary = {}
var docs_need := 70
var neg_mult := 1.0
var price_mult := 1.0
var spec := ""
var acts: Dictionary = {}
var flags: Dictionary = {}
var used_followups: Array = []
var offer_month := 6
var last_sig := ""

# навыки и поручения
var comp: Dictionary = {}
var quest: Dictionary = {}
var q_acts := 0
var q_docs := 0
var q_rest := 0
var q_pitch := 0
var q_report := 0
var q_spent := 0
var q_done := false
var perfect_reports := 0
var best_streak_total := 0

# турнир
var tour_rivals: Array = []
var tour_scores: Array = []
var tour_round := 0

# сохраняется между играми
var endings_seen: Dictionary = {}
var ach: Dictionary = {}
var new_unlocks: Array = []
var best_score := 0
var attempts := 0
var mentor_next := false


func _ready() -> void:
	load_meta()


# ---------------------------------------------------------------- сохранение

func load_meta() -> void:
	var cf := ConfigFile.new()
	if cf.load(META_PATH) != OK:
		return
	for k in cf.get_section_keys("endings"):
		endings_seen[k] = true
	for k in cf.get_section_keys("ach"):
		ach[k] = true
	best_score = int(cf.get_value("meta", "best", 0))
	attempts = int(cf.get_value("meta", "attempts", 0))


func save_meta() -> void:
	var cf := ConfigFile.new()
	for k in endings_seen:
		cf.set_value("endings", k, true)
	for k in ach:
		cf.set_value("ach", k, true)
	cf.set_value("meta", "best", best_score)
	cf.set_value("meta", "attempts", attempts)
	cf.save(META_PATH)


func unlock(id: String) -> void:
	if ach.has(id):
		return
	ach[id] = true
	new_unlocks.append(id)
	save_meta()


func unlock_ending(id: String) -> void:
	endings_seen[id] = true
	if str(Data.ENDINGS[id]["kind"]) == "win":
		unlock("winner")
	if endings_seen.size() >= 3:
		unlock("explorer")
	save_meta()


func check_achievements() -> void:
	if int(acts.get("cleanup", 0)) >= 3:
		unlock("clean")
	if docs >= 95:
		unlock("docs100")
	if staff >= 2:
		unlock("team")
	if int(acts.get("festival", 0)) >= 1:
		unlock("party")
	if flags.has("honest"):
		unlock("honest")
	if flags.has("audit_ok"):
		unlock("audit")
	if best_streak_total >= 5:
		unlock("streak")
	if perfect_reports >= 2:
		unlock("perfect")
	if flags.has("pitch_ace"):
		unlock("pitch")
	if level() >= 3:
		unlock("lvl3")


# ---------------------------------------------------------------- старт

func reset() -> void:
	month = 1
	max_month = 12
	season2 = false
	ext_base_kpi = 0
	ap = AP_PER_MONTH
	cash = 10000
	trust = 50
	docs = 80
	burnout = 10
	kpi = 0
	budget = {}
	spent = {"salary": 0, "activities": 0, "equipment": 0, "rent": 0, "admin": 0}
	monthly = {}
	mistakes = {}
	failed_lessons = []
	pending_tranche = 0
	cash_gaps = 0
	staff = 0
	team = []
	items = []
	mods = []
	done_once = {}
	last_drift = []
	extra_plan = 0
	extra_burnout = 0
	last_level = 1
	level_up_pending = 0
	scenario_id = "yard"
	scn_plan = 0
	vol_bonus = 0
	spec = ""
	acts = {}
	flags = {}
	used_followups = []
	last_sig = ""
	comp = {"comm": 0, "analytics": 0, "docs": 0, "lead": 0}
	quest = {}
	q_acts = 0
	q_docs = 0
	q_rest = 0
	q_pitch = 0
	q_report = 0
	q_spent = 0
	q_done = false
	perfect_reports = 0
	best_streak_total = 0
	tour_rivals = []
	tour_scores = []
	tour_round = 0
	new_unlocks = []
	donor = Data.DONORS.pick_random()
	docs_need = int(donor["docs"])
	neg_mult = float(donor["neg"])
	var prices: Array = [0.9, 1.0, 1.0, 1.1, 1.2]
	price_mult = float(prices.pick_random())
	var months: Array = [5, 6, 7]
	offer_month = int(months.pick_random())
	_refill_events()


func _refill_events() -> void:
	events_pool = Data.EVENTS.duplicate()
	events_pool.append_array(Data.EXTRA_EVENTS)
	events_pool.shuffle()


func fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var cnt := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			out = " " + out
	return ("-" if n < 0 else "") + out + " руб."


func start_scenario(s: Dictionary) -> void:
	scenario_id = str(s["id"])
	cash = int(s["cash"])
	trust = int(s["trust"])
	scn_plan = int(s["plan"])
	docs += int(s["docs"])
	vol_bonus = int(s["vol"])
	if mentor_next:
		trust += 8
		mentor_next = false
	_clamp()


func start_project(b: Dictionary) -> void:
	budget = b.duplicate()
	for line in ["salary", "rent", "admin"]:
		monthly[line] = roundi(float(budget[line]) / 12.0)
	cash += int(GRANT_TOTAL * TRANCHES[0])
	unlock("start")


func level() -> int:
	if kpi >= LEVEL3_KPI:
		return 3
	if kpi >= LEVEL2_KPI:
		return 2
	return 1


func take_level_up() -> int:
	var l := level_up_pending
	level_up_pending = 0
	return l


func plan_for(q: int) -> int:
	if q <= 4:
		var mults: Array = [0.9, 1.0, 1.08]
		var base := int(float(PLAN[q - 1]) * float(mults[difficulty]))
		return mini(base + scn_plan * q + extra_plan, 98)
	return mini(ext_base_kpi + 10 * (q - 4), 98)


func act_cost(a: Dictionary) -> int:
	return roundi(float(a["cost"]) * price_mult)


func item_cost(it: Dictionary) -> int:
	return roundi(float(it["cost"]) * price_mult)


func scene_state() -> Dictionary:
	return {"kpi": kpi, "level": level(), "tired": burnout, "month": month, "scenario": scenario_id,
		"spec": spec, "acts": acts, "items": items, "staff": staff}


func scene_sig() -> String:
	return "%s|%s|%d|%s|%d|%d" % [str(acts), str(items), staff, spec, level(), int(kpi / 10.0)]


func _clamp() -> void:
	trust = clampi(trust, 0, 100)
	docs = clampi(docs, 0, 100)
	burnout = clampi(burnout, 0, 100)
	kpi = clampi(kpi, 0, 100)
	var lv := level()
	if lv > last_level:
		last_level = lv
		level_up_pending = lv
	check_achievements()


func _mult() -> float:
	return 0.5 if burnout >= 70 else 1.0


# ---------------------------------------------------------------- навыки

func add_comp(id: String, n: int) -> void:
	comp[id] = int(comp.get(id, 0)) + n


func comp_total() -> int:
	var t := 0
	for k in comp:
		t += int(comp[k])
	return t


func rank_index() -> int:
	var idx := 0
	var total := comp_total()
	for i in range(Data.RANKS.size()):
		if total >= int(Data.RANKS[i][1]):
			idx = i
	return idx


func rank_name() -> String:
	return str(Data.RANKS[rank_index()][0])


func rank_next_need() -> int:
	var i := rank_index()
	if i + 1 >= Data.RANKS.size():
		return 0
	return int(Data.RANKS[i + 1][1])


# ---------------------------------------------------------------- поручения

func roll_quest() -> void:
	q_acts = 0
	q_docs = 0
	q_rest = 0
	q_pitch = 0
	q_report = 0
	q_spent = 0
	q_done = false
	quest = Data.QUESTS.pick_random()


func quest_target() -> int:
	if str(quest.get("kind", "")) == "cheap":
		return 1
	return int(quest.get("target", 1))


func quest_progress() -> int:
	match str(quest.get("kind", "")):
		"acts":
			return q_acts
		"docs":
			return q_docs
		"rest":
			return q_rest
		"pitch":
			return q_pitch
		"report":
			return q_report
		"cheap":
			return 1 if (q_acts >= 1 and q_spent <= int(quest["target"])) else 0
	return 0


func quest_reward_text() -> String:
	if quest.is_empty():
		return ""
	var r: Dictionary = quest["reward"]
	var parts: Array = []
	if r.has("trust"):
		parts.append("доверие +%d" % int(r["trust"]))
	if r.has("kpi"):
		parts.append("результат +%d" % int(r["kpi"]))
	if r.has("docs"):
		parts.append("документы +%d" % int(r["docs"]))
	if r.has("money"):
		parts.append(fmt(int(r["money"])))
	if r.has("comp"):
		parts.append("навык +2")
	return ", ".join(parts)


func _quest_msg(final := false) -> String:
	if q_done or quest.is_empty():
		return ""
	if str(quest["kind"]) == "cheap" and not final:
		return ""
	if quest_progress() < quest_target():
		return ""
	q_done = true
	var r: Dictionary = quest["reward"]
	trust += int(r.get("trust", 0))
	kpi += int(r.get("kpi", 0))
	docs += int(r.get("docs", 0))
	cash += int(r.get("money", 0))
	if r.has("comp"):
		add_comp(str(r["comp"]), 2)
	_clamp()
	return "\nПоручение выполнено! " + quest_reward_text()


# ---------------------------------------------------------------- акции

func activities_left() -> int:
	return int(budget["activities"]) - int(spent["activities"])


func has_budget_for(a: Dictionary) -> bool:
	return int(spent["activities"]) + act_cost(a) <= int(budget["activities"])


func is_done_once(a: Dictionary) -> bool:
	return bool(a.get("program", false)) and acts.has(a["id"])


func can_afford_activity(a: Dictionary) -> bool:
	return ap > 0 and level() >= int(a["level"]) and has_budget_for(a) and not is_done_once(a)


func do_activity(a: Dictionary, bonus := 0) -> String:
	var id := str(a["id"])
	var n := int(acts.get(id, 0))
	var f := maxf(pow(0.85, n), 0.45)
	var base := float(int(a["kpi"]) + bonus)
	if spec != "" and str(a.get("tag", "")) == spec:
		base += 2.0
	var gain := roundi(base * f * _mult())
	var cost := act_cost(a)
	cash -= cost
	spent["activities"] += cost
	kpi += gain
	burnout += int(a["burnout"])
	docs += int(a["docs"])
	trust += int(a.get("trust", 0))
	acts[id] = n + 1
	if a.has("mod"):
		add_mod(a["mod"])
	add_comp("lead", 1)
	q_acts += 1
	q_spent += cost
	ap -= 1
	_clamp()
	var extra := ""
	if a.has("mod"):
		extra = " Теперь действует постоянно."
	elif n >= 2:
		extra = " Повторы дают меньше."
	return "%s: результат +%d%%, расход %s.%s%s" % [a["name"], gain, fmt(cost), extra, _quest_msg()]


# ---------------------------------------------------------------- закупки

func has_item(id: String) -> bool:
	return items.has(id)


func buy_would_overspend(it: Dictionary) -> bool:
	return float(int(spent["equipment"]) + item_cost(it)) > float(budget["equipment"]) * OVERSPEND_LIMIT


func buy_item(it: Dictionary) -> String:
	var cost := item_cost(it)
	cash -= cost
	spent["equipment"] += cost
	items.append(it["id"])
	add_mod(it["mod"])
	add_comp("analytics", 1)
	ap -= 1
	_clamp()
	return "Куплено: %s (-%s). Эффект действует каждый месяц." % [it["name"], fmt(cost)]


# ---------------------------------------------------------------- команда и простые действия

func team_cost() -> int:
	var t := 0
	for id in team:
		for r in Data.STAFF:
			if r["id"] == id:
				t += int(r["cost"])
	return t


func can_hire() -> bool:
	return ap > 0 and team.size() < STAFF_MAX


func salary_short_after_hire(r: Dictionary) -> bool:
	var months_left := max_month - month + 1
	var need := (int(monthly["salary"]) + team_cost() + int(r["cost"])) * months_left
	return float(int(spent["salary"]) + need) > float(budget["salary"]) * OVERSPEND_LIMIT


func hire(r: Dictionary) -> String:
	team.append(r["id"])
	staff = team.size()
	add_mod(r["mod"])
	add_comp("lead", 2)
	ap -= 1
	_clamp()
	return "В команде новый сотрудник: %s." % r["name"]


func do_simple(id: String) -> String:
	var msg := ""
	match id:
		"rest":
			burnout -= 15
			add_comp("lead", 1)
			q_rest += 1
			msg = "Команда отдохнула: усталость -15"
		"retreat":
			cash -= 4000
			spent["activities"] += 4000
			burnout -= 25
			docs -= 2
			add_comp("lead", 1)
			q_rest += 1
			msg = "Командный выезд: усталость -25, расход 4 000 руб."
		"volunteers":
			var gain := roundi((3 + vol_bonus) * _mult())
			kpi += gain
			burnout -= 4
			docs -= 3
			add_comp("comm", 1)
			msg = "Волонтёры помогли: результат +%d%%" % gain
	ap -= 1
	_clamp()
	return msg + _quest_msg()


func can_do_doc(d: Dictionary) -> bool:
	return ap > 0 and not (bool(d.get("once", false)) and done_once.has(d["id"]))


func do_doc(d: Dictionary) -> String:
	var cost := roundi(float(d["cost"]) * price_mult) if int(d["cost"]) > 0 else 0
	cash -= cost
	spent["admin"] += cost
	docs += int(d["docs"])
	burnout += int(d["burnout"])
	trust += int(d["trust"])
	add_comp(str(d["comp"]), int(d.get("comp_n", 1)))
	if d.has("mod"):
		add_mod(d["mod"])
	if bool(d.get("once", false)):
		done_once[d["id"]] = true
	q_docs += 1
	ap -= 1
	_clamp()
	return "%s: документы +%d%s" % [d["name"], int(d["docs"]), _quest_msg()]


# ---------------------------------------------------------------- пассивные эффекты

func add_mod(m: Dictionary) -> void:
	var d: Dictionary = m.duplicate()
	if not d.has("ttl"):
		d["ttl"] = 0
	mods.append(d)


func _decay_mult() -> float:
	var mults: Array = [0.8, 1.0, 1.2]
	return float(mults[difficulty])


## Что происходит каждый месяц само по себе. forecast=true - без случайных штрафов.
func drift_lines(forecast := false) -> Array:
	var lines: Array = []
	var dm := _decay_mult()
	lines.append({"name": "Естественный спад", "kpi": -roundi(2.0 * dm), "docs": -roundi(3.0 * dm), "burnout": roundi(3.0 * dm)})
	for m in mods:
		lines.append(m)
	if team_cost() > 0:
		lines.append({"name": "Зарплаты команды", "cash": -team_cost()})
	if extra_burnout > 0:
		lines.append({"name": "Условия второго гранта", "burnout": extra_burnout})
	var q := int(ceil(month / 3.0))
	if not forecast and q_acts == 0:
		lines.append({"name": "В этом месяце не было акций", "kpi": -3})
	if docs < docs_need:
		lines.append({"name": "Документы ниже нормы донора", "trust": -2})
	if burnout >= 80:
		lines.append({"name": "Команда на грани срыва", "trust": -1})
	if kpi >= plan_for(q):
		lines.append({"name": "План выполняется", "trust": 1})
	return lines


func drift_totals(lines: Array) -> Dictionary:
	var t: Dictionary = {"kpi": 0, "docs": 0, "burnout": 0, "trust": 0, "cash": 0}
	for l in lines:
		for k in t:
			t[k] = int(t[k]) + int(l.get(k, 0))
	return t


## Деньги: сколько уходит со счёта в месяц и когда придёт следующий транш
func money_flow() -> Dictionary:
	var fixed := 0
	for line in monthly:
		fixed += int(monthly[line])
	var tc := team_cost()
	var mc := 0
	for m in mods:
		mc += int(m.get("cash", 0))
	var left := 3 - ((month - 1) % 3)
	var q := int(ceil(month / 3.0))
	var tranche := 0
	if q <= 6:
		tranche = int(GRANT_TOTAL * TRANCHES[q]) + pending_tranche
	var net := -fixed - tc + mc
	var runway := -1
	if net < 0:
		runway = maxi(int(cash / float(-net)), 0)
	return {"fixed": fixed, "team": tc, "mods": mc, "net": net, "tranche": tranche, "left": left, "runway": runway}


func drift_forecast() -> Dictionary:
	return drift_totals(drift_lines(true))


func pitch_done(pts: int, mx: int) -> String:
	ap -= 1
	var t := int(pts / 2.0)
	trust += t
	add_comp("comm", int(pts / 3.0) + 1)
	if pts >= mx:
		flags["pitch_ace"] = month
	q_pitch += 1
	_clamp()
	return "Встреча с донором: доверие +%d%s" % [t, _quest_msg()]


func report_prep_done(found: int, wrong: int) -> String:
	ap -= 1
	var g := maxi(found * 4 - wrong * 3, 0)
	docs += g
	add_comp("docs", found)
	add_comp("analytics", 1)
	q_report += 1
	_clamp()
	return "Проверка таблицы: найдено нарушений %d, документы +%d%s" % [found, g, _quest_msg()]


# ---------------------------------------------------------------- грант и продление

func take_offer(o: Dictionary) -> void:
	var m := int(o["money"])
	cash += m
	budget["activities"] += m
	extra_plan += int(o["plan"])
	extra_burnout += int(o["burnout"])


func start_extension() -> void:
	season2 = true
	max_month = 18
	ext_base_kpi = kpi
	for line in ["salary", "rent", "admin"]:
		budget[line] += int(monthly[line]) * 6
	budget["activities"] += 40000
	cash += EXTENSION_CASH
	burnout = maxi(burnout - 20, 0)
	_refill_events()
	_clamp()


# ---------------------------------------------------------------- конец месяца

func end_month() -> String:
	var fixed := 0
	for line in ["salary", "rent", "admin"]:
		var amt := int(monthly[line])
		spent[line] += amt
		fixed += amt
	var tc := team_cost()
	spent["salary"] += tc
	fixed += tc
	cash -= fixed
	var cash_before := cash + fixed
	var text := "Постоянные расходы: %s" % fmt(fixed)
	last_drift = drift_lines(false)
	var t := drift_totals(last_drift)
	kpi += int(t["kpi"])
	docs += int(t["docs"])
	burnout += int(t["burnout"])
	trust += int(t["trust"])
	cash += int(t["cash"]) + tc
	last_cash_delta = cash - cash_before
	var kept: Array = []
	for m in mods:
		var left := int(m.get("ttl", 0))
		if left > 0:
			m["ttl"] = left - 1
			if left - 1 <= 0:
				continue
		kept.append(m)
	mods = kept
	_clamp()
	text += _quest_msg(true)
	return text


func next_month() -> void:
	month += 1
	ap = AP_PER_MONTH


func chapter_event() -> Dictionary:
	match month:
		4:
			return Data.CHAPTERS["ch2"]
		7, 15:
			return Data.CRISES.pick_random()
		10:
			return Data.CHAPTERS["ch4"]
	return {}


## Следующее событие. Если раньше вы сделали выбор с последствиями,
## через месяц-другой придёт продолжение истории.
func draw_event() -> Dictionary:
	var ready: Array = []
	for f in Data.FOLLOWUPS:
		var fl: String = f["need_flag"]
		if flags.has(fl) and not used_followups.has(f["id"]) and month > int(flags[fl]):
			ready.append(f)
	if not ready.is_empty() and randf() < 0.8:
		var f2: Dictionary = ready.pick_random()
		used_followups.append(f2["id"])
		return f2
	if events_pool.is_empty():
		_refill_events()
	return events_pool.pop_back()


## Применяет выбор и возвращает то, что реально произошло
func apply_choice(ev: Dictionary, ch: Dictionary) -> Dictionary:
	var eff: Dictionary = ch.duplicate()
	if ch.has("if_docs_ok"):
		var key := "if_docs_ok" if docs >= docs_need else "if_docs_bad"
		var extra: Dictionary = ch[key]
		for k in extra:
			eff[k] = extra[k]
	var m: int = int(eff.get("money", 0))
	cash += m
	var line: String = str(eff.get("line", ""))
	if m < 0 and line != "":
		spent[line] += -m
	trust += int(eff.get("trust", 0))
	docs += int(eff.get("docs", 0))
	burnout += int(eff.get("burnout", 0))
	kpi += int(eff.get("kpi", 0))
	vol_bonus += int(eff.get("vol", 0))
	if eff.has("flag"):
		flags[eff["flag"]] = month
	if eff.has("mod"):
		add_mod(eff["mod"])
	var ok: bool = eff.get("ok", true)
	var topic: String = str(ev.get("topic", "budget"))
	if ok:
		add_comp(str(Data.TOPIC_COMP.get(topic, "analytics")), 2)
	else:
		mistakes[topic] = mistakes.get(topic, 0) + 1
		failed_lessons.append({"title": ev["title"], "lesson": eff.get("lesson", "")})
	_clamp()
	return eff


func receipt_result(correct: bool, topic: String, why: String, title: String) -> void:
	if correct:
		docs += 2
		add_comp("docs", 1)
	else:
		docs -= 6
		mistakes[topic] = mistakes.get(topic, 0) + 1
		failed_lessons.append({"title": title, "lesson": why})
	_clamp()


func evaluate_report(q: int, correct: int, total: int) -> Dictionary:
	var checks: Array = []
	var plan := plan_for(q)
	checks.append({"name": "Результаты проекта", "ok": kpi >= plan, "topic": "results",
		"detail": "Результат %d%%, нужно %d%%" % [kpi, plan]})
	checks.append({"name": "Документы в порядке", "ok": docs >= docs_need, "topic": "primary_docs",
		"detail": "Документы %d%%, нужно %d%%" % [docs, docs_need]})
	checks.append({"name": "Проверка чеков", "ok": correct >= total - 1, "topic": "primary_docs",
		"detail": "Верно %d из %d" % [correct, total]})
	var over: Array = []
	for line in Data.LINES:
		if float(spent[line]) > float(budget[line]) * OVERSPEND_LIMIT:
			over.append(Data.LINES[line])
	var budget_ok := over.is_empty()
	var budget_detail := "Все статьи в норме"
	if not budget_ok:
		budget_detail = "Перерасход: %s" % ", ".join(over)
	checks.append({"name": "Бюджет соблюдён", "ok": budget_ok, "topic": "budget", "detail": budget_detail})

	var passed := 0
	for c in checks:
		if c["ok"]:
			passed += 1
		else:
			mistakes[c["topic"]] = mistakes.get(c["topic"], 0) + 1
	add_comp("analytics", passed)
	if passed == 4:
		perfect_reports += 1

	var tranche := int(GRANT_TOTAL * TRANCHES[q])
	var paid := 0
	var td := 0
	var text := ""
	if passed >= 3:
		paid = tranche + pending_tranche
		pending_tranche = 0
		td = 5 if passed == 3 else 10
		if paid > 0:
			text = "Отчёт принят! Транш: %s" % fmt(paid)
		else:
			text = "Отчёт принят."
	elif passed == 2:
		pending_tranche += tranche
		td = -5
		text = "Есть замечания. Транш задержан."
	else:
		pending_tranche += tranche
		td = -15
		text = "Отчёт не принят. Транш задержан."
	if td < 0:
		td = int(td * neg_mult)
	cash += paid
	trust += td
	_clamp()
	return {"checks": checks, "passed": passed, "text": text, "trust_delta": td}


# ---------------------------------------------------------------- исходы

func check_game_over() -> String:
	if burnout >= 100:
		return "Команда выгорела. Проект остановлен."
	if trust <= 0:
		return "Донор расторг соглашение."
	if cash_gaps >= 3:
		return "Нечем платить по счетам: три кассовых разрыва."
	return ""


func game_over_ending() -> String:
	if burnout >= 100:
		return "lose_burnout"
	if trust <= 0:
		return "lose_trust"
	return "lose_cash"


func final_score() -> int:
	var s := trust * 0.30 + kpi * 0.30 + docs * 0.25 + minf(comp_total(), 40.0) / 40.0 * 15.0
	return clampi(int(s) - cash_gaps * 5, 0, 100)


func campaign_verdict() -> Dictionary:
	var s := final_score()
	var kind := "lose"
	var hi := 70 if season2 else 78
	var lo := 50 if season2 else 52
	if s >= hi:
		kind = "qualified"
	elif s >= lo:
		kind = "reserve"
	return {"score": s, "kind": kind}


# ---------------------------------------------------------------- турнир

func make_rivals() -> Array:
	var pool: Array = Data.RIVALS.duplicate()
	pool.shuffle()
	var out: Array = []
	for i in range(5):
		var r: Array = pool[i]
		out.append({"name": r[0], "city": r[1], "skill": randi_range(58, 86), "total": 0})
	return out


func tour_player_total() -> int:
	var t := int(final_score() / 5.0)
	for s in tour_scores:
		t += int(s)
	return t


func tour_place() -> int:
	var mine := tour_player_total()
	var place := 1
	for r in tour_rivals:
		if int(r["total"]) > mine:
			place += 1
	return place
