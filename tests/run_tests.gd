extends SceneTree

const World = preload("res://game/simulation/world_state.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_initial_state()
	_actions_and_orders()
	_operation_businesses()
	_economy()
	_member_requests()
	_ai_and_police()
	_save_and_replay()
	_bad_saves()
	_rival_staffing()
	_debug_tools()
	print("SIMULATION TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func snapshot(world: RefCounted) -> String:
	return JSON.stringify(world.save_data())

func _initial_state() -> void:
	var world = World.new()
	expect(world.districts.size() == 24, "24 simulated districts")
	expect(world.territory() == 3 and world.businesses() == 4, "Starting territory and businesses match the layout")
	expect(world.organizations.player.cash == 48250 and world.organizations.player.members == 8, "Starting organization stats")
	expect(world.daily_income() == 3080 and world.daily_payroll() == 1120, "Income and payroll derive from the world")
	expect(world.neighbors(0) == [1, 6] and world.neighbors(5) == [4, 11], "Map edges do not wrap")

func _actions_and_orders() -> void:
	var world = World.new()
	var before := snapshot(world)
	expect(not world.perform_action("claim", World.PLAYER, 23).ok, "Cannot claim a remote district")
	expect(snapshot(world) == before, "Rejected actions do not change cash, orders, events, or RNG")
	expect(world.perform_action("business", World.PLAYER, 7).ok, "Business order succeeds on owned district")
	expect(world.organizations.player.cash == 41750 and world.businesses() == 5 and world.daily_income() == 3730, "Business costs cash and increases income")
	expect(world.perform_action("claim", World.PLAYER, 13).ok, "Adjacent independent district can be claimed")
	expect(world.districts[13].owner == World.PLAYER and world.territory() == 4, "Claim changes map ownership")
	before = snapshot(world)
	expect(not world.perform_action("operation", World.PLAYER, 7).ok and snapshot(world) == before, "Two orders per day; third order rejected atomically")
	world.advance_day()
	expect(world.orders == 2, "New day replenishes orders")
	var payroll: int = world.daily_payroll()
	expect(world.perform_action("recruit").ok and world.daily_payroll() == payroll + 140, "Recruitment increases daily payroll")
	var heat: int = world.organizations.player.heat
	expect(world.perform_action("lay_low").ok and world.organizations.player.heat == maxi(0, heat - 14), "Lay low reduces heat")
	var poor = World.new()
	poor.organizations.romano.cash = 0
	before = snapshot(poor)
	expect(not poor.perform_action("claim", "romano", 3).ok and snapshot(poor) == before, "AI uses the same affordability rules")
	var operation = World.new()
	expect(operation.perform_action("operation").ok, "Operation can run in an owned district")
	expect(operation.organizations.player.cash >= 51150 and operation.organizations.player.cash <= 53350 and operation.organizations.player.heat == 45, "Operation pays within Downtown's two-business range and adds heat")

func _operation_businesses() -> void:
	for org_id in World.ORG_IDS:
		var target := 7 if org_id == World.PLAYER else 0 if org_id == "romano" else 9
		var baseline = World.new(83)
		baseline.districts[target].businesses = 0
		var starting_cash: int = baseline.organizations[org_id].cash
		expect(baseline.operation_range(target) == Vector2i(1900, 4100), "%s zero-business payout uses the base range" % org_id)
		expect(baseline.perform_action("operation", org_id, target).ok, "%s can run the zero-business operation" % org_id)
		var base_profit: int = baseline.organizations[org_id].cash - starting_cash
		for count in range(1, 4):
			var developed = World.new(83)
			developed.districts[target].businesses = count
			expect(developed.operation_range(target) == Vector2i(1900 + count * 500, 4100 + count * 500), "%s previews %d local businesses" % [org_id, count])
			var result: Dictionary = developed.perform_action("operation", org_id, target)
			expect(result.ok and developed.organizations[org_id].cash - starting_cash == base_profit + count * 500, "%s gains exactly $500 per local business with the same random roll" % org_id)
			expect(developed.organizations[org_id].heat == baseline.organizations[org_id].heat and developed.rng.state == baseline.rng.state, "Business bonus preserves heat consequences and random draw count")
			expect(result.message.contains("%d businesses" % count) and result.message.contains("bonus"), "Operation result explains the source of the payout")
	var local_only = World.new(83)
	local_only.districts[7].businesses = 0
	local_only.districts[6].businesses = 3
	expect(local_only.operation_range(7) == Vector2i(1900, 4100), "Businesses elsewhere do not increase the selected district's payout")
	local_only.districts[7].owner = "romano"
	var before := snapshot(local_only)
	expect(not local_only.perform_action("operation", World.PLAYER, 7).ok and snapshot(local_only) == before, "The bonus never enables operations in rival territory")
	expect(local_only.operation_range(-1) == Vector2i.ZERO and local_only.operation_range(24) == Vector2i.ZERO, "Invalid operation targets have no quoted payout")

func _economy() -> void:
	var world = World.new()
	world.advance_day()
	var expected: int = 48250 + int(3080 * world.market / 100.0) - 1120
	expect(world.organizations.player.cash == expected, "Daily accounts use market-adjusted income and payroll")
	var bankrupt = World.new()
	bankrupt.organizations.player.cash = 0
	for district in bankrupt.districts:
		if district.owner == World.PLAYER:
			district.owner = "neutral"
	var members: int = bankrupt.organizations.player.members
	bankrupt.advance_day()
	expect(bankrupt.organizations.player.cash == 0 and bankrupt.organizations.player.members == members - 1, "Unpaid payroll triggers loss rather than negative cash")
	expect(bankrupt.organizations.player.loyalty < 74, "Unpaid payroll lowers loyalty")

func _member_requests() -> void:
	var world = World.new()
	expect(world.resolve_request(true).ok, "Pending member can be promoted")
	expect(world.organizations.player.cash == 47050 and world.find_member(World.PLAYER, 1).loyalty == 88 and world.organizations.player.loyalty == 75 and world.orders == 2, "Promotion changes the requesting person's loyalty and recalculates the crew average without consuming an order")
	var before := snapshot(world)
	expect(not world.resolve_request(true).ok and snapshot(world) == before, "A request cannot be resolved twice")
	for i in range(6):
		world.advance_day()
	expect(world.request_pending and world.day == 7, "New member decision arrives at weekly review")

func _ai_and_police() -> void:
	var world = World.new(47)
	var initial: String = JSON.stringify(world.organizations.romano)
	for i in range(60):
		world.advance_day()
		expect(World.new().restore_data(world.save_data()), "Autonomous day %d maintains world invariants" % world.day)
	expect(JSON.stringify(world.organizations.romano) != initial, "Rivals evolve while player does nothing")
	expect(world.events.size() == 80, "Event history remains bounded")
	var rival_events := 0
	for entry in world.events:
		if entry.kind == "rival":
			rival_events += 1
	expect(rival_events > 0, "Independent rival decisions produce events")
	var police = World.new(99)
	var investigation := false
	for i in range(10):
		police.organizations.player.heat = 100
		police.advance_day()
		for entry in police.events:
			if entry.text.begins_with("Police investigated Player"):
				investigation = true
	expect(investigation, "High player heat provokes police investigations")

func _save_and_replay() -> void:
	var original = World.new(83)
	original.perform_action("operation")
	original.resolve_request(false)
	for i in range(8):
		original.advance_day()
	var path := "user://underworld-automated-test-save.json"
	expect(original.save_game(path) == OK, "Save writes successfully")
	var restored = World.new()
	expect(restored.load_game(path), "Save can be loaded from disk")
	expect(snapshot(restored) == snapshot(original), "Loading restores every field, including RNG")
	for i in range(20):
		original.advance_day()
		restored.advance_day()
	expect(snapshot(restored) == snapshot(original), "Saved random state preserves exact future simulation")
	expect(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "Test save cleaned up")
	var first = World.new(17)
	var second = World.new(17)
	for i in range(10):
		first.advance_day()
		second.advance_day()
	expect(snapshot(first) == snapshot(second), "Identical seeds produce deterministic worlds")

func _bad_saves() -> void:
	var world = World.new()
	var before := snapshot(world)
	var invalid: Array = [null, {}, {"version": 999}]
	for field in ["organizations", "districts", "events", "rng_state", "request_pending"]:
		var broken: Dictionary = world.save_data()
		broken[field] = null
		invalid.append(broken)
	var bad_owner: Dictionary = world.save_data()
	bad_owner.districts[0].owner = "unknown"
	invalid.append(bad_owner)
	var bad_money: Dictionary = world.save_data()
	bad_money.organizations.player.cash = -5
	invalid.append(bad_money)
	var bad_time: Dictionary = world.save_data()
	bad_time.day = 1.25
	invalid.append(bad_time)
	var bad_event: Dictionary = world.save_data()
	bad_event.events[0].day = 999
	invalid.append(bad_event)
	for i in range(invalid.size()):
		expect(not world.restore_data(invalid[i]) and snapshot(world) == before, "Invalid save %d rejected without modifying the world" % i)

func _rival_staffing() -> void:
	var world = World.new()
	expect(world.recruitment_target("romano") == 14 and world.recruitment_target("moretti") == 12, "Rival crew targets grow with controlled districts")
	var changes := {"romano": {"recruitment": 0, "loss": 0}, "moretti": {"recruitment": 0, "loss": 0}}
	for i in range(90):
		world.advance_day()
		for entry in world.member_changes:
			if entry.day == world.day and entry.organization in changes:
				var category := "recruitment" if entry.after > entry.before else "loss"
				changes[entry.organization][category] += 1
	for org_id in ["romano", "moretti"]:
		expect(changes[org_id].recruitment > 0, "%s naturally recruits from its starting crew size" % org_id)
		expect(changes[org_id].loss > 0, "%s naturally loses members during autonomous play" % org_id)
	var shortage = World.new()
	shortage.debug_scenario("romano", "recruitment")
	shortage.advance_day()
	expect(shortage.organizations.romano.members == 4 and shortage.ai_decisions.romano.action == "recruit", "Understaffed rival prioritizes affordable recruitment")
	expect(shortage.ai_decisions.romano.reason.contains("payroll"), "AI records recruitment reasoning")
	var poor = World.new()
	poor.debug_set_organization("romano", {"members": 5, "cash": 0, "heat": 0})
	for district in poor.districts:
		if district.owner == "romano":
			district.businesses = 0
	poor.advance_day()
	expect(poor.organizations.romano.members == 5 and poor.ai_decisions.romano.action != "recruit", "Rival preserves payroll reserve instead of spending its last cash on recruitment")
	var unprofitable = World.new()
	unprofitable.debug_set_organization("romano", {"members": 10, "cash": 50000, "heat": 0})
	for district in unprofitable.districts:
		if district.owner == "romano":
			district.businesses = 0
	unprofitable.advance_day()
	expect(unprofitable.ai_decisions.romano.action != "recruit" and unprofitable.ai_decisions.romano.reason.contains("revenue"), "Nonurgent growth needs sustainable daily income")

func _debug_tools() -> void:
	var world = World.new()
	expect(world.debug_set_organization("moretti", {"cash": 100, "members": 12, "heat": 80, "loyalty": 20, "influence": 50}).ok, "Debug can edit every faction stat")
	expect(world.organizations.moretti.members == 12 and world.member_changes[0].reason == "debug override", "Debug membership changes are labeled")
	var before := snapshot(world)
	expect(not world.debug_set_organization("moretti", {"cash": 1000, "heat": 101}).ok and snapshot(world) == before, "Invalid debug stats are rejected atomically")
	expect(not world.debug_set_organization("unknown", {"cash": 1000}).ok, "Debug rejects unknown factions")
	expect(world.debug_set_district(23, "romano", 3, 100).ok and world.districts[23].owner == "romano", "Debug ownership overrides normal adjacency rules")
	before = snapshot(world)
	expect(not world.debug_set_district(23, "unknown", 3, 100).ok and snapshot(world) == before, "Invalid district override preserves world state")
	expect(world.debug_set_world(135, 0).ok and world.market == 135 and world.orders == 0, "Debug can edit demand and player orders")
	before = snapshot(world)
	expect(not world.debug_set_world(136, 0).ok and snapshot(world) == before, "Debug rejects out-of-range global values")
	var unpaid = World.new()
	for district in unpaid.districts:
		district.owner = "romano"
		district.businesses = 3
	unpaid.market = 135
	expect(unpaid.debug_scenario("romano", "unpaid_payroll").ok, "Missed-payroll scenario can be prepared")
	unpaid.advance_day()
	expect(unpaid.organizations.romano.members == 39 and unpaid.organizations.romano.cash < 6000, "Missed-payroll scenario loses a member even with maximum empty territory income")
	var recorded := false
	for entry in unpaid.member_changes:
		if entry.organization == "romano" and entry.reason == "unpaid payroll":
			recorded = true
	expect(recorded, "Membership ledger identifies the cause of departure")
	var detained = World.new(99)
	var arrests := 0
	for i in range(10):
		detained.debug_scenario("moretti", "police")
		detained.advance_day()
		for entry in detained.member_changes:
			if entry.day == detained.day and entry.organization == "moretti" and entry.reason == "police detention":
				arrests += 1
	expect(arrests > 0, "Police investigations can remove a rival member")
	var quick = World.new(55)
	var slow = World.new(55)
	expect(quick.debug_advance(30).ok, "Debug fast-forward runs normal simulation")
	for i in range(30):
		slow.advance_day()
	expect(quick.day == slow.day and quick.organizations == slow.organizations and quick.districts == slow.districts and quick.rng.state == slow.rng.state, "Fast-forward has identical world and RNG outcomes to ordinary daily turns")
	before = snapshot(quick)
	expect(not quick.debug_advance(0).ok and not quick.debug_advance(366).ok and snapshot(quick) == before, "Invalid fast-forward does not mutate state")
	var restored = World.new()
	expect(restored.restore_data(world.save_data()) and snapshot(restored) == snapshot(world), "Debug edits and labeled events remain compatible with save/load")
	expect(restored.ai_decisions.is_empty() and restored.member_changes.is_empty(), "Transient diagnostics restart cleanly after loading")
