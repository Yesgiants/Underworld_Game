extends "res://game/ui/map_viewport.gd"

const PixelMap = preload("res://game/ui/pixel_city_map.gd")

func _init() -> void:
	map.free()
	map = PixelMap.new()
	zoom = 0.45

func _ready() -> void:
	super._ready()
	custom_minimum_size = Vector2(0, 140)
	horizontal.hide()
	vertical.hide()

func view_size() -> Vector2:
	return size.max(Vector2.ONE)

func set_zoom(value: float, anchor: Vector2 = Vector2(-1, -1)) -> void:
	if anchor.x < 0:
		anchor = view_size() * 0.5
	var map_point := view_to_map(anchor)
	zoom = clampf(value, 0.12, MAX_ZOOM)
	scroll = map_point * zoom - anchor
	_apply_view()

func fit_map() -> void:
	zoom = clampf(minf(view_size().x / MAP_SIZE.x, view_size().y / MAP_SIZE.y), 0.12, MAX_ZOOM)
	scroll = Vector2.ZERO
	_apply_view()
