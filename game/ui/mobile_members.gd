extends "res://game/ui/members_page.gd"

const Pixel = preload("res://game/ui/pixel_theme.gd")
const Portrait = preload("res://game/ui/pixel_portrait.gd")
var roster_content: VBoxContainer
var profile_content: VBoxContainer
var portrait: Control
var decline_button: Button
var roster_buttons: Dictionary = {}

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
	var heading: HBoxContainer = host._row(content, 4)
	var back: Button = host._button("BACK", close)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.custom_minimum_size.x = 64
	heading.add_child(back)
	heading.add_child(host._label("THE CREW", 18))
	faction_picker = OptionButton.new()
	faction_picker.custom_minimum_size.y = 48
	for faction in World.ORG_IDS: faction_picker.add_item(host.world.organizations[faction].name)
	faction_picker.item_selected.connect(_change_faction)
	content.add_child(faction_picker)
	summary_label = host._label("", 11)
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(summary_label)
	roster_content = VBoxContainer.new()
	roster_content.add_theme_constant_override("separation", 6)
	content.add_child(roster_content)
	profile_content = VBoxContainer.new()
	profile_content.add_theme_constant_override("separation", 8)
	content.add_child(profile_content)
	var profile_heading: HBoxContainer = host._row(profile_content, 8)
	portrait = Portrait.new()
	portrait.custom_minimum_size = Vector2(64, 72)
	profile_heading.add_child(portrait)
	name_label = host._label("", 18)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	profile_heading.add_child(name_label)
	details_label = host._label("", 12)
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	profile_content.add_child(details_label)
	loyalty_label = host._label("", 13)
	profile_content.add_child(loyalty_label)
	loyalty_bar = ProgressBar.new()
	loyalty_bar.show_percentage = false
	loyalty_bar.custom_minimum_size.y = 14
	profile_content.add_child(loyalty_bar)
	var explanation: Label = host._label("Members strengthen contested claims. Loyalty below 35 can lead to departures. Payroll and police pressure affect the crew.", 12)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	profile_content.add_child(explanation)
	promotion_button = host._button("PROMOTE / $1,200", func() -> void: host._request(true))
	profile_content.add_child(promotion_button)
	decline_button = host._button("DECLINE REQUEST", func() -> void: host._request(false))
	profile_content.add_child(decline_button)
	debug_toggle = CheckButton.new()
	debug_toggle.text = "Debug profile editing"
	debug_toggle.custom_minimum_size.y = 48
	debug_toggle.toggled.connect(func(_enabled: bool) -> void: _show_member())
	profile_content.add_child(debug_toggle)
	editor = VBoxContainer.new()
	profile_content.add_child(editor)
	first_name_edit = _name_field(editor, "First name")
	last_name_edit = _name_field(editor, "Last name")
	for field in [first_name_edit, last_name_edit]: field.custom_minimum_size.y = 48
	var numbers: HBoxContainer = host._row(editor, 6)
	age_edit = _number_field(numbers, "Age", 18, 100)
	loyalty_edit = _number_field(numbers, "Loyalty", 0, 100)
	for field in [age_edit, loyalty_edit]: field.custom_minimum_size.y = 48
	apply_button = host._button("APPLY MEMBER EDITS", _apply_edits)
	editor.add_child(apply_button)
	message_label = host._label("Tap a member to inspect their profile. Time stays paused.", 11)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(message_label)
	# Preserve the existing stable-ID roster selection and validation logic.
	member_tree = Tree.new()
	member_tree.columns = 4
	member_tree.hide()
	add_child(member_tree)
	profile_content.hide()
	visible = false

func open(faction: String = World.PLAYER, edit: bool = false) -> void:
	super.open(faction, edit)
	roster_content.show()
	profile_content.hide()
	if edit: select_member(selected_id)

func refresh() -> void:
	super.refresh()
	for child in roster_content.get_children():
		roster_content.remove_child(child)
		child.queue_free()
	roster_buttons.clear()
	for member in host.world.organizations[org_id].roster:
		var id := int(member.id)
		var button: Button = host._button("", func() -> void: select_member(id))
		button.custom_minimum_size.y = 68
		button.tooltip_text = Member.full_name(member)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 9
		row.offset_right = -9
		row.add_theme_constant_override("separation", 8)
		button.add_child(row)
		var avatar := Portrait.new()
		avatar.member_id = id
		row.add_child(avatar)
		var text := VBoxContainer.new()
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(text)
		var name: Label = host._label(Member.full_name(member).to_upper(), 12, Pixel.LIGHT)
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name.clip_text = true
		text.add_child(name)
		text.add_child(host._label("AGE %d / LOYALTY %d%%" % [member.age, member.loyalty], 11, Pixel.LIGHT))
		row.add_child(host._label(">", 18, Pixel.LIGHT))
		roster_content.add_child(button)
		roster_buttons[id] = button

func select_member(id: int) -> void:
	selected_id = id
	roster_content.hide()
	profile_content.show()
	_show_member()
	host._save_preferences()

func _show_member() -> void:
	super._show_member()
	portrait.member_id = selected_id
	portrait.queue_redraw()
	decline_button.visible = promotion_button.visible

func _change_faction(index: int) -> void:
	super._change_faction(index)
	roster_content.show()
	profile_content.hide()

func close() -> void:
	if profile_content.visible:
		profile_content.hide()
		roster_content.show()
	else:
		host.show_page("city")
