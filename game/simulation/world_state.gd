extends RefCounted
## A seeded, turn-based city simulation. UI and AI use the same action rules.

const WIDTH := 6
const HEIGHT := 4
const Member = preload("res://game/simulation/member_data.gd")
const Layout = preload("res://game/simulation/city_layout.gd")
const PLAYER := "player"
const ORG_IDS := ["player", "romano", "moretti"]
const NAMES = Layout.NAMES
const ACTIONS := ["operation", "claim", "recruit", "business", "lay_low"]
const COSTS := {"operation": 0, "claim": 6000, "recruit": 2500, "business": 6500, "lay_low": 1800}
const SAVE_VERSION := 3
const SAVE_PATH := "user://underworld_save.json"
const STAT_LIMITS := {"cash": [0, 10000000], "heat": [0, 100], "influence": [0, 999], "members": [1, 60], "loyalty": [0, 100]}

var day: int = 1
var city_layout: String = Layout.IRON_HAVEN
var market: int = 100
var orders: int = 2
var organizations: Dictionary = {}
var districts: Array = []
var events: Array = []
var request_pending: bool = true
var request_name: String = "Tony Vega"
var request_member_id: int = 1
var next_member_id: int = 1
var rng := RandomNumberGenerator.new()
# Diagnostics are observations, not simulation inputs. They reset on load.
var ai_decisions: Dictionary = {}
var member_changes: Array = []

func _init(world_seed: int = 2026) -> void:
	rng.seed = world_seed
	organizations = {
		"player": {"name": "Player", "cash": 48250, "heat": 36, "influence": 127, "members": 8, "loyalty": 74},
		"romano": {"name": "Romano Crew", "cash": 38000, "heat": 42, "influence": 104, "members": 7, "loyalty": 68},
		"moretti": {"name": "Moretti Syndicate", "cash": 42000, "heat": 28, "influence": 116, "members": 9, "loyalty": 80},
	}
	for org_id in ORG_IDS:
		var org: Dictionary = organizations[org_id]
		org.roster = Member.starting_roster(int(org.members), int(org.loyalty), next_member_id, org_id == PLAYER)
		next_member_id += int(org.members)
		_sync_roster(org)
	for i in range(WIDTH * HEIGHT):
		var owner := "neutral"
		if i in [6, 7, 12]:
			owner = PLAYER
		elif i in [0, 1, 2, 8, 14]:
			owner = "romano"
		elif i in [9, 10, 15, 16]:
			owner = "moretti"
		var businesses := 0 if owner == "neutral" else 1
		if i == 7:
			businesses = 2
		districts.append({"name": NAMES[i], "owner": owner, "businesses": businesses, "attention": 52 if i == 7 else 15 + i % 5 * 7})
	_event("Police surveillance increased in Downtown, Iron Haven.", "police")
	_event("Romano Crew is expanding near your territory.", "rival")
	_event("Tony Vega requests a promotion. Review the member request.", "member")

func territory(org_id: String = PLAYER) -> int:
	var count := 0
	for district in districts:
		if district.owner == org_id:
			count += 1
	return count

func businesses(org_id: String = PLAYER) -> int:
	var count := 0
	for district in districts:
		if district.owner == org_id:
			count += int(district.businesses)
	return count

func daily_income(org_id: String = PLAYER) -> int:
	return int((businesses(org_id) * 650 + territory(org_id) * 160) * market / 100.0)

func daily_payroll(org_id: String = PLAYER) -> int:
	return int(organizations[org_id].members) * 140

func neighbors(index: int) -> Array:
	return Layout.neighbors(index, city_layout)

func borders(index: int, org_id: String) -> bool:
	for adjacent in neighbors(index):
		if districts[adjacent].owner == org_id:
			return true
	return false

func action_blocker(action: String, org_id: String = PLAYER, index: int = 7) -> String:
	if action not in ACTIONS or org_id not in ORG_IDS:
		return "Unknown order."
	if index < 0 or index >= districts.size():
		return "Select a district."
	if org_id == PLAYER and orders <= 0:
		return "No orders remaining. Advance to the next day."
	var org: Dictionary = organizations[org_id]
	var district: Dictionary = districts[index]
	if int(org.cash) < int(COSTS[action]):
		return "Insufficient cash."
	match action:
		"operation":
			if district.owner != org_id:
				return "Select a district you control."
		"claim":
			if district.owner == org_id:
				return "You already control this district."
			if not borders(index, org_id):
				return "Choose a bordering district. Cross the river through a bridge approach." if city_layout == Layout.IRON_HAVEN else "Choose a district bordering your territory."
			if int(org.members) < 5 or int(org.influence) < 40:
				return "Requires 5 members and 40 influence."
		"business":
			if district.owner != org_id:
				return "Select a district you control."
			if int(district.businesses) >= 3:
				return "This district already has 3 businesses."
		"recruit":
			if int(org.members) >= 60:
				return "Organization is at its 60-member limit."
		"lay_low":
			if int(org.heat) == 0:
				return "Heat is already at zero."
	return ""

func perform_action(action: String, org_id: String = PLAYER, index: int = 7) -> Dictionary:
	var blocker := action_blocker(action, org_id, index)
	if not blocker.is_empty():
		return {"ok": false, "message": blocker}
	var org: Dictionary = organizations[org_id]
	var district: Dictionary = districts[index]
	org.cash -= int(COSTS[action])
	if org_id == PLAYER:
		orders -= 1
	var message := ""
	match action:
		"operation":
			var earnings := rng.randi_range(1900, 4100)
			org.cash += earnings
			org.heat += 9
			org.influence += 3
			district.attention = mini(100, int(district.attention) + 12)
			message = "%s earned $%s from an operation in %s. Heat +9." % [org.name, money(earnings), district.name]
		"claim":
			var previous: String = district.owner
			var success := previous == "neutral"
			if previous != "neutral":
				var defender: Dictionary = organizations[previous]
				var chance := clampf(0.48 + (float(org.members) - float(defender.members)) * 0.025 + (float(org.influence) - float(defender.influence)) * 0.002, 0.2, 0.8)
				success = rng.randf() < chance
			org.heat += 8
			district.attention = mini(100, int(district.attention) + 10)
			if success:
				district.owner = org_id
				org.influence += 8
				if previous != "neutral":
					organizations[previous].influence = maxi(0, int(organizations[previous].influence) - 6)
				message = "%s took control of %s. Influence +8." % [org.name, district.name]
			else:
				org.influence = maxi(0, int(org.influence) - 2)
				message = "%s held %s against %s. The challenge cost $6,000." % [organizations[previous].name, district.name, org.name]
		"recruit":
			var previous_members: int = org.members
			var recruit := _add_member(org_id)
			_adjust_loyalty(org, 1)
			_record_membership(org_id, previous_members, int(org.members), "recruitment", Member.full_name(recruit))
			message = "%s recruited %s (%d → %d). Daily payroll +$140." % [org.name, Member.full_name(recruit), previous_members, org.members]
		"business":
			district.businesses += 1
			org.influence += 2
			message = "%s opened a business in %s. Base daily revenue +$650." % [org.name, district.name]
		"lay_low":
			org.heat = maxi(0, int(org.heat) - 14)
			_adjust_loyalty(org, 2)
			message = "%s is keeping a low profile. Heat −14." % org.name
	_normalize(org)
	_event(message, "player" if org_id == PLAYER else "rival")
	return {"ok": true, "message": message}

func resolve_request(promote: bool) -> Dictionary:
	if not request_pending:
		return {"ok": false, "message": "No member request pending."}
	var org: Dictionary = organizations[PLAYER]
	var member := find_member(PLAYER, request_member_id)
	if member.is_empty():
		return {"ok": false, "message": "The requesting member is no longer in your roster."}
	if promote and int(org.cash) < 1200:
		return {"ok": false, "message": "Promotion requires $1,200."}
	request_pending = false
	if promote:
		org.cash -= 1200
		member.loyalty = mini(100, int(member.loyalty) + 6)
	else:
		member.loyalty = maxi(0, int(member.loyalty) - 5)
	_sync_roster(org)
	var message := "%s was promoted. Loyalty +6." % request_name if promote else "%s's promotion was declined. Loyalty −5." % request_name
	_event(message, "member")
	return {"ok": true, "message": message}

func advance_day() -> void:
	day += 1
	orders = 2
	market = clampi(market + rng.randi_range(-6, 6), 65, 135)
	for district in districts:
		district.attention = maxi(0, int(district.attention) - 2)
	for org_id in ORG_IDS:
		var org: Dictionary = organizations[org_id]
		var income := daily_income(org_id)
		var payroll := daily_payroll(org_id)
		org.cash += income
		if int(org.cash) < payroll:
			_adjust_loyalty(org, -8)
			_lose_member(org_id, "unpaid payroll", "economy")
			_event("%s missed payroll. Loyalty −8." % org.name, "economy")
		org.cash = maxi(0, int(org.cash) - payroll)
		org.heat = maxi(0, int(org.heat) - 2)
		if _least_loyal(org).loyalty < 35 and int(org.members) > 3 and rng.randf() < 0.2:
			_lose_member(org_id, "low loyalty", "member")
		_normalize(org)
		if org_id == PLAYER:
			_event("Daily accounts: $%s income, $%s payroll. Market demand %d%%." % [money(income), money(payroll), market], "economy")
	for org_id in ["romano", "moretti"]:
		_ai_turn(org_id)
	_police_turn()
	if day % 7 == 0 and not request_pending:
		request_pending = true
		var roster: Array = organizations[PLAYER].roster
		var requester: Dictionary = roster[rng.randi_range(0, roster.size() - 1)]
		request_member_id = int(requester.id)
		request_name = Member.full_name(requester)
		_event("%s requests a promotion." % request_name, "member")

func _ai_turn(org_id: String) -> void:
	var org: Dictionary = organizations[org_id]
	var owned: Array = []
	var expansion: Array = []
	for i in range(districts.size()):
		if districts[i].owner == org_id:
			owned.append(i)
		elif borders(i, org_id):
			expansion.append(i)
	# React at the investigation threshold, allowing risky actions to carry
	# police consequences instead of keeping rivals permanently below it.
	if int(org.heat) >= 65 and int(org.cash) >= 1800:
		_ai_action("lay_low", org_id, 0, "Heat reached the police investigation threshold.")
		return
	var crew_target := recruitment_target(org_id)
	var reserve := recruitment_reserve(org_id)
	var affordable := int(org.cash) >= 2500 + reserve
	var sustainable := daily_income(org_id) >= daily_payroll(org_id) + 140
	var understaffed := int(org.members) < crew_target
	if understaffed and affordable and (int(org.members) < 6 or sustainable) and (int(org.members) < 6 or rng.randf() < 0.4):
		_ai_action("recruit", org_id, 0, "Crew %d/%d; recruitment preserves three days of payroll ($%s)." % [org.members, crew_target, money(reserve)])
		return
	var staffing := "Crew %d/%d. " % [org.members, crew_target]
	if understaffed and not affordable:
		staffing += "Recruitment needs $%s including payroll reserve. " % money(2500 + reserve)
	elif understaffed and not sustainable:
		staffing += "Daily revenue cannot support another member. "
	if not expansion.is_empty() and rng.randf() < 0.5 and int(org.cash) >= 6000:
		var target: int = expansion[rng.randi_range(0, expansion.size() - 1)]
		if _ai_action("claim", org_id, target, staffing + "Pursuing adjacent territory.").ok:
			return
	if not owned.is_empty():
		var target: int = owned[rng.randi_range(0, owned.size() - 1)]
		if int(org.cash) >= 6500 and int(districts[target].businesses) < 3 and rng.randf() < 0.45:
			_ai_action("business", org_id, target, staffing + "Investing in daily revenue.")
		else:
			_ai_action("operation", org_id, target, staffing + "Raising operating cash.")
	else:
		ai_decisions[org_id] = {"day": day, "action": "wait", "reason": staffing + "No territory for an operation or business."}
		_event("%s has no territory and is waiting for an opportunity." % org.name, "rival")

func recruitment_target(org_id: String) -> int:
	return clampi(4 + territory(org_id) * 2, 6, 30)

func recruitment_reserve(org_id: String) -> int:
	return (int(organizations[org_id].members) + 1) * 140 * 3

func _ai_action(action: String, org_id: String, index: int, reason: String) -> Dictionary:
	var result := perform_action(action, org_id, index)
	ai_decisions[org_id] = {"day": day, "action": action, "reason": reason if result.ok else result.message}
	return result

func _record_membership(org_id: String, before: int, after: int, reason: String, person: String = "") -> void:
	if before == after:
		return
	member_changes.push_front({"day": day, "organization": org_id, "before": before, "after": after, "reason": reason, "person": person})
	if member_changes.size() > 100:
		member_changes.resize(100)

func _lose_member(org_id: String, reason: String, kind: String) -> void:
	var org: Dictionary = organizations[org_id]
	if int(org.members) <= 3:
		return
	var before: int = org.members
	var member: Dictionary = org.roster[rng.randi_range(0, org.roster.size() - 1)] if reason == "police detention" else _least_loyal(org)
	org.roster.erase(member)
	_cancel_departed_request(int(member.id))
	_sync_roster(org)
	_record_membership(org_id, before, int(org.members), reason, Member.full_name(member))
	_event("%s lost %s to %s (%d → %d)." % [org.name, Member.full_name(member), reason, before, org.members], kind)

func _police_turn() -> void:
	for org_id in ORG_IDS:
		var org: Dictionary = organizations[org_id]
		if int(org.heat) >= 65 and rng.randf() < float(org.heat) / 160.0:
			var fine := mini(int(org.cash), rng.randi_range(2200, 4500))
			org.cash -= fine
			org.heat = maxi(0, int(org.heat) - 12)
			_adjust_loyalty(org, -4)
			_lose_member(org_id, "police detention", "police")
			_event("Police investigated %s. $%s seized; loyalty −4." % [org.name, money(fine)], "police")
	if day % 4 == 0:
		var watched := rng.randi_range(0, districts.size() - 1)
		districts[watched].attention = mini(100, int(districts[watched].attention) + 18)
		_event("Police surveillance increased in %s." % districts[watched].name, "police")

func _normalize(org: Dictionary) -> void:
	org.cash = clampi(int(org.cash), 0, 10000000)
	org.heat = clampi(int(org.heat), 0, 100)
	org.influence = clampi(int(org.influence), 0, 999)
	_sync_roster(org)

func find_member(org_id: String, member_id: int) -> Dictionary:
	if org_id not in ORG_IDS:
		return {}
	for member in organizations[org_id].roster:
		if int(member.id) == member_id:
			return member
	return {}

func _sync_roster(org: Dictionary) -> void:
	org.members = org.roster.size()
	var total := 0
	for member in org.roster:
		total += int(member.loyalty)
	org.loyalty = roundi(float(total) / org.roster.size())

func _adjust_loyalty(org: Dictionary, delta: int) -> void:
	for member in org.roster:
		member.loyalty = clampi(int(member.loyalty) + delta, 0, 100)
	_sync_roster(org)

func _least_loyal(org: Dictionary) -> Dictionary:
	var result: Dictionary = org.roster[0]
	for member in org.roster:
		if int(member.loyalty) < int(result.loyalty):
			result = member
	return result

func _add_member(org_id: String) -> Dictionary:
	var org: Dictionary = organizations[org_id]
	var member := Member.create(next_member_id, day, int(org.loyalty))
	next_member_id += 1
	org.roster.append(member)
	_sync_roster(org)
	return member

func _cancel_departed_request(member_id: int) -> void:
	if request_pending and request_member_id == member_id:
		request_pending = false
		_event("%s's promotion request closed because they left the roster." % request_name, "member")

func debug_set_member(org_id: String, member_id: int, values: Dictionary) -> Dictionary:
	var member := find_member(org_id, member_id)
	if member.is_empty() or values.is_empty():
		return {"ok": false, "message": "Select an active member and at least one field."}
	for field in values:
		if field in ["first_name", "last_name"]:
			if not _valid_name(values[field]):
				return {"ok": false, "message": "Names must contain 1–40 visible characters."}
		elif field == "age":
			if not _integer(values[field], 18, 100):
				return {"ok": false, "message": "Age must be 18–100."}
		elif field == "loyalty":
			if not _integer(values[field], 0, 100):
				return {"ok": false, "message": "Loyalty must be 0–100."}
		else:
			return {"ok": false, "message": "Unknown member field."}
	var previous_name := Member.full_name(member)
	for field in values:
		member[field] = values[field].strip_edges() if field in ["first_name", "last_name"] else int(values[field])
	_sync_roster(organizations[org_id])
	if request_member_id == member_id:
		request_name = Member.full_name(member)
	var message := "[DEBUG] %s's profile updated." % previous_name
	_event(message, "debug")
	return {"ok": true, "message": message}

static func _valid_name(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length() <= 40 and not "\n" in value and not "\r" in value and not "\t" in value

func _event(text: String, kind: String) -> void:
	events.push_front({"day": day, "text": text, "kind": kind})
	if events.size() > 80:
		events.resize(80)

static func money(amount: int) -> String:
	var digits := str(absi(amount))
	var result := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0:
			result += ","
		result += digits[i]
	return ("−" if amount < 0 else "") + result

func debug_set_organization(org_id: String, values: Dictionary) -> Dictionary:
	if org_id not in ORG_IDS or values.is_empty():
		return {"ok": false, "message": "Select a faction and at least one stat."}
	for field in values:
		if field not in STAT_LIMITS or not _integer(values[field], STAT_LIMITS[field][0], STAT_LIMITS[field][1]):
			return {"ok": false, "message": "Invalid faction stat: %s." % field}
	var before: int = organizations[org_id].members
	var org: Dictionary = organizations[org_id]
	if "members" in values:
		while org.roster.size() < int(values.members):
			_add_member(org_id)
		while org.roster.size() > int(values.members):
			var removed: Dictionary = org.roster.pop_back()
			_cancel_departed_request(int(removed.id))
	for field in values:
		if field == "loyalty":
			for member in org.roster:
				member.loyalty = int(values.loyalty)
		elif field != "members":
			org[field] = int(values[field])
	_sync_roster(org)
	_record_membership(org_id, before, int(organizations[org_id].members), "debug override")
	var message := "[DEBUG] %s stats overridden." % organizations[org_id].name
	_event(message, "debug")
	return {"ok": true, "message": message}

func debug_set_district(index: int, owner: String, count: int, attention: int) -> Dictionary:
	if index < 0 or index >= districts.size() or owner not in ORG_IDS + ["neutral"] or count < 0 or count > 3 or attention < 0 or attention > 100:
		return {"ok": false, "message": "Invalid district values."}
	districts[index].owner = owner
	districts[index].businesses = count
	districts[index].attention = attention
	var message := "[DEBUG] %s ownership, businesses, and attention overridden." % districts[index].name
	_event(message, "debug")
	return {"ok": true, "message": message}

func debug_set_world(demand: int, available_orders: int) -> Dictionary:
	if demand < 65 or demand > 135 or available_orders < 0 or available_orders > 2:
		return {"ok": false, "message": "Market must be 65–135; orders must be 0–2."}
	market = demand
	orders = available_orders
	var message := "[DEBUG] Market set to %d%%; available orders %d." % [market, orders]
	_event(message, "debug")
	return {"ok": true, "message": message}

func debug_scenario(org_id: String, scenario: String) -> Dictionary:
	if org_id not in ORG_IDS or scenario not in ["recruitment", "unpaid_payroll", "police"]:
		return {"ok": false, "message": "Unknown debug scenario."}
	var values: Dictionary
	match scenario:
		"recruitment":
			values = {"cash": 50000, "members": 3, "loyalty": 80, "heat": 0}
		"unpaid_payroll":
			# 40 members cost more than even 24 empty districts can earn.
			values = {"cash": 0, "members": 40, "loyalty": 70, "heat": 0}
		"police":
			values = {"cash": 50000, "members": 10, "loyalty": 70, "heat": 100}
	var result := debug_set_organization(org_id, values)
	if scenario == "unpaid_payroll":
		for district in districts:
			if district.owner == org_id:
				district.businesses = 0
	result.message = "[DEBUG] %s scenario prepared for %s. Advance time to observe the outcome." % [scenario.replace("_", " "), organizations[org_id].name]
	_event(result.message, "debug")
	return result

func debug_advance(days: int) -> Dictionary:
	if days < 1 or days > 365 or day + days > 100000:
		return {"ok": false, "message": "Advance 1–365 days within the save's day limit."}
	for i in range(days):
		advance_day()
	var message := "[DEBUG] Advanced %d days. Now day %d." % [days, day]
	_event(message, "debug")
	return {"ok": true, "message": message}

func save_data() -> Dictionary:
	return {"version": SAVE_VERSION, "city_layout": city_layout, "day": day, "market": market, "orders": orders,
		"organizations": organizations.duplicate(true), "districts": districts.duplicate(true),
		"events": events.duplicate(true), "request_pending": request_pending,
		"request_name": request_name, "request_member_id": request_member_id,
		"next_member_id": next_member_id, "rng_state": str(rng.state)}

func save_game(path: String = SAVE_PATH) -> Error:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(save_data(), "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return write_error
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))

func load_game(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return false
	return restore_data(json.data)

func restore_data(data: Variant) -> bool:
	# Validate the complete save before touching the live world.
	if not data is Dictionary or not _integer(data.get("version"), 1, SAVE_VERSION):
		return false
	if int(data.version) == 1:
		data = _migrate_v1(data)
		if data.is_empty():
			return false
	# Older saves retain their original district names and grid connections.
	var saved_layout: Variant = Layout.LEGACY if int(data.version) == 2 else data.get("city_layout")
	if saved_layout not in [Layout.LEGACY, Layout.IRON_HAVEN]:
		return false
	if not _integer(data.get("day"), 1, 100000) or not _integer(data.get("market"), 65, 135) or not _integer(data.get("orders"), 0, 2):
		return false
	if not data.get("request_pending") is bool or not data.get("request_name") is String:
		return false
	if data.request_name.length() > 80 or not data.get("rng_state") is String or not data.rng_state.is_valid_int():
		return false
	if not _integer(data.get("next_member_id"), 2, 10000000) or not _integer(data.get("request_member_id"), 1, int(data.next_member_id) - 1):
		return false
	if not data.get("organizations") is Dictionary or data.organizations.size() != ORG_IDS.size():
		return false
	var used_ids := {}
	var pending_request_valid: bool = not data.request_pending
	for org_id in ORG_IDS:
		var org: Variant = data.organizations.get(org_id)
		if not org is Dictionary or not org.get("name") is String or org.name != organizations[org_id].name:
			return false
		for field in ["cash", "heat", "influence", "members", "loyalty"]:
			var limits: Array = STAT_LIMITS[field]
			if not _integer(org.get(field), limits[0], limits[1]):
				return false
		if not org.get("roster") is Array or org.roster.size() != int(org.members):
			return false
		var total_loyalty := 0
		for member in org.roster:
			if not member is Dictionary or not _valid_name(member.get("first_name")) or not _valid_name(member.get("last_name")):
				return false
			if not _integer(member.get("id"), 1, int(data.next_member_id) - 1) or used_ids.has(int(member.id)):
				return false
			if not _integer(member.get("age"), 18, 100) or not _integer(member.get("loyalty"), 0, 100) or not _integer(member.get("joined_day"), 1, int(data.day)):
				return false
			used_ids[int(member.id)] = true
			total_loyalty += int(member.loyalty)
			if org_id == PLAYER and int(member.id) == int(data.request_member_id) and Member.full_name(member) == data.request_name:
				pending_request_valid = true
		if int(org.loyalty) != roundi(float(total_loyalty) / org.roster.size()):
			return false
	if not pending_request_valid:
		return false
	if not data.get("districts") is Array or data.districts.size() != WIDTH * HEIGHT:
		return false
	for i in range(data.districts.size()):
		var district: Variant = data.districts[i]
		if not district is Dictionary or district.get("name") != Layout.names(saved_layout)[i] or district.get("owner") not in ORG_IDS + ["neutral"]:
			return false
		if not _integer(district.get("businesses"), 0, 3) or not _integer(district.get("attention"), 0, 100):
			return false
	if not data.get("events") is Array or data.events.size() > 80:
		return false
	for entry in data.events:
		if not entry is Dictionary or not _integer(entry.get("day"), 1, int(data.day)):
			return false
		if not entry.get("text") is String or entry.text.length() > 300 or entry.get("kind") not in ["player", "rival", "police", "member", "economy", "debug"]:
			return false
	day = int(data.day)
	city_layout = saved_layout
	market = int(data.market)
	orders = int(data.orders)
	organizations = data.organizations.duplicate(true)
	districts = data.districts.duplicate(true)
	events = data.events.duplicate(true)
	# Godot's JSON parser returns floats for numeric values. Restore integer
	# simulation fields so arithmetic and subsequent saves remain identical.
	for org_id in ORG_IDS:
		for member in organizations[org_id].roster:
			for field in ["id", "age", "loyalty", "joined_day"]:
				member[field] = int(member[field])
		_normalize(organizations[org_id])
	for district in districts:
		district.businesses = int(district.businesses)
		district.attention = int(district.attention)
	for entry in events:
		entry.day = int(entry.day)
	request_pending = data.request_pending
	request_name = data.request_name
	request_member_id = int(data.request_member_id)
	next_member_id = int(data.next_member_id)
	rng.state = int(data.rng_state)
	ai_decisions.clear()
	member_changes.clear()
	return true

func _migrate_v1(original: Dictionary) -> Dictionary:
	# Build a candidate without changing live state or advancing simulation RNG.
	var legacy_ids := ["navarro", "romano", "moretti"]
	var legacy_names := ["Navarro Organization", "Romano Crew", "Moretti Syndicate"]
	if not original.get("organizations") is Dictionary or original.organizations.size() != 3 or not original.get("districts") is Array or not original.get("events") is Array:
		return {}
	if not original.get("request_name") is String or not original.get("request_pending") is bool:
		return {}
	var data := original.duplicate(true)
	var id := 1
	for i in range(legacy_ids.size()):
		var org: Variant = data.organizations.get(legacy_ids[i])
		if not org is Dictionary or org.get("name") != legacy_names[i]:
			return {}
		if not _integer(org.get("members"), 1, 60) or not _integer(org.get("loyalty"), 0, 100):
			return {}
		org.roster = Member.starting_roster(int(org.members), int(org.loyalty), id, i == 0)
		for member in org.roster:
			member.loyalty = int(org.loyalty)
		id += int(org.members)
	data.organizations[PLAYER] = data.organizations.navarro
	data.organizations.erase("navarro")
	data.organizations[PLAYER].name = "Player"
	for district in data.districts:
		if district is Dictionary and district.get("owner") == "navarro":
			district.owner = PLAYER
	for entry in data.events:
		if entry is Dictionary and entry.get("text") is String:
			entry.text = entry.text.replace("Navarro Organization", "Player").replace("Navarro", "Player")
	var requester: Dictionary = data.organizations[PLAYER].roster[0]
	for member in data.organizations[PLAYER].roster:
		if Member.full_name(member) == data.request_name:
			requester = member
			break
	if data.request_pending and Member.full_name(requester) != data.request_name:
		var parts: PackedStringArray = data.request_name.split(" ", false, 1)
		if parts.size() != 2 or not _valid_name(parts[0]) or not _valid_name(parts[1]):
			return {}
		requester.first_name = parts[0]
		requester.last_name = parts[1]
	data.request_name = Member.full_name(requester)
	data.request_member_id = int(requester.id)
	data.next_member_id = id
	data.version = 2
	return data

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and float(value) == floorf(float(value)) and value >= minimum and value <= maximum
