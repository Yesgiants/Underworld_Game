extends SceneTree

const Main = preload("res://game/ui/main.tscn")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	# --script uses a bare SceneTree rather than the project's main viewport.
	root.size = Vector2i(1280, 960)
	var ui = Main.instantiate()
	root.add_child(ui)
	for i in range(5):
		await process_frame
	expect(ui.cash_label.text == "$48,250", "HUD displays starting cash")
	expect(ui.org_stats.text.contains("Members       8"), "Organization panel displays members")
	expect(ui.map.cell_rect(7).has_point(ui.map.cell_rect(7).get_center()), "Map exposes district rectangles")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = ui.map.cell_rect(13).get_center()
	ui.map._gui_input(click)
	expect(ui.selected == 13 and not ui.action_buttons.claim.disabled, "Clicking adjacent district selects it and enables claim")
	ui.action_buttons.claim.pressed.emit()
	expect(ui.world.districts[13].owner == "navarro" and ui.cash_label.text == "$42,250", "Claim control updates simulation, map, and cash HUD")
	ui.next_button.pressed.emit()
	expect(ui.world.day == 2 and ui.date_label.text.begins_with("DAY 02") and ui.world.orders == 2, "Next day refreshes time and orders")
	ui.request_yes.pressed.emit()
	expect(not ui.world.request_pending and not ui.request_buttons.visible, "Member decision updates the request panel")
	ui.auto_button.pressed.emit()
	expect(not ui.timer.is_stopped(), "Auto simulation can start")
	ui.auto_button.pressed.emit()
	expect(ui.timer.is_stopped(), "Auto simulation can pause")
	ui._reset()
	for i in range(3):
		await process_frame
	var bottom: Rect2 = ui.status_label.get_global_rect()
	print("UI bounds: viewport %s, footer %s" % [root.size, bottom])
	expect(bottom.end.y <= root.size.y, "Interface fits inside the viewport vertically")
	expect(ui.map.get_global_rect().end.x <= ui.org_stats.get_global_rect().position.x, "Map and organization panel do not overlap")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var error: Error = image.save_png(arg.trim_prefix("--capture="))
			expect(error == OK, "UI screenshot saved")
	print("UI SMOKE TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
