extends Node2D

## The status a signature left on a fighter (shocked, burning, frozen...),
## drawn on its own node around the bender — never on the character sprite.
## Uses the signature sheet's STATUS row (row 3) when the art pack is in;
## until then a small drawn effect per status. A short tag above the head
## names it.

const Specials = preload("res://scripts/data/specials.gd")
const T = preload("res://scripts/ui/kit/ui_tokens.gd")

var kind: String = ""
var src_id: String = ""
var left: float = 0.0
var _t: float = 0.0
var f

func _ready() -> void:
	f = get_parent()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 1

func show_status(k: String, seconds: float, sig_id: String) -> void:
	kind = k
	src_id = sig_id
	left = seconds
	_t = 0.0
	queue_redraw()

func clear() -> void:
	kind = ""
	left = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if kind == "":
		return
	_t += delta
	left -= delta
	if left <= 0.0:
		kind = ""
	queue_redraw()

func _draw() -> void:
	if kind == "":
		return
	var lift: float = f.body.position.y if f and f.body else 0.0
	var a := clampf(left / 0.25, 0.0, 1.0)
	if Specials.has_sheet(src_id):
		var tex := Specials.frame(src_id, 3, int(_t * 12.0) % 8)
		var sz := tex.get_size() * 0.75
		# the status rows sit at the bottom of their cell (at the feet)
		draw_texture_rect(tex, Rect2(Vector2(-sz.x / 2.0, -sz.y + 8 + lift), sz), false, Color(1, 1, 1, a))
	else:
		_draw_fallback(lift, a)
	# tag above the head
	var name_s: String = Specials.STATUS_NAMES.get(kind, kind.to_upper())
	var font := T.font("label")
	var w := font.get_string_size(name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var y := -100.0 + lift
	var icon: Texture2D = _icon()
	var iw := 18.0 if icon else 0.0
	var box := Rect2(Vector2(-(w + iw) / 2.0 - 6, y - 12), Vector2(w + iw + 12, 17))
	draw_rect(box, Color(T.INK, 0.8 * a))
	draw_rect(box, Color(_color(), 0.6 * a), false, 1.0)
	if icon:
		draw_texture_rect(icon, Rect2(Vector2(box.position.x + 2, y - 13), Vector2(19, 19)), false, Color(1, 1, 1, a))
	draw_string(font, Vector2(box.position.x + 6 + iw, y), name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(_color(), a))

const ICONS := {"stun": "status_stunned", "shock": "status_shocked", "lift": "status_swept_up", "freeze": "status_frozen",
	"bury": "status_buried", "soak": "status_soaked", "wind": "status_winded", "burn": "status_burning"}

static var _icons: Dictionary = {}

## Cached: a texture loaded inside _draw and dropped would be freed before it renders.
func _icon() -> Texture2D:
	if not _icons.has(kind):
		var p := "res://assets/ui/kit/%s.png" % ICONS.get(kind, "")
		_icons[kind] = load(p) if ResourceLoader.exists(p) else null
	return _icons[kind]

func _color() -> Color:
	match kind:
		"stun", "shock":
			return Color("fff2a8")
		"burn":
			return Color("ffb04a")
		"freeze":
			return Color("bfe9ff")
		"soak":
			return Color("8fd0ff")
		"bury":
			return Color("e2c48a")
		"wind", "lift":
			return Color("e8f4f4")
	return Color.WHITE

func _draw_fallback(lift: float, a: float) -> void:
	var c := _color()
	match kind:
		"stun", "shock":
			for i in 3:
				var ang := _t * 5.0 + TAU * i / 3.0
				var p := Vector2(cos(ang) * 16.0, -74.0 + lift + sin(ang) * 5.0)
				_star(p, 4.0, Color(c, a))
			if kind == "shock":
				for i in 3:
					var x := randf_range(-14, 14)
					var y := randf_range(-60, -10) + lift
					draw_polyline(PackedVector2Array([Vector2(x, y), Vector2(x + 5, y + 6), Vector2(x - 2, y + 10), Vector2(x + 4, y + 16)]), Color(c, a), 1.5)
		"burn":
			for i in 5:
				var x := -14.0 + i * 7.0
				var h := 10.0 + 6.0 * sin(_t * 14.0 + i * 1.7)
				draw_colored_polygon(PackedVector2Array([Vector2(x - 4, 2 + lift), Vector2(x, -h + lift), Vector2(x + 4, 2 + lift)]), Color(1.0, 0.45 + 0.1 * float(i % 2), 0.1, 0.85 * a))
		"freeze":
			for i in 6:
				var x := -16.0 + i * 6.5
				var h := 12.0 + float((i * 7) % 5) * 3.0
				draw_colored_polygon(PackedVector2Array([Vector2(x - 4, 4), Vector2(x, -h), Vector2(x + 4, 4)]), Color(c, 0.8 * a))
			draw_rect(Rect2(Vector2(-18, -6), Vector2(36, 10)), Color(c, 0.35 * a))
		"bury":
			var pts := PackedVector2Array()
			for i in 13:
				var k := float(i) / 12.0
				pts.append(Vector2(lerpf(-22, 22, k), -sin(k * PI) * 16.0 + 4.0))
			draw_colored_polygon(pts, Color(c, 0.85 * a))
		"soak":
			draw_circle(Vector2(0, -92 + lift), 9.0, Color(0.55, 0.62, 0.7, 0.8 * a))
			draw_circle(Vector2(-8, -89 + lift), 7.0, Color(0.55, 0.62, 0.7, 0.8 * a))
			draw_circle(Vector2(8, -89 + lift), 7.0, Color(0.55, 0.62, 0.7, 0.8 * a))
			for i in 3:
				var y := fmod(_t * 60.0 + i * 12.0, 36.0)
				draw_line(Vector2(-6 + i * 6, -84 + y + lift), Vector2(-6 + i * 6, -80 + y + lift), Color(c, a), 2.0)
		"wind", "lift":
			for i in 3:
				var r := 14.0 + i * 5.0
				var y := (0.0 if kind == "lift" else -30.0) + lift * (0.0 if kind == "lift" else 1.0) - i * 6.0
				draw_arc(Vector2(0, y), r, _t * 8.0 + i, _t * 8.0 + i + 2.4, 12, Color(c, 0.8 * a), 2.0)

func _star(p: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var rr := r if i % 2 == 0 else r * 0.4
		var ang := TAU * i / 8.0
		pts.append(p + Vector2(cos(ang), sin(ang)) * rr)
	draw_colored_polygon(pts, col)
