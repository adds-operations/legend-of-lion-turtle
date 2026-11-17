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
