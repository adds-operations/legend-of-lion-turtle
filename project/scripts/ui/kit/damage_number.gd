extends Node2D

## Floating damage number in the world. Pops, drifts up, fades.
## Color = side of the fighter who dealt the damage (gold if you hit them).

const T = preload("res://scripts/ui/kit/ui_tokens.gd")

var text: String = "10"
var color: Color = T.SIDE_YOU
var _age: float = 0.0
const LIFE := 0.8

func setup(amount: int, col: Color) -> Node2D:
	text = str(amount)
	color = col
	z_index = 50
	return self

func _process(delta: float) -> void:
	_age += delta
	position.y -= 38.0 * delta
	if _age >= LIFE:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var t := _age / LIFE
	var pop := 1.0 + 0.6 * maxf(0.0, 1.0 - t * 6.0)
	var a := 1.0 - maxf(0.0, (t - 0.55) / 0.45)
	var f := T.font("display")
	var fs := int(34 * pop)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := Vector2(-w / 2.0, 0)
	draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(T.INK, a))
	draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(color, a))
