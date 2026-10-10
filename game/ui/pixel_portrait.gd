extends Control
## Small authored sprite patterns; portraits never consume simulation RNG.

const Pixel = preload("res://game/ui/pixel_theme.gd")
var member_id: int = 1
const HAT := [
	"................", ".....kkkkkk.....", "....kkkkkkkk....",
	"...kkkkkkkkkk...", "...krrrrrrrrk...", ".kkkkkkkkkkkkkk.",
	"....hhsssshh....", "....hssssssh....", "....skssskss....",
	".....ssssss.....", ".....ssmsss.....", "......ssss......",
	".....wwssww.....", "...kkwwrrwwkk...", "..kkkwwrrwwkkk..",
	".kkkkkwrrwkkkkk.", "kkkkkkwrrwkkkkkk", "kkkkkkwkkwkkkkkk"
]
const HAIR := [
	"................", ".....hhhhhh.....", "....hhhhhhhh....",
	"...hhhhhhhhhh...", "...hhhhsshhhh...", "...hhsssssshh...",
	"...hssssssssh...", "...hskssskssh...", "...hssssssssh...",
	"...hhssmssshh...", "...hhhsssshhh...", "...hhhsssshhh...",
	"....hhwsswhh....", "...rrrwwwwrrr...", "..rrrrwsswrrrr..",
	".rrrrrrwwrrrrrr.", "rrrrrrrwwrrrrrrr", "rrrrrrrrrrrrrrrr"
]

func _ready() -> void:
	custom_minimum_size = Vector2(48, 54)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var pattern: Array = HAT if member_id % 2 == 1 else HAIR
	var skin: Color = [Color("#d09c76"), Color("#bd8965"), Color("#85563e"), Color("#dfb68a")][(member_id - 1) % 4]
	var palette := {"k": Color("#24292c"), "h": Color("#352820"), "s": skin, "w": Pixel.LIGHT, "r": Pixel.RED, "m": Color("#905747")}
	var unit := floorf(minf(size.x / 16.0, size.y / 18.0))
	var origin := ((size - Vector2(16, 18) * unit) * 0.5).floor()
	draw_rect(Rect2(origin, Vector2(16, 18) * unit), Color("#bfad92"))
	for y in range(pattern.size()):
		for x in range(pattern[y].length()):
			var color: String = pattern[y][x]
			if palette.has(color):
				draw_rect(Rect2(origin + Vector2(x, y) * unit, Vector2.ONE * unit), palette[color])
