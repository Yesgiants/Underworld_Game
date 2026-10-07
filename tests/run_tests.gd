extends SceneTree

const World = preload("res://game/simulation/world_state.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_initial_state()
	_actions_and_orders()
	_economy()
	_member_requests()
	_ai_and_police()
	_save_and_replay()
	_bad_saves()
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
	expect(world.organizations.navarro.cash == 48250 and world.organizations.navarro.members == 8, "Starting organization stats")
	expect(world.daily_income() == 3080 and world.daily_payroll() == 1120, "Income and payroll derive from the world")
	expect(world.neighbors(0) == [1, 6] and world.neighbors(5) == [4, 11], "Map edges do not wrap")

func _actions_and_orders() -> void:
	var world = World.new()
	var before := snapshot(world)
	expect(not world.perform_action("claim", World.PLAYER, 23).ok, "Cannot claim a remote district")
	expect(snapshot(world) == before, "Rejected actions do not change cash, orders, events, or RNG")
	expect(world.perform_action("business", World.PLAYER, 7).ok, "Business order succeeds on owned district")
	expect(world.organizations.navarro.cash == 41750 and world.businesses() == 5 and world.daily_income() == 3730, "Business costs cash and increases income")
	expect(world.perform_action("claim", World.PLAYER, 13).ok, "Adjacent independent district can be claimed")
	expect(world.districts[13].owner == World.PLAYER and world.territory() == 4, "Claim changes map ownership")
	before = snapshot(world)
	expect(not world.perform_action("operation", World.PLAYER, 7).ok and snapshot(world) == before, "Two orders per day; third order rejected atomically")
	world.advance_day()
	expect(world.orders == 2, "New day replenishes orders")
	var payroll: int = world.daily_payroll()
	expect(world.perform_action("recruit").ok and world.daily_payroll() == payroll + 140, "Recruitment increases daily payroll")
	var heat: int = world.organizations.navarro.heat
	expect(world.perform_action("lay_low").ok and world.organizations.navarro.heat == maxi(0, heat - 14), "Lay low reduces heat")
	var poor = World.new()
	poor.organizations.romano.cash = 0
	before = snapshot(poor)
	expect(not poor.perform_action("claim", "romano", 3).ok and snapshot(poor) == before, "AI uses the same affordability rules")
	var operation = World.new()
	expect(operation.perform_action("operation").ok, "Operation can run in an owned district")
	expect(operation.organizations.navarro.cash >= 50150 and operation.organizations.navarro.cash <= 52350 and operation.organizations.navarro.heat == 45, "Operation pays within its documented range and adds heat")

func _economy() -> void:
	var world = World.new()
	world.advance_day()
	var expected: int = 48250 + int(3080 * world.market / 100.0) - 1120
	expect(world.organizations.navarro.cash == expected, "Daily accounts use market-adjusted income and payroll")
	var bankrupt = World.new()
	bankrupt.organizations.navarro.cash = 0
	for district in bankrupt.districts:
		if district.owner == World.PLAYER:
			district.owner = "neutral"
	var members: int = bankrupt.organizations.navarro.members
	bankrupt.advance_day()
	expect(bankrupt.organizations.navarro.cash == 0 and bankrupt.organizations.navarro.members == members - 1, "Unpaid payroll triggers loss rather than negative cash")
	expect(bankrupt.organizations.navarro.loyalty < 74, "Unpaid payroll lowers loyalty")

func _member_requests() -> void:
	var world = World.new()
	expect(world.resolve_request(true).ok, "Pending member can be promoted")
	expect(world.organizations.navarro.cash == 47050 and world.organizations.navarro.loyalty == 80 and world.orders == 2, "Promotion applies cost and loyalty without consuming an order")
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
		police.organizations.navarro.heat = 100
		police.advance_day()
		for entry in police.events:
			if entry.text.begins_with("Police investigated Navarro"):
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
	bad_money.organizations.navarro.cash = -5
	invalid.append(bad_money)
	var bad_time: Dictionary = world.save_data()
	bad_time.day = 1.25
	invalid.append(bad_time)
	var bad_event: Dictionary = world.save_data()
	bad_event.events[0].day = 999
	invalid.append(bad_event)
	for i in range(invalid.size()):
		expect(not world.restore_data(invalid[i]) and snapshot(world) == before, "Invalid save %d rejected without modifying the world" % i)
