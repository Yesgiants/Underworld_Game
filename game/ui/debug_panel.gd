extends Control
## An explicitly opened, paused-world editor. Mutations go through validated APIs.

const World = preload("res://game/simulation/world_state.gd")
const GOLD := Color("#742d36")
const MUTED := Color("#71634f")

var host
var faction_picker: OptionButton
var stat_fields: Dictionary = {}
var inspector: RichTextLabel
var district_picker: OptionButton
var owner_picker: OptionButton
var business_field: SpinBox
var attention_field: SpinBox
var market_field: SpinBox
var orders_field: SpinBox
var history: RichTextLabel
var message_label: Label
var scenario_buttons: Dictionary = {}
var apply_stats_button: Button
var apply_district_button: Button
var apply_world_button: Button
var advance_buttons: Dictionary = {}
var inspect_members_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim := ColorRect.new()
	scrim.color = Color(0.04, 0.08, 0.06, 0.88)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -480
	panel.offset_right = 480
	panel.offset_top = -430
	panel.offset_bottom = 430
	panel.add_theme_stylebox_override("panel", host._style(Color("#f2e5ca"), GOLD.darkened(0.3), 7, 18, 18))
	add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)

	var title := _row(content)
	title.add_child(host._label("SIMULATION DEBUG", 22, GOLD))
	host._spacer(title)
	title.add_child(host._button("Close [F3 / Esc]", close))
	content.add_child(host._label("Time is paused. Apply changes explicitly; edits are included when you save the city.", 12, MUTED))

	var faction_row := _row(content)
	faction_row.add_child(host._label("FACTION", 12, MUTED))
	faction_picker = OptionButton.new()
	faction_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for org_id in World.ORG_IDS:
		faction_picker.add_item(host.world.organizations[org_id].name)
	faction_picker.select(1)
	faction_picker.item_selected.connect(func(_index: int) -> void: refresh())
	faction_row.add_child(faction_picker)
	inspect_members_button = host._button("Inspect members", func() -> void: host._open_members(faction_id(), true), "Open this faction's individual roster with debug editing enabled.")
	faction_row.add_child(inspect_members_button)

	var columns := _row(content, 20)
	var edits := VBoxContainer.new()
	edits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edits.add_theme_constant_override("separation", 10)
	columns.add_child(edits)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	edits.add_child(grid)
	for field in ["cash", "members", "heat", "influence", "loyalty"]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(column)
		column.add_child(host._label(field.capitalize(), 12, MUTED))
		var limits: Array = World.STAT_LIMITS[field]
		var spin := _number(limits[0], limits[1])
		column.add_child(spin)
		stat_fields[field] = spin
	apply_stats_button = host._button("Apply faction stats", _apply_stats, "Override selected faction stats without spending an order.")
	edits.add_child(apply_stats_button)
	inspector = _text_box(240)
	inspector.custom_minimum_size.x = 420
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(inspector)

	content.add_child(host._label("DISTRICT OVERRIDE  /  OWNERSHIP BYPASSES NORMAL CLAIM RULES", 11, MUTED))
	var district_row := _row(content, 8)
	district_picker = OptionButton.new()
	for name in World.NAMES:
		district_picker.add_item(name)
	district_picker.custom_minimum_size.x = 160
	district_picker.item_selected.connect(func(_index: int) -> void: _read_district())
	district_row.add_child(district_picker)
	owner_picker = OptionButton.new()
	for org_id in World.ORG_IDS:
		owner_picker.add_item(host.world.organizations[org_id].name)
	owner_picker.add_item("Independent")
	owner_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	district_row.add_child(owner_picker)
	district_row.add_child(host._label("Businesses", 12, MUTED))
	business_field = _number(0, 3, 66)
	district_row.add_child(business_field)
	district_row.add_child(host._label("Attention", 12, MUTED))
	attention_field = _number(0, 100, 74)
	district_row.add_child(attention_field)
	apply_district_button = host._button("Apply", _apply_district)
	district_row.add_child(apply_district_button)

	var world_row := _row(content)
	world_row.add_child(host._label("Market %", 12, MUTED))
	market_field = _number(65, 135)
	world_row.add_child(market_field)
	world_row.add_child(host._label("Player orders", 12, MUTED))
	orders_field = _number(0, 2, 70)
	world_row.add_child(orders_field)
	apply_world_button = host._button("Apply world values", _apply_world)
	world_row.add_child(apply_world_button)
	host._spacer(world_row)
	world_row.add_child(host._label("Valid ranges protect save compatibility.", 11, MUTED))

	var scenarios := _row(content, 8)
	scenarios.add_child(host._label("SET UP TEST", 11, MUTED))
	for definition in [["recruitment", "Recruitment", "$50,000, 3 members, low heat. A rival recruits on the next day."], ["unpaid_payroll", "Missed payroll", "Zero cash, 40 members, and remove businesses owned by this faction. Next day guarantees missed payroll."], ["police", "Police pressure", "Set heat to 100 and give 10 members. Investigations remain probabilistic."]]:
		var scenario: String = definition[0]
		var button: Button = host._button(definition[1], func() -> void: _scenario(scenario), definition[2])
		scenarios.add_child(button)
		scenario_buttons[scenario] = button
	host._spacer(scenarios)
	scenarios.add_child(host._label("Changes the selected faction.", 11, MUTED))

	var advance_row := _row(content)
	advance_row.add_child(host._label("FAST-FORWARD", 11, MUTED))
	for days in [1, 7, 30]:
		var button: Button = host._button("+%d day%s" % [days, "" if days == 1 else "s"], func() -> void: _advance(days), "Run normal simulation steps, including payroll, rivals, and police.")
		advance_row.add_child(button)
		advance_buttons[days] = button
	host._spacer(advance_row)
	advance_row.add_child(host._label("Normal simulation rules stay active.", 11, MUTED))

	content.add_child(host._label("MEMBERSHIP HISTORY  /  SELECTED FACTION  /  LATEST FIRST", 11, MUTED))
	history = _text_box(108)
	history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(history)
	message_label = host._label("Choose a faction, edit stats, or prepare a test and advance time.", 12, MUTED)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(message_label)
	visible = false

func _row(parent: Node, spacing: int = 12) -> HBoxContainer:
	return host._row(parent, spacing)

func _number(minimum: int, maximum: int, width: int = 110) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = 1
	spin.custom_minimum_size = Vector2(width, 32)
	return spin

func _text_box(height: int) -> RichTextLabel:
	var text := RichTextLabel.new()
	text.custom_minimum_size.y = height
	text.add_theme_font_size_override("normal_font_size", 13)
	text.add_theme_constant_override("line_separation", 4)
	return text

func faction_id() -> String:
	return World.ORG_IDS[faction_picker.selected]

func open() -> void:
	host._pause()
	district_picker.select(host.selected)
	refresh()
	visible = true
	faction_picker.grab_focus()

func close() -> void:
	visible = false
	host._status("Debug closed. Time stays paused; your edits remain in the city.")

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func refresh() -> void:
	var world = host.world
	var org_id := faction_id()
	var org: Dictionary = world.organizations[org_id]
	for field in stat_fields:
		stat_fields[field].value = int(org[field])
	market_field.value = world.market
	orders_field.value = world.orders
	_read_district()
	var decision: Dictionary = world.ai_decisions.get(org_id, {})
	var description := "No AI decision recorded yet." if org_id != World.PLAYER else "Player controlled; no autonomous decision."
	if not decision.is_empty():
		description = "Day %d: %s\n%s" % [decision.day, decision.action.replace("_", " "), decision.reason]
	inspector.text = "DAY %d  ·  %d districts  ·  %d businesses\nIncome $%s  /  Payroll $%s per day\nDaily net $%s  ·  Crew %d / target %d\nRecruitment requires $%s cash.\nIncludes 3 days of new payroll; normal growth also\nrequires a $140 daily surplus.\n\nLAST AI DECISION\n%s" % [world.day, world.territory(org_id), world.businesses(org_id), World.money(world.daily_income(org_id)), World.money(world.daily_payroll(org_id)), World.money(world.daily_income(org_id) - world.daily_payroll(org_id)), org.members, world.recruitment_target(org_id), World.money(2500 + world.recruitment_reserve(org_id)), description]
	var lines := ""
	for entry in world.member_changes:
		if entry.organization == org_id:
			lines += "Day %02d   %d → %d   %s%s\n" % [entry.day, entry.before, entry.after, entry.reason, " · " + entry.person if not entry.person.is_empty() else ""]
	history.text = lines if not lines.is_empty() else "No membership changes recorded this session. Recruitment, departures, detention, and debug overrides appear here."

func _read_district() -> void:
	var district: Dictionary = host.world.districts[district_picker.selected]
	owner_picker.select((World.ORG_IDS + ["neutral"]).find(district.owner))
	business_field.value = int(district.businesses)
	attention_field.value = int(district.attention)

func _apply_stats() -> void:
	var values := {}
	for field in stat_fields:
		stat_fields[field].apply()
		values[field] = int(stat_fields[field].value)
	_result(host.world.debug_set_organization(faction_id(), values))

func _apply_district() -> void:
	business_field.apply()
	attention_field.apply()
	var owner: String = (World.ORG_IDS + ["neutral"])[owner_picker.selected]
	var result: Dictionary = host.world.debug_set_district(district_picker.selected, owner, int(business_field.value), int(attention_field.value))
	if result.ok:
		host.selected = district_picker.selected
	_result(result)

func _apply_world() -> void:
	market_field.apply()
	orders_field.apply()
	_result(host.world.debug_set_world(int(market_field.value), int(orders_field.value)))

func _scenario(scenario: String) -> void:
	_result(host.world.debug_scenario(faction_id(), scenario))

func _advance(days: int) -> void:
	_result(host.world.debug_advance(days))

func _result(result: Dictionary) -> void:
	host._refresh()
	message_label.text = result.message
	message_label.add_theme_color_override("font_color", MUTED if result.ok else Color("#742d36"))
	host._status(result.message, not result.ok)
