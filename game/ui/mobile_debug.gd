extends "res://game/ui/debug_panel.gd"
## The original debug APIs in a vertically scrolling phone inspector.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var scroll: ScrollContainer = host._phone_scroll(panel)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	content.add_child(host._button("CLOSE DEBUG", close))
	content.add_child(host._label("SIMULATION DEBUG", 16))
	faction_picker = OptionButton.new()
	faction_picker.custom_minimum_size.y = 48
	for org_id in World.ORG_IDS: faction_picker.add_item(host.world.organizations[org_id].name)
	faction_picker.select(1)
	faction_picker.item_selected.connect(func(_index: int) -> void: refresh())
	content.add_child(faction_picker)
	inspect_members_button = host._button("INSPECT MEMBERS", func() -> void: host._open_members(faction_id(), true))
	content.add_child(inspect_members_button)
	for field in ["cash", "members", "heat", "influence", "loyalty"]:
		content.add_child(host._label(field.capitalize(), 12))
		var limits: Array = World.STAT_LIMITS[field]
		var spin := _number(limits[0], limits[1])
		spin.custom_minimum_size.y = 48
		content.add_child(spin)
		stat_fields[field] = spin
	apply_stats_button = host._button("APPLY FACTION STATS", _apply_stats)
	content.add_child(apply_stats_button)
	inspector = _text_box(190)
	inspector.fit_content = true
	content.add_child(inspector)
	content.add_child(host._label("DISTRICT OVERRIDE", 16))
	district_picker = OptionButton.new()
	district_picker.custom_minimum_size.y = 48
	for district in host.world.districts: district_picker.add_item(district.name)
	district_picker.item_selected.connect(func(_index: int) -> void: _read_district())
	content.add_child(district_picker)
	owner_picker = OptionButton.new()
	owner_picker.custom_minimum_size.y = 48
	for org_id in World.ORG_IDS: owner_picker.add_item(host.world.organizations[org_id].name)
	owner_picker.add_item("Independent")
	content.add_child(owner_picker)
	content.add_child(host._label("Businesses (0–3)", 12))
	business_field = _number(0, 3)
	content.add_child(business_field)
	content.add_child(host._label("Police attention (0–100)", 12))
	attention_field = _number(0, 100)
	content.add_child(attention_field)
	apply_district_button = host._button("APPLY DISTRICT", _apply_district)
	content.add_child(apply_district_button)
	content.add_child(host._label("Market demand (%)", 12))
	market_field = _number(65, 135)
	content.add_child(market_field)
	content.add_child(host._label("Orders remaining (0–2)", 12))
	orders_field = _number(0, 2)
	content.add_child(orders_field)
	apply_world_button = host._button("APPLY WORLD VALUES", _apply_world)
	content.add_child(apply_world_button)
	content.add_child(host._label("RIVAL TEST SCENARIOS", 16))
	for entry in [["recruitment", "RECRUITMENT"], ["unpaid_payroll", "MISSED PAYROLL"], ["police", "POLICE PRESSURE"]]:
		var scenario: String = entry[0]
		var button: Button = host._button(entry[1], func() -> void: _scenario(scenario))
		content.add_child(button)
		scenario_buttons[scenario] = button
	for days in [1, 7, 30]:
		var button: Button = host._button("ADVANCE %d DAYS" % days, func() -> void: _advance(days))
		content.add_child(button)
		advance_buttons[days] = button
	content.add_child(host._label("MEMBERSHIP HISTORY", 16))
	history = _text_box(140)
	history.fit_content = true
	content.add_child(history)
	message_label = host._label("Changes are applied explicitly and autosaved.", 12)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(message_label)
	for spin in [business_field, attention_field, market_field, orders_field]: spin.custom_minimum_size.y = 48
	visible = false

func open() -> void:
	host.map_view.cancel_gesture()
	super.open()

func close() -> void:
	super.close()
	host.show_page("menu")
