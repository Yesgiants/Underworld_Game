extends RefCounted
## Stable identities use their own generator so opening rosters never advances AI RNG.

const FIRST_NAMES := ["Adrian", "Bianca", "Caleb", "Daria", "Elias", "Farah", "Gabriel", "Hana", "Isaac", "Jade", "Kai", "Leila", "Mateo", "Nina", "Owen", "Priya", "Rafael", "Selena", "Theo", "Yasmin"]
const LAST_NAMES := ["Alvarez", "Brooks", "Chen", "Costa", "Cruz", "Ellis", "Foster", "Haddad", "Hayes", "Kim", "Laurent", "Mason", "Mendoza", "Morales", "Novak", "Park", "Patel", "Reed", "Santos", "Silva", "Vega", "Walsh"]
const STARTING_PLAYER := [
	["Tony", "Vega", 34], ["Elena", "Cruz", 29], ["Marcus", "Reed", 41],
	["Sofia", "Chen", 27], ["Luca", "Bennett", 38], ["Nadia", "Brooks", 32],
	["Victor", "Santos", 46], ["Maya", "Ellis", 25],
]

static func create(id: int, day: int, loyalty: int) -> Dictionary:
	var identity_rng := RandomNumberGenerator.new()
	identity_rng.seed = id * 7919
	return {"id": id, "first_name": FIRST_NAMES[(id - 1) % FIRST_NAMES.size()],
		"last_name": LAST_NAMES[((id - 1) / FIRST_NAMES.size()) % LAST_NAMES.size()],
		"age": identity_rng.randi_range(18, 62),
		"loyalty": clampi(loyalty + identity_rng.randi_range(-8, 8), 0, 100),
		"joined_day": day}

static func starting_roster(count: int, loyalty: int, first_id: int, is_player: bool) -> Array:
	var result: Array = []
	for i in range(count):
		var member := create(first_id + i, 1, loyalty)
		# Paired differences keep the original starting average unchanged.
		var offset := 0 if i == count - 1 and count % 2 == 1 else (8 - (i / 2) % 4 * 2) * (1 if i % 2 == 0 else -1)
		member.loyalty = clampi(loyalty + offset, 0, 100)
		if is_player and i < STARTING_PLAYER.size():
			member.first_name = STARTING_PLAYER[i][0]
			member.last_name = STARTING_PLAYER[i][1]
			member.age = STARTING_PLAYER[i][2]
		result.append(member)
	return result

static func full_name(member: Dictionary) -> String:
	return "%s %s" % [member.first_name, member.last_name]
