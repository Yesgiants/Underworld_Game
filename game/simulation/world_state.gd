extends RefCounted
## A seeded, turn-based city simulation. UI and AI use the same action rules.

const WIDTH := 6
const HEIGHT := 4
const PLAYER := "navarro"
const ORG_IDS := ["navarro", "romano", "moretti"]
const NAMES := [
	"North End", "Little Italy", "Old Quarter", "Uptown", "East Village", "The Heights",
	"West Market", "Downtown", "Civic Center", "Midtown", "East Market", "Parkside",
	"West Docks", "Warehouse Row", "Rail Yards", "Southbank", "Foundry", "Riverside",
	"Harbor Point", "Fish Market", "Shipyards", "The Narrows", "South End", "Bayview",
]
const ACTIONS := ["operation", "claim", "recruit", "business", "lay_low"]
const COSTS := {"operation": 0, "claim": 6000, "recruit": 2500, "business": 6500, "lay_low": 1800}
const SAVE_VERSION := 1
const SAVE_PATH := "user://underworld_save.json"

var day: int = 1
var market: int = 100
var orders: int = 2
var organizations: Dictionary = {}
var districts: Array = []
var events: Array = []
var request_pending: bool = true
var request_name: String = "Tony Vega"
var rng := RandomNumberGenerator.new()

func _init(world_seed: int = 2026) -> void:
	rng.seed = world_seed
	organizations = {
		"navarro": {"name": "Navarro Organization", "cash": 48250, "heat": 36, "influence": 127, "members": 8, "loyalty": 74},
		"romano": {"name": "Romano Crew", "cash": 38000, "heat": 42, "influence": 104, "members": 7, "loyalty": 68},
		"moretti": {"name": "Moretti Syndicate", "cash": 42000, "heat": 28, "influence": 116, "members": 9, "loyalty": 80},
	}
	for i in range(WIDTH * HEIGHT):
		var owner := "neutral"
		if i in [6, 7, 12]:
			owner = PLAYER
		elif i in [0, 1, 2, 8, 9]:
			owner = "romano"
		elif i in [15, 16, 21, 22]:
			owner = "moretti"
		var businesses := 0 if owner == "neutral" else 1
		if i == 7:
			businesses = 2
		districts.append({"name": NAMES[i], "owner": owner, "businesses": businesses, "attention": 52 if i == 7 else 15 + i % 5 * 7})
	_event("Police surveillance increased in Downtown.", "police")
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
	var result: Array = []
	var x := index % WIDTH
	var y := index / WIDTH
	if x > 0:
		result.append(index - 1)
	if x < WIDTH - 1:
		result.append(index + 1)
	if y > 0:
		result.append(index - WIDTH)
	if y < HEIGHT - 1:
		result.append(index + WIDTH)
	return result

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
				return "Choose a district bordering your territory."
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
			org.members += 1
			org.loyalty = mini(100, int(org.loyalty) + 1)
			message = "%s recruited a member. Daily payroll +$140." % org.name
		"business":
			district.businesses += 1
			org.influence += 2
			message = "%s opened a business in %s. Base daily revenue +$650." % [org.name, district.name]
		"lay_low":
			org.heat = maxi(0, int(org.heat) - 14)
			org.loyalty = mini(100, int(org.loyalty) + 2)
			message = "%s is keeping a low profile. Heat −14." % org.name
	_normalize(org)
	_event(message, "player" if org_id == PLAYER else "rival")
	return {"ok": true, "message": message}

func resolve_request(promote: bool) -> Dictionary:
	if not request_pending:
		return {"ok": false, "message": "No member request pending."}
	var org: Dictionary = organizations[PLAYER]
	if promote and int(org.cash) < 1200:
		return {"ok": false, "message": "Promotion requires $1,200."}
	request_pending = false
	if promote:
		org.cash -= 1200
		org.loyalty = mini(100, int(org.loyalty) + 6)
	else:
		org.loyalty = maxi(0, int(org.loyalty) - 5)
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
			org.loyalty -= 8
			if int(org.members) > 3:
				org.members -= 1
			_event("%s missed payroll. Loyalty fell and a member may have left." % org.name, "economy")
		org.cash = maxi(0, int(org.cash) - payroll)
		org.heat = maxi(0, int(org.heat) - 2)
		if int(org.loyalty) < 35 and int(org.members) > 3 and rng.randf() < 0.2:
			org.members -= 1
			_event("A disloyal member left %s." % org.name, "member")
		_normalize(org)
		if org_id == PLAYER:
			_event("Daily accounts: $%s income, $%s payroll. Market demand %d%%." % [money(income), money(payroll), market], "economy")
	for org_id in ["romano", "moretti"]:
		_ai_turn(org_id)
	_police_turn()
	if day % 7 == 0 and not request_pending:
		request_pending = true
		request_name = ["Tony Vega", "Elena Cruz", "Marcus Reed"][rng.randi_range(0, 2)]
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
	if int(org.heat) >= 55 and int(org.cash) >= 1800:
		perform_action("lay_low", org_id, 0)
		return
	if int(org.members) < 6 and int(org.cash) >= 2500:
		perform_action("recruit", org_id, 0)
		return
	if not expansion.is_empty() and rng.randf() < 0.5 and int(org.cash) >= 6000:
		var target: int = expansion[rng.randi_range(0, expansion.size() - 1)]
		if perform_action("claim", org_id, target).ok:
			return
	if not owned.is_empty():
		var target: int = owned[rng.randi_range(0, owned.size() - 1)]
		if int(org.cash) >= 6500 and int(districts[target].businesses) < 3 and rng.randf() < 0.45:
			perform_action("business", org_id, target)
		else:
			perform_action("operation", org_id, target)
	elif int(org.cash) >= 2500 and int(org.members) < 60:
		perform_action("recruit", org_id, 0)
	else:
		_event("%s has no territory and is waiting for an opportunity." % org.name, "rival")

func _police_turn() -> void:
	for org_id in ORG_IDS:
		var org: Dictionary = organizations[org_id]
		if int(org.heat) >= 65 and rng.randf() < float(org.heat) / 160.0:
			var fine := mini(int(org.cash), rng.randi_range(2200, 4500))
			org.cash -= fine
			org.heat = maxi(0, int(org.heat) - 12)
			org.loyalty = maxi(0, int(org.loyalty) - 4)
			_event("Police investigated %s. $%s seized; loyalty −4." % [org.name, money(fine)], "police")
	if day % 4 == 0:
		var watched := rng.randi_range(0, districts.size() - 1)
		districts[watched].attention = mini(100, int(districts[watched].attention) + 18)
		_event("Police surveillance increased in %s." % districts[watched].name, "police")

func _normalize(org: Dictionary) -> void:
	org.cash = clampi(int(org.cash), 0, 10000000)
	org.members = clampi(int(org.members), 1, 60)
	org.heat = clampi(int(org.heat), 0, 100)
	org.influence = clampi(int(org.influence), 0, 999)
	org.loyalty = clampi(int(org.loyalty), 0, 100)

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

func save_data() -> Dictionary:
	return {"version": SAVE_VERSION, "day": day, "market": market, "orders": orders,
		"organizations": organizations.duplicate(true), "districts": districts.duplicate(true),
		"events": events.duplicate(true), "request_pending": request_pending,
		"request_name": request_name, "rng_state": str(rng.state)}

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
	if not _integer(data.get("day"), 1, 100000) or not _integer(data.get("market"), 65, 135) or not _integer(data.get("orders"), 0, 2):
		return false
	if not data.get("request_pending") is bool or not data.get("request_name") is String:
		return false
	if data.request_name.length() > 80 or not data.get("rng_state") is String or not data.rng_state.is_valid_int():
		return false
	if not data.get("organizations") is Dictionary or data.organizations.size() != ORG_IDS.size():
		return false
	for org_id in ORG_IDS:
		var org: Variant = data.organizations.get(org_id)
		if not org is Dictionary or not org.get("name") is String or org.name != organizations[org_id].name:
			return false
		for field in ["cash", "heat", "influence", "members", "loyalty"]:
			var limits: Array = {"cash": [0, 10000000], "heat": [0, 100], "influence": [0, 999], "members": [1, 60], "loyalty": [0, 100]}[field]
			if not _integer(org.get(field), limits[0], limits[1]):
				return false
	if not data.get("districts") is Array or data.districts.size() != WIDTH * HEIGHT:
		return false
	for i in range(data.districts.size()):
		var district: Variant = data.districts[i]
		if not district is Dictionary or district.get("name") != NAMES[i] or district.get("owner") not in ORG_IDS + ["neutral"]:
			return false
		if not _integer(district.get("businesses"), 0, 3) or not _integer(district.get("attention"), 0, 100):
			return false
	if not data.get("events") is Array or data.events.size() > 80:
		return false
	for entry in data.events:
		if not entry is Dictionary or not _integer(entry.get("day"), 1, int(data.day)):
			return false
		if not entry.get("text") is String or entry.text.length() > 300 or entry.get("kind") not in ["player", "rival", "police", "member", "economy"]:
			return false
	day = int(data.day)
	market = int(data.market)
	orders = int(data.orders)
	organizations = data.organizations.duplicate(true)
	districts = data.districts.duplicate(true)
	events = data.events.duplicate(true)
	# Godot's JSON parser returns floats for numeric values. Restore integer
	# simulation fields so arithmetic and subsequent saves remain identical.
	for org_id in ORG_IDS:
		_normalize(organizations[org_id])
	for district in districts:
		district.businesses = int(district.businesses)
		district.attention = int(district.attention)
	for entry in events:
		entry.day = int(entry.day)
	request_pending = data.request_pending
	request_name = data.request_name
	rng.state = int(data.rng_state)
	return true

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and float(value) == floorf(float(value)) and value >= minimum and value <= maximum
