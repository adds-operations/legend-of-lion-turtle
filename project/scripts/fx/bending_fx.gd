extends RefCounted

## How every attack looks, drawn from the special-powers pack
## (assets/avatar_bending/specials/<element>_specials.png: 5 rows × 3 cells,
## 128 × 128, columns = windup / active / finish).
##
## Rows per element sheet:
##   fire  0 fire rings   1 fire wave    2 lightning   3 combustion   4 flame guard
##   water 0 octopus      1 ice barrier  2 bloodbend   3 healing      4 water surge
##   earth 0 earth armor  1 ground slam  2 lava        3 metal shell  4 earth surf
##   air   0 tornado      1 repulsion    2 air sphere  3 spirit form  4 air barrier
##
## A frame is [row, col] or [row, col, Rect2 crop inside that cell].
## FX[element][slot] keys:
##   fly      frame for the thrown power          scale   draw scale
##   orient   rotate to the travel direction      spin    radians / s
##   upright  stands on the ground (walls, funnels) instead of flying at chest height
##   drop     frame left along the path (line attacks), every `every` px
##   hit      frame shown where it lands          hit_scale
##   wind     windup frame shown at the hands as it's thrown
##   beam     frame stretched along a beam        burst  frame expanding around the caster

const SHEETS := [
	"res://assets/avatar_bending/specials/fire_specials.png",
	"res://assets/avatar_bending/specials/water_specials.png",
	"res://assets/avatar_bending/specials/earth_specials.png",
	"res://assets/avatar_bending/specials/air_specials.png",
]
const CELL := 128

const FX := [
	[  # Fire
		{"fly": [3, 0, Rect2(40, 40, 48, 48)], "scale": 1.5, "wind": [3, 0], "hit": [3, 2], "hit_scale": 0.5},                          # Q Fire Bolt: a blazing orb
		{"fly": [4, 1, Rect2(18, 4, 92, 120)], "scale": 0.42, "orient": true, "wind": [4, 0], "hit": [0, 2], "hit_scale": 0.45},     # W Flame Burst: three flame crescents
		{"fly": [1, 1, Rect2(4, 40, 120, 48)], "scale": 0.85, "upright": true, "wind": [1, 0], "hit": [1, 2], "hit_scale": 0.7},      # E Fire Wave: a wall of flame
		{"beam": [2, 1, Rect2(4, 40, 120, 48)], "wind": [2, 0], "hit": [2, 2], "hit_scale": 0.65},                                     # R Lightning
	],
	[  # Water
		{"fly": [4, 1, Rect2(4, 40, 120, 56)], "scale": 0.7, "orient": true, "wind": [4, 0], "hit": [4, 2], "hit_scale": 0.55},      # Q Water Lash
		{"fly": [1, 2, Rect2(62, 44, 60, 32)], "scale": 0.95, "orient": true, "wind": [1, 0], "hit": [1, 2], "hit_scale": 0.45},     # W Ice Shard
		{"fly": [0, 1], "scale": 0.58, "upright": true, "wind": [0, 0], "hit": [0, 2], "hit_scale": 0.6},                            # E Pushing Wave
		{"drop": [1, 1], "every": 32.0, "drop_scale": 0.48, "wind": [1, 0], "hit": [1, 2], "hit_scale": 0.5},                         # R Ice Spikes
	],
	[  # Earth
		{"fly": [0, 2, Rect2(4, 24, 32, 44)], "scale": 0.95, "spin": 7.0, "wind": [0, 0], "hit": [1, 2], "hit_scale": 0.4},          # Q Stone Shot
		{"fly": [0, 1, Rect2(12, 30, 48, 72)], "scale": 0.95, "spin": 5.0, "wind": [0, 0], "hit": [1, 2], "hit_scale": 0.65},        # W Boulder
		{"drop": [0, 0], "every": 28.0, "drop_scale": 0.5, "wind": [1, 0], "hit": [1, 2], "hit_scale": 0.55},                         # E Shockwave
		{"burst": [1, 1], "wind": [1, 0], "hit": [1, 2], "hit_scale": 0.9},                                                           # R Ground Slam
	],
	[  # Air
		{"fly": [2, 0, Rect2(34, 34, 60, 60)], "scale": 0.75, "spin": 9.0, "wind": [2, 0], "hit": [2, 2], "hit_scale": 0.45},        # Q Air Jab
		{"fly": [4, 1, Rect2(30, 0, 98, 128)], "scale": 0.42, "orient": true, "wind": [4, 0], "hit": [4, 2], "hit_scale": 0.45},     # W Compressed Gust
		{"burst": [1, 1], "wind": [1, 0], "hit": [1, 2], "hit_scale": 1.0},                                                           # E Knockback Blast
		{"fly": [0, 1], "scale": 0.72, "upright": true, "wind": [0, 0], "hit": [0, 2], "hit_scale": 0.6},                            # R Tornado
	],
]

static var _cache: Dictionary = {}

## Animated attacks. Each part of an attack (windup at the hands, travel,
## impact, trail) plays an 8-frame row of a 128 px sheet:
##   1. assets/avatar_bending/attacks/<id>.png (a dedicated pack: rows 0 windup,
##      1 travel, 2 impact, 3 trail), when installed;
##   2. otherwise rows borrowed from the signature pack
##      (assets/avatar_bending/signatures/), drawn smaller than the signatures.
## A part is [sheet id, row] or [sheet id, row, fixed column] (a still frame
## that spins, e.g. a flung rock).
const ATTACK_IDS := [
	["fire_bolt", "flame_burst", "fire_wave", "lightning"],
	["water_lash", "ice_shard", "pushing_wave", "ice_spikes"],
	["stone_shot", "boulder", "shockwave", "ground_slam"],
	["air_jab", "compressed_gust", "knockback_blast", "tornado"],
]
const ATTACK_DIR := "res://assets/avatar_bending/attacks/"
const SIG_DIR := "res://assets/avatar_bending/signatures/"
## Borrowed animation per attack: w windup, t travel, i impact, s scale, spin.
const BORROWED := [
	[  # Fire
		{"w": ["sun_dragon", 0], "t": ["sun_dragon", 0], "i": ["sun_dragon", 2], "s": 0.36},                  # Fire Bolt: a spinning fire spiral
		{"w": ["sun_dragon", 0], "t": ["sun_dragon", 1], "i": ["sun_dragon", 2], "s": 0.28},                  # Flame Burst: three little fire dragons
		{"w": ["sun_dragon", 0], "t": ["sun_dragon", 3], "i": ["sun_dragon", 2], "s": 1.0},                   # Fire Wave: a rolling wall of flame
		{"w": ["thunder_strike", 0], "t": ["thunder_strike", 1], "i": ["thunder_strike", 2], "s": 0.34},      # Lightning: a thinner bolt
	],
	[  # Water (pulled up out of the ground first)
		{"w": ["water_draw", 0], "t": ["water_draw", 3], "i": ["tidal_surge", 2], "s": 0.55},                 # Water Lash: a jet of water
		{"w": ["water_draw", 0], "t": ["glacier_prison", 0], "i": ["glacier_prison", 2], "s": 0.32},          # Ice Shard: a spinning ice ring
		{"w": ["water_draw", 0], "t": ["tidal_surge", 1], "i": ["tidal_surge", 2], "s": 0.5},                 # Pushing Wave
		{"w": ["water_draw", 0], "t": ["glacier_prison", 1], "i": ["glacier_prison", 2], "s": 0.42},          # Ice Spikes: out of the ground
	],
	[  # Earth (rock breaks out of the ground first)
		{"w": ["earth_rise", 0], "t": ["earth_rise", 0, 7], "i": ["earth_rise", 3], "s": 0.55, "spin": 9.0},  # Stone Shot: a flung rock
		{"w": ["earth_rise", 0], "t": ["pillar_eruption", 0, 7], "i": ["pillar_eruption", 2], "s": 0.5, "spin": 5.0},  # Boulder: a flung slab
		{"w": ["earth_rise", 0], "t": ["earth_rise", 2], "i": ["earth_rise", 3], "s": 0.5},                   # Shockwave: spikes out of the ground
		{"w": ["earth_rise", 0], "t": ["earth_rise", 2], "i": ["earth_rise", 3], "s": 0.55},                  # Ground Slam: a ring of spikes all around
	],
	[  # Air
		{"w": ["air_cannon", 0], "t": ["air_cannon", 1], "i": ["air_cannon", 2], "s": 0.3},                   # Air Jab
		{"w": ["air_cannon", 0], "t": ["air_cannon", 0], "i": ["air_cannon", 2], "s": 0.38},                  # Compressed Gust
		{"w": ["air_cannon", 0], "t": ["air_cannon", 2], "i": ["air_cannon", 3], "s": 0.5},                   # Knockback Blast: the shockwave ring
		{"w": ["tornado_lift", 0], "t": ["tornado_lift", 1], "i": ["tornado_lift", 2], "s": 0.42},            # Tornado: a smaller funnel
	],
]
static var _sheets: Dictionary = {}
static var _specs: Dictionary = {}

static func _sheet(path: String) -> Texture2D:
	if not _sheets.has(path):
		_sheets[path] = load(path) if ResourceLoader.exists(path) else null
	return _sheets[path]

## {"w": [tex,row,col], "t": [...], "i": [...], "tr": [...] or [], "s": scale, "spin": rate}
## or {} when no animated art is installed for this attack.
static func anim_spec(element: int, slot: int) -> Dictionary:
	var key := element * 4 + slot
	if _specs.has(key):
		return _specs[key]
	var out := {}
	var id: String = ATTACK_IDS[clampi(element, 0, 3)][clampi(slot, 0, 3)]
	var own := _sheet(ATTACK_DIR + id + ".png")
	if own:
		out = {"w": [own, 0, -1], "t": [own, 1, -1], "i": [own, 2, -1], "tr": [own, 3, -1], "s": 0.5, "spin": 0.0}
	else:
		var b: Dictionary = BORROWED[clampi(element, 0, 3)][clampi(slot, 0, 3)]
		var parts := {}
		var ok := true
		for k in ["w", "t", "i"]:
			var p: Array = b[k]
			var tex := _sheet(SIG_DIR + str(p[0]) + ".png")
			if tex == null:
				ok = false
				break
			parts[k] = [tex, int(p[1]), int(p[2]) if p.size() > 2 else -1]
		if ok:
			out = parts
			out["tr"] = []
			out["s"] = float(b["s"])
			out["spin"] = float(b.get("spin", 0.0))
	_specs[key] = out
	return out

## The frame of a part at time t (fixed column parts stay on one frame).
static func part_frame(part: Array, t: float, fps: float = 14.0, loop: bool = true) -> AtlasTexture:
	var col: int = part[2] if part[2] >= 0 else (int(t * fps) % 8 if loop else mini(7, int(t * fps)))
	var key := "p%d:%d:%d" % [part[0].get_instance_id(), part[1], col]
	if _cache.has(key):
		return _cache[key]
	var a := AtlasTexture.new()
	a.atlas = part[0]
	a.region = Rect2(col * CELL, int(part[1]) * CELL, CELL, CELL)
	_cache[key] = a
	return a

static func fx(element: int, slot: int) -> Dictionary:
	return FX[clampi(element, 0, 3)][clampi(slot, 0, 3)]

## AtlasTexture for a frame spec ([row, col] or [row, col, crop]).
static func frame(element: int, spec: Array) -> AtlasTexture:
	var key := "%d:%s" % [element, str(spec)]
	if _cache.has(key):
		return _cache[key]
	var t := AtlasTexture.new()
	t.atlas = load(SHEETS[clampi(element, 0, 3)])
	var cell := Rect2(spec[1] * CELL, spec[0] * CELL, CELL, CELL)
	if spec.size() > 2:
		var c: Rect2 = spec[2]
		cell = Rect2(cell.position + c.position, c.size)
	t.region = cell
	t.filter_clip = true
	_cache[key] = t
	return t

## The art that represents an attack (HUD tiles, lobby): its main frame.
static func icon(element: int, slot: int) -> AtlasTexture:
	var f := fx(element, slot)
	for k in ["fly", "beam", "drop", "burst"]:
		if f.has(k):
			return frame(element, f[k])
	return null
