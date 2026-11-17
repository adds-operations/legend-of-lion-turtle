extends Node2D

## A one-shot sprite effect from the bending pack: pops in, holds, fades.
## Optionally swaps to a second frame (e.g. active → finish) halfway, and
## can be stretched along a line (beams). Nearest filtering, own node, so it
## never draws on a character.

var tex: Texture2D
var then_tex: Texture2D       # shown for the second half, if set
var life: float = 0.4
var base_scale: Vector2 = Vector2.ONE
var grow: float = 0.15        # extra scale over the life
var anchor_bottom: bool = false
var _t: float = 0.0

static func make(t: Texture2D, at: Vector2, s: float, seconds: float, bottom: bool = false, next: Texture2D = null) -> Node2D:
	var f = load("res://scripts/fx/fx_sprite.gd").new()
	f.tex = t
	f.then_tex = next
	f.base_scale = Vector2(s, s)
	f.life = seconds
	f.anchor_bottom = bottom
	f.position = at
	return f

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 1

func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var k := _t / life
	var t: Texture2D = then_tex if then_tex and k > 0.55 else tex
	if t == null:
		return
	var pop := minf(1.0, _t / 0.06)
	var sc := base_scale * (0.7 + 0.3 * pop + grow * k)
	var sz := t.get_size() * sc
	var off := -sz / 2.0
	if anchor_bottom:
		off.y = -sz.y
	var a := 1.0 if k < 0.6 else 1.0 - (k - 0.6) / 0.4
	draw_texture_rect(t, Rect2(off, sz), false, Color(1, 1, 1, a))
