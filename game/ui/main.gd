extends Control

const World = preload("res://game/simulation/world_state.gd")
const CityMap = preload("res://game/ui/city_map.gd")
const TEXT := Color("#e3e8ee")
const MUTED := Color("#8996a7")
const GOLD := Color("#dfa65b")
const BG := Color("#0d1219")

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

func _ready() -> void:
	_build_theme()
	_build_ui()
	timer = Timer.new()
	timer.wait_time = 2.5
	timer.timeout.connect(_advance)
	add_child(timer)
	_refresh()
	_status("Select a district, issue an order, then advance the day. The city also moves without your orders.")

func _build_theme() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 14
	ui_theme.set_color("font_color", "Label", TEXT)
	ui_theme.set_color("default_color", "RichTextLabel", TEXT)
	ui_theme.set_color("font_color", "Button", TEXT)
	ui_theme.set_color("font_disabled_color", "Button", Color("#596574"))
	ui_theme.set_stylebox("normal", "Button", _style(Color("#202a36"), Color("#354150"), 5, 12, 10))
	ui_theme.set_stylebox("hover", "Button", _style(Color("#2b3745"), GOLD.darkened(0.3), 5, 12, 10))
	ui_theme.set_stylebox("pressed", "Button", _style(Color("#37414b"), GOLD, 5, 12, 10))
	ui_theme.set_stylebox("disabled", "Button", _style(Color("#161e28"), Color("#26303b"), 5, 12, 10))
	ui_theme.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), GOLD, 5, 12, 10))
	ui_theme.set_stylebox("panel", "TooltipPanel", _style(Color("#242e3a"), Color("#536174"), 5, 10, 8))
	ui_theme.set_color("font_color", "TooltipLabel", TEXT)
	ui_theme.set_stylebox("background", "ProgressBar", _style(Color("#27313d"), Color("#27313d"), 3, 0, 0))
	ui_theme.set_stylebox("fill", "ProgressBar", _style(Color("#69b4b0"), Color("#69b4b0"), 3, 0, 0))
	theme = ui_theme

func _style(fill: Color, border: Color, radius: int, horizontal: int, vertical: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = horizontal
	box.content_margin_right = horizontal
	box.content_margin_top = vertical
	box.content_margin_bottom = vertical
	return box

func _label(text: String, font_size: int = 14, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, callback: Callable, hint: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = hint
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	return button

func _card(parent: Node, padding: int = 18) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("#131b25"), Color("#2b3644"), 7, padding, padding))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
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
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margins.add_theme_constant_override("margin_" + side, 26)
	for side in ["top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 20)
	add_child(margins)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margins.add_child(root)

	var header := _row(root)
	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 1)
	header.add_child(brand)
	brand.add_child(_label("UNDERWORLD", 28, GOLD))
	brand.add_child(_label("A living city. A fragile empire.", 13, MUTED))
	_spacer(header)
	var tag := _label("SIMULATION PROTOTYPE  /  0.1", 11, MUTED)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(tag)
	header.add_child(_button("Save", _save, "Save the city, orders, and random state locally."))
	header.add_child(_button("Load", _load, "Load your last local save. Time pauses on load."))
	header.add_child(_button("New city", _confirm_reset, "Start again. Your last saved game is preserved."))

	var stats := _card(root, 14)
	var stats_row := _row(stats, 24)
	cash_label = _metric(stats_row, "CASH", GOLD)
	heat_label = _metric(stats_row, "HEAT", Color("#e07973"))
	influence_label = _metric(stats_row, "INFLUENCE", Color("#a9b9d4"))
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
	next_button.add_theme_stylebox_override("normal", _style(GOLD, GOLD, 5, 14, 10))
	next_button.add_theme_color_override("font_color", BG)
	stats_row.add_child(next_button)

	var middle := _row(root, 14)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var map_card := _card(middle)
	map_card.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var map_heading := _row(map_card)
	map_heading.add_child(_label("CITY MAP", 15))
	_spacer(map_heading)
	map_heading.add_child(_label("24 DISTRICTS  /  CLICK TO INSPECT", 11, MUTED))
	map = CityMap.new()
	map.world = world
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.district_selected.connect(_select_district)
	map_card.add_child(map)
	var legend := _row(map_card, 18)
	for item in [["● Navarro", GOLD], ["● Romano", Color("#aa8ccb")], ["● Moretti", Color("#69b4b0")], ["□ Independent", MUTED], ["● Surveillance", Color("#e07973")]]:
		legend.add_child(_label(item[0], 12, item[1]))
	district_label = _label("", 13)
	district_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	district_label.custom_minimum_size.y = 48
	map_card.add_child(district_label)

	var org_card := _card(middle)
	org_card.add_theme_constant_override("separation", 7)
	org_card.get_parent().custom_minimum_size.x = 340
	org_card.add_child(_label("NAVARRO ORGANIZATION", 17, GOLD))
	org_stats = _label("", 16)
	org_stats.add_theme_constant_override("line_spacing", 3)
	org_card.add_child(org_stats)
	loyalty_label = _label("", 12, MUTED)
	org_card.add_child(loyalty_label)
	loyalty_bar = ProgressBar.new()
	loyalty_bar.custom_minimum_size.y = 5
	loyalty_bar.show_percentage = false
	org_card.add_child(loyalty_bar)
	accounts_label = _label("", 12, Color("#69b4b0"))
	accounts_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	org_card.add_child(accounts_label)
	rivals_label = _label("", 12, MUTED)
	rivals_label.add_theme_constant_override("line_spacing", 3)
	org_card.add_child(rivals_label)
	_spacer(org_card).size_flags_vertical = Control.SIZE_EXPAND_FILL
	request_label = _label("", 13)
	request_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	org_card.add_child(request_label)
	request_buttons = _row(org_card, 8)
	request_yes = _button("Promote · $1,200", func() -> void: _request(true), "Loyalty +6. Does not use a daily order.")
	request_yes.name = "Promote"
	request_buttons.add_child(request_yes)
	request_buttons.add_child(_button("Decline", func() -> void: _request(false), "Loyalty −5. Does not use a daily order."))

	var orders_card := _card(root, 12)
	var orders_heading := _row(orders_card)
	orders_heading.add_child(_label("ISSUE AN ORDER", 12, MUTED))
	_spacer(orders_heading)
	orders_heading.add_child(_label("2 PER DAY  /  ORDERS APPLY IMMEDIATELY", 10, MUTED))
	var actions := _row(orders_card, 10)
	var definitions := [
		["operation", "Run operation", "Earn $1,900–4,100 · Heat +9", "Owned district. Immediate revenue adds heat and local attention."],
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
		action_buttons[action] = button
		var note := _label(entry[2], 11, MUTED)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(note)

	var log_card := _card(root, 14)
	var log_heading := _row(log_card)
	log_heading.add_child(_label("EVENTS", 14))
	_spacer(log_heading)
	log_heading.add_child(_label("LATEST FIRST  /  THE WORLD KEEPS MOVING", 10, MUTED))
	events_label = RichTextLabel.new()
	events_label.bbcode_enabled = true
	events_label.custom_minimum_size.y = 112
	events_label.add_theme_font_size_override("normal_font_size", 13)
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
	var org: Dictionary = world.organizations[World.PLAYER]
	cash_label.text = "$" + World.money(int(org.cash))
	heat_label.text = "%d / 100" % org.heat
	influence_label.text = str(int(org.influence))
	date_label.text = "DAY %02d  ·  %s" % [world.day, ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"][(world.day - 1) % 7]]
	orders_label.text = "%d / 2 orders available" % world.orders
	org_stats.text = "Members       %d\nBusinesses    %d\nTerritory     %.1f%%\nRivals        2" % [org.members, world.businesses(), world.territory() * 100.0 / 24.0]
	loyalty_label.text = "MEMBER LOYALTY                              %d%%" % org.loyalty
	loyalty_bar.value = org.loyalty
	var net: int = world.daily_income() - world.daily_payroll()
	accounts_label.text = "Daily net  %s$%s   ·   Market %d%%\nIncome $%s  /  Payroll $%s" % ["+" if net >= 0 else "", World.money(net), world.market, World.money(world.daily_income()), World.money(world.daily_payroll())]
	rivals_label.text = "RIVAL INTELLIGENCE\nRomano: %d districts · %d members\nMoretti: %d districts · %d members" % [world.territory("romano"), world.organizations.romano.members, world.territory("moretti"), world.organizations.moretti.members]
	var district: Dictionary = world.districts[selected]
	var owner: String = "Independent" if district.owner == "neutral" else world.organizations[district.owner].name
	district_label.text = "%s  /  %s\n%d businesses  ·  Police attention %d/100%s" % [district.name.to_upper(), owner, district.businesses, district.attention, "  ·  Borders your territory" if district.owner != World.PLAYER and world.borders(selected, World.PLAYER) else ""]
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
	var colors := {"player": "#dfa65b", "rival": "#aa8ccb", "police": "#e07973", "member": "#a9b9d4", "economy": "#69b4b0"}
	for entry in world.events:
		log_text += "[color=#66768c]DAY %02d[/color]  [color=%s]●[/color]  %s\n" % [entry.day, colors[entry.kind], entry.text.replace("[", "[lb]")]
	events_label.text = log_text

func _action_tooltip(action: String) -> String:
	match action:
		"operation": return "Owned district. Earn $1,900–4,100; heat +9 and local attention +12."
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
	_status("Saved city restored. Time is paused." if loaded else "No valid save found. Current city was preserved.", not loaded)

func _confirm_reset() -> void:
	_pause()
	reset_dialog.popup_centered()

func _reset() -> void:
	world = World.new()
	selected = 7
	_refresh()
	_status("A new city is ready. Your previous saved game is preserved.")

func _status(message: String, error: bool = false) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", Color("#e07973") if error else MUTED)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE and not reset_dialog.visible:
		_advance()
		get_viewport().set_input_as_handled()
