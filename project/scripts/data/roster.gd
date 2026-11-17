@tool
extends RefCounted

## The playable benders (assets/avatar_characters, pack v2).
## Mirrors assets/avatar_characters/roster.json as code so it also works in
## exported builds (JSON files are not exported by default).
##
## Each SpriteFrames resource has 8 actions × 4 directions:
##   idle, walk, strike, jump_start, airborne, land, hit, defeat
##   + _south / _west / _east / _north
## Frames are 96×96 with the ground point at (48, 80).

const FRAME_OFFSET := Vector2(-48, -80)  # AnimatedSprite2D.offset with centered = false
const BODY_HEIGHT := 58.0                # visible character height in px at 1×

## Element index (GameManager.Element) → its two benders, default first.
const FIGHTERS := [
	{"id": "ember_captain", "name": "Ember Captain", "element": 0, "origin": "Fire Nation duelist"},
	{"id": "sun_student", "name": "Sun Student", "element": 0, "origin": "Sun Warrior student"},
	{"id": "ice_guard", "name": "Ice Guard", "element": 1, "origin": "Northern Water Tribe guard"},
	{"id": "tide_runner", "name": "Tide Runner", "element": 1, "origin": "Southern Water Tribe runner"},
	{"id": "stone_warden", "name": "Stone Warden", "element": 2, "origin": "Earth Kingdom warden"},
	{"id": "sand_outrider", "name": "Sand Outrider", "element": 2, "origin": "Si Wong Desert sandbender"},
	{"id": "temple_courier", "name": "Temple Courier", "element": 3, "origin": "Air Nomad courier"},
	{"id": "cloud_keeper", "name": "Cloud Keeper", "element": 3, "origin": "Air Nomad bison keeper"},
]

static var _frames_cache: Dictionary = {}

static func for_element(element: int) -> Array:
	var out: Array = []
	for f in FIGHTERS:
		if f["element"] == element:
			out.append(f)
	return out

static func default_for(element: int) -> String:
	return for_element(element)[0]["id"]

static func get_fighter(id: String) -> Dictionary:
	for f in FIGHTERS:
		if f["id"] == id:
			return f
	return {}

static func is_valid(id: String, element: int) -> bool:
	var f := get_fighter(id)
	return not f.is_empty() and f["element"] == element

static func frames_path(id: String) -> String:
	return "res://assets/avatar_characters/%s.tres" % id

## SpriteFrames for a bender, or null if the art is missing.
static func frames(id: String) -> SpriteFrames:
	if _frames_cache.has(id):
		return _frames_cache[id]
	var path := frames_path(id)
	var sf: SpriteFrames = load(path) if ResourceLoader.exists(path) else null
	_frames_cache[id] = sf
	return sf

const TransformFrames = preload("res://assets/avatar_transformation/avatar_transformation_frames.gd")
static var _fighter_frames_cache: Dictionary = {}

static func transformation_path(id: String) -> String:
	return "res://assets/avatar_transformation/fighters/%s_avatar.tres" % id

## The bender's SpriteFrames with the Raava transformation animations merged
## in (raava_channel_*, raava_fusion_*, avatar_ready_*). A fighter-local copy:
## the character pack's own resource is never modified.
static func fighter_frames(id: String) -> SpriteFrames:
	if _fighter_frames_cache.has(id):
		return _fighter_frames_cache[id]
	var base := frames(id)
	var out := base
	var tp := transformation_path(id)
	if base and ResourceLoader.exists(tp):
		out = TransformFrames.combine(base, load(tp))
	_fighter_frames_cache[id] = out
	return out

## A single still (e.g. idle_south) for portraits in the UI.
static func still(id: String, anim: String = "idle_south") -> Texture2D:
	var sf := frames(id)
	if sf == null or not sf.has_animation(anim):
		return null
	return sf.get_frame_texture(anim, 0)

## 4-way facing from a direction vector (screen space, +y = south).
static func facing(dir: Vector2) -> String:
	if dir.length_squared() < 0.0001:
		return "south"
	if absf(dir.x) > absf(dir.y):
		return "east" if dir.x > 0.0 else "west"
	return "south" if dir.y > 0.0 else "north"
