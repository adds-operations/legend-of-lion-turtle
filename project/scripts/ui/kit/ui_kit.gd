@tool
extends RefCounted

## The painted UI kit (assets/ui/kit/, from ui_kit_pack): 9-slice buttons,
## panels, tabs, keycaps, HUD frames, pips, steppers and ink icons.
## Margins come from the kit's manifest.json (left, top, right, bottom).

const DIR := "res://assets/ui/kit/"

const MARGINS := {
	"button_primary": [24, 18, 24, 18],
	"button_secondary": [28, 18, 28, 18],
	"button_small": [14, 12, 14, 12],
	"panel_scroll": [40, 36, 40, 36],
	"panel_card": [64, 64, 64, 64],
	"panel_dark": [32, 32, 32, 32],
	"tooltip_toast": [40, 16, 20, 16],
	"tab_active": [24, 14, 24, 14],
	"tab_inactive": [24, 14, 24, 14],
	"keycap": [12, 12, 12, 12],
	"keycap_pressed": [12, 12, 12, 12],
	"hp_frame": [34, 14, 34, 14],
	"ribbon_banner": [64, 24, 64, 24],
}

static var _cache: Dictionary = {}

static func tex(name: String) -> Texture2D:
	if not _cache.has(name):
		var p := DIR + name + ".png"
		_cache[name] = load(p) if ResourceLoader.exists(p) else null
	return _cache[name]

static func has(name: String) -> bool:
	return tex(name) != null

## A StyleBoxTexture for a 9-slice piece. `family` picks the margins
## (e.g. "button_primary" for "button_primary_hover"). pad = content margins.
static func box(name: String, family: String = "", pad_x: float = -1.0, pad_y: float = -1.0, scale: float = 1.0) -> StyleBoxTexture:
	var t := tex(name)
	if t == null:
		return null
	var m: Array = MARGINS.get(family if family != "" else name, [8, 8, 8, 8])
	var sb := StyleBoxTexture.new()
	sb.texture = t
	sb.texture_margin_left = m[0]
	sb.texture_margin_top = m[1]
	sb.texture_margin_right = m[2]
	sb.texture_margin_bottom = m[3]
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.content_margin_left = m[0] * scale if pad_x < 0.0 else pad_x
	sb.content_margin_right = m[2] * scale if pad_x < 0.0 else pad_x
	sb.content_margin_top = m[1] * scale if pad_y < 0.0 else pad_y
	sb.content_margin_bottom = m[3] * scale if pad_y < 0.0 else pad_y
	return sb

## Draw a 9-slice piece into rect on any CanvasItem.
static func draw_box(ci: CanvasItem, name: String, rect: Rect2, family: String = "", modulate: Color = Color.WHITE) -> bool:
	var sb := box(name, family, 0, 0)
	if sb == null:
		return false
	sb.modulate_color = modulate
	ci.draw_style_box(sb, rect)
	return true

## Draw a fixed-size piece (icon, frame) fitted into rect.
static func draw_icon(ci: CanvasItem, name: String, rect: Rect2, modulate: Color = Color.WHITE) -> bool:
	var t := tex(name)
	if t == null:
		return false
	ci.draw_texture_rect(t, rect, false, modulate)
	return true
