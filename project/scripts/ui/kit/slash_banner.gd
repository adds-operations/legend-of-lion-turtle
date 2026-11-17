@tool
extends Control

## Full-width "big moment" banner: a sweeping brush stroke with brush-script
## text and a red ribbon tail. Used for FIGHT!, VICTORY, DEFEAT, countdown.

const T = preload("res://scripts/ui/kit/ui_tokens.gd")
const Paint = preload("res://scripts/ui/kit/ui_paint.gd")

@export var text: String = "Victory":
	set(v): text = v; queue_redraw()
## Stroke color (ink for most moments, vermilion for victory).
@export var band: Color = T.INK:
	set(v): band = v; queue_redraw()
@export var text_color: Color = T.PAPER_LIGHT:
	set(v): text_color = v; queue_redraw()
@export var font_size: int = T.FS_DISPLAY + 20:
	set(v): font_size = v; queue_redraw()
@export_range(0.0, 1.0) var reveal: float = 1.0:
	set(v): reveal = v; queue_redraw()

var _t: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if visible and not Engine.is_editor_hint():
		_t += delta
		queue_redraw()

## Animate in. Returns the tween so callers can await it.
func play(new_text: String = "", band_color: Color = band, text_col: Color = text_color) -> Tween:
	if new_text != "":
		text = new_text
	band = band_color
	text_color = text_col
	visible = true
	modulate.a = 1.0
	reveal = 0.0
	var tw := create_tween()
	tw.tween_property(self, "reveal", 1.0, T.T_SLOW).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	return tw

func dismiss() -> Tween:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, T.T_BASE)
	tw.tween_callback(func(): visible = false)
	return tw

func _draw() -> void:
	var w := size.x
	var cy := size.y * 0.5
	var h := font_size * 1.15
	var grow := clampf(reveal * 1.35, 0.0, 1.0)
	if grow <= 0.001:
		return
	# the stroke sweeps in from the left (scale from the left edge keeps the shape intact)
	var rect := Rect2(Vector2(w * 0.08, cy - h * 0.5), Vector2(w * 0.84, h))
	draw_set_transform(Vector2(rect.position.x * (1.0 - grow), 0), 0.0, Vector2(grow, 1))
	# ribbon tail fluttering behind the stroke's end
	var tail := PackedVector2Array()
	var tail_b := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var t := float(i) / n
		var x := rect.end.x - 40 + t * w * 0.14
		var y := cy + h * 0.1 + sin(t * 6.0 - _t * 6.0) * 10.0 * t
		var half := h * 0.2
		tail.append(Vector2(x, y - half))
		tail_b.append(Vector2(x, y + half))
	var rib := Paint.tex("ribbon")
	for i in n:
		var u0 := float(i) / n
		var u1 := float(i + 1) / n
		draw_primitive(PackedVector2Array([tail[i], tail[i + 1], tail_b[i + 1], tail_b[i]]),
				PackedColorArray([T.RIBBON, T.RIBBON, T.RIBBON, T.RIBBON]),
				PackedVector2Array([Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)]), rib)
	Paint.wash(self, rect.grow_individual(10, 22, 10, 22), Color(T.INK, 0.28))
	Paint.wash(self, rect.grow_individual(0, 14, 0, 14), band)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if reveal < 0.25:
		return
	var a := clampf((reveal - 0.25) / 0.4, 0.0, 1.0)
	var f := T.font("display")
	var fs := int(font_size * lerpf(1.2, 1.0, a))
	var tsz := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := Vector2((w - tsz.x) / 2.0, cy + fs * 0.3)
	draw_string(f, pos + Vector2(4, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.35 * a))
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(text_color, a))
