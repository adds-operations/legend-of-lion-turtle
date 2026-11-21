extends Node2D

## A one-shot (or looping, for a set time) animation from an 8-frame row of
## an attack sheet (128 px cells). Own node, nearest filtering, so it never
## draws on a character.

var sheet: Texture2D
var row: int = 0
var frames: int = 8
var life: float = 0.3
var loop: bool = false
var fps: float = 14.0
var s: float = 0.5
var bottom: bool = false
var flip: bool = false
var fade_out: bool = true
var col: int = -1                # fixed frame (a still that the caller spins), or -1 to animate
var spin: float = 0.0
var _t: float = 0.0

static func make(tex: Texture2D, r: int, at: Vector2, scale_: float, seconds: float, looping: bool = false,
		anchor_bottom: bool = false, rot: float = 0.0) -> Node2D:
	var a = load("res://scripts/fx/anim_fx.gd").new()
	a.sheet = tex
	a.row = r
	a.position = at
	a.s = scale_
	a.life = seconds
	a.loop = looping
	a.bottom = anchor_bottom
	a.rotation = rot
	return a

## From an attack part [texture, row, fixed col] (see BendingFX.anim_spec).
static func part(p: Array, at: Vector2, scale_: float, seconds: float, looping: bool = false,
		anchor_bottom: bool = false, rot: float = 0.0) -> Node2D:
	var a := make(p[0], p[1], at, scale_, seconds, looping, anchor_bottom, rot)
	a.col = p[2]
	return a

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 1

func _process(delta: float) -> void:
	_t += delta
	rotation += spin * delta
	if _t >= life:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	if sheet == null:
		return
	var i := int(_t * fps) % frames if loop else mini(frames - 1, int(_t / life * frames))
	if col >= 0:
		i = col
	var src := Rect2(i * 128, row * 128, 128, 128)
	var sz := Vector2(128, 128) * s
	var off := -sz / 2.0
	if bottom:
		off.y = -sz.y
	var a := 1.0
	if fade_out and _t > life * 0.75:
		a = 1.0 - (_t - life * 0.75) / (life * 0.25)
	if flip:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	draw_texture_rect_region(sheet, Rect2(off, sz), src, Color(1, 1, 1, a))
