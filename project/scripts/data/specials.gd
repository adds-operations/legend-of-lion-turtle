extends RefCounted

## Builds and signature attacks.
##
## Build: 8 points over Attack / Defense / Mobility, 0–5 each. Points only
## make you stronger; they never change which power you have.
##   Attack   +5% damage per point
##   Defense  4% less damage taken per point (all reduction capped at 50%)
##   Mobility +4% movement speed per point
##
## Signature (key A): every bender has one fixed signature attack — their
## bending style. Long range, much stronger than Z X C V, and it leaves the
## rival with a status (shocked, burning, frozen, soaked, stunned, buried,
## winded, swept up).
##
## Art: assets/avatar_bending/signatures/<id>.png when present (128 px cells,
## 8 frames × 4 rows: windup, travel, impact, status). Until then each one
## borrows a row of the specials pack (`placeholder` = [element, row]).

const POINTS := 8
const MAX_STAT := 5
const STATS := ["atk", "def", "mob"]
const STAT_NAMES := ["ATTACK", "DEFENSE", "MOBILITY"]

## Bender → signature.
const SIGNATURES := {
	"ember_captain": "thunder_strike",
	"sun_student": "sun_dragon",
	"ice_guard": "glacier_prison",
	"tide_runner": "tidal_surge",
	"stone_warden": "pillar_eruption",
	"sand_outrider": "sand_tomb",
	"temple_courier": "air_cannon",
	"cloud_keeper": "tornado_lift",
}

## Statuses: what they do and how they read on the HUD.
##   stun   can't move or act          lift  swept up: can't move or act
##   freeze rooted (can still attack)  bury  rooted (can still attack)
##   soak   45% slower                 wind  can't attack, 25% slower
##   burn   4 damage every 0.5 s
const STATUS_NAMES := {
	"stun": "STUNNED", "shock": "SHOCKED", "lift": "SWEPT UP", "freeze": "FROZEN",
	"bury": "BURIED", "soak": "SOAKED", "wind": "WINDED", "burn": "BURNING",
}

## mode: bolt   instant line after the windup (walls stop it)
##       shot   a power flying along the aim, stops at the first fighter
##       ground erupts out of the ground along the aim (jump to dodge), pierces
##       wave   a wide wave / funnel rolling along the ground, pierces
##              (unless "single": stops at the first fighter)
## Every signature hits only fighters on the ground: jumping is the dodge.
const DATA := {
	"thunder_strike": {"name": "Thunder Strike", "element": 0, "mode": "bolt",
		"desc": "A split-second charge, then lightning across the arena.",
		"windup": 0.3, "range": 620.0, "width": 18.0, "dmg": 40, "knock": 40.0,
		"status": "shock", "status_t": 1.0, "cd": 16.0, "placeholder": [0, 2]},
	"sun_dragon": {"name": "Sun Dragon", "element": 0, "mode": "shot",
		"desc": "A fire dragon that flies far and sets the rival burning.",
		"windup": 0.25, "range": 640.0, "speed": 540.0, "r": 22.0, "dmg": 30, "knock": 60.0,
		"status": "burn", "status_t": 3.0, "cd": 16.0, "placeholder": [0, 3]},
	"glacier_prison": {"name": "Glacier Prison", "element": 1, "mode": "ground",
		"desc": "Ice spikes burst from the ground in a line and freeze the rival in place.",
		"windup": 0.25, "range": 560.0, "speed": 600.0, "r": 22.0, "dmg": 28, "knock": 0.0,
		"status": "freeze", "status_t": 1.5, "cd": 16.0, "placeholder": [1, 1]},
	"tidal_surge": {"name": "Tidal Surge", "element": 1, "mode": "wave",
		"desc": "Pulls water up into a great wave that rolls the rival back and soaks them.",
		"windup": 0.25, "range": 560.0, "speed": 430.0, "r": 36.0, "dmg": 30, "knock": 130.0,
		"status": "soak", "status_t": 3.5, "cd": 16.0, "placeholder": [1, 4]},
	"pillar_eruption": {"name": "Pillar Eruption", "element": 2, "mode": "ground",
		"desc": "Stone pillars erupt from the ground toward the rival and stun them.",
		"windup": 0.25, "range": 540.0, "speed": 560.0, "r": 24.0, "dmg": 38, "knock": 50.0,
		"status": "stun", "status_t": 0.9, "cd": 17.0, "placeholder": [2, 1]},
	"sand_tomb": {"name": "Sand Tomb", "element": 2, "mode": "wave", "single": true,
		"desc": "A sand serpent skims the ground and buries the rival to the knees.",
		"windup": 0.25, "range": 600.0, "speed": 470.0, "r": 26.0, "dmg": 28, "knock": 0.0,
		"status": "bury", "status_t": 1.6, "cd": 16.0, "placeholder": [2, 4]},
	"air_cannon": {"name": "Air Cannon", "element": 3, "mode": "shot",
		"desc": "A compressed air sphere that blasts the rival far back and winds them.",
		"windup": 0.22, "range": 700.0, "speed": 700.0, "r": 20.0, "dmg": 28, "knock": 230.0,
		"status": "wind", "status_t": 2.0, "cd": 15.0, "placeholder": [3, 1]},
	"tornado_lift": {"name": "Tornado Lift", "element": 3, "mode": "wave",
		"desc": "A travelling tornado that sweeps the rival off their feet.",
		"windup": 0.25, "range": 560.0, "speed": 340.0, "r": 30.0, "dmg": 32, "knock": 0.0,
		"status": "lift", "status_t": 1.2, "cd": 17.0, "placeholder": [3, 0]},
}

const SHEET_DIR := "res://assets/avatar_bending/signatures/"

static func signature(fighter_id: String) -> String:
	return SIGNATURES.get(fighter_id, "thunder_strike")

static func info(id: String) -> Dictionary:
	return DATA.get(id, {})

static func empty_build() -> Dictionary:
	return {"atk": 0, "def": 0, "mob": 0}

static func spent(build: Dictionary) -> int:
	return int(build.get("atk", 0)) + int(build.get("def", 0)) + int(build.get("mob", 0))

## Host: a legal copy of `build` (stats only).
static func sanitize(build: Dictionary) -> Dictionary:
	var b := empty_build()
	var left := POINTS
	for s in STATS:
		var v := clampi(int(build.get(s, 0)), 0, MAX_STAT)
		v = mini(v, left)
		b[s] = v
		left -= v
	return b

static func damage_mult(build: Dictionary) -> float:
	return 1.0 + 0.05 * int(build.get("atk", 0))

static func reduction(build: Dictionary) -> float:
	return 0.04 * int(build.get("def", 0))

static func speed_mult(build: Dictionary) -> float:
	return 1.0 + 0.04 * int(build.get("mob", 0))

static func summary(build: Dictionary, fighter_id: String = "") -> String:
	var s := "ATK %d · DEF %d · MOB %d" % [int(build.get("atk", 0)), int(build.get("def", 0)), int(build.get("mob", 0))]
	if fighter_id != "":
		s += " · A: " + str(info(signature(fighter_id)).get("name", ""))
	return s

# --- Art ---------------------------------------------------------------------

static var _sheets: Dictionary = {}
static var _frames: Dictionary = {}

## The signature's own sheet (or null until the art pack is installed).
static func sheet(id: String) -> Texture2D:
	if not _sheets.has(id):
		var p := SHEET_DIR + id + ".png"
		_sheets[id] = load(p) if ResourceLoader.exists(p) else null
	return _sheets[id]

## A 128 px frame: row 0 windup, 1 travel, 2 impact, 3 status; col 0–7.
## Without the sheet, falls back to the placeholder specials-pack row
## (columns 0–2 there: windup / active / finish).
static func frame(id: String, row: int, col: int) -> Texture2D:
	var key := "%s:%d:%d" % [id, row, col]
	if _frames.has(key):
		return _frames[key]
	var t := AtlasTexture.new()
	var sh := sheet(id)
	if sh:
		t.atlas = sh
		t.region = Rect2(col * 128, row * 128, 128, 128)
	else:
		var ph: Array = info(id).get("placeholder", [0, 0])
		var pcol: int = [0, 1, 2, 1][clampi(row, 0, 3)]
		t = BendingFXRef.frame(ph[0], [ph[1], pcol])
	_frames[key] = t
	return t

static func has_sheet(id: String) -> bool:
	return sheet(id) != null

## Frames in a row of the real sheet (8), or 1 for the placeholder.
static func frames_in_row(id: String) -> int:
	return 8 if has_sheet(id) else 1

const BendingFXRef = preload("res://scripts/fx/bending_fx.gd")
