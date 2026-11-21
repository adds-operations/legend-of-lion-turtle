@tool
extends Control

## HUD portrait: the bender's bust at 2× on paper with an element wash,
## framed in the side color.

const T = preload("res://scripts/ui/kit/ui_tokens.gd")
const Emblems = preload("res://scripts/ui/kit/emblems.gd")
const Roster = preload("res://scripts/data/roster.gd")
const Paint = preload("res://scripts/ui/kit/ui_paint.gd")
## Bust crop (head + torso) of a 96×96 frame, drawn at 2× in the tile.
const BUST := Rect2(25, 18, 46, 42)

@export_range(0, 3) var element: int = 0:
	set(v): element = v; queue_redraw()
## Bender to show; falls back to the element emblem when empty or missing.
@export var fighter_id: String = "":
	set(v): fighter_id = v; queue_redraw()
@export var border: Color = T.SIDE_YOU:
	set(v): border = v; queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

func _draw() -> void:
	var r := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	Paint.fill_paper(self, Paint.brush_poly(r, element + 2, 1.5, 12.0), T.PAPER_LIGHT)
	draw_colored_polygon(Paint.brush_poly(r.grow(-6), element + 3, 3.0, 14.0), Color(T.element_wash(element), 0.9))
	var tex := Roster.still(fighter_id)
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		var dst := Rect2(r.get_center() - BUST.size + Vector2(0, 2), BUST.size * 2.0)
		draw_texture_rect_region(at.atlas, dst, Rect2(at.region.position + BUST.position, BUST.size))
	else:
		Emblems.draw(self, Emblems.element_kind(element), r.grow(-r.size.y * 0.2), T.element_color(element))
	var frame_tex := Paint.tex_kit("portrait_frame")
	if frame_tex:
		draw_rect(r.grow(-7), border, false, 2.0)   # your side colour, just inside the frame
		draw_texture_rect(frame_tex, r.grow(4), false)
	else:
		Paint.ink_frame(self, r, border, 3.0, element + 4)
