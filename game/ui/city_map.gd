extends Control
## A clickable schematic city, deliberately independent of art assets.

signal district_selected(index: int)

const World = preload("res://game/simulation/world_state.gd")
const Layout = preload("res://game/simulation/city_layout.gd")
const Ledger = preload("res://game/ui/ledger_theme.gd")
const COLORS := {
	"player": Color("#aa7b32"), "romano": Color("#805a87"),
	"moretti": Color("#3f7562"), "neutral": Color("#8d8777"),
}
var world: RefCounted
var selected: int = 7
var hovered: int = -1
var map_font: Font = Ledger.SERIF

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
	draw_colored_polygon(water, Color("#9bb0ae"))
	draw_polyline(left, Color("#627d7a"), 2.0, true)
	draw_polyline(right, Color("#627d7a"), 2.0, true)
	for step in range(12):
		var y := 34.0 + step * (size.y - 44.0) / 12.0
		var x := _river_center(y)
		draw_line(Vector2(x - 12, y), Vector2(x + 9, y), Color("#769694"), 1.0)
	draw_string(map_font, Vector2(8, 20), "WEST BANK / OLD CITY", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Ledger.MUTED)
	draw_string(map_font, Vector2(size.x - 194, 20), "EAST BANK / MILL BELT", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Ledger.MUTED)
	var river_text := "CALDER"
	var width := map_font.get_string_size(river_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(map_font, Vector2(_river_center(20) - width / 2, 20), river_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Ledger.GREEN)
	for bridge in Layout.BRIDGES:
		var west := cell_rect(bridge.west)
		var east := cell_rect(bridge.east)
		var y := west.get_center().y
		var start := Vector2(west.end.x, y)
		var finish := Vector2(east.position.x, y)
		var color := Ledger.RED if selected in [bridge.west, bridge.east] else Color("#786b56")
		draw_line(start, finish, Color("#dfceb0"), 18.0)
		draw_line(start + Vector2(0, -5), finish + Vector2(0, -5), color, 1.5)
		draw_line(start + Vector2(0, 5), finish + Vector2(0, 5), color, 1.5)
		draw_line(start, finish, color.darkened(0.45), 4.0)
		var label_width := map_font.get_string_size(bridge.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(map_font, Vector2((start.x + finish.x - label_width) / 2.0, y - 14), bridge.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Ledger.INK)

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
	draw_rect(Rect2(Vector2.ZERO, size), Color("#ebddc1"))
	# Faint survey rules belong to the map canvas and move with it.
	for x in range(0, int(size.x), 32):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color("#dbccb04a"), 1)
	for y in range(0, int(size.y), 32):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color("#dbccb04a"), 1)
	if world.city_layout == Layout.IRON_HAVEN:
		_draw_river()
	for i in range(world.districts.size()):
		var district: Dictionary = world.districts[i]
		var rect := cell_rect(i)
		var color: Color = COLORS[district.owner]
		var fill := Color("#f3e7cf").lerp(color, 0.28 if district.owner != "neutral" else 0.1)
		if i == hovered:
			fill = fill.lightened(0.06)
		draw_style_box(Ledger.box(fill, color.darkened(0.1), 12, 0, 0), rect)
		# Blocks, side streets, and mill chimneys make the enlarged city readable.
		var street_area := rect.size - Vector2(34, 95)
		for row in range(3):
			for block in range(5):
				var block_size := Vector2(street_area.x / 5.0 - 9, street_area.y / 3.0 - 10)
				var position := rect.position + Vector2(15, 18) + Vector2(block * street_area.x / 5.0, row * street_area.y / 3.0)
				draw_rect(Rect2(position, block_size), color.lightened(0.45))
				draw_rect(Rect2(position, block_size), color.darkened(0.05), false, 1)
				if i in [14, 15, 16, 17, 19, 22] and row == 0:
					draw_line(position + Vector2(4, 0), position + Vector2(4, -6), color, 3)
		var marker := rect.position + Vector2(rect.size.x - 18, 18)
		if district.owner == "neutral":
			draw_rect(Rect2(marker - Vector2(5, 5), Vector2(10, 10)), color, false, 1.5)
		else:
			draw_circle(marker, 6, color)
		if int(district.attention) >= 60:
			draw_circle(rect.position + Vector2(rect.size.x - 18, 38), 5, Ledger.RED)
		var label_size := 22
		var label_width := map_font.get_string_size(district.name, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
		draw_string(map_font, rect.position + Vector2((rect.size.x - label_width) / 2.0, rect.size.y - 36), district.name, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, Ledger.INK)
		var businesses_text := "%d %s" % [district.businesses, "business" if int(district.businesses) == 1 else "businesses"]
		var detail_width := map_font.get_string_size(businesses_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(map_font, rect.position + Vector2((rect.size.x - detail_width) / 2.0, rect.size.y - 14), businesses_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Ledger.MUTED)
		if i == selected:
			var selection := Ledger.box(Color(0, 0, 0, 0), Ledger.RED, 18, 0, 0)
			selection.set_border_width_all(4)
			draw_style_box(selection, rect.grow(2))
