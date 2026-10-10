extends "res://game/ui/city_map.gd"

const Pixel = preload("res://game/ui/pixel_theme.gd")

func _draw() -> void:
	if world == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Pixel.PAPER)
	if world.city_layout == Layout.IRON_HAVEN:
		for step in range(32):
			var y := float(step) * size.y / 32
			var river_x := snappedf(_river_center(y), 8)
			draw_rect(Rect2(river_x - 36, y, 72, size.y / 32 + 1), Color("#7c9f9b"))
			draw_rect(Rect2(river_x - 36, y, 6, size.y / 32 + 1), Pixel.TEAL)
			draw_rect(Rect2(river_x + 30, y, 6, size.y / 32 + 1), Pixel.TEAL)
			if step % 3 == 0:
				draw_rect(Rect2(river_x - 12, y + 8, 24, 3), Color("#b3c6b1"))
	for i in range(world.districts.size()):
		var rect := cell_rect(i)
		var district: Dictionary = world.districts[i]
		var owner_color: Color = COLORS[district.owner]
		draw_rect(rect, Pixel.LIGHT if i % 2 == 0 else Pixel.PAPER)
		draw_rect(rect, Pixel.COPPER, false, 3)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 14)), owner_color)
		for building in range(6):
			var origin := rect.position + Vector2(24 + building % 3 * 58, 76 + building / 3 * 56)
			var height := 28 + (i + building * 3) % 4 * 6
			draw_rect(Rect2(origin, Vector2(38, height)), Pixel.MUTED.darkened(0.1 * (building % 2)))
			draw_rect(Rect2(origin + Vector2(-3, -5), Vector2(44, 5)), Pixel.COVER)
			for window_x in [7, 23]:
				draw_rect(Rect2(origin + Vector2(window_x, 8), Vector2(8, 10)), Pixel.PAPER)
		var label: String = district.name.to_upper()
		draw_string(Pixel.FONT, rect.position + Vector2(12, 46), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, 18, Pixel.INK)
		var detail := "%d BIZ / %d HEAT" % [district.businesses, district.attention]
		draw_string(Pixel.BODY, rect.position + Vector2(12, rect.size.y - 14), detail, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, 20, Pixel.INK)
		if i == selected:
			draw_rect(rect.grow(-3), Pixel.TEAL, false, 8)
		if int(district.attention) >= 60:
			draw_rect(Rect2(rect.end - Vector2(22, 22), Vector2(12, 12)), Pixel.RED)
	if world.city_layout == Layout.IRON_HAVEN:
		for bridge in Layout.BRIDGES:
			var west := cell_rect(bridge.west)
			var east := cell_rect(bridge.east)
			var y := west.get_center().y
			draw_rect(Rect2(west.end.x, y - 12, east.position.x - west.end.x, 24), Pixel.COPPER)
			draw_rect(Rect2(west.end.x, y - 3, east.position.x - west.end.x, 6), Pixel.COVER)
			draw_string(Pixel.BODY, Vector2(west.end.x - 30, y - 24), bridge.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pixel.INK)
