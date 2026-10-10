extends RefCounted
## Shared paper, ink, and brass styling for every ledger page and editor.

const INK := Color("#2f261e")
const MUTED := Color("#71634f")
const BRASS := Color("#a37a3c")
const RED := Color("#742d36")
const GREEN := Color("#23483d")
const PAPER := Color("#f2e5ca")
const SERIF = preload("res://game/assets/fonts/LiberationSerif-Regular.ttf")
const HEADING = preload("res://game/assets/fonts/LiberationSerif-Bold.ttf")
const MONO = preload("res://game/assets/fonts/LiberationMono-Regular.ttf")

static func box(fill: Color, border: Color, radius: int = 4, horizontal: int = 12, vertical: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style

static func capsule(fill: Color, border: Color = BRASS) -> StyleBoxFlat:
	var style := box(fill, border, 28, 18, 9)
	style.set_border_width_all(2)
	style.shadow_color = Color(0.15, 0.1, 0.05, 0.18)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 2)
	return style

static func button_colors(button: Button, fill: Color, text: Color = PAPER) -> void:
	button.add_theme_stylebox_override("normal", capsule(fill))
	button.add_theme_stylebox_override("hover", capsule(fill.lightened(0.12), Color("#c59c57")))
	button.add_theme_stylebox_override("pressed", capsule(fill.darkened(0.12)))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, text)

static func build() -> Theme:
	var result := Theme.new()
	result.default_font = SERIF
	result.default_font_size = 16
	for type in ["Label", "RichTextLabel", "CheckButton", "CheckBox", "LineEdit", "SpinBox", "Tree", "PopupMenu", "Window"]:
		result.set_color("font_color", type, INK)
	result.set_color("default_color", "RichTextLabel", INK)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		result.set_color(state, "CheckButton", PAPER)
	result.set_stylebox("panel", "PanelContainer", box(Color("#f2e5caad"), Color("#a38b665f"), 5, 14, 12))
	for type in ["Button", "OptionButton"]:
		result.set_font("font", type, HEADING)
		result.set_color("font_color", type, PAPER)
		result.set_color("font_hover_color", type, PAPER)
		result.set_color("font_pressed_color", type, PAPER)
		result.set_color("font_focus_color", type, PAPER)
		result.set_color("font_disabled_color", type, Color("#8a7c64"))
		result.set_stylebox("normal", type, capsule(GREEN))
		result.set_stylebox("hover", type, capsule(GREEN.lightened(0.12)))
		result.set_stylebox("pressed", type, capsule(GREEN.darkened(0.12)))
		result.set_stylebox("disabled", type, capsule(Color("#d6c8aa"), Color("#b3a284")))
		result.set_stylebox("focus", type, box(Color(0, 0, 0, 0), RED, 28, 0, 0))
	result.set_stylebox("panel", "TooltipPanel", box(PAPER, BRASS, 8, 12, 10))
	result.set_color("font_color", "TooltipLabel", INK)
	result.set_font("font", "TooltipLabel", SERIF)
	result.set_font_size("font_size", "TooltipLabel", 16)
	result.set_stylebox("background", "ProgressBar", box(Color("#cabc9e"), Color("#b3a284"), 6, 0, 0))
	result.set_stylebox("fill", "ProgressBar", box(GREEN, GREEN, 6, 0, 0))
	result.set_stylebox("normal", "LineEdit", box(Color("#fbf1d9"), Color("#b3a284"), 5, 8, 6))
	result.set_stylebox("focus", "LineEdit", box(Color("#fff5df"), RED, 5, 8, 6))
	result.set_color("caret_color", "LineEdit", INK)
	result.set_color("selection_color", "LineEdit", Color("#ccb794"))
	result.set_color("font_selected_color", "LineEdit", INK)
	result.set_stylebox("panel", "Tree", box(Color("#f7ecd6"), Color("#b3a284"), 4, 8, 8))
	result.set_stylebox("selected", "Tree", box(Color("#d9c7a6"), BRASS, 4, 4, 4))
	result.set_stylebox("selected_focus", "Tree", box(Color("#dfceaf"), RED, 4, 4, 4))
	result.set_color("font_selected_color", "Tree", INK)
	result.set_color("title_button_color", "Tree", INK)
	result.set_stylebox("title_button_normal", "Tree", box(Color("#e6d7b9"), Color("#b3a284"), 3, 6, 6))
	result.set_stylebox("title_button_hover", "Tree", box(Color("#dcc8a3"), BRASS, 3, 6, 6))
	result.set_stylebox("panel", "PopupMenu", box(PAPER, BRASS, 6, 10, 8))
	result.set_color("font_hover_color", "PopupMenu", INK)
	result.set_stylebox("hover", "PopupMenu", box(Color("#d9c7a6"), BRASS, 5, 8, 5))
	var window_frame := box(PAPER, BRASS, 8, 16, 12)
	window_frame.content_margin_top = 34
	result.set_stylebox("embedded_border", "Window", window_frame)
	result.set_stylebox("embedded_unfocused_border", "Window", window_frame)
	result.set_color("title_color", "Window", INK)
	result.set_color("title_outline_modulate", "Window", PAPER)
	result.set_font("title_font", "Window", HEADING)
	result.set_font_size("title_font_size", "Window", 18)
	for type in ["HScrollBar", "VScrollBar"]:
		result.set_stylebox("scroll", type, box(Color("#ddcfaf"), Color("#b9a888"), 5, 0, 0))
		result.set_stylebox("grabber", type, box(Color("#9f8354"), BRASS, 5, 0, 0))
		result.set_stylebox("grabber_highlight", type, box(Color("#b89a64"), BRASS, 5, 0, 0))
		result.set_stylebox("grabber_pressed", type, box(GREEN, BRASS, 5, 0, 0))
	return result
