extends Control

const Pixel = preload("res://game/ui/pixel_theme.gd")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Pixel.COVER)
	draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Pixel.COPPER.darkened(0.3), false, 2)
	for y in range(16, int(size.y) - 10, 18):
		draw_rect(Rect2(5, y, 2, 5), Pixel.COPPER.darkened(0.4))
	for y in range(100, int(size.y) - 150, 48):
		draw_rect(Rect2(1, y, 7, 8), Pixel.INK)
		draw_rect(Rect2(2, y + 1, 5, 6), Pixel.COPPER)
		draw_rect(Rect2(2, y + 1, 4, 2), Pixel.PAPER)
