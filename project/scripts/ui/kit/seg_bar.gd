@tool
extends Control

## Segmented health bar in an ink well, with a pale "recent damage" trail.
## Ticks every `segment` HP make chunks readable at a glance.

const T = preload("res://scripts/ui/kit/ui_tokens.gd")
const Paint = preload("res://scripts/ui/kit/ui_paint.gd")

@export var max_value: float = 300.0:
	set(v): max_value = maxf(v, 1.0); queue_redraw()
@export var value: float = 300.0:
	set(v): _set_value(v)
	get: return _value
@export var segment: float = 50.0:
	set(v): segment = v; queue_redraw()
@export var fill: Color = T.SIDE_YOU:
	set(v): fill = v; queue_redraw()
## Fill from the right edge (for the rival's bar so both drain toward the center).
@export var reverse: bool = false:
	set(v): reverse = v; queue_redraw()
@export var skew: float = T.SKEW:
	set(v): skew = v; queue_redraw()

var _value: float = 300.0
var _lag: float = 300.0
var _lag_tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lag = value

func _set_value(v: float) -> void:
	var old := _value
	_value = clampf(v, 0.0, max_value)
	if is_equal_approx(old, _value):
		return
	if not is_inside_tree() or Engine.is_editor_hint():
		_lag = value
	elif value < old:
		if _lag_tween:
			_lag_tween.kill()
		_lag = maxf(_lag, old)
		_lag_tween = create_tween()
		_lag_tween.tween_interval(0.35)
		_lag_tween.tween_method(func(x): _lag = x; queue_redraw(), _lag, value, 0.4).set_ease(Tween.EASE_OUT)
	else:
		_lag = value
	queue_redraw()

func _part(frac: float) -> Rect2:
	var w := size.x * clampf(frac, 0.0, 1.0)
	return Rect2(Vector2(size.x - w, 0) if reverse else Vector2.ZERO, Vector2(w, size.y))

func _draw() -> void:
	var full := Rect2(Vector2.ZERO, size)
	# ink well
	draw_colored_polygon(Paint.brush_poly(full.grow(2), 4, 1.2, 12.0), T.INK)
	draw_rect(full, Color(T.WOOD_DARK, 0.9))
	if _lag > value:
		draw_rect(_part(_lag / max_value), T.HP_LAG)
	if value > 0.0:
		var c := fill
		if value / max_value <= 0.25 and not Engine.is_editor_hint():
			c = c.lerp(T.DANGER, 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0))
		var r := _part(value / max_value)
		draw_rect(r, c)
		# painted highlight + a darker lower lip, like a brush pass
		draw_rect(Rect2(r.position, Vector2(r.size.x, size.y * 0.3)), Color(1, 1, 1, 0.22))
		draw_rect(Rect2(r.position + Vector2(0, size.y * 0.78), Vector2(r.size.x, size.y * 0.22)), Color(0, 0, 0, 0.14))
	# segment ticks
	if segment > 0.0:
		var n := int(max_value / segment)
		for i in range(1, n):
			var x := size.x * (i * segment / max_value)
			draw_line(Vector2(x, 1), Vector2(x, size.y - 1), Color(T.INK, 0.85), 2.0, true)

func _process(_d: float) -> void:
	if value / max_value <= 0.25 and value > 0.0:
		queue_redraw()
