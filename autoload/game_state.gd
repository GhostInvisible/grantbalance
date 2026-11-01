extends Node
## Состояние и правила игры. Интерфейса здесь нет.

const Data = preload("res://data/game_data.gd")

const AP_PER_MONTH := 3
const GRANT_TOTAL := 600000
const AUDIT_MONTHS: Array = [3, 6, 9, 12]
const SAVE_SLOTS: Array = ["auto", "1", "2", "3"]
const META_PATH := "user://meta.cfg"

# Правила донора (учебные)
const MAX_ADMIN_PCT := 0.15
const MAX_EQUIPMENT_PCT := 0.25
const MIN_EVENTS_PCT := 0.25
const MAX_SALARY_PCT := 0.45
const MIN_PLAN_PCT := 0.90
const OVERSPEND_LIMIT := 1.10
const FATAL_REFUND_PCT := 0.25
const DOCS_NEED := 70

const ISSUE_RULES: Dictionary = {
	"doc_gap": {"trust": -3, "share": 0.3, "topic": "primary_docs"},
	"misclass": {"trust": -1, "share": 0.15, "topic": "accounting"},
	"wrong_contract": {"trust": -5, "share": 0.4, "topic": "contracts"},
	"unreported": {"trust": -10, "share": 1.0, "topic": "approval", "fatal": true},
	"late_notice": {"trust": -3, "share": 0.3, "topic": "approval"},
	"bad_choice": {"trust": -3, "share": 0.5, "topic": "budget"},
}

const FINDING_LESSON: Dictionary = {
	"doc_gap": "Не хватало документов. Для каждой операции нужен полный комплект.",
	"misclass": "Операция записана не по той статье сметы. Учёт должен соответствовать смете.",
	"wrong_contract": "Выбран неверный вид договора. Постоянная работа - трудовой, разовые услуги - ГПХ или самозанятый.",
	"unreported": "Изменение сделано без согласования с фондом. Это нецелевое использование средств.",
	"late_notice": "Фонд узнал об изменении после траты. Согласовывать нужно заранее.",
	"bad_choice": "Расход был сделан вопреки правилам и не подтверждается.",
	"overspend": "Статья сметы превышена больше чем на 10% без согласования.",
	"results": "Результаты проекта отстают от плана.",
	"docs_low": "Порядок в документах ниже нормы фонда.",
}

var month := 1
var max_month := 12
var ap := 3
var cash := 0
var trust := 50
var docs := 80
var burnout := 10
var kpi := 0

var plan_ids: Array = []
var plan_attempts := 0
var budget: Dictionary = {}
var spent: Dictionary = {}
var auto_monthly: Dictionary = {}
var kpi_w: Dictionary = {}
var ops: Dictionary = {}
var requests: Array = []
var staff: Array = []
var issues: Array = []
var journal: Array = []
var appr_extra: Dictionary = {}
var overspend_charged: Dictionary = {}
var refund_total := 0
var audits_done := 0
var surprise_done := 0
var mistakes: Dictionary = {}
var flags: Dictionary = {}
var used_followups: Array = []
var events_pool: Array = []
var mods: Array = []
var items: Array = []
var acts: Dictionary = {}
var comp: Dictionary = {}
var contracts_ok := 0
var consulted := false

var pending_tranche := 0
var incoming: Array = []
var tranche_shares: Array = [0.30, 0.25, 0.25, 0.20, 0.0]
var tranche_name := "Классика"
var cash_gaps := 0
var last_drift: Array = []
var last_cash_delta := 0
var last_incoming_text := ""
var last_sig := ""

var endings_seen: Dictionary = {}
var ach: Dictionary = {}
var new_unlocks: Array = []
var best_score := 0
var attempts := 0


func _ready() -> void:
	load_meta()


# ---------------------------------------------------------------- мета-сохранение

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


# ---------------------------------------------------------------- старт

func reset() -> void:
	month = 1
	max_month = 12
	ap = AP_PER_MONTH
	cash = 10000
	trust = 50
	docs = 80
	burnout = 10
	kpi = 0
	plan_ids = []
	plan_attempts = 0
	budget = {}
	spent = {"salary": 0, "activities": 0, "equipment": 0, "rent": 0, "admin": 0}
	auto_monthly = {}
	kpi_w = {}
	ops = {}
	requests = []
	staff = []
	issues = []
	journal = []
	appr_extra = {}
	overspend_charged = {}
	refund_total = 0
	audits_done = 0
	surprise_done = 0
	mistakes = {}
	flags = {}
	used_followups = []
	mods = []
	items = []
	acts = {}
	comp = {"plan": 0, "acc": 0, "docs": 0, "contr": 0, "appr": 0}
	contracts_ok = 0
	consulted = false
	pending_tranche = 0
	incoming = []
	cash_gaps = 0
	last_drift = []
	last_cash_delta = 0
	last_incoming_text = ""
	last_sig = ""
	new_unlocks = []
	_roll_tranches()
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


func pos(id: String) -> Dictionary:
	for p in Data.POSITIONS:
		if p["id"] == id:
			return p
	return {}


# ---------------------------------------------------------------- проектирование сметы

func plan_has(id: String) -> bool:
	return plan_ids.has(id)


func plan_toggle(id: String) -> void:
	if plan_ids.has(id):
		plan_ids.erase(id)
	else:
		plan_ids.append(id)


func plan_cat_total(cat: String) -> int:
	var t := 0
	for id in plan_ids:
		var p := pos(str(id))
		if str(p["cat"]) == cat:
			t += int(p["cost"])
	return t


func plan_total() -> int:
	var t := 0
	for cat in Data.LINES:
		t += plan_cat_total(str(cat))
	return t


func plan_events_count() -> int:
	var n := 0
	for id in plan_ids:
		if str(pos(str(id))["kind"]) == "event":
			n += 1
	return n


## Замечания фонда к заявке. Пустой список - заявка утверждена.
func plan_problems() -> Array:
	var out: Array = []
	var total := plan_total()
	var g := float(GRANT_TOTAL)
	if total > GRANT_TOTAL:
		out.append("Смета больше гранта: %s при лимите %s." % [fmt(total), fmt(GRANT_TOTAL)])
	elif total < int(g * MIN_PLAN_PCT):
		out.append("В смете меньше 90%% гранта (%s). Фонд ждёт, что деньги будут использованы по назначению." % fmt(total))
	if plan_cat_total("admin") > int(g * MAX_ADMIN_PCT):
		out.append("Админ. расходы больше 15%% гранта (лимит %s)." % fmt(int(g * MAX_ADMIN_PCT)))
	if plan_cat_total("equipment") > int(g * MAX_EQUIPMENT_PCT):
		out.append("Оборудование больше 25%% гранта (лимит %s)." % fmt(int(g * MAX_EQUIPMENT_PCT)))
	if plan_cat_total("salary") > int(g * MAX_SALARY_PCT):
		out.append("Оплата труда больше 45%% гранта (лимит %s)." % fmt(int(g * MAX_SALARY_PCT)))
	if plan_cat_total("activities") < int(g * MIN_EVENTS_PCT):
		out.append("На мероприятия нужно не менее 25%% гранта (%s). Фонд оценивает результат проекта." % fmt(int(g * MIN_EVENTS_PCT)))
	if plan_events_count() < 3:
		out.append("В проекте должно быть не меньше трёх мероприятий.")
	if not (plan_has("p_coord") or plan_has("p_dir")):
		out.append("Нет ответственного за проект: добавьте координатора или директора.")
	if not (plan_has("p_acc") or plan_has("a_soft")):
		out.append("Не предусмотрено бухгалтерское сопровождение: нужен бухгалтер или бухгалтерская программа.")
	return out


func approve_plan() -> void:
	budget = {}
	for cat in Data.LINES:
		budget[cat] = plan_cat_total(str(cat))
	auto_monthly = {}
	var total_w := 0.0
	for id in plan_ids:
		var p := pos(str(id))
		var kind := str(p["kind"])
		if kind == "auto":
			var c := str(p["cat"])
			auto_monthly[c] = int(auto_monthly.get(c, 0)) + roundi(float(p["cost"]) / float(p["months"]))
			if p.has("mod"):
				add_mod(p["mod"])
		else:
			ops[id] = {"status": "todo", "denied": []}
		if kind == "event":
			total_w += float(p["w"])
	for id in plan_ids:
		var p2 := pos(str(id))
		if str(p2["kind"]) == "event":
			kpi_w[id] = 100.0 * float(p2["w"]) / total_w
	cash += int(GRANT_TOTAL * float(tranche_shares[0]))
	if plan_attempts == 0:
		unlock("plan_ok")


# ---------------------------------------------------------------- график траншей

func _roll_tranches() -> void:
	var total := 0.0
	for pl in Data.TRANCHE_PLANS:
		total += float(pl["w"][1])
	var r := randf() * total
	var pick: Dictionary = Data.TRANCHE_PLANS[0]
	var acc := 0.0
	for pl in Data.TRANCHE_PLANS:
		acc += float(pl["w"][1])
		if r <= acc:
			pick = pl
			break
	tranche_name = str(pick["name"])
	tranche_shares = []
	for sh in pick["shares"]:
		tranche_shares.append(float(sh))
	while tranche_shares.size() < 5:
		tranche_shares.append(0.0)


func tranche_schedule() -> Array:
	var out: Array = []
	var labels: Array = ["На старте", "После 1-й проверки", "После 2-й проверки", "После 3-й проверки", "После итоговой проверки"]
	for i in range(5):
		var sh := float(tranche_shares[i])
		if sh > 0.0:
			out.append("%s: %s (%d%%)" % [labels[i], fmt(int(GRANT_TOTAL * sh)), roundi(sh * 100.0)])
	return out


func _roll_delay() -> int:
	return 1 if randf() < 0.25 else 0


func _roll_factor(perfect: bool) -> Array:
	var opts: Array = [0.95, 1.0, 1.0, 1.05]
	var f := float(opts.pick_random())
	var note := ""
	if perfect:
		f += 0.05
		note = "Бонус +5% за проверку без замечаний. "
	if f < 0.99:
		note += "Фонд удержал %d%% (курсовая разница и комиссия)." % roundi((1.0 - f) * 100.0)
	return [f, note.strip_edges()]


# ---------------------------------------------------------------- показатели

func _clamp() -> void:
	trust = clampi(trust, 0, 100)
	docs = clampi(docs, 0, 100)
	burnout = clampi(burnout, 0, 100)
	kpi = clampi(kpi, 0, 100)


func level() -> int:
	if kpi >= 60:
		return 3
	if kpi >= 30:
		return 2
	return 1


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


func log_decision(kind: String, title: String, lesson: String, topic := "") -> void:
	journal.append({"m": month, "kind": kind, "title": title, "lesson": lesson, "topic": topic})
	if kind == "bad" and topic != "":
		mistakes[topic] = int(mistakes.get(topic, 0)) + 1
	if journal.size() > 80:
		journal.pop_front()


func add_mod(m: Dictionary) -> void:
	var d: Dictionary = m.duplicate()
	if not d.has("ttl"):
		d["ttl"] = 0
	mods.append(d)


# ---------------------------------------------------------------- операции проекта

func op_status(id: String) -> String:
	if ops.has(id):
		return str(ops[id]["status"])
	return ""


func variants_for(pid: String) -> Array:
	var p := pos(pid)
	var c := int(p["cost"])
	var out: Array = []
	match str(p["kind"]):
		"equip":
			out.append({"id": "plan", "text": "Купить «%s» у поставщика из сметы" % p["name"], "cost": c, "appr": false,
				"docs": Data.EQ_DOCS.duplicate(), "why": "Покупка точно по смете - самый безопасный путь."})
			out.append({"id": "cheaper", "text": "Купить такой же товар у другого поставщика, дешевле на 10%", "cost": roundi(c * 0.9), "appr": false,
				"docs": Data.EQ_DOCS.duplicate(), "why": "Тот же товар у другого продавца дешевле - допустимо, если документы в порядке и назначение то же."})
			out.append({"id": "other_model", "text": "Взять другое оборудование (аналога из сметы нет), дороже на 15%", "cost": roundi(c * 1.15), "appr": true,
				"docs": Data.EQ_DOCS.duplicate(), "why": "Замена оборудования меняет условия проекта: нужно согласовать с фондом до покупки."})
			out.append({"id": "price_up", "text": "Купить у того же поставщика, но цена выросла на 25%", "cost": roundi(c * 1.25), "appr": true,
				"docs": Data.EQ_DOCS.duplicate(), "why": "Превышение стоимости строки больше чем на 10% нужно согласовать."})
			out.append({"id": "personal", "text": "Купить в магазине на личные деньги, чек принести потом", "cost": c, "appr": false,
				"docs": Data.PERSONAL_DOCS.duplicate(), "why": "Покупка за личные деньги допустима только через подотчёт: чек, авансовый отчёт, акт."})
		"event":
			out.append({"id": "plan", "text": "Провести как в проекте", "cost": c, "appr": false, "kpi_mult": 1.0,
				"docs": p["docs"].duplicate(), "why": "Мероприятие проведено по плану и подтверждено документами."})
			out.append({"id": "cheap", "text": "Провести на бесплатной площадке партнёра, сэкономив 20%", "cost": roundi(c * 0.8), "appr": false, "kpi_mult": 1.0,
				"docs": p["docs"].duplicate(), "why": "Экономия без изменения содержания проекта допустима."})
			out.append({"id": "scaled", "text": "Сделать масштабнее: больше гостей и угощений (+25% расходов)", "cost": roundi(c * 1.25), "appr": true, "kpi_mult": 1.2,
				"docs": p["docs"].duplicate(), "why": "Рост расходов статьи больше чем на 10% нужно согласовать с фондом."})
			out.append({"id": "replaced", "text": "Заменить на более простое мероприятие (участников меньше)", "cost": c, "appr": true, "kpi_mult": 0.75,
				"docs": p["docs"].duplicate(), "why": "Изменение содержания мероприятия - это изменение проекта. Его согласуют заранее."})
		"staff":
			for cid in ["labor", "gph", "selfemp", "oral"]:
				var info: Dictionary = p["contracts"][cid]
				out.append({"id": cid, "text": "%s (%s в месяц)" % [Data.CONTRACT_NAMES[cid], fmt(int(info["monthly"]))], "cost": 0, "appr": false,
					"docs": Data.CONTRACT_DOCS[cid].duplicate(), "ok": bool(info["ok"]), "monthly": int(info["monthly"]), "why": str(info["why"])})
	return out


func finish_op(pid: String, v: Dictionary, mode: String, sel: Array, cat_sel: String) -> String:
	var p := pos(pid)
	var kind := str(p["kind"])
	var pname := str(p["name"])
	var cat := str(p["cat"])
	var cost := int(v["cost"])
	var amount := cost if cost > 0 else int(p["cost"])
	var required: Array = v["docs"].duplicate()
	if mode == "approved":
		required.append("approval_letter")
	var missing: Array = []
	for d in required:
		if not sel.has(d):
			missing.append(d)
	var noise := 0
	for d in sel:
		if Data.DOC_NOISE.has(d):
			noise += 1

	if missing.is_empty():
		docs += 3
		add_comp("docs", 2)
	else:
		var names: Array = []
		for d in missing:
			names.append(str(Data.DOC_TYPES[d]))
		var share := minf(0.2 * missing.size(), 0.6)
		add_issue("doc_gap", "%s: не хватает документов (%s)" % [pname, ", ".join(names)], amount, share, pid)
		log_decision("bad", "%s: неполный комплект документов" % pname, "Не было: %s." % ", ".join(names), "primary_docs")
		docs -= 3
	if noise > 0:
		docs -= noise
		log_decision("bad", "%s: в комплект положили лишнее" % pname, "Переписка, скриншоты и устные договорённости не заменяют документы.", "primary_docs")

	if kind == "staff":
		if bool(v["ok"]):
			contracts_ok += 1
			add_comp("contr", 2)
			log_decision("good", "%s: верный договор" % pname, str(v["why"]), "contracts")
			if contracts_ok >= 4:
				unlock("contracts")
		else:
			add_issue("wrong_contract", "%s: неверный вид договора (%s)" % [pname, Data.CONTRACT_NAMES[str(v["id"])]], int(p["cost"]), -1.0, pid)
			log_decision("bad", "%s: неверный вид договора" % pname, str(v["why"]), "contracts")

	if bool(v["appr"]):
		match mode:
			"silent":
				add_issue("unreported", "%s: изменение без согласования с фондом" % pname, cost, -1.0, pid)
				log_decision("bad", "%s: изменили и промолчали" % pname, "Изменение сметы нужно согласовывать до траты. Об этом вы не сообщили фонду.", "approval")
			"late":
				add_issue("late_notice", "%s: фонд уведомлён после траты" % pname, cost, -1.0, pid)
				log_decision("bad", "%s: сообщили фонду после траты" % pname, "Согласование должно быть до траты.", "approval")
			"approved":
				var base := int(p["cost"])
				appr_extra[cat] = int(appr_extra.get(cat, 0)) + maxi(cost - base, 0)
				log_decision("good", "%s: согласовали до траты" % pname, "У вас есть письмо фонда. Это защищает от возврата денег.", "approval")

	if cat_sel != cat:
		add_issue("misclass", "%s: записано в журнал по статье «%s» вместо «%s»" % [pname, Data.LINES[cat_sel], Data.LINES[cat]], amount, -1.0, pid)
		log_decision("bad", "%s: ошибка в учёте" % pname, "Операцию записали не в ту статью сметы.", "accounting")
	else:
		add_comp("acc", 1)

	if kind != "staff":
		cash -= cost
		spent[cat] = int(spent.get(cat, 0)) + cost
	match kind:
		"event":
			kpi += roundi(float(kpi_w.get(pid, 0)) * float(v.get("kpi_mult", 1.0)))
			burnout += int(p.get("burnout", 6))
			var yk := str(p.get("yard", ""))
			if yk != "":
				acts[yk] = int(acts.get(yk, 0)) + 1
			if pid == "e_fest":
				unlock("big_fest")
		"equip":
			if p.has("mod"):
				add_mod(p["mod"])
			var ik := str(p.get("yard", ""))
			if ik != "":
				items.append(ik)
			burnout += 1
		"staff":
			staff.append({"pos": pid, "name": pname, "contract": str(v["id"]), "monthly": int(v["monthly"]), "ok": bool(v["ok"])})
			if p.has("mod"):
				add_mod(p["mod"])
			burnout += 1
	ops[pid] = {"status": "done", "variant": str(v["id"]), "mode": mode, "denied": []}
	ap -= 1
	_clamp()
	return "Операция «%s» проведена и записана в журнал." % pname


func send_request(pid: String, vid: String, strong: bool) -> void:
	requests.append({"pos": pid, "variant": vid, "strong": strong, "sent": month, "status": "waiting"})
	ops[pid]["status"] = "waiting"
	ops[pid]["variant"] = vid
	add_comp("appr", 2 if strong else 1)
	unlock("asked")
	log_decision("good", "Запрос на согласование: %s" % pos(pid)["name"],
		"Вы запросили согласование до траты" + (" и приложили обоснование." if strong else ", но письмо было коротким. С обоснованием шанс одобрения выше."), "approval")
	ap -= 1


func resolve_requests() -> Array:
	var msgs: Array = []
	for r in requests:
		if str(r["status"]) != "waiting" or int(r["sent"]) >= month:
			continue
		var pname := str(pos(str(r["pos"]))["name"])
		var chance := 0.45
		if bool(r["strong"]):
			chance = 0.9 if trust >= 35 else 0.65
		var o: Dictionary = ops[r["pos"]]
		if randf() < chance:
			r["status"] = "approved"
			o["status"] = "approved"
			msgs.append("Фонд согласовал изменение по строке «%s». Теперь можно выполнять." % pname)
		else:
			r["status"] = "denied"
			o["status"] = "todo"
			o["denied"].append(r["variant"])
			trust -= 1
			msgs.append("Фонд отказал в изменении по строке «%s». Нужно выбрать другой вариант." % pname)
	_clamp()
	return msgs


# ---------------------------------------------------------------- нарушения и сверка

func add_issue(kind: String, title: String, amount: int, share := -1.0, pid := "") -> void:
	var rule: Dictionary = ISSUE_RULES[kind]
	var sh := share if share >= 0.0 else float(rule["share"])
	issues.append({"kind": kind, "title": title, "amount": amount, "share": sh, "status": "open", "month": month, "pos": pid})


func open_issue_count() -> int:
	var n := 0
	for it in issues:
		if str(it["status"]) == "open":
			n += 1
	return n


func can_fix(it: Dictionary) -> bool:
	return str(it["status"]) == "open" and ["doc_gap", "misclass", "unreported", "wrong_contract"].has(str(it["kind"]))


func fix_cost(it: Dictionary) -> int:
	match str(it["kind"]):
		"doc_gap":
			return 500
		"wrong_contract":
			return 3000
	return 0


func fix_issue(i: int) -> String:
	var it: Dictionary = issues[i]
	var cost := fix_cost(it)
	cash -= cost
	var kind := str(it["kind"])
	var msg := ""
	match kind:
		"doc_gap":
			it["status"] = "fixed"
			docs += 2
			msg = "Недостающие документы собраны."
		"misclass":
			it["status"] = "fixed"
			add_comp("acc", 1)
			msg = "Запись в журнале исправлена."
		"unreported":
			it["kind"] = "late_notice"
			it["share"] = float(ISSUE_RULES["late_notice"]["share"])
			it["title"] = str(it["title"]) + " (фонд уведомлён)"
			msg = "Вы сообщили фонду. Теперь это не нецелевое использование, но замечание останется."
			add_comp("appr", 1)
		"wrong_contract":
			var p := pos(str(it["pos"]))
			var best_id := ""
			var best_m := 999999
			for cid in p["contracts"]:
				var info: Dictionary = p["contracts"][cid]
				if bool(info["ok"]) and int(info["monthly"]) < best_m:
					best_m = int(info["monthly"])
					best_id = str(cid)
			for s in staff:
				if s["pos"] == it["pos"]:
					s["contract"] = best_id
					s["monthly"] = best_m
					s["ok"] = true
			it["status"] = "fixed"
			msg = "Договор переоформлен на верный вид."
			add_comp("contr", 1)
	unlock("honest")
	log_decision("good", "Исправили до проверки: " + str(it["title"]), "Исправить ошибку самому до проверки всегда лучше.", "")
	_clamp()
	return msg


# ---------------------------------------------------------------- проверки

func audit_due() -> String:
	if AUDIT_MONTHS.has(month):
		return "scheduled"
	if month >= 2 and surprise_done < 2:
		var p := minf(0.06 + 0.05 * open_issue_count(), 0.4)
		if randf() < p:
			return "surprise"
	return ""


func audit_findings() -> Array:
	var out: Array = []
	for i in range(issues.size()):
		var it: Dictionary = issues[i]
		if str(it["status"]) != "open":
			continue
		var rule: Dictionary = ISSUE_RULES[str(it["kind"])]
		out.append({"idx": i, "title": str(it["title"]), "kind": str(it["kind"]), "refund": roundi(float(it["amount"]) * float(it["share"])),
			"trust": int(rule["trust"]), "fatal": bool(rule.get("fatal", false)), "topic": str(rule["topic"]), "cat": ""})
	for cat in Data.LINES:
		var limit := float(budget.get(cat, 0)) * OVERSPEND_LIMIT + float(appr_extra.get(cat, 0))
		var excess := int(float(spent.get(cat, 0)) - limit) - int(overspend_charged.get(cat, 0))
		if excess > 500:
			out.append({"idx": -1, "title": "Перерасход по статье «%s» без согласования" % Data.LINES[cat], "kind": "overspend", "refund": excess,
				"trust": -5, "fatal": false, "topic": "budget", "cat": str(cat)})
	var expected := 80.0 * month / float(max_month)
	if float(kpi) < expected * 0.7:
		out.append({"idx": -1, "title": "Результаты проекта отстают от плана", "kind": "results", "refund": 0, "trust": -4, "fatal": false, "topic": "planning", "cat": ""})
	if docs < DOCS_NEED:
		out.append({"idx": -1, "title": "Порядок в документах ниже нормы фонда", "kind": "docs_low", "refund": 0, "trust": -3, "fatal": false, "topic": "primary_docs", "cat": ""})
	return out


## Применяет результаты проверки. Возвращает код концовки, если игра проиграна, иначе пустую строку.
func apply_findings(findings: Array) -> String:
	var verdict := ""
	var refund_sum := 0
	for f in findings:
		refund_sum += int(f["refund"])
		trust += int(f["trust"])
		log_decision("bad", str(f["title"]), str(FINDING_LESSON.get(str(f["kind"]), "")), str(f["topic"]))
		if int(f["idx"]) >= 0:
			issues[int(f["idx"])]["status"] = "charged"
		if str(f["kind"]) == "overspend":
			var c := str(f["cat"])
			overspend_charged[c] = int(overspend_charged.get(c, 0)) + int(f["refund"])
			if int(f["refund"]) >= int(GRANT_TOTAL * 0.10):
				verdict = "lose_refund"
		if bool(f["fatal"]):
			verdict = "lose_unreported"
	cash -= refund_sum
	refund_total += refund_sum
	if verdict == "" and refund_total >= int(GRANT_TOTAL * FATAL_REFUND_PCT):
		verdict = "lose_refund"
	if findings.is_empty():
		trust += 3
		unlock("audit_clean")
	audits_done += 1
	_clamp()
	return verdict


## Транш после плановой проверки
func pay_tranche(findings: Array) -> String:
	var q := int(month / 3.0)
	var refund_sum := 0
	for f in findings:
		refund_sum += int(f["refund"])
	var expected := 80.0 * month / float(max_month)
	var ok := refund_sum <= int(GRANT_TOTAL * 0.03) and float(kpi) >= expected * 0.5 and trust > 25
	var tranche := int(GRANT_TOTAL * float(tranche_shares[q]))
	if not ok:
		pending_tranche += tranche
		return "Фонд задержал транш до устранения замечаний."
	var base := tranche + pending_tranche
	pending_tranche = 0
	if base <= 0:
		return "Отчёт принят."
	var fr: Array = _roll_factor(findings.is_empty())
	var amount := int(base * float(fr[0]))
	var text := ""
	var delay := _roll_delay() if month < max_month else 0
	if delay > 0:
		incoming.append({"amount": amount, "left": delay})
		text = "Отчёт принят. Транш %s задержался и придёт через %d мес." % [fmt(amount), delay]
	else:
		cash += amount
		text = "Отчёт принят! Транш: %s" % fmt(amount)
	if str(fr[1]) != "":
		text += "\n" + str(fr[1])
	return text


## Приёмка документов в отчёт (мини-игра на проверке)
func accept_result(c: Dictionary, choice: String) -> Dictionary:
	var ans := str(c["answer"])
	var amt := int(c["amount"])
	var topic := str(c["topic"])
	if choice == ans:
		docs += 1
		add_comp(str(Data.TOPIC_COMP.get(topic, "docs")), 1)
		_clamp()
		return {"ok": true, "text": "Верно. " + str(c["why"])}
	var text := ""
	if choice == "include" and ans == "exclude":
		cash -= amt
		refund_total += amt
		trust -= 2
		text = "Вы включили недопустимый расход. Фонд потребует вернуть %s." % fmt(amt)
	elif choice == "include" and ans == "fix":
		var half := roundi(amt * 0.5)
		cash -= half
		refund_total += half
		trust -= 1
		text = "Документы были неполными. Фонд не принял половину суммы: %s." % fmt(half)
	elif choice == "exclude" and ans == "include":
		docs -= 2
		text = "Допустимый расход остался без подтверждения. Деньги проекта пропали зря."
	elif choice == "exclude" and ans == "fix":
		docs -= 1
		text = "Расход можно было сохранить, если доработать документы."
	elif choice == "fix" and ans == "include":
		burnout += 2
		text = "Документы были в порядке. Вы потеряли время на лишнюю доработку."
	else:
		docs -= 1
		text = "Доработка не поможет: расход недопустим в любом случае."
	log_decision("bad", str(c["text"]), str(c["why"]), topic)
	_clamp()
	return {"ok": false, "text": text + " " + str(c["why"])}


## Тренировка «Комплект документов»
func docset_result(purpose: Dictionary, sel: Array) -> Dictionary:
	var missing: Array = []
	var extra: Array = []
	for d in purpose["docs"]:
		if not sel.has(d):
			missing.append(str(Data.DOC_TYPES[d]))
	for d in sel:
		if not purpose["docs"].has(d):
			extra.append(str(Data.DOC_TYPES[d]))
	ap -= 1
	if missing.is_empty() and extra.is_empty():
		docs += 8
		add_comp("docs", 3)
		unlock("docset")
		_clamp()
		return {"ok": true, "text": "Комплект собран верно. " + str(purpose["why"])}
	docs += 3
	add_comp("docs", 1)
	log_decision("bad", "Комплект: " + str(purpose["title"]), str(purpose["why"]), "primary_docs")
	_clamp()
	var t := ""
	if not missing.is_empty():
		t += "Не хватало: " + ", ".join(missing) + ". "
	if not extra.is_empty():
		t += "Лишнее: " + ", ".join(extra) + ". "
	return {"ok": false, "text": t + str(purpose["why"])}


func do_rest() -> String:
	burnout -= 15
	ap -= 1
	_clamp()
	return "Команда отдохнула: нагрузка -15."


func consult() -> String:
	ap -= 1
	trust += 1
	add_comp("plan", 1)
	consulted = true
	_clamp()
	return str(Data.TIPS.pick_random())


# ---------------------------------------------------------------- деньги и месяц

func payroll_total() -> int:
	var t := 0
	for s in staff:
		t += int(s["monthly"])
	return t


func auto_total() -> int:
	var t := 0
	for k in auto_monthly:
		t += int(auto_monthly[k])
	return t


func drift_lines(_forecast := false) -> Array:
	var lines: Array = []
	lines.append({"name": "Рабочая нагрузка и бумаги копятся", "docs": -2, "burnout": 2})
	for m in mods:
		lines.append(m)
	if docs < DOCS_NEED:
		lines.append({"name": "Порядок в документах ниже нормы фонда", "trust": -1})
	if burnout >= 80:
		lines.append({"name": "Команда на грани срыва", "trust": -1})
	return lines


func drift_totals(lines: Array) -> Dictionary:
	var t: Dictionary = {"kpi": 0, "docs": 0, "burnout": 0, "trust": 0, "cash": 0}
	for l in lines:
		for k in t:
			t[k] = int(t[k]) + int(l.get(k, 0))
	return t


func drift_forecast() -> Dictionary:
	return drift_totals(drift_lines(true))


func money_flow() -> Dictionary:
	var fixed := auto_total()
	var tc := payroll_total()
	var mc := 0
	for m in mods:
		mc += int(m.get("cash", 0))
	var left := 3 - ((month - 1) % 3)
	var q := int(ceil(month / 3.0))
	var tranche := 0
	if q <= 4:
		tranche = int(GRANT_TOTAL * float(tranche_shares[q])) + pending_tranche
	var net := -fixed - tc + mc
	var runway := -1
	if net < 0:
		runway = maxi(int(cash / float(-net)), 0)
	var inc := 0
	for i2 in incoming:
		inc += int(i2["amount"])
	return {"fixed": fixed, "team": tc, "mods": mc, "net": net, "tranche": tranche, "left": left, "runway": runway, "incoming": inc}


func end_month() -> String:
	var cash_before := cash
	var payroll := payroll_total()
	var auto := auto_total()
	cash -= payroll + auto
	spent["salary"] = int(spent["salary"]) + payroll
	for c in auto_monthly:
		spent[c] = int(spent.get(c, 0)) + int(auto_monthly[c])
	var text := "Постоянные расходы: %s (зарплаты %s, аренда и админ. %s)" % [fmt(payroll + auto), fmt(payroll), fmt(auto)]
	last_drift = drift_lines(false)
	var t := drift_totals(last_drift)
	kpi += int(t["kpi"])
	docs += int(t["docs"])
	burnout += int(t["burnout"])
	trust += int(t["trust"])
	cash += int(t["cash"])
	var kept: Array = []
	for m in mods:
		var left := int(m.get("ttl", 0))
		if left > 0:
			m["ttl"] = left - 1
			if left - 1 <= 0:
				continue
		kept.append(m)
	mods = kept
	last_incoming_text = ""
	var still: Array = []
	for inc in incoming:
		inc["left"] = int(inc["left"]) - 1
		if int(inc["left"]) <= 0:
			cash += int(inc["amount"])
			last_incoming_text += " Пришёл транш: %s." % fmt(int(inc["amount"]))
		else:
			still.append(inc)
	incoming = still
	last_cash_delta = cash - cash_before
	_clamp()
	return text + last_incoming_text


func next_month() -> void:
	month += 1
	ap = AP_PER_MONTH
	consulted = false


func chapter_event() -> Dictionary:
	match month:
		2:
			return Data.CHAPTERS["ch2"]
		5:
			return Data.CHAPTERS["ch5"]
		8:
			return Data.CHAPTERS["ch8"]
		10:
			return Data.CHAPTERS["ch10"]
	return {}


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


func apply_choice(ev: Dictionary, ch: Dictionary) -> Dictionary:
	var eff: Dictionary = ch.duplicate()
	var m: int = int(eff.get("money", 0))
	cash += m
	var line: String = str(eff.get("line", ""))
	if m < 0 and line != "":
		spent[line] = int(spent.get(line, 0)) + (-m)
	trust += int(eff.get("trust", 0))
	docs += int(eff.get("docs", 0))
	burnout += int(eff.get("burnout", 0))
	kpi += int(eff.get("kpi", 0))
	if eff.has("flag"):
		flags[eff["flag"]] = month
	if eff.has("mod"):
		add_mod(eff["mod"])
	var ok: bool = eff.get("ok", true)
	var topic: String = str(ev.get("topic", "budget"))
	if eff.has("issue"):
		var iss: Dictionary = eff["issue"]
		add_issue(str(iss["kind"]), str(iss["title"]), int(iss["amount"]))
	elif not ok and m < 0:
		add_issue("bad_choice", str(ev["title"]), -m)
	if ok:
		add_comp(str(eff.get("comp", Data.TOPIC_COMP.get(topic, "plan"))), 2)
		if topic == "approval" or eff.has("comp"):
			log_decision("good", str(ev["title"]), str(eff.get("lesson", "")), topic)
	else:
		log_decision("bad", str(ev["title"]), str(eff.get("lesson", "")), topic)
	_clamp()
	return eff


# ---------------------------------------------------------------- исходы

func check_game_over() -> String:
	if burnout >= 100:
		return "Команда выгорела. Проект остановлен."
	if trust <= 0:
		return "Фонд расторг соглашение."
	if cash_gaps >= 3:
		return "Нечем платить по счетам: три кассовых разрыва."
	return ""


func game_over_ending() -> String:
	if burnout >= 100:
		return "lose_burnout"
	if trust <= 0:
		return "lose_trust"
	return "lose_cash"


func events_done() -> int:
	var n := 0
	for id in ops:
		if str(pos(str(id)).get("kind", "")) == "event" and str(ops[id]["status"]) == "done":
			n += 1
	return n


func final_ending() -> String:
	if kpi < 40:
		return "lose_results"
	if refund_total >= int(GRANT_TOTAL * 0.12) or trust < 35:
		return "mid_refund"
	if kpi >= 85 and refund_total == 0 and trust >= 70 and open_issue_count() == 0:
		return "win_model"
	if kpi >= 60 and trust >= 50:
		return "win_success"
	return "mid_remarks"


func final_score() -> int:
	var s := trust * 0.3 + kpi * 0.35 + docs * 0.2 + minf(comp_total(), 40.0) / 40.0 * 15.0 - refund_total / 20000.0
	return clampi(int(s), 0, 100)


func count_charged() -> int:
	var n := 0
	for it in issues:
		if str(it["status"]) == "charged":
			n += 1
	return n


## Причины концовки для итогового отчёта
func ending_facts() -> Array:
	var out: Array = []
	out.append("Результат проекта: %d%%. Проведено мероприятий: %d из %d." % [kpi, events_done(), plan_events_count()])
	out.append("Доверие фонда: %d. Порядок в документах: %d." % [trust, docs])
	out.append("Возвращено фонду: %s (%d%% гранта)." % [fmt(refund_total), roundi(refund_total * 100.0 / GRANT_TOTAL)])
	out.append("Проверок пройдено: %d. Нарушений, найденных проверкой: %d." % [audits_done, count_charged()])
	return out


# ---------------------------------------------------------------- картинка

func scene_state() -> Dictionary:
	return {"kpi": kpi, "level": level(), "tired": burnout, "month": month, "scenario": "yard",
		"spec": "", "acts": acts, "items": items, "staff": staff.size()}


func scene_sig() -> String:
	return "%s|%s|%d|%d|%d" % [str(acts), str(items), staff.size(), level(), int(kpi / 10.0)]


# ---------------------------------------------------------------- сохранения

func _save_path(slot: String) -> String:
	return "user://save_%s.json" % slot


func _fix(v: Variant) -> Variant:
	if v is Dictionary:
		var out: Dictionary = {}
		for k in v:
			out[k] = _fix(v[k])
		return out
	if v is Array:
		var arr: Array = []
		for x in v:
			arr.append(_fix(x))
		return arr
	if v is float and v == floorf(v) and absf(v) < 1000000000.0:
		return int(v)
	return v


func save_to(slot: String, note: String) -> bool:
	var pool_ids: Array = []
	for e in events_pool:
		pool_ids.append(e["id"])
	var d: Dictionary = {
		"v": 2, "ts": Time.get_unix_time_from_system(), "date": Time.get_datetime_string_from_system(false, true), "note": note,
		"month": month, "ap": ap, "cash": cash, "trust": trust, "docs": docs, "burnout": burnout, "kpi": kpi,
		"plan_ids": plan_ids, "plan_attempts": plan_attempts, "budget": budget, "spent": spent, "auto_monthly": auto_monthly,
		"kpi_w": kpi_w, "ops": ops, "requests": requests, "staff": staff, "issues": issues, "journal": journal,
		"appr_extra": appr_extra, "overspend_charged": overspend_charged, "refund_total": refund_total,
		"audits_done": audits_done, "surprise_done": surprise_done, "mistakes": mistakes, "flags": flags,
		"used_followups": used_followups, "pool": pool_ids, "mods": mods, "items": items, "acts": acts, "comp": comp,
		"contracts_ok": contracts_ok, "consulted": consulted, "pending_tranche": pending_tranche, "incoming": incoming,
		"tranche_shares": tranche_shares, "tranche_name": tranche_name, "cash_gaps": cash_gaps,
	}
	var f := FileAccess.open(_save_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	f.close()
	return true


func _read_slot(slot: String) -> Dictionary:
	if not FileAccess.file_exists(_save_path(slot)):
		return {}
	var f := FileAccess.open(_save_path(slot), FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		var fixed: Dictionary = _fix(parsed)
		if int(fixed.get("v", 0)) != 2:
			return {}
		return fixed
	return {}


func slot_info(slot: String) -> Dictionary:
	var d := _read_slot(slot)
	if d.is_empty():
		return {}
	return {"month": int(d.get("month", 1)), "cash": int(d.get("cash", 0)), "kpi": int(d.get("kpi", 0)),
		"trust": int(d.get("trust", 0)), "date": str(d.get("date", "")), "ts": float(d.get("ts", 0))}


func latest_slot() -> String:
	var best := ""
	var best_ts := -1.0
	for slot in SAVE_SLOTS:
		var info := slot_info(slot)
		if not info.is_empty() and float(info["ts"]) > best_ts:
			best_ts = float(info["ts"])
			best = slot
	return best


func delete_slot(slot: String) -> void:
	if FileAccess.file_exists(_save_path(slot)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path(slot)))


## Загружает игру. Возвращает записку месяца или "?" при ошибке.
func load_from(slot: String) -> String:
	var d := _read_slot(slot)
	if d.is_empty():
		return "?"
	month = int(d["month"])
	max_month = 12
	ap = int(d["ap"])
	cash = int(d["cash"])
	trust = int(d["trust"])
	docs = int(d["docs"])
	burnout = int(d["burnout"])
	kpi = int(d["kpi"])
	plan_ids = d["plan_ids"]
	plan_attempts = int(d["plan_attempts"])
	budget = d["budget"]
	spent = d["spent"]
	auto_monthly = d["auto_monthly"]
	kpi_w = d["kpi_w"]
	ops = d["ops"]
	requests = d["requests"]
	staff = d["staff"]
	issues = d["issues"]
	journal = d["journal"]
	appr_extra = d["appr_extra"]
	overspend_charged = d["overspend_charged"]
	refund_total = int(d["refund_total"])
	audits_done = int(d["audits_done"])
	surprise_done = int(d["surprise_done"])
	mistakes = d["mistakes"]
	flags = d["flags"]
	used_followups = d["used_followups"]
	events_pool = []
	var all_events: Array = Data.EVENTS.duplicate()
	all_events.append_array(Data.EXTRA_EVENTS)
	for id in d["pool"]:
		for e in all_events:
			if str(e["id"]) == str(id):
				events_pool.append(e)
	mods = d["mods"]
	items = d["items"]
	acts = d["acts"]
	comp = d["comp"]
	contracts_ok = int(d["contracts_ok"])
	consulted = bool(d["consulted"])
	pending_tranche = int(d["pending_tranche"])
	incoming = d["incoming"]
	tranche_shares = []
	for sh in d["tranche_shares"]:
		tranche_shares.append(float(sh))
	while tranche_shares.size() < 5:
		tranche_shares.append(0.0)
	tranche_name = str(d["tranche_name"])
	cash_gaps = int(d["cash_gaps"])
	last_sig = ""
	last_drift = []
	new_unlocks = []
	return str(d["note"])
