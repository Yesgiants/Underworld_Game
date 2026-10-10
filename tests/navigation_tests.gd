extends SceneTree

const Main = preload("res://game/ui/main.tscn")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func mouse(point: Vector2, button: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = pressed
	root.push_input(event)

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)

func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 960)
	var ui = Main.instantiate()
	root.add_child(ui)
	for i in range(5):
		await process_frame
	var camera = ui.map_view
	var initial: Dictionary = ui.world.save_data()
	var cash_rect: Rect2 = ui.cash_label.get_global_rect()
	var orders_rect: Rect2 = ui.action_buttons.operation.get_global_rect()
	expect(ui.map.size == Vector2(1600, 1000) and ui.map.size.x > camera.size.x, "City canvas is larger than its independent viewport")
	camera.set_zoom(1.0)
	camera.pan(Vector2(320, 280))
	expect(camera.scroll.x > 0 and camera.scroll.y > 0, "Map can scroll on both axes")
	expect(ui.cash_label.get_global_rect() == cash_rect and ui.action_buttons.operation.get_global_rect() == orders_rect, "Map navigation leaves ledger stats and orders fixed")
	var anchor: Vector2 = camera.view_size() * 0.5
	var map_point: Vector2 = camera.view_to_map(anchor)
	camera.set_zoom(1.2, anchor)
	expect(camera.view_to_map(anchor).distance_to(map_point) < 0.01, "Zoom preserves the map point under the cursor")
	camera.set_zoom(99)
	expect(is_equal_approx(camera.zoom, 1.6), "Zoom has an upper bound")
	camera.set_zoom(0.01)
	expect(is_equal_approx(camera.zoom, 0.25), "Zoom has a lower bound")
	camera.fit_map()
	expect(ui.map.position.x >= 0 and ui.map.position.y >= 0 and (ui.map.position + ui.map.size * camera.zoom).x <= camera.view_size().x + 0.01 and (ui.map.position + ui.map.size * camera.zoom).y <= camera.view_size().y + 0.01, "Fit shows the complete city inside the viewport")
	for district in range(24):
		var local: Vector2 = camera.map_to_view(ui.map.cell_rect(district).get_center())
		var point: Vector2 = camera.global_position + local
		mouse(point, MOUSE_BUTTON_LEFT, true)
		mouse(point, MOUSE_BUTTON_LEFT, false)
		expect(ui.selected == district, "Real transformed mouse input selects district %d" % district)
	var river_point: Vector2 = camera.global_position + camera.map_to_view(Vector2(ui.map._river_center(500), 500))
	mouse(river_point, MOUSE_BUTTON_LEFT, true)
	mouse(river_point, MOUSE_BUTTON_LEFT, false)
	expect(ui.selected == 23, "Clicking the river does not select a district")
	ui._select_district(7)
	expect(ui.operation_note.text.contains("2,900–5,100") and ui.action_buttons.operation.tooltip_text.contains("2 here"), "Operation quote and tooltip match the selected district's businesses")
	ui._select_district(6)
	expect(ui.operation_note.text.contains("2,400–4,600"), "Changing district updates the operation payout quote")
	ui._select_district(7)
	camera.set_zoom(1)
	camera.focus_selected()
	var point: Vector2 = camera.global_position + camera.view_size() * 0.5
	var before_scroll: Vector2 = camera.scroll
	mouse(point, MOUSE_BUTTON_LEFT, true)
	var motion := InputEventMouseMotion.new()
	motion.position = point - Vector2(90, 60)
	motion.global_position = motion.position
	motion.relative = Vector2(-90, -60)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion)
	mouse(motion.position, MOUSE_BUTTON_LEFT, false)
	expect(camera.scroll != before_scroll and ui.selected == 7 and not camera.dragging, "Dragging pans without an accidental district selection")
	before_scroll = camera.scroll
	mouse(point, MOUSE_BUTTON_WHEEL_DOWN, true)
	expect(camera.scroll.y > before_scroll.y, "Mouse wheel scrolls the map vertically")
	var horizontal_wheel := InputEventMouseButton.new()
	horizontal_wheel.position = point
	horizontal_wheel.global_position = point
	horizontal_wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	horizontal_wheel.pressed = true
	horizontal_wheel.shift_pressed = true
	before_scroll = camera.scroll
	root.push_input(horizontal_wheel)
	expect(camera.scroll.x > before_scroll.x, "Shift-wheel scrolls the map horizontally")
	var zoom_wheel := horizontal_wheel.duplicate() as InputEventMouseButton
	zoom_wheel.shift_pressed = false
	zoom_wheel.ctrl_pressed = true
	zoom_wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	var previous_zoom: float = camera.zoom
	root.push_input(zoom_wheel)
	expect(camera.zoom > previous_zoom, "Ctrl-wheel zooms the map")
	camera.grab_focus()
	before_scroll = camera.scroll
	key(KEY_RIGHT)
	expect(camera.scroll.x > before_scroll.x, "Arrow keys pan the focused map")
	key(KEY_HOME)
	expect(ui.map.position.y >= 0, "Home fits the map through real keyboard input")
	camera.set_zoom(1)
	ui._select_district(15)
	key(KEY_F)
	var selected_point: Vector2 = camera.map_to_view(ui.map.cell_rect(15).get_center())
	expect(selected_point.distance_to(camera.view_size() * 0.5) < 0.01, "Focus centers the selected district")
	ui._select_district(23)
	camera.focus_selected()
	selected_point = camera.map_to_view(ui.map.cell_rect(23).get_center())
	expect(Rect2(Vector2.ZERO, camera.view_size()).has_point(selected_point), "Edge districts remain visible when focus is clamped at map bounds")
	camera.horizontal.value = 90
	camera.vertical.value = 120
	expect(camera.scroll == Vector2(90, 120), "Scrollbar controls update the same map camera")
	camera.pan(Vector2(-9999, -9999))
	expect(camera.scroll == Vector2.ZERO, "Panning stays inside the map bounds")
	expect(ui.world.save_data() == initial, "Inspection and navigation do not change simulation state or RNG")
	ui._open_members()
	before_scroll = camera.scroll
	point = camera.global_position + camera.view_size() * 0.5
	mouse(point, MOUSE_BUTTON_WHEEL_DOWN, true)
	key(KEY_RIGHT)
	expect(camera.scroll == before_scroll and ui.members_page.visible, "Members overlay blocks map mouse and keyboard navigation")
	key(KEY_ESCAPE)
	expect(not ui.members_page.visible, "Escape closes the Members overlay")
	ui._open_accounts()
	expect(ui.accounts_dialog.visible and ui.accounts_dialog.dialog_text.contains("Daily income") and ui.timer.is_stopped(), "Accounts tab opens the current finances and pauses time")
	var space := InputEventKey.new()
	space.pressed = true
	space.keycode = KEY_SPACE
	ui._unhandled_key_input(space)
	expect(ui.world.day == 1, "Accounts page blocks the advance-day shortcut")
	ui.accounts_dialog.hide()
	print("NAVIGATION TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
