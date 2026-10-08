extends SceneTree

const World = preload("res://game/simulation/world_state.gd")
const Layout = preload("res://game/simulation/city_layout.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_topology()
	_claims()
	_saves()
	print("CITY TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func _topology() -> void:
	var world = World.new()
	expect(world.city_layout == Layout.IRON_HAVEN and Layout.city_name(world.city_layout) == "Iron Haven", "New games use Iron Haven")
	expect(world.neighbors(-1).is_empty() and world.neighbors(24).is_empty(), "Invalid district IDs have no connections")
	expect(not 3 in world.neighbors(2) and not 15 in world.neighbors(14), "River separates northern and industrial waterfronts")
	var crossings: Array = []
	for district in range(24):
		expect(world.districts[district].name == Layout.NAMES[district] and not Layout.DESCRIPTIONS[district].is_empty(), "District %d has authored name and character" % district)
		for adjacent in world.neighbors(district):
			expect(district in world.neighbors(adjacent), "Connection %d–%d is reciprocal" % [district, adjacent])
			if district % 6 == 2 and adjacent == district + 1:
				crossings.append([district, adjacent])
	expect(crossings == [[8, 9], [20, 21]], "Only City Bridge and Foundry Bridge cross the river")
	var visited: Array = [0]
	var pending: Array = [0]
	while not pending.is_empty():
		var current: int = pending.pop_front()
		for adjacent in world.neighbors(current):
			if adjacent not in visited:
				visited.append(adjacent)
				pending.append(adjacent)
	expect(visited.size() == 24, "Every district is reachable through real connections")
	for faction in World.ORG_IDS:
		var owned: Array = []
		for i in range(24):
			if world.districts[i].owner == faction:
				owned.append(i)
		var reached: Array = [owned[0]]
		pending = [owned[0]]
		while not pending.is_empty():
			var current: int = pending.pop_front()
			for adjacent in world.neighbors(current):
				if adjacent in owned and adjacent not in reached:
					reached.append(adjacent)
					pending.append(adjacent)
		expect(reached.size() == owned.size(), "%s starts in connected territory" % faction)
	expect(Layout.district_detail(8, world.city_layout).contains("City Bridge") and Layout.district_detail(21, world.city_layout).contains("Foundry Bridge"), "Bridge approaches have useful district descriptions")

func _claims() -> void:
	for faction in World.ORG_IDS:
		var world = World.new()
		for district in world.districts:
			district.owner = "neutral"
		world.districts[2].owner = faction
		var before: Dictionary = world.save_data()
		expect(not world.perform_action("claim", faction, 3).ok and world.save_data() == before, "%s cannot cross unbridged water or spend resources on rejection" % faction)
		world.districts[2].owner = "neutral"
		world.districts[8].owner = faction
		expect(world.perform_action("claim", faction, 9).ok and world.districts[9].owner == faction, "%s can expand across City Bridge" % faction)
		world.districts[20].owner = faction
		expect(world.perform_action("claim", faction, 21).ok, "%s can expand across Foundry Bridge" % faction)
		# Check the same crossing in reverse without another owned east-bank edge.
		var reverse = World.new()
		for district in reverse.districts:
			district.owner = "neutral"
		reverse.districts[9].owner = faction
		expect(reverse.perform_action("claim", faction, 8).ok, "%s can cross from east to west" % faction)
	var rival = World.new(17)
	for district in rival.districts:
		district.owner = "neutral"
	rival.districts[2].owner = "romano"
	# Repeatedly reset ownership while allowing real AI turns to choose orders.
	for i in range(30):
		rival.debug_set_organization("romano", {"cash": 50000, "heat": 0, "members": 14})
		rival.advance_day()
		expect(rival.districts[3].owner == "neutral", "Rival AI respects the river on turn %d" % i)
		for district in rival.districts:
			district.owner = "neutral"
		rival.districts[2].owner = "romano"

func _saves() -> void:
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v0.2.0_grid_save.json"))
	var before := JSON.stringify(legacy)
	var world = World.new()
	expect(world.restore_data(legacy) and world.city_layout == Layout.LEGACY, "Authentic earlier v0.2 save retains the original map")
	# JSON numbers are floats; the loader intentionally normalizes them to ints.
	expect(JSON.parse_string(JSON.stringify(world.districts)) == legacy.districts and JSON.parse_string(JSON.stringify(world.organizations)) == legacy.organizations, "Loading older saves preserves all districts and member profiles")
	expect(3 in world.neighbors(2) and 15 in world.neighbors(14), "Legacy grid keeps original cross-column adjacency")
	expect(JSON.stringify(legacy) == before, "Migration leaves input untouched")
	var restored = World.new()
	expect(restored.restore_data(world.save_data()) and restored.city_layout == Layout.LEGACY, "Resaving preserves the legacy layout")
	for i in range(15):
		world.advance_day()
		restored.advance_day()
	expect(world.save_data() == restored.save_data(), "Legacy layout replay stays deterministic")
	world = World.new(83)
	world.perform_action("claim", World.PLAYER, 13)
	expect(restored.restore_data(world.save_data()) and restored.city_layout == Layout.IRON_HAVEN, "Iron Haven save restores its geography")
	for i in range(15):
		world.advance_day()
		restored.advance_day()
	expect(world.save_data() == restored.save_data(), "Iron Haven geography and RNG round trip exactly")
	var bad: Dictionary = world.save_data()
	before = JSON.stringify(world.save_data())
	bad.city_layout = "unknown"
	expect(not world.restore_data(bad) and JSON.stringify(world.save_data()) == before, "Unknown map IDs rejected atomically")
	bad = world.save_data()
	bad.erase("city_layout")
	expect(not world.restore_data(bad) and JSON.stringify(world.save_data()) == before, "Current saves require a map identity")
	bad = world.save_data()
	bad.city_layout = Layout.LEGACY
	expect(not world.restore_data(bad) and JSON.stringify(world.save_data()) == before, "District names must match their declared map")
