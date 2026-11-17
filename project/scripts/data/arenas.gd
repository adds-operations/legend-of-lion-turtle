@tool
extends RefCounted

## The playable arenas (assets/avatar_arenas, waterways pack).
## Mirrors assets/avatar_arenas/arenas.json as code so it also works in
## exported builds. Each arena scene is an AvatarArenaLayout (960×640 art,
## its own play rect, spawns, water, bendable ground, sources, Raava points).

const CANVAS := Vector2(960, 640)
## Physics layers used by the pack's scenes and what this game remaps them to.
const PACK_COVER_LAYER := 2      # pack: SolidCover
const PACK_BOUNDARY_LAYER := 4   # pack: Boundary
const GAME_OBSTACLES_LAYER := 8  # project layer 4 "Obstacles"
const GAME_WALLS_LAYER := 4      # project layer 3 "Walls"

const NATION_NAMES := {"earth": "Earth Kingdom", "water": "Water Tribes", "fire": "Fire Nation", "air": "Air Nomads"}

const ARENAS := [
	{"id": "jade_lotus_court", "name": "Jade Lotus Court", "nation": "earth", "layout": "vertical lotus canal"},
	{"id": "badgermole_quarry", "name": "Badgermole Quarry", "nation": "earth", "layout": "diagonal creek"},
	{"id": "reedstone_marsh", "name": "Reedstone Marsh", "nation": "earth", "layout": "forked river"},
	{"id": "amber_bamboo_ruins", "name": "Amber Bamboo Ruins", "nation": "earth", "layout": "west-to-southeast elbow"},
	{"id": "moon_oasis", "name": "Moon Oasis", "nation": "water", "layout": "northeast-to-southwest creek"},
	{"id": "glacier_switchback", "name": "Glacier Switchback", "nation": "water", "layout": "glacial S-bend"},
	{"id": "tideglass_harbor", "name": "Tideglass Harbor", "nation": "water", "layout": "tidal channels"},
	{"id": "southern_thaw", "name": "Southern Thaw", "nation": "water", "layout": "offset ice channels"},
	{"id": "obsidian_forge", "name": "Obsidian Forge", "nation": "fire", "layout": "offset forge run"},
	{"id": "ember_terrace", "name": "Ember Terrace", "nation": "fire", "layout": "perimeter U-channel"},
	{"id": "black_sand_basin", "name": "Black Sand Basin", "nation": "fire", "layout": "split ravine stream"},
	{"id": "lantern_aqueduct", "name": "Lantern Aqueduct", "nation": "fire", "layout": "aqueduct runs"},
	{"id": "cloudbell_court", "name": "Cloudbell Court", "nation": "air", "layout": "diagonal temple spillway"},
	{"id": "windstep_garden", "name": "Windstep Garden", "nation": "air", "layout": "mountain stream"},
	{"id": "bison_rest", "name": "Bison Rest", "nation": "air", "layout": "meadow bend"},
	{"id": "summit_cistern", "name": "Summit Cistern", "nation": "air", "layout": "cistern spillway"},
]

const DEFAULT_ID := "jade_lotus_court"

static func ids() -> Array:
	var out: Array = []
	for a in ARENAS:
		out.append(a["id"])
	return out

static func get_arena(id: String) -> Dictionary:
	for a in ARENAS:
		if a["id"] == id:
			return a
	return {}

static func is_valid(id: String) -> bool:
	return not get_arena(id).is_empty()

static func scene_path(id: String) -> String:
	return "res://assets/avatar_arenas/scenes/%s.tscn" % id

static func art_path(id: String) -> String:
	return "res://assets/avatar_arenas/art/%s.png" % id

static func display_name(id: String) -> String:
	return str(get_arena(id).get("name", id))

static func nation_name(id: String) -> String:
	return str(NATION_NAMES.get(get_arena(id).get("nation", ""), ""))

## Next / previous arena id, wrapping around.
static func step(id: String, delta: int) -> String:
	var list := ids()
	var i := list.find(id)
	if i < 0:
		return DEFAULT_ID
	return list[(i + delta + list.size()) % list.size()]
