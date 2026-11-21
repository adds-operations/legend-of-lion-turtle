extends Node2D

## Your aim, on the ground under your feet: a ring (seen in 3/4, so an
## ellipse) with a brush arrow on its edge pointing exactly where your powers
## will fly, and a short dashed guide along that line. It turns vermilion and
## brackets the rival when the aim assist would lock onto them. Holding SHIFT
## (fine aim) lengthens the guide.
##
## Its own node, drawn under the bender: it never draws on the sprite.

const T = preload("res://scripts/ui/kit/ui_tokens.gd")

const RX := 30.0
const RY := 12.5
const KIT := "res://assets/ui/kit/"

var f
var color: Color = T.SIDE_YOU
var _t: float = 0.0
var _ring_tex: Texture2D
var _ring_lock_tex: Texture2D
var _arrow_tex: Texture2D

func _ready() -> void:
	f = get_parent()
	position = Vector2(0, 4)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for pair in [["aim_ring", "_ring_tex"], ["aim_ring_lock", "_ring_lock_tex"], ["aim_arrow", "_arrow_tex"]]:
		var p: String = KIT + pair[0] + ".png"
		if ResourceLoader.exists(p):
			set(pair[1], load(p))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

## Where the aim direction meets the ellipse.
func _edge(d: Vector2) -> Vector2:
	var k := 1.0 / sqrt(pow(d.x / RX, 2) + pow(d.y / RY, 2)) if d != Vector2.ZERO else RX
	return d * k

func _draw() -> void:
	if f == null or f.is_defeated:
		return
	var d: Vector2 = f.aim_direction.normalized() if f.aim_direction != Vector2.ZERO else Vector2.RIGHT
	var locked: bool = f.lock_target != null and is_instance_valid(f.lock_target)
	var col: Color = T.VERMILION if locked else color
	var fine: bool = f.fine_aiming
	# ring
	if (locked and _ring_lock_tex) or (not locked and _ring_tex):
		var tex: Texture2D = _ring_lock_tex if locked else _ring_tex
		var sz := Vector2(RX * 2.0 + 14.0, RY * 2.0 + 6.0)
		draw_texture_rect(tex, Rect2(-sz / 2.0, sz), false)
	else:
		var pts := PackedVector2Array()
		for i in 49:
			var a := TAU * i / 48.0
			pts.append(Vector2(cos(a) * RX, sin(a) * RY))
		draw_colored_polygon(pts, Color(col, 0.10))
		draw_polyline(pts, Color(T.INK, 0.45), 3.5, true)
		draw_polyline(pts, Color(col, 0.95), 2.0, true)
		# eight compass ticks
		for i in 8:
			var a := TAU * i / 8.0
			var p0 := Vector2(cos(a) * RX, sin(a) * RY)
			draw_line(p0 * 0.84, p0, Color(col, 0.7), 1.5, true)
	# the arc of the ring facing your aim is lit (it stays visible beside your
	# legs even when you aim up, behind yourself)
	var aa := atan2(d.y * RX, d.x * RY)
	var lit := PackedVector2Array()
	for i in 13:
		var a := aa - 0.55 + 1.1 * i / 12.0
		lit.append(Vector2(cos(a) * RX, sin(a) * RY))
	draw_polyline(lit, Color(T.INK, 0.6), 6.0, true)
	draw_polyline(lit, col.lightened(0.25), 3.5, true)
	_pointer(self)
	# lock bracket under the rival
	if locked:
		var c := to_local(f.lock_target.global_position) + Vector2(0, 0)
		var pulse := 1.0 + 0.08 * sin(_t * 10.0)
		var rx := 22.0 * pulse
		var ry := 9.0 * pulse
		for q in 4:
			var a0 := TAU * q / 4.0 + PI / 4.0
			var arc := PackedVector2Array()
			for i in 7:
				var a := a0 - 0.35 + 0.7 * i / 6.0
				arc.append(c + Vector2(cos(a) * rx, sin(a) * ry))
			draw_polyline(arc, T.VERMILION, 2.0, true)

## The guide and arrow, on the ground (under the bender, never over them).
func _pointer(ci: CanvasItem) -> void:
	if f == null or f.is_defeated:
		return
	var d: Vector2 = f.aim_direction.normalized() if f.aim_direction != Vector2.ZERO else Vector2.RIGHT
	var locked: bool = f.lock_target != null and is_instance_valid(f.lock_target)
	var col: Color = T.VERMILION if locked else color
	var fine: bool = f.fine_aiming
	# dashed guide along the true travel direction
	var e := _edge(d)
	var guide := 150.0 if fine else (110.0 if d.y < -0.5 else 70.0)   # up the screen: long enough to clear the bender
	var dash := 9.0
	var x := 8.0
	while x < guide:
		var a0 := e + d * x
		var a1 := e + d * minf(x + dash * 0.6, guide)
		var fade := 1.0 - x / guide
		ci.draw_line(a0, a1, Color(T.INK, 0.35 * fade), 4.0, true)
		ci.draw_line(a0, a1, Color(col, 0.75 * fade + 0.2), 2.5, true)
		x += dash
	# the arrow on the ring edge
	# aiming up the screen the ring edge is behind your legs: the arrow rides the
	# end of the guide instead, above your head
	var tip := e + d * (guide + 14.0 if d.y < -0.5 else 20.0)
	if _arrow_tex:
		tip = e + d * (guide + 8.0 if d.y < -0.5 else 14.0)
	if _arrow_tex:
		ci.draw_set_transform(tip, d.angle(), Vector2.ONE)
		ci.draw_texture_rect(_arrow_tex, Rect2(Vector2(-12, -12), Vector2(24, 24)), false, Color(1.0, 0.45, 0.38) if locked else Color.WHITE)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		# a brush chevron: ink outline, side colour inside
		var side := d.orthogonal() * 10.0
		var back := tip - d * 17.0
		var poly := PackedVector2Array([tip + d * 2.0, back + side * 1.15 - d * 1.5, back + d * 6.0, back - side * 1.15 - d * 1.5])
		ci.draw_colored_polygon(poly, Color(T.INK, 0.85))
		var inner := PackedVector2Array([tip - d * 1.0, back + side * 0.8 + d * 1.0, back + d * 7.5, back - side * 0.8 + d * 1.0])
		ci.draw_colored_polygon(inner, col)
