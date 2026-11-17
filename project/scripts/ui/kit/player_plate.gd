@tool
extends Control

## Lobby identity plate as a small horizontal scroll: side-color stroke,
## bender portrait, YOU/RIVAL tag, player name, bender and ready state.
## `mirrored` flips it for the right-hand (rival) side.

const T = preload("res://scripts/ui/kit/ui_tokens.gd")
const Emblems = preload("res://scripts/ui/kit/emblems.gd")
const Roster = preload("res://scripts/data/roster.gd")
const Paint = preload("res://scripts/ui/kit/ui_paint.gd")
const CROP := Rect2(20, 14, 56, 68)

@export var player_name: String = "Player":
	set(v): player_name = v; queue_redraw()
@export_range(0, 3) var element: int = 0:
	set(v): element = v; queue_redraw()
@export var fighter_id: String = "":
	set(v): fighter_id = v; queue_redraw()
@export var is_you: bool = true:
	set(v): is_you = v; queue_redraw()
@export var is_ready: bool = false:
	set(v): is_ready = v; queue_redraw()
@export var present: bool = true:
	set(v): present = v; queue_redraw()
@export var mirrored: bool = false:
	set(v): mirrored = v; queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(420, 96)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

func _draw() -> void:
	var side := T.side_color(is_you)
	var paper := Rect2(Vector2(12, 4), size - Vector2(24, 8))
	Paint.paper_sheet(self, paper, 3 if is_you else 4)
	# side-color stroke along the outer edge
	var bar := Rect2(Vector2(paper.end.x - 14, paper.position.y + 6) if mirrored else paper.position + Vector2(6, 6), Vector2(8, paper.size.y - 12))
	draw_colored_polygon(Paint.brush_poly(bar, 7, 1.0, 6.0), side)
	# vertical rods on both ends (a horizontal scroll)
	for x in [paper.position.x - 2, paper.end.x + 2]:
		draw_rect(Rect2(Vector2(x - 5, paper.position.y - 6), Vector2(10, paper.size.y + 12)), T.WOOD)
		draw_rect(Rect2(Vector2(x - 5, paper.position.y - 6), Vector2(3.5, paper.size.y + 12)), T.WOOD_LIGHT)
		draw_circle(Vector2(x, paper.position.y - 6), 7.0, T.WOOD_DARK)
		draw_circle(Vector2(x, paper.end.y + 6), 7.0, T.WOOD_DARK)

	var hf := T.font("heading")
	var lf := T.font("label")
	var pad := 30.0
	if not present:
		var wt := "Waiting for rival..."
		var bf := T.font("body")
		var ww := bf.get_string_size(wt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(bf, Vector2(paper.get_center().x - ww / 2.0, paper.get_center().y + 8), wt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, T.INK_FAINT)
		return

	var col := T.element_color(element)
	# bender tile: the chosen bender at 1× (pixel-perfect) on an element wash
	var tile := Rect2(Vector2(paper.end.x - pad - 72, paper.position.y + 8) if mirrored else Vector2(paper.position.x + pad, paper.position.y + 8), Vector2(72, 72))
	draw_colored_polygon(Paint.brush_poly(tile, element + 9, 2.0, 10.0), Color(T.element_wash(element), 0.9))
	var tex := Roster.still(fighter_id, "idle_east" if not mirrored else "idle_west")
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		var dst := Rect2(tile.get_center() - CROP.size / 2.0 + Vector2(0, 2), CROP.size)
		draw_texture_rect_region(at.atlas, dst, Rect2(at.region.position + CROP.position, CROP.size))
	else:
		Emblems.draw(self, Emblems.element_kind(element), tile.grow(-14), col)
	Paint.ink_frame(self, tile, T.INK, 1.5, element + 11)

	var tx := tile.position.x - 16 if mirrored else tile.end.x + 16
	var align := HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
	var tw := 230.0
	var x0 := tx - tw if mirrored else tx
	# YOU / RIVAL tag in side color
	var tag := "YOU" if is_you else "RIVAL"
	var tgw := lf.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 12
	var tgx := (tx - tgw) if mirrored else tx
	draw_rect(Rect2(Vector2(tgx, paper.position.y + 10), Vector2(tgw, 17)), side)
	draw_string(lf, Vector2(tgx + 6, paper.position.y + 23), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, T.text_on_side(is_you))
	draw_string(hf, Vector2(x0, paper.position.y + 54), player_name, align, tw, 26, T.INK)
	var bender: String = str(Roster.get_fighter(fighter_id).get("name", T.ELEMENT_NAMES[element])).to_upper()
	var state := "READY" if is_ready else "CHOOSING"
	var sep := "  ·  "
	var w1 := lf.get_string_size(bender, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_LABEL).x
	var w2 := lf.get_string_size(sep + state, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_LABEL).x
	var sx := (tx - w1 - w2) if mirrored else tx
	draw_string(lf, Vector2(sx, paper.position.y + 78), bender, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_LABEL, col)
	draw_string(lf, Vector2(sx + w1, paper.position.y + 78), sep + state, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_LABEL,
			T.SUCCESS if is_ready else T.INK_FAINT)
