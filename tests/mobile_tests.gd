extends SceneTree

const Main = preload("res://game/ui/mobile.tscn")
const World = preload("res://game/simulation/world_state.gd")
const SAVE := "user://underworld-mobile-test.json"
const PREFS := "user://underworld-mobile-test.cfg"
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func touch(point: Vector2, index: int, pressed: bool, cancelled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = cancelled
	root.push_input(event)

func drag(point: Vector2, index: int) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	root.push_input(event)

func cleanup() -> void:
	for path in [SAVE, SAVE + ".bak", SAVE + ".tmp", SAVE + ".bak.tmp", PREFS]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func frames(count: int = 4) -> void:
	for _i in range(count): await process_frame

func _run() -> void:
	cleanup()
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(360, 640)
	var ui = Main.instantiate()
	ui.save_path = SAVE
	ui.ui_path = PREFS
	root.add_child(ui)
	await frames()
	expect(ui.cash_label.text == "$48,250" and ui.timer.is_stopped(), "Mobile opens with the current world and paused time")
	for dims in [Vector2i(360, 640), Vector2i(360, 780), Vector2i(768, 1024)]:
		root.size = dims
		await frames()
		expect(ui.navigation.get_global_rect().end.y <= dims.y and ui.navigation.get_global_rect().end.x <= dims.x, "Navigation fits %s" % dims)
		expect(ui.map_view.get_global_rect().end.y <= ui.navigation.global_position.y, "Map stays above fixed navigation at %s" % dims)
	root.size = Vector2i(360, 640)
	await frames()
	for button in [ui.next_button, ui.auto_button, ui.nav_buttons.city, ui.nav_buttons.ledger, ui.nav_buttons.crew]:
		expect(button.size.y >= 48, "Primary control has a 48-unit touch area")
	var camera = ui.map_view
	var before := JSON.stringify(ui.world.save_data())
	camera.fit_map()
	expect((ui.map.position + ui.map.size * camera.zoom).x <= camera.size.x + 0.1 and (ui.map.position + ui.map.size * camera.zoom).y <= camera.size.y + 0.1, "Fit displays all districts on a phone")
	for district in range(24):
		var point: Vector2 = camera.global_position + camera.map_to_view(ui.map.cell_rect(district).get_center())
		touch(point, 0, true)
		touch(point, 0, false)
		expect(ui.selected == district, "Native touch selects district %d" % district)
	expect(JSON.stringify(ui.world.save_data()) == before, "Touch inspection preserves orders and random state")
	ui._select_district(7)
	camera.set_zoom(0.6)
	camera.focus_selected()
	var point: Vector2 = camera.global_position + camera.size * 0.5
	var original_scroll: Vector2 = camera.scroll
	touch(point, 0, true)
	drag(point - Vector2(30, 20), 0)
	touch(point - Vector2(30, 20), 0, false)
	expect(camera.scroll != original_scroll and ui.selected == 7, "One-finger drag pans without a selection")
	var original_zoom: float = camera.zoom
	touch(point - Vector2(30, 0), 0, true)
	touch(point + Vector2(30, 0), 1, true)
	drag(point + Vector2(60, 0), 1)
	touch(point + Vector2(60, 0), 1, false)
	touch(point - Vector2(30, 0), 0, false)
	expect(camera.zoom > original_zoom and ui.selected == 7 and camera.touches.is_empty(), "Pinch zoom cannot become a district tap on release")
	touch(point, 0, true)
	touch(point, 0, false, true)
	expect(camera.touches.is_empty() and ui.selected == 7, "Cancelled touches cannot leave a stuck drag or select")
	ui._open_orders()
	expect(ui.order_sheet.visible and ui.next_button.disabled, "District sheet blocks day controls")
	ui.action_buttons.operation.pressed.emit()
	expect(ui.world.orders == 1 and ui.world.organizations.player.cash > 48250, "Phone operation applies the existing local business payout")
	var restored := World.new()
	expect(restored.load_game(SAVE) and restored.save_data() == ui.world.save_data(), "An order autosaves the complete world and RNG")
	ui._close_orders()
	ui.next_button.pressed.emit()
	ui.next_button.pressed.emit()
	expect(ui.world.day == 2, "Repeated immediate Next day taps advance only once")
	expect(restored.load_game(SAVE) and restored.save_data() == ui.world.save_data(), "Day settlement autosaves rival decisions and payroll")
	ui.show_page("ledger")
	expect(ui.ledger_page.visible and not ui.city_page.visible and ui.timer.is_stopped(), "Ledger exposes accounts and events with time paused")
	ui._open_members()
	await frames()
	expect(ui.members_page.roster_buttons.size() == 8, "Crew has a tappable row for every current member")
	ui.members_page.roster_buttons[1].pressed.emit()
	expect(ui.members_page.profile_content.visible and ui.members_page.name_label.text == "Tony Vega", "Crew opens the correct stable-ID member profile")
	ui.members_page.promotion_button.pressed.emit()
	expect(not ui.world.request_pending and ui.world.find_member(World.PLAYER, 1).loyalty == 88, "Member promotion keeps existing individual loyalty effects")
	ui._go_back()
	expect(ui.members_page.roster_content.visible, "Back from a profile returns to the roster")
	ui._go_back()
	expect(ui.page_id == "city", "Back from the roster returns to City")
	ui.show_page("menu")
	ui.debug_button.pressed.emit()
	ui.debug_panel.scenario_buttons.recruitment.pressed.emit()
	ui.debug_panel.advance_buttons[1].pressed.emit()
	expect(ui.world.organizations.romano.members == 4, "Phone debug scenarios demonstrate rival recruitment")
	expect(restored.load_game(SAVE) and restored.save_data() == ui.world.save_data(), "Debug changes also autosave")
	ui.debug_panel.close()
	ui.show_page("city")
	ui._toggle_time()
	touch(point, 0, true)
	ui._background()
	expect(ui.timer.is_stopped() and camera.touches.is_empty(), "Backgrounding pauses automatic days and cancels gestures")
	expect(restored.load_game(SAVE) and restored.save_data() == ui.world.save_data(), "Backgrounding writes a valid campaign")
	ui._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	expect(not ui.backgrounded and ui.timer.is_stopped(), "Resuming leaves time paused")
	ui._select_district(12)
	ui._open_members()
	ui.members_page.select_member(2)
	var final_world := JSON.stringify(ui.world.save_data())
	ui._background()
	ui.queue_free()
	await frames()
	ui = Main.instantiate()
	ui.save_path = SAVE
	ui.ui_path = PREFS
	root.add_child(ui)
	await frames()
	expect(JSON.stringify(ui.world.save_data()) == final_world and ui.timer.is_stopped(), "Restart restores the full campaign without offline progression")
	expect(ui.selected == 12 and ui.page_id == "crew" and ui.members_page.selected_id == 2 and ui.members_page.profile_content.visible, "Restart restores selected district, page, and member profile")
	var prior_campaign: Dictionary = ui.world.save_data()
	ui._reset()
	expect(ui.world.day == 1 and ui.world.organizations.player.cash == 48250, "New city resets and autosaves after explicit confirmation")
	var prior := World.new()
	expect(prior.load_game(SAVE + ".bak") and prior.save_data() == prior_campaign, "New city does not overwrite its prior-campaign recovery backup with a duplicate save")
	ui.show_page("city")
	ui.queue_free()
	await frames()
	# Recovery must survive corruption and retain valid older data.
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string("{interrupted-save")
	file.close()
	expect(restored.load_game(SAVE), "A corrupt primary recovers from its validated backup")
	var recovered := JSON.stringify(restored.save_data())
	expect(restored.save_game(SAVE) == OK, "Recovered state can be saved again")
	var backup := World.new()
	expect(backup.load_game(SAVE + ".bak") and backup.save_data() == restored.save_data(), "Corruption cannot overwrite the valid recovery backup")
	if DisplayServer.get_name() != "headless":
		ui = Main.instantiate()
		ui.save_path = SAVE
		ui.ui_path = PREFS
		root.add_child(ui)
		await frames()
		await RenderingServer.frame_post_draw
		expect(root.get_texture().get_image().save_png("res://docs/mobile_pixel_city.png") == OK, "Rendered mobile City capture saved")
		ui._open_members()
		await frames()
		await RenderingServer.frame_post_draw
		expect(root.get_texture().get_image().save_png("res://docs/mobile_pixel_crew.png") == OK, "Rendered mobile Crew capture saved")
		ui.queue_free()
		await frames()
	cleanup()
	print("MOBILE TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
