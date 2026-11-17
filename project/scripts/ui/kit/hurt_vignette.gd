extends Control

## Red screen-edge flash when the local fighter takes damage.

const T = preload("res://scripts/ui/kit/ui_tokens.gd")

var _a: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func pulse(strength: float = 1.0) -> void:
	_a = clampf(maxf(_a, 0.55 * strength), 0.0, 0.8)
	queue_redraw()

func _process(delta: float) -> void:
	if _a > 0.0:
		_a = maxf(0.0, _a - delta * 1.8)
		queue_redraw()

func _draw() -> void:
	if _a <= 0.0:
		return
	var w := size.x
	var h := size.y
	var e := minf(w, h) * 0.18
	var c := Color(T.DANGER, _a)
	var z := Color(T.DANGER, 0.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w - e, e), Vector2(e, e)]), PackedColorArray([c, c, z, z]))
	draw_polygon(PackedVector2Array([Vector2(0, h), Vector2(e, h - e), Vector2(w - e, h - e), Vector2(w, h)]), PackedColorArray([c, z, z, c]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(e, e), Vector2(e, h - e), Vector2(0, h)]), PackedColorArray([c, z, z, c]))
	draw_polygon(PackedVector2Array([Vector2(w, 0), Vector2(w, h), Vector2(w - e, h - e), Vector2(w - e, e)]), PackedColorArray([c, c, z, z]))
