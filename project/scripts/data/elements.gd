@tool
extends RefCounted

## Player-facing element info (lobby cards, HUD). Index = GameManager.Element.
## Attack names follow docs/game-design-spec.md §5. Keys follow §4.

const KEYS := ["Z", "X", "C", "V"]
## Input actions for the four attack keys.
const ACTIONS := ["attack_1", "attack_2", "attack_3", "attack_4"]

const INFO := [
	{
		"name": "FIRE",
		"tagline": "Relentless pressure. Fast bolts, explosive bursts.",
		"attacks": ["Fire Bolt", "Flame Burst", "Fire Wave", "Lightning"],
		"emblems": ["bolt", "burst", "arc", "special"],
	},
	{
		"name": "WATER",
		"tagline": "Flowing control. Lash, push and punish mistakes.",
		"attacks": ["Water Lash", "Ice Shard", "Pushing Wave", "Ice Spikes"],
		"emblems": ["bolt", "burst", "arc", "special"],
	},
	{
		"name": "EARTH",
		"tagline": "Heavy hitter. Big damage that shapes the arena.",
		"attacks": ["Stone Shot", "Boulder", "Shockwave", "Ground Slam"],
		"emblems": ["bolt", "burst", "arc", "special"],
	},
	{
		"name": "AIR",
		"tagline": "Evasive and tricky. Knock rivals out of position.",
		"attacks": ["Air Jab", "Compressed Gust", "Knockback Blast", "Tornado"],
		"emblems": ["bolt", "burst", "arc", "special"],
	},
]

## All four attacks of every element are in the game.
const IMPLEMENTED_ATTACKS := 4

## Attack tuning: ATTACKS[element][slot]. How each one looks is in
## scripts/fx/bending_fx.gd (sprites from the special-powers pack).
##   kind     "shot"  a power thrown straight ahead (the default)
##            "line"  a power that erupts along the ground ahead (ice spikes, shockwave)
##            "beam"  instant along a line up to `range` px, `width` wide (lightning)
##            "burst" everything within `radius` px of the caster (slam, blast)
##   dmg      damage per hit            speed   px/s           cd    cooldown s
##   r        hit radius                count   powers thrown  spread  fan in degrees
##   knock    push on hit, px (bursts push away from the caster)
##   life     seconds                   pierce  passes through fighters
##   tick     with pierce: seconds between repeat hits on the same fighter
const ATTACKS := [
	[  # Fire — relentless pressure
		{"dmg": 10, "speed": 470.0, "cd": 0.35, "r": 8.0},
		{"dmg": 7, "speed": 430.0, "cd": 1.1, "r": 8.0, "count": 3, "spread": 18.0},
		{"dmg": 14, "speed": 300.0, "cd": 2.2, "r": 22.0, "knock": 30.0, "pierce": true, "tick": 9.0, "life": 0.9},
		{"kind": "beam", "dmg": 26, "cd": 4.0, "range": 360.0, "width": 16.0},
	],
	[  # Water — flowing control
		{"dmg": 9, "speed": 460.0, "cd": 0.35, "r": 10.0, "life": 0.6},
		{"dmg": 14, "speed": 580.0, "cd": 1.0, "r": 7.0},
		{"dmg": 10, "speed": 280.0, "cd": 2.2, "r": 22.0, "knock": 90.0, "pierce": true, "tick": 9.0, "life": 1.0},
		{"kind": "line", "dmg": 18, "speed": 420.0, "cd": 3.8, "r": 18.0, "pierce": true, "tick": 9.0, "life": 0.5},
	],
	[  # Earth — heavy hitter
		{"dmg": 13, "speed": 390.0, "cd": 0.5, "r": 9.0},
		{"dmg": 24, "speed": 260.0, "cd": 1.6, "r": 15.0, "knock": 50.0},
		{"kind": "line", "dmg": 14, "speed": 360.0, "cd": 2.4, "r": 20.0, "pierce": true, "tick": 9.0, "life": 0.6},
		{"kind": "burst", "dmg": 22, "cd": 4.5, "radius": 95.0, "knock": 80.0},
	],
	[  # Air — evasive, pushes you around
		{"dmg": 8, "speed": 640.0, "cd": 0.3, "r": 8.0},
		{"dmg": 10, "speed": 480.0, "cd": 1.0, "r": 13.0, "knock": 70.0},
		{"kind": "burst", "dmg": 10, "cd": 2.6, "radius": 105.0, "knock": 160.0},
		{"dmg": 6, "speed": 190.0, "cd": 4.5, "r": 22.0, "pierce": true, "tick": 0.4, "life": 2.4, "knock": 25.0},
	],
]

## One attack's full tuning, with defaults filled in.
static func attack(element: int, slot: int) -> Dictionary:
	var a: Dictionary = {"kind": "shot", "dmg": 10, "speed": 420.0, "cd": 0.4, "r": 7.0, "count": 1, "spread": 0.0,
			"knock": 0.0, "life": 1.6, "pierce": false, "tick": 0.5, "range": 300.0, "width": 14.0, "radius": 90.0}
	a.merge(ATTACKS[clampi(element, 0, 3)][clampi(slot, 0, 3)], true)
	a["name"] = INFO[clampi(element, 0, 3)]["attacks"][clampi(slot, 0, 3)]
	return a

## What key `key` (0–3 = Z X C V) throws: [element, attack slot, cooldown multiplier].
## The Avatar's keys are Fire, Water, Earth and Air, each throwing that
## element's best power (its 4th attack) at half the cooldown.
static func attack_for(active_element: int, key: int, is_avatar: bool) -> Array:
	if is_avatar:
		return [key, 3, 0.5]
	return [active_element, key, 1.0]

## The element a fighter throws from a key: the Avatar's Z X C V are Fire,
## Water, Earth and Air (Fire Bolt, Ice Shard, Shockwave, Tornado);
## everyone else throws their own element.
static func element_for_slot(active_element: int, slot: int, is_avatar: bool) -> int:
	return slot if is_avatar else active_element

static func get_info(element: int) -> Dictionary:
	return INFO[clampi(element, 0, 3)]
