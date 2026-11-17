@tool
extends Control

## Screen backdrop in the Scroll & Ink language — a painted golden-hour
## landscape: a dry-brushed sky, a pale sun ringed by brushed halos, karst
## mountains in ink wash fading into mist, a glittering river, an ink grass
## ridge, bamboo poles flying torn red banners, and leaves on the wind.
## The painted layers are textures from res://assets/ui/paint/
## (tools/paint/gen_textures.py); motion is drawn here.

const T = preload("res://scripts/ui/kit/ui_tokens.gd")
const Paint = preload("res://scripts/ui/kit/ui_paint.gd")

const SUN_TEX_DISC := 150.0   # disc radius inside sun.png (1024²)

## Sun position as a fraction of the screen.
@export var sun_center: Vector2 = Vector2(0.72, 0.42):
	set(v): sun_center = v; queue_redraw()
## Radius of the sun disc in pixels (the halo rings reach ~3.3× this).
@export var sun_radius: float = 150.0:
	set(v): sun_radius = v; queue_redraw()
## Red banners on bamboo poles: one Vector4 per pole —
## (x as fraction of width, banner height as fraction of height, scale, blow direction ±1).
## The pole runs from the banner down to the bottom edge.
@export var banners: Array[Vector4] = [Vector4(0.06, 0.18, 1.0, 1), Vector4(0.94, 0.16, 1.0, -1)]:
	set(v): banners = v; queue_redraw()
## Mountains, river and the ink ridge. Off = sky, sun, banners and leaves only.
@export var show_horizon: bool = true:
	set(v): show_horizon = v; queue_redraw()
## Where the river meets the mountains, as a fraction of the height.
@export_range(0.4, 1.0) var horizon_y: float = 0.74:
	set(v): horizon_y = v; queue_redraw()
@export_range(0, 60) var leaf_count: int = 22:
	set(v): leaf_count = v; _seed_leaves(); queue_redraw()
## Darken toward the top edge (dusk) — 0 for the plain golden look.
@export_range(0.0, 1.0) var dusk: float = 0.0:
	set(v): dusk = v; queue_redraw()

var _t: float = 0.0
var _leaves: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_seed_leaves()

func _seed_leaves() -> void:
	_leaves.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in leaf_count:
		_leaves.append({
			"x": rng.randf(), "y": rng.randf(),
			"s": rng.randf_range(5.0, 13.0),
			"v": rng.randf_range(0.04, 0.1),
			"spin": rng.randf_range(-2.0, 2.0),
			"ph": rng.randf() * TAU,
			"d": rng.randf(),   # depth: far leaves are smaller and paler
		})

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	# --- painted sky (cover the screen, keep the aspect) ------------------
	var sky := Paint.tex("sky")
	var k := maxf(w / sky.get_width(), h / sky.get_height())
	var ssz := sky.get_size() * k
	draw_texture_rect(sky, Rect2((size - ssz) / 2.0, ssz), false)
	if dusk > 0.0:
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.7), Vector2(0, h * 0.7)]),
				PackedColorArray([Color(T.INK, dusk * 0.55), Color(T.INK, dusk * 0.55), Color(T.INK, 0), Color(T.INK, 0)]))

	# --- sun: disc, glow and brushed halo rings (turning very slowly) -----
	var sc := Vector2(w * sun_center.x, h * sun_center.y)
	var sun := Paint.tex("sun")
	var sk := sun_radius / SUN_TEX_DISC
	var half := sun.get_size() * sk * 0.5
	draw_texture_rect(Paint.glow(), Rect2(sc - half * 1.4, half * 2.8), false, Color(T.HAZE, 0.35))
	draw_set_transform(sc, _t * 0.015, Vector2.ONE)
	draw_texture_rect(sun, Rect2(-half, half * 2.0), false, Color(1, 0.99, 0.95, 0.95))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if show_horizon:
		_landscape(w, h, sc)

	# --- bamboo poles with torn red banners -------------------------------
	for i in banners.size():
		var b: Vector4 = banners[i]
		_banner_pole(Vector2(w * b.x, h), h * (1.0 - b.y), b.z, i, b.w)

	# --- leaves on the wind ----------------------------------------------
	for l in _leaves:
		var lx := fposmod(l["x"] * w + _t * l["v"] * w * 0.9, w + 40.0) - 20.0
		var ly := fposmod(l["y"] * h + sin(_t * 0.7 + l["ph"]) * 26.0 + _t * l["v"] * 60.0, h)
		_leaf(Vector2(lx, ly), l["s"] * (0.55 + 0.45 * l["d"]), _t * l["spin"] + l["ph"], 0.45 + 0.4 * l["d"])

func _landscape(w: float, h: float, sc: Vector2) -> void:
	var hy := h * horizon_y
	# far karst towers, pale with distance, drifting a touch
	var far := Paint.tex("mountains_far")
	var fh := w * far.get_height() / far.get_width()
	var drift := sin(_t * 0.05) * 6.0
	draw_texture_rect(far, Rect2(Vector2(-10 + drift, hy - fh * 0.92), Vector2(w + 20, fh)), false, Color("e8a95a", 0.55))
	# mist between the ranges
	draw_texture_rect(Paint.glow(), Rect2(Vector2(-w * 0.2, hy - h * 0.16), Vector2(w * 1.4, h * 0.22)), false, Color(T.HAZE, 0.45))
	var near := Paint.tex("mountains_near")
	var nh := w * near.get_height() / near.get_width()
	draw_texture_rect(near, Rect2(Vector2(-10 - drift * 0.6, hy - nh * 0.88), Vector2(w + 20, nh)), false, Color("8f5426", 0.62))
	draw_texture_rect(Paint.glow(), Rect2(Vector2(-w * 0.2, hy - h * 0.06), Vector2(w * 1.4, h * 0.12)), false, Color(T.HAZE, 0.5))

	# river: gold water, the sun's reflection column, twinkling glitter
	var water_r := Rect2(Vector2(0, hy), Vector2(w, h - hy))
	draw_texture_rect(Paint.tex("water"), water_r, false)
	var col_w := sun_radius * 1.9
	draw_texture_rect(Paint.glow(), Rect2(Vector2(sc.x - col_w / 2.0, hy - 10), Vector2(col_w, (h - hy) * 1.6)), false, Color(T.SUN, 0.55))
	var tw := 0.5 + 0.5 * sin(_t * 2.3)
	draw_texture_rect(Paint.tex("sparkle_a"), water_r, false, Color(1, 1, 0.94, 0.35 + 0.65 * tw))
	draw_texture_rect(Paint.tex("sparkle_b"), water_r, false, Color(1, 1, 0.94, 0.35 + 0.65 * (1.0 - tw)))
	draw_rect(Rect2(0, hy - 1, w, 2), Color(T.SUN, 0.5))

	# ink grass ridge along the bottom
	var g := Paint.tex("ground")
	var gh := maxf(h * 0.2, w * g.get_height() / g.get_width())
	var gy := h - 84.0 - gh * 0.45   # the ridge line sits ~84 px above the bottom: room for key hints
	draw_texture_rect(g, Rect2(Vector2(0, gy), Vector2(w, gh)), false, T.INK)
	if gy + gh < h:
		draw_rect(Rect2(0, gy + gh - 1, w, h - gy - gh + 1), T.INK)

func _banner_pole(foot: Vector2, height: float, scale_k: float, seed: int, dir: float) -> void:
	var top := foot + Vector2(0, -height)
	var pole_w := 9.0 * scale_k
	var bam := Paint.tex("bamboo")
	var src_h := (height + 6) * bam.get_width() / pole_w   # repeat vertically at the pole's scale
	draw_texture_rect_region(bam, Rect2(Vector2(top.x - pole_w * 0.5, top.y - 6), Vector2(pole_w, height + 6)),
			Rect2(0, 0, bam.get_width(), src_h), Color("4b3a27"))
	dir = 1.0 if dir >= 0.0 else -1.0
	# two torn strips per pole, the long one on top
	_ribbon(top + Vector2(0, 14 * scale_k), 300.0 * scale_k, 46.0 * scale_k, dir, seed * 3.1, 1.0)
	_ribbon(top + Vector2(0, 44 * scale_k), 190.0 * scale_k, 26.0 * scale_k, dir, seed * 3.1 + 1.7, 0.82)

## A torn cloth strip streaming in the wind, textured with ribbon.png.
func _ribbon(root: Vector2, length: float, width: float, dir: float, ph: float, shade: float) -> void:
	var n := 24
	var top_e := PackedVector2Array()
	var bot_e := PackedVector2Array()
	var uv_t := PackedVector2Array()
	var uv_b := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		var x := root.x + dir * t * length
		var wave := sin(t * 4.2 - _t * 2.6 + ph) * (2.0 + 18.0 * t) + sin(t * 9.0 - _t * 4.4 + ph) * 3.0 * t
		var y := root.y + wave + t * t * 30.0 - t * 12.0
		var hw := width * 0.5
		top_e.append(Vector2(x, y - hw))
		bot_e.append(Vector2(x, y + hw))
		uv_t.append(Vector2(t, 0))
		uv_b.append(Vector2(t, 1))
	# render as quads so folds that overlap never break the triangulation
	var tex := Paint.tex("ribbon")
	var c := Color(T.RIBBON.r * shade, T.RIBBON.g * shade, T.RIBBON.b * shade)
	for i in n:
		draw_primitive(PackedVector2Array([top_e[i], top_e[i + 1], bot_e[i + 1], bot_e[i]]),
				PackedColorArray([c, c, c, c]),
				PackedVector2Array([uv_t[i], uv_t[i + 1], uv_b[i + 1], uv_b[i]]), tex)

func _leaf(at: Vector2, s: float, rot: float, alpha: float) -> void:
	var d := Vector2(cos(rot), sin(rot))
	var nrm := Vector2(-d.y, d.x)
	draw_colored_polygon(PackedVector2Array([at - d * s, at + nrm * s * 0.34 - d * s * 0.2, at + d * s, at - nrm * s * 0.3 + d * s * 0.1]),
			Color(T.INK, alpha))
