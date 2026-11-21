extends Node2D

## Where an earth power leaves the ground: a crack opens and dust puffs as the
## rock lifts out. Uses assets/avatar_bending/signatures/earth_rise.png when
## installed (row 1 crack, row 3 dust); a drawn crack until then.

const SHEET := "res://assets/avatar_bending/signatures/earth_rise.png"
const LIFE := 0.45

var _t: float = 0.0
var _seed: int = 0
static var _sheet: Texture2D
static var _checked: bool = false

static func crack(parent: Node, at: Vector2) -> void:
	if parent == null:
		return
	var c = load("res://scripts/fx/earth_rise.gd").new()
	c.position = at
	c._seed = int(at.x * 7.0 + at.y * 13.0)
	parent.add_child(c)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -1
	if not _checked:
		_checked = true
		if ResourceLoader.exists(SHEET):
			_sheet = load(SHEET)

func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()

func _frame(row: int, col: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = _sheet
	a.region = Rect2(col * 128, row * 128, 128, 128)
	return a

func _draw() -> void:
	var k := _t / LIFE
	var a := 1.0 if k < 0.6 else 1.0 - (k - 0.6) / 0.4
	if _sheet:
		var col := mini(7, int(k * 8.0))
		draw_texture_rect(_frame(1, col), Rect2(Vector2(-24, -30), Vector2(48, 48)), false, Color(1, 1, 1, a))
		draw_texture_rect(_frame(3, col), Rect2(Vector2(-24, -40), Vector2(48, 48)), false, Color(1, 1, 1, a))
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var ink := Color(0.22, 0.15, 0.1, 0.75 * a)
	for i in 4:
		var ang := rng.randf_range(0, TAU)
		var p := Vector2.ZERO
		var pts := PackedVector2Array([p])
		for j in 3:
			p += Vector2(cos(ang), sin(ang) * 0.45) * rng.randf_range(4, 7)
			ang += rng.randf_range(-0.6, 0.6)
			pts.append(p)
		draw_polyline(pts, ink, 1.5)
	# dust
	for i in 5:
		var ang := TAU * i / 5.0 + 0.3
		var r := 6.0 + k * 16.0
		draw_circle(Vector2(cos(ang) * r, sin(ang) * r * 0.4 - k * 6.0), 3.0 + k * 2.0, Color(0.72, 0.62, 0.48, 0.5 * a))
