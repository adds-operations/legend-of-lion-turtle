@tool
extends RefCounted

## "Scroll & Ink" design tokens — the single source of truth for the UI.
##
## Language (warm, painted martial-arts storybook):
##   1. Golden air   — screens sit in a hazy golden sky with a pale sun disc
##                     ringed by brushed halos; dark leaves drift through it.
##   2. Paper & ink  — every surface is parchment with paper grain; text and
##                     frames are ink. Menus are hanging scrolls on wooden rods
##                     that unroll when they open.
##   3. One red      — VERMILION (banner red) is the call to action: the
##                     primary button, seals, ribbons, big moments.
##   4. Sun vs dusk  — the local player is SUN GOLD, the rival is DUSK INDIGO,
##                     independent of element (mirror matches stay readable).
##   5. Brush, not box — edges are brush strokes with dry, tapered ends.
##                     No skew, no bevels, no gradients except light and wash.
##   6. Keycaps      — every screen still lists its shortcuts as paper tags.
##
## Usage: const T = preload("res://scripts/ui/kit/ui_tokens.gd")
## After changing tokens, rebuild the theme:
##   Godot --headless --path project --script res://tools/build_theme.gd

# ---------------------------------------------------------------- sky
const SKY_TOP := Color("f6d77a")    # top of the golden haze
const SKY_MID := Color("f2b84b")    # horizon glow
const SKY_LOW := Color("d98c2b")    # low amber, behind silhouettes
const HAZE := Color("fbecc4")       # mist bands
const SUN := Color("fff7dc")        # sun disc
const SUN_RING := Color(1.0, 0.98, 0.9, 0.5)

# ---------------------------------------------------------------- paper
const PAPER := Color("f2e2b8")       # parchment surface — text goes on this
const PAPER_LIGHT := Color("f8eed3") # raised paper, fields, text on red/ink
const PAPER_DARK := Color("e6d09a")  # folds, pressed, borders (not for text)
const PAPER_EDGE := Color("b89458")  # burnt edge of a scroll

# ---------------------------------------------------------------- ink
const INK := Color("2a1f17")         # text, frames, silhouettes. 12.5:1 on paper
const INK_SOFT := Color("5a4632")    # secondary text. 6.9:1 on paper
const INK_FAINT := Color("6b563b")   # captions, placeholders. 5.4:1 on paper
const INK_WASH := Color(0.165, 0.122, 0.09, 0.16)  # watercolor shadow, dim layers

# ---------------------------------------------------------------- wood (scroll rods)
const WOOD := Color("6b4a2b")
const WOOD_LIGHT := Color("9a7045")
const WOOD_DARK := Color("3a2716")

# ---------------------------------------------------------------- red: the call to action
const VERMILION := Color("b52a1a")        # primary button, seals. paper-light on it 5.5:1
const VERMILION_HOVER := Color("cc3a22")
const VERMILION_DEEP := Color("8f1e14")   # pressed, ribbon shadow
const RIBBON := Color("d1361f")           # decorative banners (brighter, never text)

# ---------------------------------------------------------------- sides
const SIDE_YOU := Color("f2a516")         # sun gold — fills/markers only, ink text on it (7.8:1)
const SIDE_RIVAL := Color("3e3f86")       # dusk indigo — paper-light text on it (8:1)
const TEXT_ON_YOU := INK
const TEXT_ON_RIVAL := PAPER_LIGHT

# ---------------------------------------------------------------- feedback
const SUCCESS := Color("2a6e49")   # jade: READY, good ping. 4.8:1 on paper
const WARNING := Color("934808")   # join errors, high ping. 5.2:1 on paper
const DANGER := VERMILION          # low HP, hurt, disconnects
const HP_LAG := Color(1.0, 0.97, 0.88, 0.95)  # recent-damage trail

# ---------------------------------------------------------------- elements
## Text-safe on paper (≥4.5:1). Index = GameManager.Element.
const ELEMENT := [
	Color("b03a0e"),  # Fire
	Color("1a6290"),  # Water
	Color("6e5520"),  # Earth
	Color("25696a"),  # Air
]
## Bright versions for light: power glows, trails, in-arena effects.
const ELEMENT_GLOW := [
	Color("ff7a2e"),
	Color("4fb6ff"),
	Color("e0ad62"),
	Color("c4f4ff"),
]
## Watercolor tints for card washes and tiles.
const ELEMENT_WASH := [
	Color("f0b083"),
	Color("a9cfe6"),
	Color("d8bf86"),
	Color("bfe3dc"),
]
const ELEMENT_NAMES := ["FIRE", "WATER", "EARTH", "AIR"]

# ---------------------------------------------------------------- shape
## Kept at 0: the scroll language has no lean. Components still call
## skew_points() so a future style can bring it back in one place.
const SKEW := 0.0
const BRUSH_ROUGH := 2.5      # px of edge wobble on brush shapes
const BORDER_HAIR := 1
const BORDER_INK := 2         # ink frame around tiles and bars
const BORDER_FOCUS := 2
const ROD_H := 12             # scroll rod thickness
const ROD_OVERHANG := 14      # rod sticks out past the paper on each side
const ACCENT_BAR_W := 6

# ---------------------------------------------------------------- space (4-pt grid)
const S1 := 4
const S2 := 8
const S3 := 12
const S4 := 16
const S5 := 24
const S6 := 32
const S7 := 48
const S8 := 64
const SCREEN_MARGIN := 48

# ---------------------------------------------------------------- type scale (px at 1280×720)
const FS_DISPLAY := 104    # brush script: ROUND 1, FIGHT!, VICTORY, countdown
const FS_TITLE := 64       # serif title: game name, host IP, result score
const FS_H1 := 38          # screen headers
const FS_H2 := 26          # panel headers, player names
const FS_H3 := 20          # buttons, HUD names, status
const FS_BODY := 18
const FS_LABEL := 14
const FS_CAPTION := 13

# ---------------------------------------------------------------- motion (seconds)
const T_FAST := 0.08       # hover, press
const T_BASE := 0.18       # state changes
const T_UNROLL := 0.32     # scrolls unrolling
const T_SLOW := 0.4        # banners, intros
const T_HOLD := 1.1        # how long a big-moment word stays up

# ---------------------------------------------------------------- fonts (all SIL OFL, Latin subsets)
const FONT_DISPLAY_PATH := "res://assets/fonts/ZhiMangXing-Regular.ttf"
const FONT_HEADING_PATH := "res://assets/fonts/KaiseiTokumin-ExtraBold.ttf"
const FONT_BODY_PATH := "res://assets/fonts/ShipporiMinchoB1-Regular.ttf"
const FONT_BODY_STRONG_PATH := "res://assets/fonts/ShipporiMinchoB1-SemiBold.ttf"
const FONT_LABEL_PATH := "res://assets/fonts/ShipporiMinchoB1-Bold.ttf"

static var _fonts: Dictionary = {}

static func font(role: String) -> Font:
	if _fonts.has(role):
		return _fonts[role]
	var path: String = {
		"display": FONT_DISPLAY_PATH,
		"heading": FONT_HEADING_PATH,
		"body": FONT_BODY_PATH,
		"body_strong": FONT_BODY_STRONG_PATH,
		"label": FONT_LABEL_PATH,
	}.get(role, FONT_BODY_PATH)
	var f: Font = load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font
	_fonts[role] = f
	return f

static func element_color(element: int) -> Color:
	return ELEMENT[clampi(element, 0, 3)]

static func element_glow(element: int) -> Color:
	return ELEMENT_GLOW[clampi(element, 0, 3)]

static func element_wash(element: int) -> Color:
	return ELEMENT_WASH[clampi(element, 0, 3)]

static func side_color(is_you: bool) -> Color:
	return SIDE_YOU if is_you else SIDE_RIVAL

static func text_on_side(is_you: bool) -> Color:
	return TEXT_ON_YOU if is_you else TEXT_ON_RIVAL

## Rect corners (kept for components that may lean again; SKEW is 0).
static func skew_points(rect: Rect2, skew: float = SKEW) -> PackedVector2Array:
	var lean := rect.size.y * skew * 0.5
	return PackedVector2Array([
		rect.position + Vector2(lean, 0),
		rect.position + Vector2(rect.size.x + lean, 0),
		rect.position + Vector2(rect.size.x - lean, rect.size.y),
		rect.position + Vector2(-lean, rect.size.y),
	])
