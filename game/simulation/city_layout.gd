extends RefCounted
## Fixed geography shared by rendering, player claims, and rival expansion.

const IRON_HAVEN := "iron_haven"
const LEGACY := "legacy_grid"
const WIDTH := 6
const HEIGHT := 4
const LEGACY_NAMES := [
	"North End", "Little Italy", "Old Quarter", "Uptown", "East Village", "The Heights",
	"West Market", "Downtown", "Civic Center", "Midtown", "East Market", "Parkside",
	"West Docks", "Warehouse Row", "Rail Yards", "Southbank", "Foundry", "Riverside",
	"Harbor Point", "Fish Market", "Shipyards", "The Narrows", "South End", "Bayview",
]
const NAMES := [
	"North End", "Little Italy", "Old Quarter", "East Heights", "Oak Hill", "Parkside",
	"West Market", "Downtown", "City Hall", "East Market", "Bricktown", "Mill End",
	"West Docks", "Depot Row", "Rail Yards", "Foundry", "Steelworks", "East Docks",
	"South End", "Old Freight", "Southbank", "Iron Gate", "Coal Yard", "Workers Row",
]
const DESCRIPTIONS := [
	"Steep streets and aging row houses above the old city.",
	"Family restaurants, social clubs, and close-knit blocks.",
	"Old brick apartments and corner shops along the west bank.",
	"Hillside homes overlooking the industrial river valley.",
	"Quiet residential streets and established local businesses.",
	"A park neighborhood on the eastern edge of town.",
	"Wholesale stalls, small shops, and busy market streets.",
	"The commercial center: offices, bars, and late-night diners.",
	"Municipal offices at the western approach to City Bridge.",
	"Shops and warehouses at the eastern approach to City Bridge.",
	"Brick tenements and workshops near the mills.",
	"An old mill neighborhood with a fading main street.",
	"Working river docks and warehouses on the western shore.",
	"Freight depots and loading bays south of downtown.",
	"Rail sidings serving the west-bank warehouses.",
	"Metalworking sheds and foundries along the east bank.",
	"Steel mills, service roads, and shift-worker bars.",
	"Industrial wharves serving the eastern factories.",
	"Modest homes at the southern edge of the old city.",
	"Disused freight buildings and small repair businesses.",
	"A warehouse neighborhood at Foundry Bridge's west end.",
	"Factory gates at Foundry Bridge's eastern approach.",
	"Coal storage yards and heavy freight infrastructure.",
	"Workers' housing beyond the industrial belt.",
]
const BRIDGES := [
	{"name": "City Bridge", "west": 8, "east": 9},
	{"name": "Foundry Bridge", "west": 20, "east": 21},
]

static func names(layout: String) -> Array:
	return LEGACY_NAMES if layout == LEGACY else NAMES

static func city_name(layout: String) -> String:
	return "Prototype City" if layout == LEGACY else "Iron Haven"

static func neighbors(index: int, layout: String) -> Array:
	if index < 0 or index >= WIDTH * HEIGHT:
		return []
	var result: Array = []
	var x := index % WIDTH
	var y := index / WIDTH
	var crossing := layout == LEGACY
	for bridge in BRIDGES:
		if index in [bridge.west, bridge.east]:
			crossing = true
	if x > 0 and (x != 3 or crossing):
		result.append(index - 1)
	if x < WIDTH - 1 and (x != 2 or crossing):
		result.append(index + 1)
	if y > 0:
		result.append(index - WIDTH)
	if y < HEIGHT - 1:
		result.append(index + WIDTH)
	return result

static func district_detail(index: int, layout: String) -> String:
	if layout == LEGACY:
		return "Original prototype district."
	var bank := "West bank" if index % WIDTH < 3 else "East bank"
	for bridge in BRIDGES:
		if index in [bridge.west, bridge.east]:
			bank += " · " + bridge.name + " approach"
	return bank + " · " + DESCRIPTIONS[index]
