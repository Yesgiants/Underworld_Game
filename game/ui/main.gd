extends Control

const World = preload("res://game/simulation/world_state.gd")
const MapViewport = preload("res://game/ui/map_viewport.gd")
const Ledger = preload("res://game/ui/ledger_theme.gd")
const DebugPanel = preload("res://game/ui/debug_panel.gd")
const MembersPage = preload("res://game/ui/members_page.gd")
const Layout = preload("res://game/simulation/city_layout.gd")
const TEXT = Ledger.INK
const MUTED = Ledger.MUTED
const GOLD = Ledger.RED
const BG = Ledger.PAPER

var world = World.new()
var selected: int = 7
var timer: Timer
var map: Control
var cash_label: Label
var heat_label: Label
var influence_label: Label
var date_label: Label
var orders_label: Label
var org_stats: Label
var loyalty_label: Label
var loyalty_bar: ProgressBar
var accounts_label: Label
var rivals_label: Label
var district_label: Label
var request_label: Label
var request_buttons: HBoxContainer
var request_yes: Button
var events_label: RichTextLabel
var status_label: Label
var auto_button: Button
var next_button: Button
var action_buttons: Dictionary = {}
var reset_dialog: ConfirmationDialog
var debug_panel: Control
var debug_button: Button
var members_page: Control
var members_button: LinkButton
var map_title: Label
var map_hint: Label
var map_view: Control
var zoom_label: Label
var operation_note: Label
var accounts_dialog: AcceptDialog

func _ready() -> void:
	_build_theme()
	_build_ui()
	timer = Timer.new()
	timer.wait_time = 2.5
	timer.timeout.connect(_advance)
	add_child(timer)
	_refresh()
	map_view.focus_selected()
	_status("Select a district, issue an order, then advance the day. The city also moves without your orders.")

func _build_theme() -> void:
	theme = Ledger.build()

func _style(fill: Color, border: Color, radius: int, horizontal: int, vertical: int) -> StyleBoxFlat:
	return Ledger.box(fill, border, radius, horizontal, vertical)

func _label(text: String, font_size: int = 14, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_font_override("font", Ledger.HEADING if font_size >= 16 else Ledger.SERIF)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, callback: Callable, hint: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 15)
	button.tooltip_text = hint
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	return button

func _card(parent: Node, padding: int = 12) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("#f2e5ca88"), Color("#a38b6670"), 7, padding, padding))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	return content

func _row(parent: Node, separation: int = 12) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	parent.add_child(row)
	return row

func _spacer(parent: Node) -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)
	return spacer

func _build_ui() -> void:
	var background := TextureRect.new()
	background.texture = preload("res://game/assets/ledger_background.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 44)
	margins.add_theme_constant_override("margin_right", 84)
	margins.add_theme_constant_override("margin_top", 34)
	margins.add_theme_constant_override("margin_bottom", 58)
	add_child(margins)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margins.add_child(root)

	var header := _row(root)
	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 1)
	header.add_child(brand)
	brand.add_child(_label("UNDERWORLD", 38, TEXT))
	brand.add_child(_label("—  T H E   F A M I L Y   L E D G E R  —", 11, GOLD))
	_spacer(header)
	var tag := _label("PROTOTYPE  /  0.2.0 DEV", 11, MUTED)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(tag)
	header.add_child(_button("Save", _save, "Save the city, orders, and random state locally."))
	header.add_child(_button("Load", _load, "Load your last local save. Time pauses on load."))
	debug_button = _button("Debug [F3]", func() -> void: debug_panel.toggle(), "Pause time and edit factions, districts, and world values.")
	header.add_child(debug_button)
	header.add_child(_button("New city", _confirm_reset, "Start again. Your last saved game is preserved."))

	var stats := _card(root, 14)
	var stats_row := _row(stats, 24)
	cash_label = _metric(stats_row, "CASH", GOLD)
	heat_label = _metric(stats_row, "HEAT", Ledger.RED)
	influence_label = _metric(stats_row, "INFLUENCE", TEXT)
	_spacer(stats_row)
	var time_column := VBoxContainer.new()
	stats_row.add_child(time_column)
	date_label = _label("", 17)
	orders_label = _label("", 12, MUTED)
	time_column.add_child(date_label)
	time_column.add_child(orders_label)
	auto_button = _button("▶ Run time", _toggle_time, "Automatically advance one day every 2.5 seconds. Rivals act each day.")
	stats_row.add_child(auto_button)
	next_button = _button("Next day →", _advance, "Advance one day: income, payroll, rival decisions, and police activity. Shortcut: Space.")
	next_button.name = "NextDay"
	Ledger.button_colors(next_button, Color("#c7a363"), TEXT)
	stats_row.add_child(next_button)

	var middle := _row(root, 14)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var map_card := _card(middle)
	map_card.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var map_heading := _row(map_card)
	map_title = _label("", 18)
	map_heading.add_child(map_title)
	_spacer(map_heading)
	map_heading.add_child(_button("−", func() -> void: map_view.set_zoom(map_view.zoom / 1.12), "Zoom out."))
	zoom_label = _label("70%", 12, MUTED)
	map_heading.add_child(zoom_label)
	map_heading.add_child(_button("+", func() -> void: map_view.set_zoom(map_view.zoom * 1.12), "Zoom in."))
	map_heading.add_child(_button("Fit", func() -> void: map_view.fit_map(), "Show the whole city. Shortcut: Home when the map is focused."))
	map_heading.add_child(_button("Focus", func() -> void: map_view.focus_selected(), "Center the selected district. Shortcut: F."))
	map_hint = _label("", 11, MUTED)
	map_card.add_child(map_hint)
	map_view = MapViewport.new()
	map = map_view.map
	map.world = world
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.district_selected.connect(_select_district)
	map_view.view_changed.connect(func() -> void: zoom_label.text = "%d%%" % roundi(map_view.zoom * 100))
	map_card.add_child(map_view)
	var legend := _row(map_card, 18)
	for item in [["● Player", Color("#976a20")], ["● Romano", Color("#805a87")], ["● Moretti", Ledger.GREEN], ["□ Independent", MUTED], ["● Surveillance", Ledger.RED]]:
		legend.add_child(_label(item[0], 12, item[1]))
	map_card.add_child(_label("Drag to pan · Wheel to scroll · Ctrl + wheel to zoom · Arrow keys to move", 11, MUTED))

	var org_scroll := ScrollContainer.new()
	org_scroll.custom_minimum_size.x = 300
	org_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	middle.add_child(org_scroll)
	var org_card := _card(org_scroll)
	org_card.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	org_card.add_theme_constant_override("separation", 7)
	org_card.get_parent().custom_minimum_size.x = 286
	org_card.add_child(_label("PLAYER", 17, GOLD))
	members_button = LinkButton.new()
	members_button.add_theme_font_size_override("font_size", 16)
	members_button.add_theme_color_override("font_color", GOLD)
	members_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	members_button.tooltip_text = "Open the roster and click a member to inspect their name, age, and loyalty."
	members_button.pressed.connect(func() -> void: _open_members())
	org_card.add_child(members_button)
	org_stats = _label("", 16)
	org_stats.add_theme_constant_override("line_spacing", 3)
	org_card.add_child(org_stats)
	loyalty_label = _label("", 12, MUTED)
	org_card.add_child(loyalty_label)
	loyalty_bar = ProgressBar.new()
	loyalty_bar.custom_minimum_size.y = 5
	loyalty_bar.show_percentage = false
	org_card.add_child(loyalty_bar)
	accounts_label = _label("", 13, Ledger.GREEN)
	accounts_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	org_card.add_child(accounts_label)
	rivals_label = _label("", 12, MUTED)
	rivals_label.add_theme_constant_override("line_spacing", 3)
	org_card.add_child(rivals_label)
	district_label = _label("", 13)
	district_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	org_card.add_child(district_label)
	request_label = _label("", 13)
	request_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	org_card.add_child(request_label)
	request_buttons = _row(org_card, 8)
	request_yes = _button("Promote · $1,200", func() -> void: _request(true), "Loyalty +6. Does not use a daily order.")
	request_yes.name = "Promote"
	request_buttons.add_child(request_yes)
	request_buttons.add_child(_button("Decline", func() -> void: _request(false), "Loyalty −5. Does not use a daily order."))

	var orders_card := _card(root, 10)
	var orders_heading := _row(orders_card)
	orders_heading.add_child(_label("ISSUE AN ORDER", 12, MUTED))
	_spacer(orders_heading)
	orders_heading.add_child(_label("2 PER DAY  /  ORDERS APPLY IMMEDIATELY", 10, MUTED))
	var actions := _row(orders_card, 10)
	var definitions := [
		["operation", "Run operation", "", "Owned district. Each local business adds $500 to the payout."],
		["claim", "Claim district", "$6,000 · Influence +8", "Adjacent district. Independent claims succeed; rival challenges have a 20–80% success chance. Heat +8; payment is spent even if the challenge fails."],
		["business", "Open business", "$6,500 · Revenue +$650/day", "Owned district, maximum 3 businesses. Revenue varies with market demand."],
		["recruit", "Recruit member", "$2,500 · Payroll +$140/day", "Add a member to strengthen contested claims."],
		["lay_low", "Lay low", "$1,800 · Heat −14", "Reduce police pressure and improve loyalty by 2."],
	]
	for entry in definitions:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 5)
		actions.add_child(column)
		var action: String = entry[0]
		var button := _button(entry[1], func() -> void: _act(action), entry[3])
		button.name = action.capitalize().replace(" ", "")
		column.add_child(button)
		if action in ["claim", "recruit"]:
			Ledger.button_colors(button, Ledger.RED)
		action_buttons[action] = button
		var note := _label(entry[2], 11, MUTED)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(note)
		if action == "operation":
			operation_note = note

	var log_card := _card(root, 10)
	var log_heading := _row(log_card)
	log_heading.add_child(_label("EVENTS", 14))
	_spacer(log_heading)
	log_heading.add_child(_label("LATEST FIRST  /  THE WORLD KEEPS MOVING", 10, MUTED))
	events_label = RichTextLabel.new()
	events_label.bbcode_enabled = true
	events_label.custom_minimum_size.y = 74
	events_label.add_theme_font_override("normal_font", Ledger.MONO)
	events_label.add_theme_font_size_override("normal_font_size", 12)
	events_label.add_theme_constant_override("line_separation", 5)
	log_card.add_child(events_label)
	status_label = _label("", 12, MUTED)
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	root.add_child(status_label)

	reset_dialog = ConfirmationDialog.new()
	reset_dialog.title = "Start a new city?"
	reset_dialog.dialog_text = "Current unsaved progress will be lost. Your saved game will remain available."
	reset_dialog.ok_button_text = "Start new city"
	reset_dialog.confirmed.connect(_reset)
	add_child(reset_dialog)
	debug_panel = DebugPanel.new()
	debug_panel.host = self
	add_child(debug_panel)
	members_page = MembersPage.new()
	members_page.host = self
	add_child(members_page)
	accounts_dialog = AcceptDialog.new()
	accounts_dialog.title = "The Family Ledger · Accounts"
	accounts_dialog.min_size = Vector2i(560, 260)
	add_child(accounts_dialog)
	var tabs := VBoxContainer.new()
	tabs.anchor_left = 1
	tabs.anchor_right = 1
	tabs.anchor_top = 0.28
	tabs.offset_left = -76
	tabs.offset_right = -8
	tabs.add_theme_constant_override("separation", 12)
	add_child(tabs)
	for entry in [["CITY", func() -> void: map_view.grab_focus(); map_view.focus_selected()], ["MEMBERS", func() -> void: _open_members()], ["ACCOUNTS", _open_accounts]]:
		var tab := _button(entry[0], entry[1])
		tab.add_theme_font_size_override("font_size", 11)
		tab.custom_minimum_size.y = 72
		Ledger.button_colors(tab, Ledger.RED if entry[0] == "CITY" else Ledger.GREEN)
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style: StyleBoxFlat = tab.get_theme_stylebox(state).duplicate()
			style.content_margin_left = 8
			style.content_margin_right = 8
			tab.add_theme_stylebox_override(state, style)
		tabs.add_child(tab)
	# Overlay pages must be above navigation tabs for drawing and mouse input.
	move_child(debug_panel, get_child_count() - 1)
	move_child(members_page, get_child_count() - 1)

func _metric(parent: Node, heading: String, color: Color) -> Label:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 130
	column.add_theme_constant_override("separation", 3)
	parent.add_child(column)
	column.add_child(_label(heading, 11, MUTED))
	var value := _label("", 25, color)
	column.add_child(value)
	return value

func _refresh() -> void:
	map_title.text = Layout.city_name(world.city_layout).to_upper()
	map_hint.text = "24 DISTRICTS / 2 BRIDGES / CALDER RIVER" if world.city_layout == Layout.IRON_HAVEN else "24 DISTRICTS / ORIGINAL MAP"
	var payout: Vector2i = world.operation_range(selected)
	operation_note.text = "$%s–%s · Heat +9" % [World.money(payout.x), World.money(payout.y)]
	var org: Dictionary = world.organizations[World.PLAYER]
	cash_label.text = "$" + World.money(int(org.cash))
	heat_label.text = "%d / 100" % org.heat
	influence_label.text = str(int(org.influence))
	date_label.text = "DAY %02d  ·  %s" % [world.day, ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"][(world.day - 1) % 7]]
	orders_label.text = "%d / 2 orders available" % world.orders
	members_button.text = "Members       %d   →" % org.members
	org_stats.text = "Businesses    %d\nTerritory     %.1f%%\nRivals        2" % [world.businesses(), world.territory() * 100.0 / 24.0]
	loyalty_label.text = "AVERAGE LOYALTY                  %d%%" % org.loyalty
	loyalty_bar.value = org.loyalty
	var net: int = world.daily_income() - world.daily_payroll()
	accounts_label.text = "Daily net  %s$%s   ·   Market %d%%\nIncome $%s  /  Payroll $%s" % ["+" if net >= 0 else "", World.money(net), world.market, World.money(world.daily_income()), World.money(world.daily_payroll())]
	rivals_label.text = "RIVAL INTELLIGENCE\nRomano: %d districts · %d members\nMoretti: %d districts · %d members" % [world.territory("romano"), world.organizations.romano.members, world.territory("moretti"), world.organizations.moretti.members]
	var district: Dictionary = world.districts[selected]
	var owner: String = "Independent" if district.owner == "neutral" else world.organizations[district.owner].name
	district_label.text = "%s  /  %s\n%d businesses  ·  Police attention %d/100%s" % [district.name.to_upper(), owner, district.businesses, district.attention, "  ·  Borders your territory" if district.owner != World.PLAYER and world.borders(selected, World.PLAYER) else ""]
	district_label.text += "\n" + Layout.district_detail(selected, world.city_layout)
	request_label.text = "MEMBER REQUEST\n%s seeks a promotion." % world.request_name if world.request_pending else "MEMBER REQUEST\nNo pending requests. Next review every 7 days."
	request_buttons.visible = world.request_pending
	request_yes.disabled = int(org.cash) < 1200
	for action in action_buttons:
		var blocker: String = world.action_blocker(action, World.PLAYER, selected)
		action_buttons[action].disabled = not blocker.is_empty()
		action_buttons[action].tooltip_text = blocker if not blocker.is_empty() else _action_tooltip(action)
	map.world = world
	map.selected = selected
	map.queue_redraw()
	var log_text := ""
	var colors := {"player": "#976a20", "rival": "#805a87", "police": "#742d36", "member": "#52422f", "economy": "#23483d", "debug": "#8e5929"}
	for entry in world.events:
		log_text += "[color=#71634f]DAY %02d[/color]  [color=%s]●[/color]  %s\n" % [entry.day, colors[entry.kind], entry.text.replace("[", "[lb]")]
	events_label.text = log_text
	if debug_panel != null and debug_panel.visible:
		debug_panel.refresh()
	if members_page != null and members_page.visible:
		members_page.refresh()

func _open_members(faction: String = World.PLAYER, edit: bool = false) -> void:
	members_page.open(faction, edit)

func _action_tooltip(action: String) -> String:
	match action:
		"operation":
			var payout: Vector2i = world.operation_range(selected)
			return "Owned district. Earn $%s–%s: $1,900–4,100 base plus $500 per local business (%d here). Heat +9; local attention +12." % [World.money(payout.x), World.money(payout.y), world.districts[selected].businesses]
		"claim": return "Costs $6,000. Adjacent independent claims succeed. Rival challenges have 20–80% odds based on members and influence; costs are spent even on failure. Heat +8."
		"business": return "Costs $6,500. Adds $650 base daily revenue, adjusted by market demand. Maximum 3 per district."
		"recruit": return "Costs $2,500. Adds a member and $140 daily payroll. Members strengthen territorial challenges."
		"lay_low": return "Costs $1,800. Reduces heat by 14 and improves loyalty by 2."
	return ""

func _select_district(index: int) -> void:
	selected = index
	_refresh()

func _act(action: String) -> void:
	var result: Dictionary = world.perform_action(action, World.PLAYER, selected)
	_refresh()
	_status(result.message, not result.ok)

func _advance() -> void:
	world.advance_day()
	_refresh()
	_status("Day %d: accounts settled, rivals acted, and police reviewed the city." % world.day)

func _toggle_time() -> void:
	if timer.is_stopped():
		timer.start()
		auto_button.text = "Ⅱ Pause time"
		_status("Time is running. Rivals and the economy advance every 2.5 seconds.")
	else:
		_pause()
		_status("Time paused. Issue orders or advance one day at a time.")

func _pause() -> void:
	timer.stop()
	auto_button.text = "▶ Run time"

func _request(promote: bool) -> void:
	var result: Dictionary = world.resolve_request(promote)
	_refresh()
	_status(result.message, not result.ok)

func _save() -> void:
	var error: Error = world.save_game()
	_status("City saved locally, including simulation random state." if error == OK else "Could not save the city: %s." % error_string(error), error != OK)

func _load() -> void:
	_pause()
	var loaded: bool = world.load_game()
	_refresh()
	map_view.focus_selected()
	_status("Saved city restored. Time is paused." if loaded else "No valid save found. Current city was preserved.", not loaded)

func _confirm_reset() -> void:
	_pause()
	reset_dialog.popup_centered()

func _reset() -> void:
	world = World.new()
	selected = 7
	_refresh()
	map_view.focus_selected()
	_status("A new city is ready. Your previous saved game is preserved.")

func _status(message: String, error: bool = false) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", Ledger.RED if error else MUTED)

func _open_accounts() -> void:
	_pause()
	accounts_dialog.dialog_text = "PLAYER ACCOUNTS\n\nCash on hand: $%s\nBusinesses: %d · Districts: %d\nDaily income: $%s\nDaily payroll: $%s\nDaily net: $%s\nMarket demand: %d%%\n\nOperations earn an extra $500 for each business in the selected district.\nTime remains paused when you close this page." % [World.money(world.organizations[World.PLAYER].cash), world.businesses(), world.territory(), World.money(world.daily_income()), World.money(world.daily_payroll()), World.money(world.daily_income() - world.daily_payroll()), world.market]
	accounts_dialog.popup_centered()

func _input(event: InputEvent) -> void:
	# Keep keyboard navigation on the editor while its overlay is open.
	# A previously focused gameplay button must not accept Enter/Space.
	var overlay: Control = members_page if members_page.visible else debug_panel if debug_panel.visible else null
	if overlay != null and event is InputEventKey:
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and not overlay.is_ancestor_of(focused):
			if members_page.visible:
				members_page.member_tree.grab_focus()
			else:
				debug_panel.faction_picker.grab_focus()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3 and not reset_dialog.visible and not accounts_dialog.visible:
			if members_page.visible:
				members_page.debug_toggle.button_pressed = not members_page.debug_toggle.button_pressed
			else:
				debug_panel.toggle()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and overlay != null:
			overlay.close()
			get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE and not reset_dialog.visible and not accounts_dialog.visible and not debug_panel.visible and not members_page.visible:
		_advance()
		get_viewport().set_input_as_handled()
