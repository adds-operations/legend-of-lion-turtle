@tool
extends RefCounted

## Vector emblems drawn with CanvasItem primitives — no image assets needed,
## crisp at any size. Swap for illustrated icons later by replacing draw().
##
## Element emblems: "fire", "water", "earth", "air"
## Ability emblems: "bolt", "burst", "arc", "jump", "special", "lock"

const ELEMENT_KINDS := ["fire", "water", "earth", "air"]

static func draw(ci: CanvasItem, kind: String, rect: Rect2, color: Color) -> void:
	var c := rect.get_center()
	var r := minf(rect.size.x, rect.size.y) * 0.5
	match kind:
		"fire": _fire(ci, c, r, color)
		"water": _water(ci, c, r, color)
		"earth": _earth(ci, c, r, color)
		"air": _air(ci, c, r, color)
		"bolt": _bolt(ci, c, r, color)
		"burst": _burst(ci, c, r, color)
		"arc": _arc(ci, c, r, color)
		"jump": _jump(ci, c, r, color)
		"special": _special(ci, c, r, color)
		"lock": _lock(ci, c, r, color)
		_: ci.draw_circle(c, r * 0.4, color)

static func element_kind(element: int) -> String:
	return ELEMENT_KINDS[clampi(element, 0, 3)]

# --- elements -------------------------------------------------------------

static func _fire(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	# Outer flame with a curl, inner core.
	var pts := PackedVector2Array([
		c + Vector2(0.05, -1.0) * r, c + Vector2(0.45, -0.35) * r, c + Vector2(0.62, 0.15) * r,
		c + Vector2(0.48, 0.62) * r, c + Vector2(0.0, 0.9) * r, c + Vector2(-0.48, 0.62) * r,
		c + Vector2(-0.62, 0.12) * r, c + Vector2(-0.35, -0.4) * r, c + Vector2(-0.18, -0.05) * r,
	])
	ci.draw_colored_polygon(pts, col)
	var core := PackedVector2Array([
		c + Vector2(0.0, -0.15) * r, c + Vector2(0.28, 0.3) * r, c + Vector2(0.0, 0.68) * r,
		c + Vector2(-0.28, 0.3) * r,
	])
	ci.draw_colored_polygon(core, col.lightened(0.55))

static func _water(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	# Droplet over two waves.
	var drop := PackedVector2Array()
	drop.append(c + Vector2(0, -0.95) * r)
	for i in 13:
		var a := lerpf(-0.45, PI + 0.45, float(i) / 12.0)
		drop.append(c + Vector2(0, 0.0) * r + Vector2(cos(a), sin(a)) * r * 0.45)
	ci.draw_colored_polygon(drop, col)
	for k in 2:
		var y := 0.62 + k * 0.28
		var wave := PackedVector2Array()
		for i in 13:
			var t := float(i) / 12.0
			wave.append(c + Vector2(-0.8 + t * 1.6, y + sin(t * TAU) * 0.08) * r)
		ci.draw_polyline(wave, col, maxf(2.0, r * 0.12), true)

static func _earth(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	# Faceted stone block with a highlight face.
	var outer := PackedVector2Array([
		c + Vector2(-0.75, -0.35) * r, c + Vector2(-0.2, -0.85) * r, c + Vector2(0.65, -0.6) * r,
		c + Vector2(0.85, 0.2) * r, c + Vector2(0.35, 0.85) * r, c + Vector2(-0.6, 0.7) * r,
	])
	ci.draw_colored_polygon(outer, col)
	var face := PackedVector2Array([
		c + Vector2(-0.75, -0.35) * r, c + Vector2(-0.2, -0.85) * r, c + Vector2(0.65, -0.6) * r,
		c + Vector2(0.1, -0.15) * r,
	])
	ci.draw_colored_polygon(face, col.lightened(0.35))
	ci.draw_line(c + Vector2(0.1, -0.15) * r, c + Vector2(0.35, 0.85) * r, col.darkened(0.35), maxf(1.5, r * 0.07))

static func _air(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	# Three-armed spiral.
	var w := maxf(2.0, r * 0.14)
	for k in 3:
		var base := TAU * k / 3.0
		var pts := PackedVector2Array()
		for i in 16:
			var t := float(i) / 15.0
			var a := base + t * 2.3
			pts.append(c + Vector2(cos(a), sin(a)) * r * (0.12 + t * 0.78))
		ci.draw_polyline(pts, col, w, true)
	ci.draw_circle(c, r * 0.14, col)

# --- abilities ------------------------------------------------------------

static func _bolt(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([
		c + Vector2(-0.85, 0.0) * r, c + Vector2(-0.2, -0.38) * r, c + Vector2(0.5, -0.38) * r,
		c + Vector2(0.9, 0.0) * r, c + Vector2(0.5, 0.38) * r, c + Vector2(-0.2, 0.38) * r,
	])
	ci.draw_colored_polygon(pts, col)
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(0.0, 0.0) * r, c + Vector2(0.35, -0.16) * r, c + Vector2(0.62, 0.0) * r,
		c + Vector2(0.35, 0.16) * r]), col.lightened(0.6))

static func _burst(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a), sin(a)) * r * (0.85 if i % 2 == 0 else 0.42))
	ci.draw_colored_polygon(pts, col)

static func _arc(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_arc(c + Vector2(-0.35, 0) * r, r * 0.85, -1.0, 1.0, 16, col, maxf(3.0, r * 0.22), true)
	ci.draw_arc(c + Vector2(-0.35, 0) * r, r * 0.5, -0.9, 0.9, 12, col.lightened(0.4), maxf(2.0, r * 0.12), true)

static func _jump(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var w := maxf(2.5, r * 0.18)
	for k in 2:
		var y := -0.1 + k * 0.45
		ci.draw_polyline(PackedVector2Array([
			c + Vector2(-0.55, y + 0.3) * r, c + Vector2(0, y - 0.2) * r, c + Vector2(0.55, y + 0.3) * r]),
			col if k == 0 else Color(col, 0.55), w, true)

static func _special(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -0.9) * r, c + Vector2(0.62, 0) * r, c + Vector2(0, 0.9) * r, c + Vector2(-0.62, 0) * r]), col)
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -0.45) * r, c + Vector2(0.3, 0) * r, c + Vector2(0, 0.45) * r, c + Vector2(-0.3, 0) * r]),
		col.lightened(0.6))

static func _lock(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var w := maxf(2.0, r * 0.14)
	ci.draw_arc(c + Vector2(0, -0.15) * r, r * 0.32, PI, TAU, 12, col, w, true)
	ci.draw_rect(Rect2(c + Vector2(-0.48, -0.15) * r, Vector2(0.96, 0.75) * r), col)
