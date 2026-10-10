extends Control
## Only this clipped workspace moves. Ledger controls stay outside its canvas.

signal district_selected(index: int)
signal view_changed

const CityMap = preload("res://game/ui/city_map.gd")
const MAP_SIZE := Vector2(1600, 1000)
const MIN_ZOOM := 0.25
const MAX_ZOOM := 1.6
const BAR_SIZE := 14.0
var map = CityMap.new()
var zoom: float = 0.7
var scroll := Vector2.ZERO
var horizontal: HScrollBar
var vertical: VScrollBar
var updating: bool = false
var dragging: bool = false
var drag_button: int = 0
var drag_distance: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(560, 220)
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.size = MAP_SIZE
	add_child(map)
	map.district_selected.connect(func(index: int) -> void: district_selected.emit(index))
	horizontal = HScrollBar.new()
	horizontal.anchor_top = 1
	horizontal.anchor_bottom = 1
	horizontal.anchor_right = 1
	horizontal.offset_top = -BAR_SIZE
	horizontal.offset_right = -BAR_SIZE
	add_child(horizontal)
	vertical = VScrollBar.new()
	vertical.anchor_left = 1
	vertical.anchor_right = 1
	vertical.anchor_bottom = 1
	vertical.offset_left = -BAR_SIZE
	vertical.offset_bottom = -BAR_SIZE
	add_child(vertical)
	horizontal.value_changed.connect(func(value: float) -> void:
		if not updating:
			scroll.x = value
			_apply_view()
	)
	vertical.value_changed.connect(func(value: float) -> void:
		if not updating:
			scroll.y = value
			_apply_view()
	)
	resized.connect(_apply_view)
	mouse_exited.connect(func() -> void:
		map.hovered = -1
		map.queue_redraw()
		tooltip_text = ""
	)
	call_deferred("focus_selected")

func view_size() -> Vector2:
	return (size - Vector2(BAR_SIZE, BAR_SIZE)).max(Vector2.ONE)

func view_to_map(point: Vector2) -> Vector2:
	return (point - map.position) / zoom

func map_to_view(point: Vector2) -> Vector2:
	return map.position + point * zoom

func _apply_view() -> void:
	if horizontal == null:
		return
	var extent := MAP_SIZE * zoom
	var available := view_size()
	scroll = scroll.clamp(Vector2.ZERO, (extent - available).max(Vector2.ZERO))
	map.scale = Vector2(zoom, zoom)
	map.position = -scroll + ((available - extent) * 0.5).max(Vector2.ZERO)
	updating = true
	horizontal.max_value = extent.x
	horizontal.page = minf(available.x, extent.x)
	horizontal.value = scroll.x
	vertical.max_value = extent.y
	vertical.page = minf(available.y, extent.y)
	vertical.value = scroll.y
	updating = false
	map.queue_redraw()
	view_changed.emit()

func pan(delta: Vector2) -> void:
	scroll += delta
	_apply_view()

func set_zoom(value: float, anchor: Vector2 = Vector2(-1, -1)) -> void:
	if anchor.x < 0:
		anchor = view_size() * 0.5
	var map_point := view_to_map(anchor)
	zoom = clampf(value, MIN_ZOOM, MAX_ZOOM)
	scroll = map_point * zoom - anchor
	_apply_view()

func fit_map() -> void:
	zoom = clampf(minf(view_size().x / MAP_SIZE.x, view_size().y / MAP_SIZE.y), MIN_ZOOM, MAX_ZOOM)
	scroll = Vector2.ZERO
	_apply_view()

func focus_selected() -> void:
	scroll = map.cell_rect(map.selected).get_center() * zoom - view_size() * 0.5
	_apply_view()

func _gui_input(event: InputEvent) -> void:
	if map.world == null:
		return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT] and event.pressed:
			var direction := -1.0 if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT] else 1.0
			if event.ctrl_pressed:
				set_zoom(zoom * (1.12 if direction < 0 else 1.0 / 1.12), event.position)
			elif event.shift_pressed or event.button_index in [MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
				pan(Vector2(direction * 70.0, 0))
			else:
				pan(Vector2(0, direction * 70.0))
			accept_event()
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			if event.pressed:
				grab_focus()
				dragging = true
				drag_button = event.button_index
				drag_distance = 0
			elif dragging and event.button_index == drag_button:
				dragging = false
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				if drag_button == MOUSE_BUTTON_LEFT and drag_distance < 6.0:
					var index: int = map.district_at(view_to_map(event.position))
					if index >= 0:
						map.selected = index
						district_selected.emit(index)
						map.queue_redraw()
			accept_event()
	if event is InputEventMouseMotion:
		if dragging:
			drag_distance += event.relative.length()
			if drag_button != MOUSE_BUTTON_LEFT or drag_distance >= 6:
				mouse_default_cursor_shape = Control.CURSOR_DRAG
				pan(-event.relative)
		else:
			var local := InputEventMouseMotion.new()
			local.position = view_to_map(event.position)
			map._gui_input(local)
			tooltip_text = map.tooltip_text
		accept_event()
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT: pan(Vector2(-70, 0))
			KEY_RIGHT: pan(Vector2(70, 0))
			KEY_UP: pan(Vector2(0, -70))
			KEY_DOWN: pan(Vector2(0, 70))
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: set_zoom(zoom * 1.12)
			KEY_MINUS, KEY_KP_SUBTRACT: set_zoom(zoom / 1.12)
			KEY_HOME: fit_map()
			KEY_F: focus_selected()
			_: return
		accept_event()
