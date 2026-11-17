@tool
extends Control

## HUD ability tile: a parchment plaque with an ink frame, the ability's
## emblem in its element ink, an ink-wash curtain while cooling down, and a
## paper key tag underneath.

const T = preload("res://scripts/ui/kit/ui_tokens.gd")
const Emblems = preload("res://scripts/ui/kit/emblems.gd")
const Paint = preload("res://scripts/ui/kit/ui_paint.gd")

@export var key_text: String = "LMB":
	set(v): key_text = v; queue_redraw()
@export var emblem: String = "bolt":
	set(v): emblem = v; queue_redraw()
@export var color: Color = T.ELEMENT[0]:
	set(v): color = v; queue_redraw()
## The attack's own art; replaces the emblem when set.
var icon: Texture2D:
	set(v): icon = v; queue_redraw()
@export var locked: bool = false:
	set(v): locked = v; queue_redraw()
@export var large: bool = false:
	set(v): large = v; _resize(); queue_redraw()

var _remaining: float = 0.0
var _total: float = 1.0
var _flash: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_resize()

func _resize() -> void:
	custom_minimum_size = Vector2(76, 96) if large else Vector2(60, 82)

func set_cooldown(remaining: float, total: float) -> void:
	var was_cooling := _remaining > 0.0
	_remaining = maxf(remaining, 0.0)
	_total = maxf(total, 0.01)
	if was_cooling and _remaining <= 0.0:
		_flash = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 4.0)
		queue_redraw()

func _draw() -> void:
	var side := size.x - 6.0
	var frame := Rect2(Vector2(3, 0), Vector2(side, side))
	var ready := not locked and _remaining <= 0.0
	var seed := key_text.length() * 7 + int(large)

	Paint.fill_paper(self, Paint.brush_poly(frame, seed, 1.2, 12.0), T.PAPER if not locked else T.PAPER_DARK)
	if ready:
		# a warm wash of the element behind the emblem
		draw_circle(frame.get_center(), side * 0.36, Color(color.lightened(0.55), 0.5))

	var icon_rect := frame.grow(-side * 0.22)
	var icon_col := T.INK_FAINT if locked else (color if ready else Color(color, 0.5))
	if icon and not locked:
		var isz := icon.get_size()
		var k := minf(frame.size.x * 0.86 / isz.x, frame.size.y * 0.86 / isz.y)
		var r := Rect2(frame.get_center() - isz * k / 2.0, isz * k)
		draw_texture_rect(icon, r, false, Color.WHITE if ready else Color(1, 1, 1, 0.45))
	else:
		Emblems.draw(self, "lock" if locked else emblem, icon_rect, icon_col)

	if not locked and _remaining > 0.0:
		# ink-wash curtain shrinks downward from the top
		var frac := clampf(_remaining / _total, 0.0, 1.0)
		draw_rect(Rect2(frame.position, Vector2(frame.size.x, frame.size.y * frac)), Color(T.INK, 0.55))
		var f := T.font("heading")
		var txt := ("%.1f" % _remaining) if _remaining < 1.0 else str(ceili(_remaining))
		var fs := 22 if large else 18
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(f, frame.get_center() + Vector2(-tw / 2.0, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, T.INK)
		draw_string(f, frame.get_center() + Vector2(-tw / 2.0, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, T.PAPER_LIGHT)

	Paint.ink_frame(self, frame, T.INK if ready else Color(T.INK, 0.6), 3.0 if ready else 2.0, seed)
	if _flash > 0.0:
		draw_rect(frame, Color(T.SUN, _flash * 0.7))

	# key tag
	var kf := T.font("label")
	var ks := T.FS_CAPTION
	var kw := kf.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, ks).x + 14.0
	var cap := Rect2(Vector2((size.x - kw) / 2.0, side + 6.0), Vector2(kw, 18))
	draw_rect(cap, T.PAPER_LIGHT if not locked else Color(T.PAPER_LIGHT, 0.5))
	draw_rect(cap, T.INK if not locked else Color(T.INK, 0.4), false, 1.0)
	draw_string(kf, cap.position + Vector2(7, 13.5), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, ks, T.INK if not locked else T.INK_FAINT)
