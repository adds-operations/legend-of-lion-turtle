@tool
extends Button

## Lobby element card as a small hanging scroll. Shows the element's two
## benders on a watercolor wash, its name in brush script, its playstyle and
## three attacks with their keys. Click a bender to pick them.
## Markers: gold frame + gold "YOU" tag for the local pick, indigo "RIVAL"
## tag for the opponent; a gold / indigo brush stroke under each portrait marks
## which bender each player chose.

signal bender_chosen(fighter_id: String)

const T = preload("res://scripts/ui/kit/ui_tokens.gd")
const Emblems = preload("res://scripts/ui/kit/emblems.gd")
const Elements = preload("res://scripts/data/elements.gd")
const Roster = preload("res://scripts/data/roster.gd")
const Paint = preload("res://scripts/ui/kit/ui_paint.gd")

## Portrait crop inside a 96×96 frame (the whole standing body) and scale.
const CROP := Rect2(20, 16, 56, 66)
const PORTRAIT_SCALE := 1.5

@export_range(0, 3) var element: int = 0:
	set(v): element = v; queue_redraw()
@export var picked_by_you: bool = false:
	set(v): picked_by_you = v; queue_redraw()
@export var picked_by_rival: bool = false:
	set(v): picked_by_rival = v; queue_redraw()
@export var hotkey: String = "1":
	set(v): hotkey = v; queue_redraw()
## Bender ids chosen by each player (only meaningful when picked_by_*).
@export var your_fighter: String = "":
	set(v): your_fighter = v; queue_redraw()
@export var rival_fighter: String = "":
	set(v): rival_fighter = v; queue_redraw()

var _hover_t: float = 0.0
var _hover_bender: int = -1
var _portrait_rects: Array = []

func _ready() -> void:
	text = ""
	custom_minimum_size = Vector2(250, 330)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # crisp pixel-art portraits
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED  # paper grain tiles
	for s in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(func(): _hover_bender = -1; queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	pressed.connect(_on_pressed)

func benders() -> Array:
	return Roster.for_element(element)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var idx := -1
		for i in _portrait_rects.size():
			if (_portrait_rects[i] as Rect2).has_point(event.position):
				idx = i
		if idx != _hover_bender:
			_hover_bender = idx
			queue_redraw()

func _on_pressed() -> void:
	var list := benders()
	var id: String
	if _hover_bender >= 0 and _hover_bender < list.size():
		id = list[_hover_bender]["id"]
	elif picked_by_you and your_fighter != "":
		id = your_fighter
	else:
		id = list[0]["id"]
	bender_chosen.emit(id)

func _process(delta: float) -> void:
	var target := 1.0 if (is_hovered() or has_focus()) and not disabled else 0.0
	if not is_equal_approx(_hover_t, target):
		_hover_t = move_toward(_hover_t, target, delta / T.T_BASE)
		queue_redraw()

func _draw() -> void:
	var info: Dictionary = Elements.get_info(element)
	var col := T.element_color(element)
	var wash := T.element_wash(element)
	var dim := disabled and not picked_by_you
	var lift := -6.0 * _hover_t
	var o := float(T.ROD_OVERHANG) * 0.6
	var paper := Rect2(Vector2(14, 22 + lift), Vector2(size.x - 28, size.y - 40))

	# hanging cord to a nail above the top rod
	var nail := Vector2(size.x * 0.5, 2 + lift)
	draw_line(Vector2(paper.position.x + 30, paper.position.y), nail, Color(T.INK, 0.75), 1.5, true)
	draw_line(Vector2(paper.end.x - 30, paper.position.y), nail, Color(T.INK, 0.75), 1.5, true)
	draw_circle(nail, 3.0, T.WOOD_DARK)

	# parchment body
	Paint.paper_sheet(self, paper, element * 13 + 1, T.PAPER if not picked_by_you else T.PAPER_LIGHT)
	# element watercolor wash behind the benders
	var wash_r := Rect2(paper.position + Vector2(8, 14), Vector2(paper.size.x - 16, 124))
	Paint.wash(self, wash_r, Color(wash.darkened(0.08), 0.9), element % 2 == 1)

	# --- the two benders -------------------------------------------------
	_portrait_rects.clear()
	var list := benders()
	var pw := CROP.size.x * PORTRAIT_SCALE
	var ph := CROP.size.y * PORTRAIT_SCALE
	var gap := 14.0
	var total := pw * list.size() + gap * (list.size() - 1)
	var x0 := paper.get_center().x - total / 2.0
	var py := paper.position.y + 18
	var lf := T.font("label")
	for i in list.size():
		var f: Dictionary = list[i]
		var pr := Rect2(Vector2(x0 + i * (pw + gap), py), Vector2(pw, ph))
		_portrait_rects.append(pr.grow_individual(4, 4, 4, 22))
		var is_yours: bool = picked_by_you and f["id"] == your_fighter
		var is_rivals: bool = picked_by_rival and f["id"] == rival_fighter
		var hovered := i == _hover_bender and not disabled
		# ground shadow
		draw_colored_polygon(Paint.brush_poly(Rect2(pr.position + Vector2(10, ph - 10), Vector2(pw - 20, 8)), i + 5, 1.0, 8.0),
				Color(T.INK, 0.28 if (is_yours or hovered) else 0.16))
		var tex := Roster.still(f["id"])
		if tex is AtlasTexture:
			var at := tex as AtlasTexture
			var src := Rect2(at.region.position + CROP.position, CROP.size)
			var mod := Color(1, 1, 1, 0.45) if dim or (picked_by_you and not is_yours and not hovered) else Color.WHITE
			draw_texture_rect_region(at.atlas, pr, src, mod)
		elif tex:
			draw_texture_rect(tex, pr, false)
		var bar_y := pr.end.y + 3
		if is_yours:
			Paint.stroke(self, Rect2(Vector2(pr.position.x + 2, bar_y - 3), Vector2(pw - 4, 12)), T.SIDE_YOU)
		if is_rivals:
			Paint.stroke(self, Rect2(Vector2(pr.position.x + 2, bar_y - 3 + (7 if is_yours else 0)), Vector2(pw - 4, 12)), T.SIDE_RIVAL, true)
		var nm: String = str(f["name"])
		var name_col := T.INK if (is_yours or hovered) else T.INK_SOFT
		if dim:
			name_col = T.INK_FAINT
		draw_string(lf, Vector2(pr.position.x - gap * 0.5, bar_y + 24), nm, HORIZONTAL_ALIGNMENT_CENTER, pw + gap, 12, name_col)

	# --- element name in brush script ------------------------------------
	var ny := py + ph + 62
	var df := T.font("display")
	var name_s: String = str(info["name"]).capitalize()
	var nw := df.get_string_size(name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	var ex := paper.get_center().x - (nw + 30) / 2.0
	Emblems.draw(self, Emblems.element_kind(element), Rect2(Vector2(ex, ny - 26), Vector2(22, 22)),
			col if not dim else Color(col, 0.4))
	draw_string(df, Vector2(ex + 30, ny), name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, col if not dim else T.INK_FAINT)

	# tagline
	var bf := T.font("body")
	draw_multiline_string(bf, Vector2(paper.position.x + 16, ny + 16), info["tagline"],
			HORIZONTAL_ALIGNMENT_CENTER, paper.size.x - 32, 12, 2, T.INK_SOFT if not dim else T.INK_FAINT)

	# attacks
	var y := ny + 53
	for i in 4:
		var key: String = Elements.KEYS[i]
		var available := i < Elements.IMPLEMENTED_ATTACKS
		var cap := Rect2(Vector2(paper.position.x + 18, y - 12), Vector2(30, 15))
		draw_rect(cap, T.PAPER_LIGHT if available else Color(T.PAPER_LIGHT, 0.5))
		draw_rect(cap, T.INK if available else Color(T.INK, 0.35), false, 1.0)
		var kw := lf.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(lf, Vector2(cap.get_center().x - kw / 2.0, y), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
				T.INK if available else T.INK_FAINT)
		var atk: String = info["attacks"][i]
		var name_w := paper.size.x - 18 - 30 - 10 - 34
		draw_string(lf, Vector2(cap.end.x + 10, y + 1), atk, HORIZONTAL_ALIGNMENT_LEFT, name_w, 13,
				T.INK if available and not dim else T.INK_FAINT)
		if not available:
			Emblems.draw(self, "lock", Rect2(Vector2(paper.end.x - 30, y - 12), Vector2(12, 12)), T.INK_FAINT)
		y += 16

	# rods (drawn last so they sit over the paper edge)
	Paint.rod(self, paper.position.x - o, paper.end.x + o, paper.position.y)
	Paint.rod(self, paper.position.x - o, paper.end.x + o, paper.end.y, T.ROD_H + 2)

	# selection frame / hover / focus
	if picked_by_you:
		Paint.ink_frame(self, paper.grow(3), T.SIDE_YOU, 4.0, element + 50)
	elif _hover_t > 0.0:
		Paint.ink_frame(self, paper.grow(2), Color(T.VERMILION, _hover_t), 2.0, element + 51)
	if has_focus() and not picked_by_you:
		Paint.ink_frame(self, paper.grow(6), T.INK, 1.5, element + 52)
	if dim:
		draw_colored_polygon(Paint.brush_poly(paper, element + 60), Color(T.PAPER_DARK, 0.45))

	# hotkey tag
	var hk := Rect2(Vector2(paper.position.x + 6, paper.position.y + 10), Vector2(20, 20))
	draw_rect(hk, T.INK)
	draw_string(lf, hk.position + Vector2(6, 15), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, T.PAPER_LIGHT)

	# pick tags hang from the top rod
	var cx := paper.get_center().x
	var ty := paper.position.y + 6
	if picked_by_you and picked_by_rival:
		_tag(Vector2(cx - 78, ty), "YOU", T.SIDE_YOU, T.TEXT_ON_YOU)
		_tag(Vector2(cx + 6, ty), "RIVAL", T.SIDE_RIVAL, T.TEXT_ON_RIVAL)
	elif picked_by_you:
		_tag(Vector2(cx - 24, ty), "YOU", T.SIDE_YOU, T.TEXT_ON_YOU)
	elif picked_by_rival:
		_tag(Vector2(cx - 32, ty), "RIVAL", T.SIDE_RIVAL, T.TEXT_ON_RIVAL)

func _tag(pos: Vector2, label: String, bg: Color, fg: Color) -> void:
	var f := T.font("heading")
	var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 20
	var rr := Rect2(pos, Vector2(w, 22))
	draw_colored_polygon(Paint.brush_poly(rr, label.length(), 1.0, 8.0), bg)
	draw_rect(rr, T.INK, false, 1.0)
	draw_string(f, pos + Vector2(10, 16), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, fg)
