extends Control

## The build board, drawn in the Scroll & Ink style of the lobby cards.
## Left: a parchment sheet with the 8 points and the three stats (click a
## pip, or − / +). Points only make you stronger. Right: your bender's
## signature attack on A — fixed per bender (their bending style); switch
## benders on the Element tab to change it.
##
## Keyboard (forwarded by the owner through key_input): ↑ ↓ pick a stat,
## ← → take / add a point.

signal build_changed(build: Dictionary)
signal message(text: String)

const T = preload("res://scripts/ui/kit/ui_tokens.gd")
const Paint = preload("res://scripts/ui/kit/ui_paint.gd")
const Emblems = preload("res://scripts/ui/kit/emblems.gd")
const Specials = preload("res://scripts/data/specials.gd")
const Roster = preload("res://scripts/data/roster.gd")
const Kit = preload("res://scripts/ui/kit/ui_kit.gd")

const SHEET_W := 430.0
const CARD_GAP := 12.0
const STAT_EFFECT := ["+%d%% damage", "%d%% less damage taken", "+%d%% move speed"]
const STAT_PER := [5, 4, 4]

var element: int = 0
var fighter_id: String = ""
var build: Dictionary = Specials.empty_build()
var locked: bool = false

var _row: int = 0               # keyboard-focused stat
var _hover: String = ""         # hovered hit id
var _hits: Array = []           # [[Rect2, id]]
var _anim_t: float = 0.0
var _pulse: Dictionary = {}     # id -> 1.0 flash after a change

func _ready() -> void:
	custom_minimum_size = Vector2(1184, 330)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	focus_mode = Control.FOCUS_NONE

func set_state(elem: int, fighter: String, b: Dictionary, is_locked: bool = false) -> void:
	element = elem
	fighter_id = fighter
	build = Specials.sanitize(b)
	locked = is_locked
	queue_redraw()

func points_left() -> int:
	return Specials.POINTS - Specials.spent(build)

# --- Changes -----------------------------------------------------------------

func change_stat(stat: int, d: int) -> void:
	set_stat(stat, int(build[Specials.STATS[stat]]) + d)

func set_stat(stat: int, v: int) -> void:
	if locked:
		message.emit("You're READY — cancel it to change your build.")
		return
	var key: String = Specials.STATS[stat]
	var cur := int(build[key])
	v = clampi(v, 0, Specials.MAX_STAT)
	v = mini(v, cur + points_left())
	if v == cur:
		if points_left() <= 0 and v < Specials.MAX_STAT:
			message.emit("No points left — take one from another stat.")
		return
	build[key] = v
	_row = stat
	_pulse["stat%d" % stat] = 1.0
	queue_redraw()
	build_changed.emit(build.duplicate())

func key_input(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed):
		return false
	match event.keycode:
		KEY_UP:
			_row = posmod(_row - 1, 3); queue_redraw()
		KEY_DOWN:
			_row = posmod(_row + 1, 3); queue_redraw()
		KEY_LEFT, KEY_MINUS:
			change_stat(_row, -1)
		KEY_RIGHT, KEY_EQUAL, KEY_PLUS:
			change_stat(_row, 1)
		_:
			return false
	return true

# --- Input -------------------------------------------------------------------

func _hit_at(p: Vector2) -> String:
	for h in _hits:
		if (h[0] as Rect2).has_point(p):
			return h[1]
	return ""

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _hit_at(event.position)
		if h != _hover:
			_hover = h
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h != "" else Control.CURSOR_ARROW
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var h := _hit_at(event.position)
		if h == "":
			return
		accept_event()
		var parts := h.split(":")
		match parts[0]:
			"pip":
				var stat := int(parts[1])
				var n := int(parts[2]) + 1
				# Clicking the last filled pip empties it.
				set_stat(stat, n - 1 if int(build[Specials.STATS[stat]]) == n else n)
			"minus":
				change_stat(int(parts[1]), -1)
			"plus":
				change_stat(int(parts[1]), 1)
			"row":
				_row = int(parts[1]); queue_redraw()
			"card":
				message.emit("Your signature comes with your bender — pick another bender on the Element tab to change it.")

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != "":
		_hover = ""
		queue_redraw()

func _process(delta: float) -> void:
	_anim_t += delta
	for k in _pulse.keys():
		_pulse[k] = maxf(0.0, _pulse[k] - delta * 2.5)
		if _pulse[k] <= 0.0:
			_pulse.erase(k)
	if is_visible_in_tree():
		queue_redraw()

# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	_hits.clear()
	_draw_sheet(Rect2(Vector2(0, 4), Vector2(SHEET_W, size.y - 8)))
	var x := SHEET_W + 16.0
	_draw_signature(Rect2(Vector2(x, 4), Vector2(size.x - x, size.y - 8)))

func _draw_sheet(r: Rect2) -> void:
	var hf := T.font("heading")
	var lf := T.font("label")
	var bf := T.font("body")
	Paint.paper_sheet(self, r, 7, T.PAPER)
	var o := float(T.ROD_OVERHANG) * 0.6
	var pad := 26.0
	var x0 := r.position.x + pad
	# header
	draw_string(lf, Vector2(x0, r.position.y + 34), "8 POINTS  ·  0–5 EACH", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, T.VERMILION)
	draw_string(hf, Vector2(x0, r.position.y + 64), "Stats", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, T.INK)
	var left := points_left()
	var seal_r := Rect2(Vector2(r.end.x - pad - 54, r.position.y + 22), Vector2(54, 54))
	if left > 0:
		var k := 1.0 + 0.06 * sin(_anim_t * 5.0)
		seal_r = Rect2(seal_r.get_center() - seal_r.size * k * 0.5, seal_r.size * k)
		Paint.seal(self, seal_r, str(left), 11)
	else:
		draw_colored_polygon(Paint.brush_poly(seal_r, 11, 1.5, 6.0), T.SUCCESS)
		var w := lf.get_string_size("✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		draw_string(lf, seal_r.get_center() + Vector2(-w / 2.0, 9), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, T.PAPER_LIGHT)
	var lab := "POINTS LEFT" if left > 0 else "ALL SPENT"
	var lw := lf.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(lf, Vector2(seal_r.get_center().x - lw / 2.0, seal_r.end.y + 14), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, T.INK_SOFT)

	# stat rows
	var y := r.position.y + 104.0
	var row_h := (r.end.y - 22.0 - y) / 3.0
	for i in 3:
		var rr := Rect2(Vector2(r.position.x + 12, y), Vector2(r.size.x - 24, row_h - 4))
		_hits.append([rr, "row:%d" % i])
		var v := int(build[Specials.STATS[i]])
		var focus := i == _row and not locked
		if focus:
			Paint.wash(self, rr.grow_individual(0, 2, 0, 2), Color(T.SIDE_YOU, 0.22), i % 2 == 0)
		var pulse: float = _pulse.get("stat%d" % i, 0.0)
		# emblem + name
		var er := Rect2(Vector2(x0 - 4, y + 8), Vector2(26, 26))
		_stat_icon(i, er, T.INK if v > 0 else T.INK_FAINT)
		draw_string(hf, Vector2(x0 + 30, y + 30), Specials.STAT_NAMES[i].capitalize(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, T.INK)
		# − pips +
		var px := x0 + 150.0
		var minus_r := Rect2(Vector2(px, y + 10), Vector2(24, 24))
		_round_button(minus_r, "–", v > 0 and not locked, "minus:%d" % i)
		var pip_x := minus_r.end.x + 8
		for p in Specials.MAX_STAT:
			var pr := Rect2(Vector2(pip_x + p * 30, y + 9), Vector2(26, 26))
			_hits.append([pr.grow(2), "pip:%d:%d" % [i, p]])
			var filled := p < v
			var hov := _hover == "pip:%d:%d" % [i, p]
			if Kit.has("pip_full"):
				var pm := Color.WHITE
				if filled and p == v - 1 and pulse > 0.0:
					pm = Color(1, 1, 1).lightened(pulse * 0.5)
				elif hov and not filled:
					pm = Color(1.0, 0.85, 0.75)
				Kit.draw_icon(self, "pip_full" if filled else "pip_empty", pr.grow(1), pm)
				continue
			var col := T.element_color(element) if filled else Color(T.PAPER_DARK, 0.9)
			if filled and p == v - 1 and pulse > 0.0:
				col = col.lightened(pulse * 0.5)
			draw_colored_polygon(Paint.brush_poly(pr, i * 7 + p + 1, 1.2, 6.0), col)
			Paint.ink_frame(self, pr, T.INK if (filled or hov) else Color(T.INK, 0.45), 1.5 if hov else 1.0, i * 7 + p + 20)
		var plus_r := Rect2(Vector2(pip_x + Specials.MAX_STAT * 30 + 4, y + 10), Vector2(24, 24))
		_round_button(plus_r, "+", v < Specials.MAX_STAT and left > 0 and not locked, "plus:%d" % i)
		# effect + unlock line
		var eff := (STAT_EFFECT[i] as String) % (STAT_PER[i] * v)
		draw_string(bf, Vector2(x0 + 30, y + 52), eff, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, T.INK if v > 0 else T.INK_FAINT)
		y += row_h

	draw_string(lf, Vector2(x0, r.end.y - 16), "↑ ↓ STAT   ← → POINT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, T.INK_FAINT)
	Paint.vrod(self, r.position.x, r.position.y - o, r.end.y + o)
	Paint.vrod(self, r.end.x, r.position.y - o, r.end.y + o)

## Attack: a flame fist. Defense: a cloud shield. Mobility: wind feet.
func _stat_icon(i: int, r: Rect2, col: Color) -> void:
	if Kit.draw_icon(self, ["stat_attack", "stat_defense", "stat_mobility"][i], r.grow(5), Color(1, 1, 1, col.a if col != T.INK_FAINT else 0.55)):
		return
	var c := r.get_center()
	var h := r.size.y * 0.5
	match i:
		0:
			Emblems.draw(self, "burst", r, col)
		1:
			var pts := PackedVector2Array([c + Vector2(-h * 0.8, -h * 0.75), c + Vector2(h * 0.8, -h * 0.75),
					c + Vector2(h * 0.75, h * 0.05), c + Vector2(0, h * 0.95), c + Vector2(-h * 0.75, h * 0.05)])
			draw_colored_polygon(pts, col)
			draw_line(c + Vector2(0, -h * 0.55), c + Vector2(0, h * 0.6), T.PAPER_LIGHT, 2.0, true)
		2:
			for k in 3:
				var y := c.y - h * 0.55 + k * h * 0.55
				draw_line(Vector2(r.position.x + k * 3.0, y), Vector2(r.end.x - 6.0, y), col, 3.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2(r.end.x - 9, c.y - h * 0.7), Vector2(r.end.x + 2, c.y), Vector2(r.end.x - 9, c.y + h * 0.7)]), col)

func _round_button(r: Rect2, glyph: String, enabled: bool, id: String) -> void:
	if enabled:
		_hits.append([r.grow(3), id])
	var hov := _hover == id and enabled
	var kname := "stepper_%s_%s" % ["minus" if glyph == "–" else "plus", "disabled" if not enabled else ("hover" if hov else "normal")]
	if Kit.draw_icon(self, kname, r.grow(3)):
		return
	draw_circle(r.get_center(), r.size.x * 0.5, T.INK if hov else (T.PAPER_LIGHT if enabled else Color(T.PAPER_DARK, 0.5)))
	draw_arc(r.get_center(), r.size.x * 0.5, 0, TAU, 24, T.INK if enabled else Color(T.INK, 0.3), 1.5, true)
	var f := T.font("heading")
	var w := f.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(f, r.get_center() + Vector2(-w / 2.0, 6), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			T.PAPER_LIGHT if hov else (T.INK if enabled else Color(T.INK, 0.3)))

## The bender's signature: animated art (windup → travel → impact) beside
## its name, what it does and its numbers.
func _draw_signature(r: Rect2) -> void:
	var sig := Specials.signature(fighter_id)
	var info := Specials.info(sig)
	var hf := T.font("heading")
	var lf := T.font("label")
	var bf := T.font("body")
	var df := T.font("display")
	var col := T.element_color(element)
	var o := float(T.ROD_OVERHANG) * 0.6
	Paint.paper_sheet(self, r, 23, T.PAPER_LIGHT)
	_hits.append([r, "card:0"])
	# art panel
	var art_r := Rect2(r.position + Vector2(22, 22), Vector2(r.size.y - 44, r.size.y - 44))
	Paint.wash(self, art_r, Color(T.element_wash(element).darkened(0.08), 0.95), false)
	var n := Specials.frames_in_row(sig)
	var seq_row := 0
	var seq_col := 0
	if n > 1:
		var k := int(_anim_t * 12.0) % (n * 3 + 6)   # windup, travel, impact, a short rest
		seq_row = mini(2, k / n)
		seq_col = k % n if k < n * 3 else n - 1
	else:
		var k := int(_anim_t * 2.5) % 3
		seq_row = k
	var tex := Specials.frame(sig, seq_row, seq_col)
	var s := minf(art_r.size.x, art_r.size.y) - 12.0
	draw_texture_rect(tex, Rect2(art_r.get_center() - Vector2(s, s) * 0.5, Vector2(s, s)), false)
	Paint.ink_frame(self, art_r, Color(T.INK, 0.6), 1.5, 31)
	# text
	var x := art_r.end.x + 24.0
	var w := r.end.x - x - 24.0
	var bender: Dictionary = Roster.get_fighter(fighter_id)
	draw_string(lf, Vector2(x, r.position.y + 40), "%s'S SIGNATURE  ·  KEY A" % str(bender.get("name", "BENDER")).to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, w, 12, T.VERMILION)
	draw_string(df, Vector2(x, r.position.y + 88), str(info.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, w, 46, col)
	draw_multiline_string(bf, Vector2(x, r.position.y + 118), str(info.get("desc", "")), HORIZONTAL_ALIGNMENT_LEFT, w, 16, 3, T.INK)
	# numbers
	var dmg := int(round(float(info.get("dmg", 0)) * Specials.damage_mult(build)))
	var status_name: String = Specials.STATUS_NAMES.get(str(info.get("status", "")), "")
	var facts := [
		["DAMAGE", "%d" % dmg],
		["RANGE", "%d px" % int(info.get("range", 0))],
		["COOLDOWN", "%d s" % int(info.get("cd", 0))],
		["LEAVES THEM", "%s  %.1f s" % [status_name, float(info.get("status_t", 0.0))]],
	]
	var fy := r.position.y + 182.0
	var fw := w / 4.0
	for i in facts.size():
		var fx := x + i * fw
		draw_string(lf, Vector2(fx, fy), facts[i][0], HORIZONTAL_ALIGNMENT_LEFT, fw - 8, 10, T.INK_SOFT)
		draw_string(hf, Vector2(fx, fy + 26), facts[i][1], HORIZONTAL_ALIGNMENT_LEFT, fw - 8, 19 if i < 3 else 15, T.INK)
	draw_line(Vector2(x, fy - 18), Vector2(x + w, fy - 18), Color(T.INK, 0.25), 1.0)
	var tip := "Fixed to your bender: every one has their own style. Jump to dodge a signature."
	draw_multiline_string(bf, Vector2(x, r.end.y - 52), tip, HORIZONTAL_ALIGNMENT_LEFT, w, 13, 2, T.INK_FAINT)
	Paint.vrod(self, r.position.x, r.position.y - o, r.end.y + o)
	Paint.vrod(self, r.end.x, r.position.y - o, r.end.y + o)
	if locked:
		draw_colored_polygon(Paint.brush_poly(r, 61), Color(T.PAPER_DARK, 0.3))
