@tool
extends HBoxContainer

## Keycap hint: [ESC] BACK. A paper tag with an ink border plus what it does.
## The screen's main shortcut gets a vermilion tag (emphasis).

const T = preload("res://scripts/ui/kit/ui_tokens.gd")

@export var key_text: String = "ESC":
	set(v): key_text = v; _sync()
@export var label_text: String = "BACK":
	set(v): label_text = v; _sync()
@export var emphasis: bool = false:
	set(v): emphasis = v; _sync()
## Light text for use over dark (ink) areas.
@export var on_dark: bool = false:
	set(v): on_dark = v; _sync()

var _cap: Label
var _label: Label

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cap = Label.new()
	_cap.add_theme_font_override("font", T.font("label"))
	_cap.add_theme_font_size_override("font_size", T.FS_CAPTION)
	_cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_cap)
	_label = Label.new()
	_label.add_theme_font_override("font", T.font("label"))
	_label.add_theme_font_size_override("font_size", T.FS_LABEL)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
	_sync()

func setup(key: String, label: String, is_emphasis: bool = false) -> Control:
	key_text = key
	label_text = label
	emphasis = is_emphasis
	return self

func _sync() -> void:
	if not _cap:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = T.VERMILION if emphasis else T.PAPER_LIGHT
	sb.border_color = T.VERMILION_DEEP if emphasis else T.INK
	sb.set_border_width_all(1)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 0
	sb.content_margin_bottom = 1
	_cap.add_theme_stylebox_override("normal", sb)
	_cap.add_theme_color_override("font_color", T.PAPER_LIGHT if emphasis else T.INK)
	_label.add_theme_color_override("font_color", T.PAPER_LIGHT if on_dark else T.INK_SOFT)
	_cap.text = key_text
	_label.text = label_text
