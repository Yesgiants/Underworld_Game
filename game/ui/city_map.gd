extends Control
## A clickable schematic city, deliberately independent of art assets.

signal district_selected(index: int)

const World = preload("res://game/simulation/world_state.gd")
const COLORS := {
	"player": Color("#dfa65b"), "romano": Color("#aa8ccb"),
	"moretti": Color("#69b4b0"), "neutral": Color("#526071"),
}
var world: RefCounted
var selected: int = 7
var hovered: int = -1
var map_font: Font = ThemeDB.fallback_font

func _ready() -> void:
	custom_minimum_size = Vector2(620, 258)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_exited.connect(func() -> void:
		hovered = -1
		queue_redraw()
	)

func cell_rect(index: int) -> Rect2:
	var cell := Vector2(size.x / World.WIDTH, size.y / World.HEIGHT)
	return Rect2(Vector2(index % World.WIDTH, index / World.WIDTH) * cell + Vector2(4, 4), cell - Vector2(8, 8))

func district_at(point: Vector2) -> int:
	if point.x < 0 or point.y < 0 or point.x >= size.x or point.y >= size.y:
		return -1
	for i in range(World.WIDTH * World.HEIGHT):
		if cell_rect(i).has_point(point):
			return i
	return -1

func _gui_input(event: InputEvent) -> void:
	if world == null:
		return
	if event is InputEventMouseMotion:
		var index := district_at(event.position)
		if index != hovered:
			hovered = index
			if index >= 0:
				var district: Dictionary = world.districts[index]
				var owner: String = "Independent" if district.owner == "neutral" else world.organizations[district.owner].name
				tooltip_text = "%s · %s\n%d businesses · Police attention %d/100" % [district.name, owner, district.businesses, district.attention]
			else:
				tooltip_text = ""
			queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var index := district_at(event.position)
		if index >= 0:
			selected = index
			district_selected.emit(index)
			queue_redraw()
			accept_event()

func _draw() -> void:
	if world == null:
		return
	for i in range(world.districts.size()):
		var district: Dictionary = world.districts[i]
		var rect := cell_rect(i)
		var color: Color = COLORS[district.owner]
		var fill := Color("#141c25").lerp(color, 0.13 if district.owner != "neutral" else 0.03)
		if i == hovered:
			fill = fill.lightened(0.09)
		draw_rect(rect, fill)
		draw_rect(rect, color.darkened(0.56), false, 1.0)
		# Tiny blocks suggest streets and buildings without implying a detailed map.
		for block in range(4):
			var block_size := Vector2(10 + (i + block) % 3 * 4, 10 + (i * 2 + block) % 3 * 3)
			var position := rect.position + Vector2(12 + block * 20, 10)
			draw_rect(Rect2(position, block_size), color.darkened(0.63))
		draw_line(rect.position + Vector2(10, 34), rect.position + Vector2(rect.size.x - 10, 34), Color("#29313c"), 1)
		var marker := rect.position + Vector2(rect.size.x - 15, 15)
		if district.owner == "neutral":
			draw_rect(Rect2(marker - Vector2(4, 4), Vector2(8, 8)), color, false, 1.0)
		else:
			draw_circle(marker, 4, color)
		if int(district.attention) >= 60:
			draw_circle(rect.position + Vector2(rect.size.x - 15, 31), 3, Color("#e07973"))
		var label_size := 12
		var label_width := map_font.get_string_size(district.name, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
		draw_string(map_font, rect.position + Vector2((rect.size.x - label_width) / 2.0, rect.size.y - 10), district.name, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, Color("#c3cbd6"))
		if i == selected:
			draw_rect(rect.grow(1), Color("#eed2a4"), false, 2.0)
