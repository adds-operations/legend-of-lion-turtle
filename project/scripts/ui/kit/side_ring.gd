@tool
extends Node2D

## Ground marker under a fighter: gold ring for you, red for the rival.
## Keeps mirror matches (same element on both sides) readable.

const T = preload("res://scripts/ui/kit/ui_tokens.gd")

@export var color: Color = T.SIDE_YOU:
	set(v): color = v; queue_redraw()
@export var radius: Vector2 = Vector2(22, 9):
	set(v): radius = v; queue_redraw()
## Draw a small forward chevron on the ring toward the aim direction.
var aim: Vector2 = Vector2.RIGHT:
	set(v): aim = v; queue_redraw()

func _draw() -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_polyline(pts, Color(color, 0.85), 2.0, true)
	var inner := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		inner.append(Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(inner, Color(color, 0.12))
	var d := Vector2(aim.x * radius.x, aim.y * radius.y).normalized() if aim != Vector2.ZERO else Vector2.RIGHT
	var tip := Vector2(d.x * (radius.x + 7), d.y * (radius.y + 4))
	var side := Vector2(-d.y, d.x) * 5.0
	draw_colored_polygon(PackedVector2Array([tip, tip - d * 7 + side, tip - d * 7 - side]), color)
