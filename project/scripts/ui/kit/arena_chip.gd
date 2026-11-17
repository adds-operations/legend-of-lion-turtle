@tool
extends Control

## Lobby arena picker: a small parchment card with the arena's painting,
## name and region. The host can step through arenas with the arrows (or
## Q / E); the joining player sees the host's choice live.

signal step_requested(delta: int)

const T = preload("res://scripts/ui/kit/ui_tokens.gd")
const Paint = preload("res://scripts/ui/kit/ui_paint.gd")
const Arenas = preload("res://scripts/data/arenas.gd")

@export var arena_id: String = Arenas.DEFAULT_ID:
	set(v): arena_id = v; _thumb = null; queue_redraw()
@export var can_change: bool = true:
	set(v): can_change = v; queue_redraw()
@export var ping_text: String = "":
	set(v): ping_text = v; queue_redraw()
@export var ping_color: Color = T.INK_FAINT:
	set(v): ping_color = v; queue_redraw()

var _thumb: Texture2D
var _prev_rect: Rect2
var _next_rect: Rect2
var _hover: int = 0  # -1 prev, 1 next

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	custom_minimum_size = Vector2(380, 96)
	mouse_exited.connect(func(): _hover = 0; queue_redraw())

func _gui_input(event: InputEvent) -> void:
	if not can_change:
		return
	if event is InputEventMouseMotion:
		var h := -1 if _prev_rect.has_point(event.position) else (1 if _next_rect.has_point(event.position) else 0)
		if h != _hover:
			_hover = h
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h != 0 else Control.CURSOR_ARROW
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _prev_rect.has_point(event.position):
			step_requested.emit(-1)
			accept_event()
		elif _next_rect.has_point(event.position):
			step_requested.emit(1)
			accept_event()

func _draw() -> void:
	var r := Rect2(Vector2(4, 2), size - Vector2(8, 4))
	Paint.paper_sheet(self, r, 12)
	# thumbnail of the painting
	if _thumb == null and ResourceLoader.exists(Arenas.art_path(arena_id)):
		_thumb = load(Arenas.art_path(arena_id))
	var th := Rect2(r.position + Vector2(10, 8), Vector2(117, 78))
	if _thumb:
		draw_texture_rect(_thumb, th, false)
	Paint.ink_frame(self, th, T.INK, 2.0, 13)

	var x := th.end.x + 14
	var lf := T.font("label")
	var hf := T.font("heading")
	draw_string(lf, Vector2(x, r.position.y + 24), "A R E N A", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, T.VERMILION)
	draw_string(hf, Vector2(x, r.position.y + 48), Arenas.display_name(arena_id), HORIZONTAL_ALIGNMENT_LEFT, r.end.x - x - 60, 19, T.INK)
	draw_string(lf, Vector2(x, r.position.y + 68), Arenas.nation_name(arena_id), HORIZONTAL_ALIGNMENT_LEFT, r.end.x - x - 60, 13, T.INK_SOFT)
	var foot := "Q / E to change" if can_change else "The host picks the arena"
	if ping_text != "":
		draw_string(lf, Vector2(x, r.position.y + 86), ping_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ping_color)
		foot = ""
	if foot != "":
		draw_string(lf, Vector2(x, r.position.y + 86), foot, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, T.INK_FAINT)

	# arrows (host only)
	_prev_rect = Rect2()
	_next_rect = Rect2()
	if can_change:
		var ay := r.get_center().y
		_prev_rect = Rect2(Vector2(r.end.x - 58, ay - 16), Vector2(24, 32))
		_next_rect = Rect2(Vector2(r.end.x - 30, ay - 16), Vector2(24, 32))
		for i in 2:
			var rr: Rect2 = _prev_rect if i == 0 else _next_rect
			var dir := -1.0 if i == 0 else 1.0
			var hot := (_hover == -1 and i == 0) or (_hover == 1 and i == 1)
			var c := rr.get_center()
			draw_colored_polygon(PackedVector2Array([c + Vector2(dir * 8, 0), c + Vector2(-dir * 6, -10), c + Vector2(-dir * 6, 10)]),
					T.VERMILION if hot else T.INK)
