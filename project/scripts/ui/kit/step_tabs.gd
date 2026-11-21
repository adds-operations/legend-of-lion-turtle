extends Control

## Two brush tabs above the lobby's main area: "1  ELEMENT & BENDER" and
## "2  BUILD". The active tab is a vermilion brush stroke; the build tab
## carries a pulsing seal while points are unspent, and a one-line summary
## of the build sits at the right.

signal tab_selected(index: int)

const T = preload("res://scripts/ui/kit/ui_tokens.gd")
const Paint = preload("res://scripts/ui/kit/ui_paint.gd")

var active: int = 0:
	set(v): active = v; queue_redraw()
var points_left: int = 0:
	set(v): points_left = v; queue_redraw()
var summary: String = "":
	set(v): summary = v; queue_redraw()

var _rects: Array = []
var _hover: int = -1
var _t: float = 0.0

const LABELS := ["ELEMENT & BENDER", "BUILD & SIGNATURE"]
const KEYS := ["1–4", "B"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(600, 36)

func _process(delta: float) -> void:
	_t += delta
	if points_left > 0 and active == 0:
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := -1
		for i in _rects.size():
			if (_rects[i] as Rect2).has_point(event.position):
				h = i
		if h != _hover:
			_hover = h
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h >= 0 else Control.CURSOR_ARROW
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _hover >= 0:
		accept_event()
		tab_selected.emit(_hover)

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != -1:
		_hover = -1
		queue_redraw()

func _draw() -> void:
	_rects.clear()
	var hf := T.font("heading")
	var lf := T.font("label")
	var x := 0.0
	for i in 2:
		var label: String = LABELS[i]
		var w := hf.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 70.0
		if i == 1:
			w += 38.0
		var r := Rect2(Vector2(x, 0), Vector2(w, size.y))
		_rects.append(r)
		var on := i == active
		var hov := i == _hover and not on
		var kit_tab := Paint.tex_kit("tab_active")
		if kit_tab:
			var sb := StyleBoxTexture.new()
			sb.texture = kit_tab if on else Paint.tex_kit("tab_inactive")
			for side_i in [SIDE_LEFT, SIDE_RIGHT]:
				sb.set_texture_margin(side_i, 24)
			for side_i in [SIDE_TOP, SIDE_BOTTOM]:
				sb.set_texture_margin(side_i, 14)
			sb.modulate_color = Color.WHITE if (on or not hov) else Color(1.0, 0.9, 0.8)
			draw_style_box(sb, r.grow_individual(4, 3, 8, 3))
		elif on:
			Paint.stroke(self, r.grow_individual(6, 2, 10, 2), T.VERMILION, i == 1)
		elif hov:
			Paint.stroke(self, r.grow_individual(6, 2, 10, 2), Color(T.INK, 0.18), i == 1)
		var fg := T.PAPER_LIGHT if on else T.INK
		# step number in a small square
		var nr := Rect2(Vector2(x + 10, size.y * 0.5 - 11), Vector2(22, 22))
		draw_rect(nr, T.PAPER_LIGHT if on else T.INK)
		draw_string(lf, nr.position + Vector2(7, 16), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, T.VERMILION if on else T.PAPER_LIGHT)
		draw_string(hf, Vector2(x + 42, size.y * 0.5 + 7), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, fg)
		if i == 1:
			var sx := x + w - 34.0
			var sr := Rect2(Vector2(sx, size.y * 0.5 - 13), Vector2(26, 26))
			if points_left > 0:
				var k := 1.0 + (0.08 * sin(_t * 5.0) if not on else 0.0)
				sr = Rect2(sr.get_center() - sr.size * k * 0.5, sr.size * k)
				if on:
					draw_colored_polygon(Paint.brush_poly(sr, 4, 1.2, 6.0), T.PAPER_LIGHT)
					var tw := lf.get_string_size(str(points_left), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
					draw_string(lf, sr.get_center() + Vector2(-tw / 2.0, 5), str(points_left), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, T.VERMILION)
				else:
					Paint.seal(self, sr, str(points_left), 4)
			else:
				draw_colored_polygon(Paint.brush_poly(sr, 4, 1.2, 6.0), T.SUCCESS)
				var cw := lf.get_string_size("✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
				draw_string(lf, sr.get_center() + Vector2(-cw / 2.0, 6), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, T.PAPER_LIGHT)
		x += w + 18.0
	# key hint + summary on the right
	if summary != "":
		var sw := lf.get_string_size(summary, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(lf, Vector2(size.x - sw, size.y * 0.5 + 5), summary, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, T.INK)
		var cap := "YOUR BUILD"
		var cw2 := lf.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(lf, Vector2(size.x - sw - cw2 - 12, size.y * 0.5 + 4), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, T.VERMILION)
