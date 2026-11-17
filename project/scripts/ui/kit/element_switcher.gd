@tool
extends Control

## The Avatar's element bar: four paper keycaps (1–4) with element emblems.
## The active element is raised, washed in its color and underlined with a
## brush stroke; the others stay faded. Shown above the HUD card once the
## local fighter merges with Raava.

const T = preload("res://scripts/ui/kit/ui_tokens.gd")
const Paint = preload("res://scripts/ui/kit/ui_paint.gd")
const Emblems = preload("res://scripts/ui/kit/emblems.gd")

@export_range(0, 3) var active: int = 0:
	set(v):
		if v != active:
			_pop = 1.0
		active = v
		queue_redraw()
## Small caps label above the keycaps ("AVATAR", or "ELEMENTS" in training).
var title: String = "AVATAR":
	set(v): title = v; queue_redraw()
## Avatar: all four lit, tagged Q W E R (each key throws its element).
## Otherwise (training): the active one lit, tagged 1–4.
var avatar: bool = false:
	set(v): avatar = v; queue_redraw()
## 0..1 while the 0.3 s switch recovery runs (drawn as a draining underline).
var recovery: float = 0.0:
	set(v): recovery = v; queue_redraw()
var _pop: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

func _process(delta: float) -> void:
	if _pop > 0.0:
		_pop = maxf(0.0, _pop - delta * 4.0)
		queue_redraw()

func _draw() -> void:
	var f := T.font("label")
	var hf := T.font("heading")
	var w := 44.0
	var gap := 8.0
	Paint.wash(self, Rect2(Vector2(-16, -4), Vector2(4 * w + 3 * gap + 32, size.y + 4)), Color(T.INK, 0.6))
	draw_string(T.font("label"), Vector2(14, 11), " ".join(title.split("")), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, T.PAPER_LIGHT)
	for i in 4:
		var on := avatar or i == active
		var lift := -6.0 - 4.0 * _pop if on else 0.0
		var r := Rect2(Vector2(i * (w + gap), 26 + lift), Vector2(w, w))
		Paint.fill_paper(self, Paint.brush_poly(r, i + 70, 1.2, 10.0), T.PAPER_LIGHT if on else Color(T.PAPER_DARK, 0.85))
		if on:
			draw_colored_polygon(Paint.brush_poly(r.grow(-4), i + 74, 2.0, 10.0), Color(T.element_wash(i), 0.95))
		Emblems.draw(self, Emblems.element_kind(i), r.grow(-11), T.element_color(i) if on else Color(T.INK_FAINT, 0.7))
		Paint.ink_frame(self, r, T.INK if on else Color(T.INK, 0.4), 2.0 if on else 1.0, i + 78)
		# key number tag
		var kr := Rect2(r.position + Vector2(-4, -6), Vector2(16, 16))
		draw_rect(kr, T.INK if on else Color(T.INK, 0.55))
		draw_string(hf, kr.position + Vector2(4, 13), "QWER"[i] if avatar else str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, T.PAPER_LIGHT)
		if on and not avatar:
			var ur := Rect2(Vector2(r.position.x - 2, r.end.y + 2), Vector2(w + 4, 9))
			Paint.stroke(self, ur, T.element_glow(i))
			if recovery > 0.0:
				draw_rect(Rect2(ur.position + Vector2(0, 10), Vector2(ur.size.x * recovery, 2)), T.PAPER_LIGHT)
