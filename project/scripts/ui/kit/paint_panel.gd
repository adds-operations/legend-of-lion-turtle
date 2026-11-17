@tool
extends Control

## A painted surface: parchment, a brush stroke, or an ink wash, with
## brushed edges. Use behind content, as a header stroke, or as a color chip.

const T = preload("res://scripts/ui/kit/ui_tokens.gd")
const Paint = preload("res://scripts/ui/kit/ui_paint.gd")

enum Style { PAPER, STROKE, WASH, SOLID }

@export var style: Style = Style.PAPER:
	set(v): style = v; queue_redraw()
@export var color: Color = T.PAPER:
	set(v): color = v; queue_redraw()
@export var frame: bool = false:
	set(v): frame = v; queue_redraw()
@export var seed: int = 1:
	set(v): seed = v; queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	match style:
		Style.PAPER:
			Paint.paper_sheet(self, r, seed, color)
		Style.STROKE:
			Paint.stroke(self, r, color, seed % 2 == 0)
		Style.WASH:
			Paint.wash(self, r.grow_individual(14, 8, 14, 8), color, seed % 2 == 0)
		Style.SOLID:
			draw_colored_polygon(Paint.brush_poly(r, seed, 1.0, 12.0), color)
	if frame:
		Paint.ink_frame(self, r, T.INK, T.BORDER_INK, seed + 3)
