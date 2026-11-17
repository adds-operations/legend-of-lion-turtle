extends Node2D

## The Avatar's accent on the character (spec §12: "clearly show the active
## element on the HUD and character"). Its own node, drawn *behind* the
## sprite, so the character art itself is never tinted or covered:
##   - a Raava-blue spirit ring and glow at the feet (who is the Avatar),
##   - the four elements circling as motes, the active one large and bright
##     (which element they bend right now). Switching flashes the ring.

const T = preload("res://scripts/ui/kit/ui_tokens.gd")
const Paint = preload("res://scripts/ui/kit/ui_paint.gd")
const SPIRIT := Color(0.72, 0.9, 1.0)

var element: int = 0:
	set(v):
		element = v
		_flash = 1.0
var _t: float = 0.0
var _flash: float = 1.0
var _glow_layer: Node2D

func _ready() -> void:
	_glow_layer = Node2D.new()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow_layer.material = m
	_glow_layer.show_behind_parent = true
	_glow_layer.draw.connect(_draw_glow)
	add_child(_glow_layer)

func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 2.0)
	queue_redraw()
	_glow_layer.queue_redraw()

func _jump_y() -> float:
	var body: Node2D = get_parent().get_node_or_null("Body")
	return body.position.y if body else 0.0

func _draw() -> void:
	# spirit ring on the ground (stays on the ground during jumps, like the shadow)
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.38))
	var r := 30.0 + 6.0 * _flash + 1.5 * sin(_t * 5.0)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(SPIRIT, 0.75), 3.0, true)
	draw_arc(Vector2.ZERO, r + 6.0, _t * 2.0, _t * 2.0 + PI * 0.6, 16, Color(T.element_glow(element), 0.9), 3.0, true)
	draw_arc(Vector2.ZERO, r + 6.0, _t * 2.0 + PI, _t * 2.0 + PI * 1.6, 16, Color(T.element_glow(element), 0.9), 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_glow() -> void:
	var gl := Paint.glow()
	var col: Color = T.element_glow(element)
	var y := _jump_y()
	_glow_layer.draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.42))
	var r := 44.0 + 12.0 * _flash
	_glow_layer.draw_texture_rect(gl, Rect2(Vector2(-r, -r), Vector2(r, r) * 2.0), false, Color(SPIRIT, 0.5 + 0.4 * _flash))
	_glow_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# halo behind the body
	_glow_layer.draw_texture_rect(gl, Rect2(Vector2(-36, -84 + y), Vector2(72, 84)), false, Color(SPIRIT, 0.22 + 0.35 * _flash))
	# the four elements circling at waist height
	for i in 4:
		var a := _t * 1.6 + i * TAU / 4.0
		var p := Vector2(cos(a) * 28.0, -32.0 + y + sin(a) * 10.0)
		var active := i == element
		var mr := 12.0 if active else 6.0
		_glow_layer.draw_texture_rect(gl, Rect2(p - Vector2(mr, mr), Vector2(mr, mr) * 2.0), false,
				Color(T.element_glow(i), 1.0 if active else 0.55))
	_glow_layer.draw_texture_rect(gl, Rect2(Vector2(-r, -r * 0.5), Vector2(r * 2.0, r)), false, Color(col, 0.35 + 0.4 * _flash))
