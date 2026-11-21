extends Node2D

## Water benders bend from water they hold: a ribbon of water orbits them.
## Each water power uses some; when it runs out (or after it has been held a
## while) they pull more out of the nearest water body — a river or pool in
## the arena — or out of the ground, and hold it again.
##
## Purely visual and on every peer: it never delays or blocks an attack.
## Uses assets/avatar_bending/signatures/water_draw.png when installed
## (row 0 draw, 1 orbit, 2 shrink, 3 stream); a drawn ribbon until then.

const SHEET := "res://assets/avatar_bending/signatures/water_draw.png"
const CHARGES := 5
const HOLD_TIME := 9.0       # seconds held before it is drawn fresh
const DRAW_TIME := 0.35
const SOURCE_REACH := 360.0

var f
var charges: int = CHARGES
var _held: float = 0.0
var _draw_t: float = -1.0
var _source: Vector2         # world point the water is pulled from
var _t: float = 0.0
var _sheet: Texture2D

func _ready() -> void:
	f = get_parent()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(SHEET):
		_sheet = load(SHEET)

func _shown() -> bool:
	return f != null and not f.is_defeated and (f.active_element == 1 or f.is_avatar)

func refill_now() -> void:
	charges = CHARGES
	_held = 0.0
	_draw_t = -1.0

func use() -> void:
	charges -= 1
	if charges <= 0:
		_start_draw()

func _start_draw() -> void:
	_draw_t = 0.0
	_source = _nearest_source()

func _nearest_source() -> Vector2:
	var me: Vector2 = f.global_position
	var arena = get_tree().current_scene
	var best := me + Vector2(f.aim_direction.x * 28.0, 10.0)   # from the ground at the feet
	var best_d := SOURCE_REACH
	if arena and arena.get("layout") and arena.layout.has_method("source_points"):
		for p in arena.layout.source_points(&"water"):
			var d := me.distance_to(p)
			if d < best_d:
				best_d = d
				best = p
	return best

func _process(delta: float) -> void:
	_t += delta
	if not _shown():
		visible = false
		return
	visible = true
	if _draw_t >= 0.0:
		_draw_t += delta
		if _draw_t >= DRAW_TIME:
			_draw_t = -1.0
			charges = CHARGES
			_held = 0.0
	else:
		_held += delta
		if _held >= HOLD_TIME:
			_start_draw()
	queue_redraw()

func _frame(row: int, col: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = _sheet
	a.region = Rect2(col * 128, row * 128, 128, 128)
	return a

func _draw() -> void:
	var lift: float = f.body.position.y if f.body else 0.0
	var centre := Vector2(0, -30 + lift)
	if _draw_t >= 0.0:
		var k := _draw_t / DRAW_TIME
		var src := to_local(_source)
		var tip := src.lerp(centre, minf(1.0, k * 1.4))
		if _sheet:
			var tex := _frame(3, int(_t * 14.0) % 8)
			var seg := src.distance_to(tip)
			var d := (tip - src).normalized()
			var step := 32.0
			var x := 0.0
			while x < seg:
				draw_set_transform(src + d * (x + step * 0.5), d.angle(), Vector2.ONE)
				draw_texture_rect(tex, Rect2(Vector2(-16, -16), Vector2(32, 32)), false)
				x += step
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var up := _frame(0, mini(7, int(k * 8.0)))
			draw_texture_rect(up, Rect2(src - Vector2(24, 44), Vector2(48, 48)), false)
		else:
			# a wobbling stream pulled up and across to the bender
			var pts := PackedVector2Array()
			for i in 13:
				var s := float(i) / 12.0
				var p := src.lerp(tip, s)
				p += Vector2(0, -sin(s * PI) * 26.0) + Vector2(0, sin(_t * 18.0 + s * 9.0) * 3.0)
				pts.append(p)
			draw_polyline(pts, Color(0.35, 0.7, 1.0, 0.85), 5.0, true)
			draw_polyline(pts, Color(0.85, 0.95, 1.0, 0.8), 2.0, true)
			draw_circle(src, 7.0 * (1.0 - k), Color(0.4, 0.75, 1.0, 0.7))
		return
	if charges <= 0:
		return
	var fill := float(charges) / CHARGES
	if _sheet:
		var tex := _frame(1, int(_t * 10.0) % 8)
		var s := 0.42 * (0.6 + 0.4 * fill)
		var sz := tex.get_size() * s
		draw_texture_rect(tex, Rect2(centre - sz / 2.0, sz), false, Color(1, 1, 1, 0.9))
		return
	# a ribbon of water beads orbiting the waist
	var n := 4 + charges * 2
	for i in n:
		var ang := _t * 3.2 + TAU * i / float(n)
		var p := centre + Vector2(cos(ang) * 22.0, sin(ang) * 7.0)
		var behind := sin(ang) < 0.0
		draw_circle(p, 2.2 + fill * 1.2, Color(0.4, 0.75, 1.0, 0.45 if behind else 0.9))
