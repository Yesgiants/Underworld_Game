extends RefCounted
## Tobacco & Teal: shared semantic colors and reusable stepped pixel controls.

const INK := Color("#30251e")
const MUTED := Color("#78634e")
const PAPER := Color("#e5cfa8")
const LIGHT := Color("#f1dfbf")
const COVER := Color("#372820")
const TEAL := Color("#285b54")
const COPPER := Color("#ab7a50")
const RED := Color("#873b3c")
const FONT = preload("res://game/assets/fonts/Silkscreen-Regular.ttf")
const BODY = preload("res://game/assets/fonts/LiberationMono-Regular.ttf")
static var textures: Dictionary = {}

static func button_box(fill: Color) -> StyleBoxTexture:
	var key := fill.to_html()
	if not textures.has(key):
		var image := Image.create(24, 24, false, Image.FORMAT_RGBA8)
		for y in range(24):
			var edge_distance := mini(y, 23 - y)
			var inset := 8 if edge_distance == 0 else 6 if edge_distance == 1 else 4 if edge_distance < 4 else 2 if edge_distance < 6 else 0
			for x in range(inset, 24 - inset):
				var edge := y in [0, 23] or x == inset or x == 23 - inset
				image.set_pixel(x, y, INK if edge else fill.lightened(0.12) if y < 3 else fill)
		textures[key] = ImageTexture.create_from_image(image)
	var box := StyleBoxTexture.new()
	box.texture = textures[key]
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		box.set_texture_margin(side, 10)
		box.set_content_margin(side, 10 if side in [SIDE_LEFT, SIDE_RIGHT] else 8)
	return box

static func panel(fill: Color = LIGHT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = COPPER
	box.set_border_width_all(2)
	box.set_content_margin_all(10)
	return box

static func accent(button: Button, fill: Color = TEAL) -> void:
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_stylebox_override("normal", button_box(fill))
	button.add_theme_stylebox_override("hover", button_box(fill.lightened(0.08)))
	button.add_theme_stylebox_override("pressed", button_box(fill.darkened(0.15)))
	button.add_theme_color_override("font_color", LIGHT)
	button.add_theme_color_override("font_hover_color", LIGHT)
	button.add_theme_color_override("font_pressed_color", LIGHT)

static func build() -> Theme:
	FONT.set("antialiasing", TextServer.FONT_ANTIALIASING_NONE)
	var theme := Theme.new()
	theme.default_font = BODY
	theme.default_font_size = 12
	for type in ["Label", "RichTextLabel", "LineEdit", "SpinBox", "Tree", "CheckButton", "CheckBox", "PopupMenu", "Window"]:
		theme.set_color("font_color", type, INK)
	theme.set_color("default_color", "RichTextLabel", INK)
	for type in ["Button", "OptionButton"]:
		theme.set_font("font", type, FONT)
		theme.set_font_size("font_size", type, 11)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			theme.set_color(state, type, LIGHT)
		theme.set_color("font_disabled_color", type, MUTED)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var fill := TEAL.darkened(0.15) if state == "pressed" else Color("#c4ae8d") if state == "disabled" else COPPER if state == "focus" else TEAL
			theme.set_stylebox(state, type, button_box(fill))
	theme.set_stylebox("panel", "PanelContainer", panel())
	theme.set_stylebox("normal", "LineEdit", panel(LIGHT))
	theme.set_stylebox("focus", "LineEdit", panel(PAPER))
	theme.set_color("caret_color", "LineEdit", INK)
	theme.set_stylebox("panel", "PopupMenu", panel())
	theme.set_stylebox("hover", "PopupMenu", panel(PAPER))
	theme.set_color("font_hover_color", "PopupMenu", INK)
	theme.set_stylebox("panel", "Tree", panel())
	theme.set_stylebox("selected", "Tree", panel(PAPER))
	theme.set_stylebox("selected_focus", "Tree", panel(PAPER))
	theme.set_color("font_selected_color", "Tree", INK)
	theme.set_stylebox("background", "ProgressBar", panel(Color("#bfaa88")))
	theme.set_stylebox("fill", "ProgressBar", panel(TEAL))
	theme.set_stylebox("embedded_border", "Window", panel())
	theme.set_stylebox("embedded_unfocused_border", "Window", panel())
	theme.set_color("title_color", "Window", INK)
	return theme
