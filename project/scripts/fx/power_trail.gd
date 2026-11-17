extends Node2D

## Soft "motion blur" for anything a bender throws: a tapered gradient ribbon
## following the power's path, drawn in three additive passes (wide haze,
## mid glow, bright core) plus a radial glow at the head.
##
## It lives beside the power (not inside it), so it never rotates with it,
## outlives it for a short fade, and never touches a character sprite.
##
##   var trail := PowerTrail.new()
##   trail.follow(projectile, element_glow_color)
##   projectile.get_parent().add_child(trail)

const Paint = preload("res://scripts/ui/kit/ui_paint.gd")

## Length of the trail in px (the gradient runs over this distance).
@export var length: float = 96.0
## Thickness at the head in px.
@export var width: float = 18.0
@export var color: Color = Color(1, 0.6, 0.2)
## Radius of the halo around the head in px.
@export var halo: float = 26.0
## Seconds the trail takes to fade after its power is gone.
@export var linger: float = 0.18

var _target: Node2D
var _points: PackedVector2Array = PackedVector2Array()
var _released: bool = false
var _fade: float = 1.0

func follow(target: Node2D, glow_color: Color) -> void:
	_target = target
	color = glow_color
	target.tree_exiting.connect(release)

func _ready() -> void:
	top_level = true
	z_index = 2
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat

## Stop following; the tail catches up with the head and fades out.
func release() -> void:
	_released = true

func _process(delta: float) -> void:
	if not _released and is_instance_valid(_target):
		var p := _target.global_position
		if _points.is_empty() or _points[_points.size() - 1].distance_to(p) > 2.0:
			_points.append(p)
	elif not _released:
		_released = true
	if _released:
		_fade -= delta / maxf(linger, 0.01)
		if _fade <= 0.0:
			queue_free()
			return
		if _points.size() > 1:
			_points.remove_at(0)
	_trim()
	queue_redraw()

## Keep only the last `length` px of path.
func _trim() -> void:
	var total := 0.0
	var i := _points.size() - 1
	while i > 0:
		total += _points[i].distance_to(_points[i - 1])
		if total > length:
			break
		i -= 1
	if i > 0:
		_points = _points.slice(i)

func _draw() -> void:
	if _points.size() < 2:
		if _points.size() == 1:
			_halo(_points[0])
		return
	var a := clampf(_fade, 0.0, 1.0)
	_ribbon(width * 1.9, Color(color, 0.16 * a))   # haze (the blur)
	_ribbon(width * 1.0, Color(color, 0.35 * a))   # glow
	_ribbon(width * 0.38, Color(color.lerp(Color.WHITE, 0.65), 0.7 * a))  # hot core
	if not _released:
		_halo(_points[_points.size() - 1])

## A tapered strip whose alpha and width grow from tail (0) to head (1).
func _ribbon(w: float, c: Color) -> void:
	var n := _points.size()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var cols_l := PackedColorArray()
	var cols_r := PackedColorArray()
	for i in n:
		var t := float(i) / (n - 1)
		var p := _points[i] - global_position
		var d: Vector2
		if i < n - 1:
			d = (_points[i + 1] - _points[i]).normalized()
		else:
			d = (_points[i] - _points[i - 1]).normalized()
		var nrm := Vector2(-d.y, d.x) * w * 0.5 * (0.15 + 0.85 * t * t)
		left.append(p + nrm)
		right.append(p - nrm)
		var ct := Color(c, c.a * t * t)
		cols_l.append(ct)
		cols_r.append(ct)
	right.reverse()
	cols_r.reverse()
	left.append_array(right)
	cols_l.append_array(cols_r)
	draw_polygon(left, cols_l)

func _halo(p: Vector2) -> void:
	var r := halo
	draw_texture_rect(Paint.glow(), Rect2(p - global_position - Vector2(r, r), Vector2(r, r) * 2.0), false,
			Color(color, 0.55 * clampf(_fade, 0.0, 1.0)))
