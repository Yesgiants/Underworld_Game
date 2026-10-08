extends Control
## A clickable schematic city, deliberately independent of art assets.

signal district_selected(index: int)

const World = preload("res://game/simulation/world_state.gd")
const Layout = preload("res://game/simulation/city_layout.gd")
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
	if world != null and world.city_layout == Layout.IRON_HAVEN:
		var row_height := (size.y - 44.0) / World.HEIGHT
		var y := 28.0 + (index / World.WIDTH) * row_height
		var river_x := _river_center(y + row_height / 2.0)
		var east := index % World.WIDTH >= 3
		var bank_start := river_x + 42.0 if east else 0.0
		var bank_width := size.x - bank_start if east else river_x - 42.0
		var cell_width := bank_width / 3.0
		return Rect2(Vector2(bank_start + (index % 3) * cell_width + 4, y + 4), Vector2(cell_width - 8, row_height - 8))
	var cell := Vector2(size.x / World.WIDTH, size.y / World.HEIGHT)
	return Rect2(Vector2(index % World.WIDTH, index / World.WIDTH) * cell + Vector2(4, 4), cell - Vector2(8, 8))

func _river_center(y: float) -> float:
	return size.x * 0.5 + sin(y / maxf(size.y, 1.0) * TAU - 0.8) * 12.0

func _draw_river() -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for step in range(25):
		var y := size.y * step / 24.0
		left.append(Vector2(_river_center(y) - 35.0, y))
		right.append(Vector2(_river_center(y) + 35.0, y))
	var water := left.duplicate()
	for step in range(right.size() - 1, -1, -1):
		water.append(right[step])
	draw_colored_polygon(water, Color("#193241"))
	draw_polyline(left, Color("#365262"), 2.0, true)
	draw_polyline(right, Color("#365262"), 2.0, true)
	for step in range(12):
		var y := 34.0 + step * (size.y - 44.0) / 12.0
		var x := _river_center(y)
		draw_line(Vector2(x - 12, y), Vector2(x + 9, y), Color("#244554"), 1.0)
	draw_string(map_font, Vector2(6, 17), "WEST BANK / OLD CITY", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#8996a7"))
	draw_string(map_font, Vector2(size.x - 145, 17), "EAST BANK / MILL BELT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#8996a7"))
	var river_text := "CALDER"
	var width := map_font.get_string_size(river_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(map_font, Vector2(_river_center(17) - width / 2, 17), river_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#90b1c0"))
	for bridge in Layout.BRIDGES:
		var west := cell_rect(bridge.west)
		var east := cell_rect(bridge.east)
		var y := west.get_center().y
		var start := Vector2(west.end.x, y)
		var finish := Vector2(east.position.x, y)
		var color := Color("#eed2a4") if selected in [bridge.west, bridge.east] else Color("#81949e")
		draw_line(start, finish, Color("#0c1720"), 13.0)
		draw_line(start + Vector2(0, -5), finish + Vector2(0, -5), color, 1.5)
		draw_line(start + Vector2(0, 5), finish + Vector2(0, 5), color, 1.5)
		draw_line(start, finish, color.darkened(0.45), 4.0)
		var label_width := map_font.get_string_size(bridge.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(map_font, Vector2((start.x + finish.x - label_width) / 2.0, y - 12), bridge.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#c3cbd6"))

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
				tooltip_text += "\n" + Layout.district_detail(index, world.city_layout)
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
	if world.city_layout == Layout.IRON_HAVEN:
		_draw_river()
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
			var position := rect.position + Vector2(8 + block * (rect.size.x - 26) / 4.0, 10)
			draw_rect(Rect2(position, block_size), color.darkened(0.63))
		draw_line(rect.position + Vector2(10, 34), rect.position + Vector2(rect.size.x - 10, 34), Color("#29313c"), 1)
		var marker := rect.position + Vector2(rect.size.x - 15, 15)
		if district.owner == "neutral":
			draw_rect(Rect2(marker - Vector2(4, 4), Vector2(8, 8)), color, false, 1.0)
		else:
			draw_circle(marker, 4, color)
		if int(district.attention) >= 60:
			draw_circle(rect.position + Vector2(rect.size.x - 15, 31), 3, Color("#e07973"))
		var label_size := 11 if world.city_layout == Layout.IRON_HAVEN else 12
		var label_width := map_font.get_string_size(district.name, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
		draw_string(map_font, rect.position + Vector2((rect.size.x - label_width) / 2.0, rect.size.y - 10), district.name, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, Color("#c3cbd6"))
		if i == selected:
			draw_rect(rect.grow(1), Color("#eed2a4"), false, 2.0)
