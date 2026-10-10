extends "res://game/ui/main.gd"
## A phone-sized notebook over the existing simulation and order handlers.

const Pixel = preload("res://game/ui/pixel_theme.gd")
const PhoneMap = preload("res://game/ui/mobile_map_viewport.gd")
const PhoneMembers = preload("res://game/ui/mobile_members.gd")
const PhoneDebug = preload("res://game/ui/mobile_debug.gd")
const Notebook = preload("res://game/ui/pixel_notebook.gd")
const UI_PATH := "user://underworld_mobile.cfg"
var margins: MarginContainer
var pages: Control
var city_page: VBoxContainer
var ledger_page: ScrollContainer
var menu_page: ScrollContainer
var order_sheet: PanelContainer
var district_summary: Label
var navigation: HBoxContainer
var time_controls: HBoxContainer
var stats_row: HBoxContainer
var nav_buttons: Dictionary = {}
var page_id: String = "city"
var initialized: bool = false
var backgrounded: bool = false
var saved_snapshot: String = ""
var save_error: Error = OK
var save_path: String = World.SAVE_PATH
var ui_path: String = UI_PATH
var last_commands: Dictionary = {}
var safe_area_timer: Timer

func _ready() -> void:
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	var loaded := world.load_game(save_path)
	super._ready()
	saved_snapshot = JSON.stringify(world.save_data())
	initialized = true
	_restore_preferences()
	_apply_safe_area()
	safe_area_timer = Timer.new()
	safe_area_timer.wait_time = 0.3
	safe_area_timer.timeout.connect(_apply_safe_area)
	add_child(safe_area_timer)
	safe_area_timer.start()
	_status("Campaign restored. Time is paused." if loaded else "Welcome to Iron Haven. Tap a district to begin.")

func _build_theme() -> void:
	theme = Pixel.build()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _label(text: String, font_size: int = 12, color: Color = Pixel.INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_font_override("font", Pixel.FONT if font_size >= 16 else Pixel.BODY)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text: String, callback: Callable, hint: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = hint
	button.pressed.connect(callback)
	return button

func _card(parent: Node, padding: int = 8) -> VBoxContainer:
	var panel := PanelContainer.new()
	var box := Pixel.panel()
	box.set_content_margin_all(padding)
	panel.add_theme_stylebox_override("panel", box)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	return content

func _phone_scroll(parent: Node) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	parent.add_child(scroll)
	return scroll

func _fill(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _build_ui() -> void:
	var cover := Notebook.new()
	_fill(cover)
	add_child(cover)
	margins = MarginContainer.new()
	_fill(margins)
	add_child(margins)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margins.add_child(root)
	var heading := _row(root, 6)
	var brand := VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(brand)
	brand.add_child(_label("UNDERWORLD", 22, Pixel.LIGHT))
	brand.add_child(_label("FAMILY LEDGER / PLAYER", 10, Pixel.COPPER))
	var menu_button := _button("MENU", func() -> void: show_page("menu"))
	menu_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	menu_button.custom_minimum_size.x = 64
	heading.add_child(menu_button)
	stats_row = _row(root, 6)
	for entry in [["CASH", "cash"], ["HEAT", "heat"], ["INFLUENCE", "influence"]]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_row.add_child(column)
		column.add_child(_label(entry[0], 9, Pixel.COPPER))
		var value := _label("", 14, Pixel.LIGHT)
		column.add_child(value)
		match entry[1]:
			"cash": cash_label = value
			"heat": heat_label = value
			"influence": influence_label = value
	pages = Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages.custom_minimum_size.y = 100
	root.add_child(pages)
	city_page = VBoxContainer.new()
	_fill(city_page)
	city_page.add_theme_constant_override("separation", 5)
	pages.add_child(city_page)
	var heading_row := _row(city_page, 4)
	map_title = _label("", 16, Pixel.LIGHT)
	map_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(map_title)
	date_label = _label("", 10, Pixel.LIGHT)
	heading_row.add_child(date_label)
	map_view = PhoneMap.new()
	map = map_view.map
	map.world = world
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.district_selected.connect(_select_district)
	city_page.add_child(map_view)
	var map_controls := _row(city_page, 4)
	for entry in [["−", func() -> void: map_view.set_zoom(map_view.zoom / 1.2)], ["+", func() -> void: map_view.set_zoom(map_view.zoom * 1.2)], ["FIT", func() -> void: map_view.fit_map()], ["FOCUS", func() -> void: map_view.focus_selected()]]:
		map_controls.add_child(_button(entry[0], entry[1]))
	var district_card := _card(city_page, 7)
	var district_row := _row(district_card, 6)
	district_summary = _label("", 11)
	district_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	district_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	district_row.add_child(district_summary)
	var orders := _button("ORDERS", _open_orders)
	orders.size_flags_horizontal = Control.SIZE_SHRINK_END
	district_row.add_child(orders)
	ledger_page = _phone_scroll(pages)
	_fill(ledger_page)
	var ledger := _card(ledger_page)
	ledger.add_child(_label("THE LEDGER", 20))
	members_button = LinkButton.new()
	members_button.custom_minimum_size.y = 48
	members_button.pressed.connect(func() -> void: _open_members())
	ledger.add_child(members_button)
	org_stats = _label("", 13)
	ledger.add_child(org_stats)
	loyalty_label = _label("", 10)
	ledger.add_child(loyalty_label)
	loyalty_bar = ProgressBar.new()
	loyalty_bar.show_percentage = false
	loyalty_bar.custom_minimum_size.y = 10
	ledger.add_child(loyalty_bar)
	accounts_label = _label("", 12, Pixel.TEAL)
	accounts_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ledger.add_child(accounts_label)
	rivals_label = _label("", 11)
	ledger.add_child(rivals_label)
	for faction in ["romano", "moretti"]:
		ledger.add_child(_button("VIEW " + faction.to_upper() + " CREW", func() -> void: _open_members(faction)))
	request_label = _label("", 12)
	request_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ledger.add_child(request_label)
	request_buttons = _row(ledger, 4)
	request_yes = _button("PROMOTE $1,200", func() -> void: _request(true))
	request_buttons.add_child(request_yes)
	request_buttons.add_child(_button("DECLINE", func() -> void: _request(false)))
	ledger.add_child(_label("EVENTS / LATEST FIRST", 14))
	events_label = RichTextLabel.new()
	events_label.bbcode_enabled = true
	events_label.fit_content = true
	events_label.custom_minimum_size.y = 100
	ledger.add_child(events_label)
	menu_page = _phone_scroll(pages)
	_fill(menu_page)
	var menu := _card(menu_page)
	menu.add_child(_label("NOTEBOOK MENU", 18))
	menu.add_child(_label("Progress saves after every order and day.", 11))
	menu.add_child(_button("SAVE NOW", _save))
	menu.add_child(_button("LOAD LAST SAVE", _load))
	debug_button = _button("SIMULATION DEBUG", func() -> void: debug_panel.open())
	menu.add_child(debug_button)
	menu.add_child(_button("NEW CITY", _confirm_reset))
	menu.add_child(_button("BACK TO CITY", func() -> void: show_page("city")))
	menu.add_child(_button("EXIT GAME", func() -> void: _background(); get_tree().quit()))
	var help := _label("Tap a district to inspect it. Drag to pan; pinch or use +/− to zoom.\n\nYou have two orders per day. Next day settles income, payroll, rivals, and police.\n\nOperations earn $500 extra per business in the selected district. Members help contested claims; low loyalty can cause departures.\n\nv0.2.0 mobile prototype / offline", 12)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu.add_child(help)
	_build_order_sheet()
	members_page = PhoneMembers.new()
	members_page.host = self
	pages.add_child(members_page)
	debug_panel = PhoneDebug.new()
	debug_panel.host = self
	pages.add_child(debug_panel)
	status_label = _label("", 10, Pixel.LIGHT)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 28
	root.add_child(status_label)
	time_controls = _row(root, 5)
	auto_button = _button("RUN TIME", _toggle_time)
	time_controls.add_child(auto_button)
	next_button = _button("NEXT DAY", _advance)
	time_controls.add_child(next_button)
	navigation = _row(root, 4)
	for entry in [["city", "CITY"], ["ledger", "LEDGER"], ["crew", "CREW"]]:
		var id: String = entry[0]
		var tab := _button(entry[1], func() -> void: show_page(id))
		navigation.add_child(tab)
		nav_buttons[id] = tab
	var hidden := VBoxContainer.new()
	hidden.hide()
	add_child(hidden)
	map_hint = _label("")
	zoom_label = _label("")
	orders_label = _label("")
	for label in [map_hint, zoom_label, orders_label]: hidden.add_child(label)
	reset_dialog = ConfirmationDialog.new()
	reset_dialog.title = "NEW CAMPAIGN"
	reset_dialog.dialog_text = "Replace this campaign with a new city?\nThe new campaign will autosave."
	reset_dialog.dialog_autowrap = true
	reset_dialog.min_size = Vector2i(280, 140)
	reset_dialog.confirmed.connect(_reset)
	add_child(reset_dialog)
	accounts_dialog = AcceptDialog.new()
	add_child(accounts_dialog)
	show_page("city")

func _build_order_sheet() -> void:
	order_sheet = PanelContainer.new()
	_fill(order_sheet)
	pages.add_child(order_sheet)
	var scroll := _phone_scroll(order_sheet)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	content.add_child(_button("BACK TO MAP", _close_orders))
	district_label = _label("", 12)
	district_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(district_label)
	operation_note = _label("", 12, Pixel.TEAL)
	content.add_child(operation_note)
	for entry in [["operation", "RUN OPERATION"], ["claim", "CLAIM / $6,000"], ["business", "BUSINESS / $6,500"], ["recruit", "RECRUIT / $2,500"], ["lay_low", "LAY LOW / $1,800"]]:
		var action: String = entry[0]
		var button := _button(entry[1], func() -> void: _act(action))
		content.add_child(button)
		action_buttons[action] = button
		var note := _label("", 11)
		note.name = action + "_note"
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(note)
	order_sheet.hide()

func _refresh() -> void:
	super._refresh()
	var district: Dictionary = world.districts[selected]
	var owner: String = "Independent" if district.owner == "neutral" else world.organizations[district.owner].name
	district_summary.text = "%s / %s\n%d businesses / police %d\n%d ORDERS LEFT" % [district.name, owner, district.businesses, district.attention, world.orders]
	date_label.text = "DAY %02d" % world.day
	loyalty_label.text = "AVERAGE LOYALTY %d%%" % world.organizations.player.loyalty
	for action in action_buttons:
		var note: Label = order_sheet.find_child(action + "_note", true, false)
		note.text = world.action_blocker(action, World.PLAYER, selected) if action_buttons[action].disabled else _action_tooltip(action)
	if initialized and JSON.stringify(world.save_data()) != saved_snapshot:
		_autosave()
	_update_time_controls()

func show_page(id: String) -> void:
	if timer != null: _pause()
	map_view.cancel_gesture()
	order_sheet.hide()
	if members_page != null: members_page.hide()
	if debug_panel != null: debug_panel.hide()
	page_id = id
	city_page.visible = id == "city"
	ledger_page.visible = id == "ledger"
	menu_page.visible = id == "menu"
	if id == "crew" and members_page != null: members_page.open()
	for key in nav_buttons: Pixel.accent(nav_buttons[key], Pixel.TEAL if key == id else Pixel.COVER)
	_update_time_controls()
	if initialized: _save_preferences()

func _open_orders() -> void:
	_pause()
	_refresh()
	order_sheet.show()
	map_view.cancel_gesture()
	_update_time_controls()

func _close_orders() -> void:
	order_sheet.hide()
	_update_time_controls()

func _update_time_controls() -> void:
	if auto_button == null or next_button == null: return
	var blocked := page_id != "city" or order_sheet.visible or debug_panel.visible or backgrounded or reset_dialog.visible
	auto_button.disabled = blocked
	next_button.disabled = blocked
	var keyboard_open := DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) and DisplayServer.virtual_keyboard_get_height() > 0
	if time_controls != null: time_controls.visible = page_id == "city" and not keyboard_open

func _open_members(faction: String = World.PLAYER, edit: bool = false) -> void:
	show_page("crew")
	members_page.open(faction, edit)

func _open_accounts() -> void:
	show_page("ledger")

func _select_district(index: int) -> void:
	super._select_district(index)
	if initialized: _save_preferences()

func _command_allowed(command: String) -> bool:
	var now := Time.get_ticks_msec()
	if backgrounded or now - int(last_commands.get(command, -1000)) < 200: return false
	last_commands[command] = now
	return true

func _act(action: String) -> void:
	if _command_allowed(action): super._act(action)

func _advance() -> void:
	if page_id == "city" and not order_sheet.visible and not debug_panel.visible and not reset_dialog.visible and _command_allowed("day"):
		super._advance()

func _toggle_time() -> void:
	if page_id == "city" and not order_sheet.visible and not debug_panel.visible and not backgrounded:
		super._toggle_time()
		auto_button.text = "RUN TIME" if timer.is_stopped() else "PAUSE TIME"

func _pause() -> void:
	if timer != null: timer.stop()
	if auto_button != null: auto_button.text = "RUN TIME"

func _autosave() -> void:
	save_error = world.save_game(save_path)
	if save_error == OK: saved_snapshot = JSON.stringify(world.save_data())
	_save_preferences()

func _save() -> void:
	_autosave()
	_status("Campaign saved." if save_error == OK else "Save failed: " + error_string(save_error), save_error != OK)

func _load() -> void:
	_pause()
	initialized = false
	var loaded := world.load_game(save_path)
	if loaded: save_error = OK
	_refresh()
	initialized = true
	saved_snapshot = JSON.stringify(world.save_data())
	_status("Campaign loaded. Time paused." if loaded else "No valid save found. Current city preserved.", not loaded)

func _reset() -> void:
	world = World.new()
	selected = 7
	show_page("city")
	initialized = false
	_refresh()
	initialized = true
	_autosave()
	map_view.focus_selected()
	_status("New campaign saved. Welcome to Iron Haven.")

func _confirm_reset() -> void:
	_pause()
	reset_dialog.popup_centered(Vector2i(300, 160))

func _status(message: String, error: bool = false) -> void:
	if status_label == null: return
	status_label.text = message + (" / SAVE FAILED" if save_error != OK else "")
	status_label.add_theme_color_override("font_color", Pixel.COPPER if error or save_error != OK else Pixel.LIGHT)

func _save_preferences() -> void:
	var config := ConfigFile.new()
	config.set_value("ui", "page", page_id)
	config.set_value("ui", "district", selected)
	if members_page != null:
		config.set_value("ui", "faction", members_page.org_id)
		config.set_value("ui", "member", members_page.selected_id)
		config.set_value("ui", "profile", members_page.profile_content.visible)
	config.save(ui_path)

func _restore_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(ui_path) != OK: return
	selected = clampi(int(config.get_value("ui", "district", 7)), 0, 23)
	_refresh()
	var id: String = config.get_value("ui", "page", "city")
	show_page(id if id in ["city", "ledger", "crew", "menu"] else "city")
	if page_id == "crew":
		var faction: String = config.get_value("ui", "faction", World.PLAYER)
		members_page.open(faction if faction in World.ORG_IDS else World.PLAYER)
		members_page.selected_id = int(config.get_value("ui", "member", 1))
		members_page.refresh()
		if bool(config.get_value("ui", "profile", false)): members_page.select_member(members_page.selected_id)
	map_view.focus_selected()

func _apply_safe_area() -> void:
	if margins == null: return
	var inset := Vector4(10, 10, 10, 10)
	if OS.has_feature("android") or OS.has_feature("ios"):
		var physical := Vector2(DisplayServer.window_get_size())
		var logical := get_viewport_rect().size
		var safe := DisplayServer.get_display_safe_area()
		if physical.x > 0 and physical.y > 0 and safe.has_area():
			var ratio := logical / physical
			inset += Vector4(safe.position.x * ratio.x, safe.position.y * ratio.y, maxf(0, physical.x - safe.end.x) * ratio.x, maxf(0, physical.y - safe.end.y) * ratio.y)
		var keyboard := DisplayServer.virtual_keyboard_get_height() * logical.y / maxf(1, physical.y)
		inset.w = maxf(inset.w, keyboard + 10)
		navigation.visible = keyboard == 0
		time_controls.visible = keyboard == 0 and page_id == "city"
		stats_row.visible = keyboard == 0
		if keyboard > 0:
			var focused := get_viewport().gui_get_focus_owner()
			var ancestor: Node = focused
			while ancestor != null:
				if ancestor is ScrollContainer:
					ancestor.call_deferred("ensure_control_visible", focused)
					break
				ancestor = ancestor.get_parent()
	for entry in [["margin_left", inset.x], ["margin_top", inset.y], ["margin_right", inset.z], ["margin_bottom", inset.w]]:
		margins.add_theme_constant_override(entry[0], int(entry[1]))

func _background() -> void:
	if not initialized: return
	backgrounded = true
	_pause()
	map_view.cancel_gesture()
	if safe_area_timer != null: safe_area_timer.stop()
	_autosave()
	_status("Progress saved. Time paused." if save_error == OK else "Time paused. Could not save progress.", save_error != OK)
	_update_time_controls()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_background()
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN] and initialized:
		backgrounded = false
		_pause()
		_apply_safe_area()
		if safe_area_timer != null: safe_area_timer.start()
		_update_time_controls()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and initialized:
		_go_back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST and initialized:
		_background()
		get_tree().quit()

func _go_back() -> void:
	if reset_dialog.visible: reset_dialog.hide()
	elif debug_panel.visible: debug_panel.close()
	elif order_sheet.visible: _close_orders()
	elif page_id == "crew": members_page.close()
	elif page_id != "city": show_page("city")
	else: show_page("menu")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_go_back()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F3:
			debug_panel.toggle()
			get_viewport().set_input_as_handled()
