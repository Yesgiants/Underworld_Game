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
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 960)
	var ui = Main.instantiate()
	root.add_child(ui)
	for i in range(5):
		await process_frame
	expect(ui.cash_label.text == "$48,250", "HUD displays starting cash")
	expect(ui.map_title.text == "IRON HAVEN" and ui.map_hint.text.contains("2 BRIDGES"), "City heading identifies Iron Haven and its crossings")
	for i in range(24):
		expect(ui.map.district_at(ui.map.cell_rect(i).get_center()) == i, "District %d selects its own rectangle" % i)
	var river_point := Vector2(ui.map._river_center(ui.map.size.y * 0.5), ui.map.size.y * 0.5)
	expect(ui.map.district_at(river_point) == -1, "River water cannot select or claim a district")
	var hover := InputEventMouseMotion.new()
	hover.position = ui.map.cell_rect(8).get_center()
	ui.map._gui_input(hover)
	expect(ui.map.tooltip_text.contains("City Bridge"), "Bridge district tooltip describes its crossing")
	ui._select_district(8)
	expect(ui.district_label.text.contains("City Bridge"), "District inspection displays bridge approach")
	ui._select_district(7)
	expect(ui.members_button.text.contains("Members       8"), "Organization panel displays clickable members")
	expect(ui.map.cell_rect(7).has_point(ui.map.cell_rect(7).get_center()), "Map exposes district rectangles")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = ui.map.cell_rect(13).get_center()
	ui.map._gui_input(click)
	expect(ui.selected == 13 and not ui.action_buttons.claim.disabled, "Clicking adjacent district selects it and enables claim")
	ui.action_buttons.claim.pressed.emit()
	expect(ui.world.districts[13].owner == "player" and ui.cash_label.text == "$42,250", "Claim control updates simulation, map, and cash HUD")
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
	expect(ui.map_view.get_global_rect().end.x <= ui.org_stats.get_global_rect().position.x and ui.map_view.clip_contents, "Map workspace clips the enlarged canvas without overlapping the organization panel")
	ui.auto_button.pressed.emit()
	var before: Dictionary = ui.world.save_data()
	ui.debug_button.pressed.emit()
	var debug = ui.debug_panel
	expect(debug.visible and ui.timer.is_stopped(), "Opening debug pauses time")
	expect(ui.world.save_data() == before, "Opening debug does not tamper with the world")
	ui.next_button.grab_focus()
	var enter := InputEventKey.new()
	enter.pressed = true
	enter.keycode = KEY_ENTER
	root.push_input(enter)
	await process_frame
	expect(ui.world.day == before.day and debug.is_ancestor_of(root.gui_get_focus_owner()), "Debug prevents an underlying gameplay button from receiving keyboard activation")
	debug.faction_picker.get_popup().hide()
	debug.stat_fields.cash.get_line_edit().text = "53000"
	debug.stat_fields.members.get_line_edit().text = "12"
	debug.apply_stats_button.pressed.emit()
	expect(ui.world.organizations.romano.cash == 53000 and ui.world.organizations.romano.members == 12, "Debug stat fields apply to selected rival")
	expect(ui.rivals_label.text.contains("12 members"), "Main HUD updates after debug edits")
	debug.scenario_buttons.recruitment.pressed.emit()
	debug.advance_buttons[1].pressed.emit()
	expect(ui.world.organizations.romano.members == 4, "Debug recruitment scenario demonstrates rival hiring")
	expect(debug.history.text.contains("recruitment") and debug.inspector.text.contains("recruit"), "Debug shows membership cause and last AI decision")
	debug.scenario_buttons.unpaid_payroll.pressed.emit()
	debug.advance_buttons[1].pressed.emit()
	expect(ui.world.organizations.romano.members == 39 and debug.history.text.contains("unpaid payroll"), "Debug payroll scenario demonstrates rival losing a member")
	debug.market_field.get_line_edit().text = "120"
	debug.orders_field.get_line_edit().text = "0"
	debug.apply_world_button.pressed.emit()
	expect(ui.world.market == 120 and ui.world.orders == 0 and ui.action_buttons.recruit.disabled, "Debug global values refresh normal action availability")
	debug.district_picker.select(23)
	debug._read_district()
	debug.owner_picker.select(0)
	debug.business_field.get_line_edit().text = "3"
	debug.attention_field.get_line_edit().text = "90"
	debug.apply_district_button.pressed.emit()
	expect(ui.world.districts[23].owner == "player" and ui.world.districts[23].businesses == 3 and ui.world.districts[23].attention == 90 and ui.selected == 23, "Debug district overrides update the city map")
	var day: int = ui.world.day
	debug.advance_buttons[7].pressed.emit()
	expect(ui.world.day == day + 7, "Debug seven-day fast-forward button works")
	for i in range(3):
		await process_frame
	var fields_match := true
	for field in debug.stat_fields:
		var spin: SpinBox = debug.stat_fields[field]
		var expected: int = ui.world.organizations.romano[field]
		if int(spin.value) != expected or int(spin.get_line_edit().text.to_float()) != expected:
			printerr("Debug field mismatch: %s, value=%s, displayed=%s, expected=%s" % [field, spin.value, spin.get_line_edit().text, expected])
			fields_match = false
	expect(fields_match, "Debug numeric fields display the updated faction after fast-forward")
	var panel: Control = debug.get_child(1)
	expect(panel.get_global_rect().position.y >= 0 and panel.get_global_rect().end.y <= root.size.y, "Debug panel fits the viewport")
	expect(debug.message_label.get_global_rect().end.y <= panel.get_global_rect().end.y, "Debug controls fit inside their panel")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-debug="):
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			expect(image.save_png(arg.trim_prefix("--capture-debug=")) == OK, "Debug screenshot saved")
	var close_key := InputEventKey.new()
	close_key.pressed = true
	close_key.keycode = KEY_F3
	ui._input(close_key)
	expect(not debug.visible and ui.timer.is_stopped(), "F3 closes debug while preserving paused time")
	ui._reset()
	for i in range(3):
		await process_frame
	var old_save: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v0.2.0_grid_save.json"))
	expect(ui.world.restore_data(old_save), "UI can load an earlier v0.2 city")
	ui._refresh()
	expect(ui.map_title.text == "PROTOTYPE CITY" and ui.map.district_at(ui.map.cell_rect(3).get_center()) == 3, "Earlier save uses its original grid renderer and title")
	ui._reset()
	for i in range(3):
		await process_frame
	ui.auto_button.pressed.emit()
	var roster_before: Dictionary = ui.world.save_data()
	ui.members_button.pressed.emit()
	var page = ui.members_page
	expect(page.visible and ui.timer.is_stopped(), "Clickable Members link opens roster and pauses time")
	expect(ui.world.save_data() == roster_before, "Inspecting members preserves world state and random generator")
	expect(page.member_tree.get_root().get_child_count() == 8 and page.summary_label.text.begins_with("Player"), "Members page shows the Player roster")
	expect(page.name_label.text == "Tony Vega" and page.details_label.text.contains("34") and page.loyalty_label.text.contains("82"), "Selected profile displays its own full name, age, and loyalty")
	for i in range(3):
		await process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-members="):
			await RenderingServer.frame_post_draw
			expect(root.get_texture().get_image().save_png(arg.trim_prefix("--capture-members=")) == OK, "Members screenshot saved")
	var roster_panel: Control = page.get_child(1)
	expect(roster_panel.get_global_rect().position.y >= 0 and roster_panel.get_global_rect().end.y <= root.size.y and roster_panel.get_global_rect().end.x <= root.size.x, "Members page fits the viewport")
	var elena: TreeItem = page.member_tree.get_root().get_child(1)
	elena.select(0)
	page.member_tree.item_selected.emit()
	expect(page.name_label.text == "Elena Cruz" and page.selected_id == 2, "Clicking another member changes the profile")
	var edit_key := InputEventKey.new()
	edit_key.pressed = true
	edit_key.keycode = KEY_F3
	ui._input(edit_key)
	expect(page.editor.visible and not ui.debug_panel.visible, "F3 on Members page enables individual editing")
	page.first_name_edit.text = "Elena"
	page.last_name_edit.text = "Voss"
	page.age_edit.get_line_edit().text = "31"
	page.loyalty_edit.get_line_edit().text = "35"
	page.apply_button.pressed.emit()
	expect(ui.world.find_member("player", 2).last_name == "Voss" and ui.world.find_member("player", 2).age == 31 and ui.world.find_member("player", 2).loyalty == 35, "Individual edits update the actual member")
	expect(page.name_label.text == "Elena Voss" and page.selected_id == 2 and ui.loyalty_label.text.contains(str(ui.world.organizations.player.loyalty)), "Profile identity and crew average refresh after editing")
	page.faction_picker.select(1)
	page.faction_picker.item_selected.emit(1)
	expect(page.org_id == "romano" and page.member_tree.get_root().get_child_count() == 7, "Members page can inspect rival people")
	ui.world.debug_set_organization("romano", {"members": 9})
	ui._refresh()
	expect(page.member_tree.get_root().get_child_count() == 9, "Roster count updates after faction debug resizing")
	page.close()
	ui.debug_button.pressed.emit()
	ui.debug_panel.inspect_members_button.pressed.emit()
	expect(page.visible and page.org_id == "romano" and page.editor.visible and not ui.debug_panel.visible, "Debug Inspect members opens the chosen faction with individual editing")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	ui._input(escape)
	expect(not page.visible and ui.timer.is_stopped(), "Escape closes Members page and leaves time paused")
	ui._reset()
	for i in range(3):
		await process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var error: Error = image.save_png(arg.trim_prefix("--capture="))
			expect(error == OK, "UI screenshot saved")
	print("UI SMOKE TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
