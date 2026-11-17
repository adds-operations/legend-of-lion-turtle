extends Node2D

## A short soft burst of light: where a power leaves the bender's hands
## (cast) and where it lands (impact). Additive, blurred by a radial
## gradient, with a thin expanding ring. Drawn on its own layer — the bender
## sprite is never touched.

const Paint = preload("res://scripts/ui/kit/ui_paint.gd")

var color: Color = Color(1, 0.6, 0.2)
var radius: float = 34.0
var duration: float = 0.26
var ring: bool = true
var _age: float = 0.0

func setup(at: Vector2, glow_color: Color, r: float = 34.0, d: float = 0.26, with_ring: bool = true) -> Node2D:
	global_position = at
	color = glow_color
	radius = r
	duration = d
	ring = with_ring
	return self

func _ready() -> void:
	z_index = 3
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat

func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := _age / duration
	var ease_out := 1.0 - pow(1.0 - t, 3.0)
	var r := radius * (0.55 + 0.75 * ease_out)
	var a := 1.0 - t
	draw_texture_rect(Paint.glow(), Rect2(Vector2(-r, -r), Vector2(r, r) * 2.0), false, Color(color, 0.8 * a))
	draw_texture_rect(Paint.glow(), Rect2(Vector2(-r, -r) * 0.45, Vector2(r, r) * 0.9), false,
			Color(color.lerp(Color.WHITE, 0.7), 0.7 * a))
	if ring:
		draw_arc(Vector2.ZERO, r * 0.9, 0.0, TAU, 40, Color(color, 0.45 * a), 2.5 * (1.0 - t) + 0.5, true)
