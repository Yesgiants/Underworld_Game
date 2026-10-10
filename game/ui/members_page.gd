extends Control
## A roster page with a selected person's profile and optional debug editing.

const World = preload("res://game/simulation/world_state.gd")
const Member = preload("res://game/simulation/member_data.gd")
const GOLD := Color("#742d36")
const MUTED := Color("#71634f")

var host
var org_id: String = World.PLAYER
var selected_id: int = 1
var building: bool = false
var faction_picker: OptionButton
var member_tree: Tree
var summary_label: Label
var name_label: Label
var details_label: Label
var loyalty_label: Label
var loyalty_bar: ProgressBar
var promotion_button: Button
var debug_toggle: CheckButton
var editor: VBoxContainer
var first_name_edit: LineEdit
var last_name_edit: LineEdit
var age_edit: SpinBox
var loyalty_edit: SpinBox
var apply_button: Button
var message_label: Label

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
	panel.offset_left = -520
	panel.offset_right = 520
	panel.offset_top = -410
	panel.offset_bottom = 410
	panel.add_theme_stylebox_override("panel", host._style(Color("#f2e5ca"), Color("#a38b66"), 7, 20, 20))
	add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)
	var heading: HBoxContainer = host._row(content)
	heading.add_child(host._label("MEMBERS", 24, GOLD))
	host._spacer(heading)
	faction_picker = OptionButton.new()
	for faction in World.ORG_IDS:
		faction_picker.add_item(host.world.organizations[faction].name)
	faction_picker.custom_minimum_size.x = 230
	faction_picker.item_selected.connect(_change_faction)
	heading.add_child(faction_picker)
	debug_toggle = CheckButton.new()
	debug_toggle.text = "Debug editing [F3]"
	debug_toggle.tooltip_text = "Edit individual names, age, and loyalty. Changes affect the saved city."
	debug_toggle.toggled.connect(func(_enabled: bool) -> void: _show_member())
	heading.add_child(debug_toggle)
	heading.add_child(host._button("Close [Esc]", close))
	summary_label = host._label("", 14, MUTED)
	content.add_child(summary_label)
	var columns: HBoxContainer = host._row(content, 20)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	member_tree = Tree.new()
	member_tree.columns = 4
	member_tree.hide_root = true
	member_tree.column_titles_visible = true
	member_tree.select_mode = Tree.SELECT_ROW
	member_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	member_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	member_tree.add_theme_font_size_override("font_size", 15)
	member_tree.add_theme_constant_override("v_separation", 10)
	member_tree.add_theme_stylebox_override("panel", host._style(Color("#f7ecd6"), Color("#b3a284"), 4, 8, 8))
	for i in range(4):
		member_tree.set_column_title(i, ["First name", "Last name", "Age", "Loyalty"][i])
		member_tree.set_column_custom_minimum_width(i, [140, 145, 65, 85][i])
		member_tree.set_column_expand(i, i < 2)
	member_tree.item_selected.connect(_selection_changed)
	columns.add_child(member_tree)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 310
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	var profile := VBoxContainer.new()
	profile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile.add_theme_constant_override("separation", 12)
	scroll.add_child(profile)
	profile.add_child(host._label("MEMBER PROFILE", 11, MUTED))
	name_label = host._label("", 23, GOLD)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	profile.add_child(name_label)
	details_label = host._label("", 14)
	details_label.add_theme_constant_override("line_spacing", 5)
	profile.add_child(details_label)
	loyalty_label = host._label("", 13)
	profile.add_child(loyalty_label)
	loyalty_bar = ProgressBar.new()
	loyalty_bar.custom_minimum_size.y = 8
	loyalty_bar.show_percentage = false
	profile.add_child(loyalty_bar)
	var explanation: Label = host._label("Each member has their own loyalty. Below 35, they may leave. Missed payroll and police pressure affect the crew; promotions affect the requesting person.", 12, MUTED)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	profile.add_child(explanation)
	promotion_button = host._button("Promote · $1,200", func() -> void: host._request(true), "Resolve this person's pending request; their loyalty increases by 6.")
	profile.add_child(promotion_button)
	editor = VBoxContainer.new()
	editor.add_theme_constant_override("separation", 8)
	profile.add_child(editor)
	editor.add_child(host._label("DEBUG PROFILE OVERRIDE", 11, GOLD))
	first_name_edit = _name_field(editor, "First name")
	last_name_edit = _name_field(editor, "Last name")
	var numbers: HBoxContainer = host._row(editor, 12)
	age_edit = _number_field(numbers, "Age", 18, 100)
	loyalty_edit = _number_field(numbers, "Loyalty", 0, 100)
	apply_button = host._button("Apply member edits", _apply_edits)
	editor.add_child(apply_button)
	message_label = host._label("Select a member to inspect their profile. Time stays paused while this page is open.", 12, MUTED)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(message_label)
	visible = false

func _name_field(parent: Node, caption: String) -> LineEdit:
	parent.add_child(host._label(caption, 12, MUTED))
	var field := LineEdit.new()
	field.max_length = 40
	field.custom_minimum_size.y = 34
	parent.add_child(field)
	return field

func _number_field(parent: Node, caption: String, minimum: int, maximum: int) -> SpinBox:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	column.add_child(host._label(caption, 12, MUTED))
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.step = 1
	field.custom_minimum_size = Vector2(110, 34)
	column.add_child(field)
	return field

func open(faction: String = World.PLAYER, edit: bool = false) -> void:
	host._pause()
	if host.debug_panel.visible:
		host.debug_panel.close()
	org_id = faction
	faction_picker.select(World.ORG_IDS.find(org_id))
	selected_id = int(host.world.organizations[org_id].roster[0].id)
	debug_toggle.button_pressed = edit
	refresh()
	visible = true
	member_tree.grab_focus()

func close() -> void:
	visible = false
	debug_toggle.button_pressed = false
	host._status("Members page closed. Time stays paused.")

func _change_faction(index: int) -> void:
	org_id = World.ORG_IDS[index]
	selected_id = int(host.world.organizations[org_id].roster[0].id)
	refresh()

func refresh() -> void:
	building = true
	var org: Dictionary = host.world.organizations[org_id]
	if host.world.find_member(org_id, selected_id).is_empty():
		selected_id = int(org.roster[0].id)
	summary_label.text = "%s  /  %d members  /  Average loyalty %d%%  /  Daily payroll $%s" % [org.name, org.members, org.loyalty, World.money(host.world.daily_payroll(org_id))]
	member_tree.clear()
	var root := member_tree.create_item()
	for member in org.roster:
		var row := member_tree.create_item(root)
		row.set_metadata(0, int(member.id))
		row.set_text(0, member.first_name)
		row.set_text(1, member.last_name)
		row.set_text(2, str(int(member.age)))
		row.set_text(3, "%d%%" % member.loyalty)
		row.set_custom_color(3, Color("#742d36") if int(member.loyalty) < 35 else Color("#23483d") if int(member.loyalty) >= 70 else GOLD)
		if int(member.id) == selected_id:
			row.select(0)
	building = false
	_show_member()

func _selection_changed() -> void:
	if building:
		return
	var item := member_tree.get_selected()
	if item != null:
		selected_id = int(item.get_metadata(0))
		_show_member()

func _show_member() -> void:
	var member: Dictionary = host.world.find_member(org_id, selected_id)
	if member.is_empty():
		return
	name_label.text = Member.full_name(member)
	details_label.text = "First name    %s\nLast name     %s\nAge               %d\nDaily payroll  $140\nJoined            Day %d" % [member.first_name, member.last_name, member.age, member.joined_day]
	loyalty_label.text = "LOYALTY  %d / 100" % member.loyalty
	loyalty_bar.value = int(member.loyalty)
	promotion_button.visible = org_id == World.PLAYER and host.world.request_pending and host.world.request_member_id == selected_id
	promotion_button.disabled = int(host.world.organizations[World.PLAYER].cash) < 1200
	editor.visible = debug_toggle.button_pressed
	first_name_edit.text = member.first_name
	last_name_edit.text = member.last_name
	age_edit.value = int(member.age)
	loyalty_edit.value = int(member.loyalty)

func _apply_edits() -> void:
	if not debug_toggle.button_pressed:
		return
	age_edit.apply()
	loyalty_edit.apply()
	var result: Dictionary = host.world.debug_set_member(org_id, selected_id, {"first_name": first_name_edit.text, "last_name": last_name_edit.text, "age": int(age_edit.value), "loyalty": int(loyalty_edit.value)})
	host._refresh()
	message_label.text = result.message
	message_label.add_theme_color_override("font_color", MUTED if result.ok else Color("#742d36"))
