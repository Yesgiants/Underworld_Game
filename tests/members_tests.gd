extends SceneTree

const World = preload("res://game/simulation/world_state.gd")
const Member = preload("res://game/simulation/member_data.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_rosters()
	_member_lifecycle()
	_individual_loyalty()
	_member_debug()
	_save_validation()
	_legacy_migration()
	print("MEMBER TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func snapshot(world: RefCounted) -> String:
	return JSON.stringify(world.save_data())

func _rosters() -> void:
	var world = World.new()
	var ids := {}
	for org_id in World.ORG_IDS:
		var org: Dictionary = world.organizations[org_id]
		expect(org.members == org.roster.size(), "%s count comes from roster" % org_id)
		var sum := 0
		for member in org.roster:
			expect(not ids.has(member.id) and member.age >= 18 and member.age <= 62 and not member.first_name.is_empty() and not member.last_name.is_empty(), "Starting person has unique identity, adult age, and full name")
			ids[member.id] = true
			sum += int(member.loyalty)
		expect(org.loyalty == roundi(float(sum) / org.members), "%s organization loyalty is the rounded member average" % org_id)
	expect(world.organizations.player.name == "Player" and World.PLAYER == "player", "Player renamed in display and ownership identity")
	expect(Member.full_name(world.find_member("player", 1)) == "Tony Vega", "Initial requester is an actual named member")
	expect(world.find_member("player", 1).age == 34, "Individual profile records age")

func _member_lifecycle() -> void:
	var world = World.new()
	var previous_ids: Array = world.organizations.player.roster.map(func(person: Dictionary) -> int: return person.id)
	var next_id: int = world.next_member_id
	var result: Dictionary = world.perform_action("recruit")
	expect(result.ok and world.organizations.player.roster.size() == 9, "Recruitment adds a real person")
	var recruit := world.find_member("player", next_id)
	expect(not recruit.is_empty() and world.next_member_id == next_id + 1 and recruit.joined_day == world.day, "New identity uses monotonic saved ID and joins today")
	expect(result.message.contains(Member.full_name(recruit)), "Recruitment names the person in its event")
	expect(world.organizations.player.roster.slice(0, 8).map(func(person: Dictionary) -> int: return person.id) == previous_ids, "Recruitment preserves existing identities")
	var target := world.find_member("player", 1)
	world.debug_set_member("player", 1, {"loyalty": 0})
	world._lose_member("player", "low loyalty", "member")
	expect(world.find_member("player", 1).is_empty() and world.organizations.player.members == 8, "Departure removes the least-loyal named person")
	expect(not world.request_pending, "A departed requester cannot retain a ghost promotion request")
	expect(world.events.any(func(entry: Dictionary) -> bool: return entry.text.contains("Tony Vega") and entry.text.contains("low loyalty")), "Departure event names the person and cause")
	world.debug_set_organization("romano", {"members": 3})
	var count: int = world.organizations.romano.roster.size()
	world._lose_member("romano", "police detention", "police")
	expect(world.organizations.romano.roster.size() == count, "Minimum crew survives automatic losses")
	# Keep a reference to prove removed people are not reused as fresh recruits.
	expect(target.id == 1 and recruit.id != target.id, "Departed IDs remain distinct from recruitment IDs")

func _individual_loyalty() -> void:
	var world = World.new()
	var peers: Array = world.organizations.player.roster.slice(1).map(func(person: Dictionary) -> int: return person.loyalty)
	var before: int = world.find_member("player", 1).loyalty
	world.resolve_request(true)
	expect(world.find_member("player", 1).loyalty == before + 6, "Promotion affects its requesting individual")
	expect(world.organizations.player.roster.slice(1).map(func(person: Dictionary) -> int: return person.loyalty) == peers, "Promotion leaves peers' loyalty unchanged")
	expect(world.organizations.player.loyalty == 75, "Promotion recalculates organizational average")
	var shared: Array = world.organizations.player.roster.map(func(person: Dictionary) -> int: return person.loyalty)
	world.perform_action("lay_low")
	for i in range(shared.size()):
		expect(world.organizations.player.roster[i].loyalty == mini(100, shared[i] + 2), "Low-profile conditions improve each member's loyalty")
	var at_risk = World.new()
	at_risk.debug_set_organization("player", {"loyalty": 80})
	at_risk.debug_set_member("player", 1, {"loyalty": 0})
	expect(at_risk.organizations.player.loyalty > 35, "A disloyal individual can exist in a loyal organization")
	for i in range(20):
		if at_risk.find_member("player", 1).is_empty():
			break
		at_risk.advance_day()
	expect(at_risk.find_member("player", 1).is_empty(), "Individual loyalty triggers departure even when the crew average is healthy")
	if at_risk.request_pending:
		expect(not at_risk.find_member("player", at_risk.request_member_id).is_empty(), "Weekly request belongs to a surviving roster member")

func _member_debug() -> void:
	var world = World.new()
	expect(world.debug_set_member("player", 1, {"first_name": "Alex", "last_name": "Mercer", "age": 45, "loyalty": 30}).ok, "Debug edits full individual profile")
	expect(world.find_member("player", 1).age == 45 and world.request_name == "Alex Mercer", "Renaming updates the linked promotion request")
	var before := snapshot(world)
	expect(not world.debug_set_member("player", 1, {"first_name": "Changed", "age": 17}).ok and snapshot(world) == before, "Invalid mixed profile edits are atomic")
	expect(not world.debug_set_member("player", 1, {"last_name": "   "}).ok and snapshot(world) == before, "Blank names rejected")
	expect(not world.debug_set_member("player", 9999, {"loyalty": 100}).ok and snapshot(world) == before, "Unknown member cannot be edited")
	var ids: Array = world.organizations.romano.roster.map(func(person: Dictionary) -> int: return person.id)
	world.debug_set_organization("romano", {"members": 12, "loyalty": 40})
	expect(world.organizations.romano.roster.size() == 12 and world.organizations.romano.roster.all(func(person: Dictionary) -> bool: return person.loyalty == 40), "Faction overrides resize people and apply shared loyalty consistently")
	expect(world.organizations.romano.roster.slice(0, 7).map(func(person: Dictionary) -> int: return person.id) == ids, "Faction resizing preserves current identities")
	world.debug_set_organization("romano", {"members": 5})
	expect(world.organizations.romano.roster.size() == 5 and world.organizations.romano.members == 5, "Debug downsizing removes people and updates derived count")

func _save_validation() -> void:
	var world = World.new(71)
	world.debug_set_member("player", 1, {"first_name": "Alex", "age": 45, "loyalty": 42})
	world.perform_action("recruit")
	var path := "user://underworld-member-test.json"
	expect(world.save_game(path) == OK, "Roster saves to disk")
	var loaded = World.new()
	expect(loaded.load_game(path) and snapshot(loaded) == snapshot(world), "Names, ages, loyalty, IDs, next ID, and linked requests survive JSON save/load")
	for i in range(15):
		world.advance_day()
		loaded.advance_day()
	expect(snapshot(world) == snapshot(loaded), "Future recruitment and departures replay exactly after loading")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var invalid: Array = []
	var duplicate: Dictionary = world.save_data()
	duplicate.organizations.romano.roster[0].id = duplicate.organizations.player.roster[0].id
	invalid.append(duplicate)
	var age: Dictionary = world.save_data()
	age.organizations.player.roster[0].age = 17
	invalid.append(age)
	var count: Dictionary = world.save_data()
	count.organizations.player.members += 1
	invalid.append(count)
	var loyalty: Dictionary = world.save_data()
	loyalty.organizations.player.loyalty = (loyalty.organizations.player.loyalty + 1) % 100
	invalid.append(loyalty)
	var requester: Dictionary = world.save_data()
	requester.request_pending = true
	requester.request_member_id = requester.next_member_id - 1
	requester.request_name = "Ghost Member"
	invalid.append(requester)
	var next_id: Dictionary = world.save_data()
	next_id.next_member_id = 1
	invalid.append(next_id)
	var before := snapshot(world)
	for i in range(invalid.size()):
		expect(not world.restore_data(invalid[i]) and snapshot(world) == before, "Malformed roster save %d rejected without modifying live world" % i)

func _legacy_migration() -> void:
	# Fixture produced using the implementation from annotated tag v0.1.0.
	var legacy: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v0.1.0_save.json"))
	if not legacy is Dictionary:
		expect(false, "Authentic v0.1.0 save fixture loads")
		return
	var before := JSON.stringify(legacy)
	var world = World.new()
	expect(world.restore_data(legacy), "Actual v0.1.0 save migrates")
	expect(world.organizations.player.name == "Player" and not world.organizations.has("navarro"), "Legacy player identity migrates")
	expect(world.organizations.player.cash == int(legacy.organizations.navarro.cash) and world.organizations.player.members == int(legacy.organizations.navarro.members) and world.organizations.player.loyalty == int(legacy.organizations.navarro.loyalty), "Legacy finances, crew count, and aggregate loyalty preserved")
	expect(world.districts.all(func(district: Dictionary) -> bool: return district.owner != "navarro"), "Legacy map ownership migrated")
	expect(not world.find_member("player", world.request_member_id).is_empty() and world.request_name == legacy.request_name, "Legacy request reconstructed as an actual person")
	expect(str(world.rng.state) == legacy.rng_state and world.day == legacy.day, "Migration preserves world time and simulation RNG state")
	expect(JSON.stringify(legacy) == before, "Migration does not mutate the input save")
	expect(World.new().restore_data(world.save_data()), "Migrated world can be saved and reloaded as v0.2")
