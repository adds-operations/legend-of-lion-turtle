@tool
extends PanelContainer

## A hanging scroll: the theme's parchment panel plus wooden rods top and
## bottom and red tassels. Call unroll() when it opens.

const T = preload("res://scripts/ui/kit/ui_tokens.gd")
const Paint = preload("res://scripts/ui/kit/ui_paint.gd")

@export var rods: bool = true:
	set(v): rods = v; queue_redraw()
@export var tassels: bool = true:
	set(v): tassels = v; queue_redraw()
## Rods run along the left/right edges instead (horizontal scroll).
@export var horizontal: bool = false:
	set(v): horizontal = v; queue_redraw()

var _sway: float = 0.0
var _t: float = 0.0

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not tassels:
		return
	_t += delta
	_sway = sin(_t * 1.6) * 0.6
	queue_redraw()

func _draw() -> void:
	if not rods:
		return
	var o := float(T.ROD_OVERHANG)
	if horizontal:
		_vrod(-2.0)
		_vrod(size.x + 2.0)
		return
	Paint.rod(self, -o, size.x + o, 2.0)
	Paint.rod(self, -o, size.x + o, size.y - 2.0, T.ROD_H + 2)
	if tassels:
		Paint.tassel(self, Vector2(-o + 2, size.y + 4), 28.0, _sway)
		Paint.tassel(self, Vector2(size.x + o - 2, size.y + 4), 28.0, -_sway)

func _vrod(x: float) -> void:
	var o := float(T.ROD_OVERHANG) * 0.6
	Paint.vrod(self, x, -o, size.y + o)

## Unroll from the top rod down (or from the left rod across).
func unroll() -> void:
	pivot_offset = Vector2.ZERO
	var axis := "scale:x" if horizontal else "scale:y"
	if horizontal:
		scale = Vector2(0.04, 1.0)
	else:
		scale = Vector2(1.0, 0.04)
	modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(self, axis, 1.0, T.T_UNROLL).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
