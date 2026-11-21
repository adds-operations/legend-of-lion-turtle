extends Control

## The in-game menu (Esc): RESUME, AUTO-AIM on / off, LEAVE.
## Training pauses while it's open; a LAN match keeps running (your rival
## isn't paused), so your bender just stands still until you resume.
## Parchment card from the UI kit, centred over a dark wash.

const T = preload("res://scripts/ui/kit/ui_tokens.gd")
const KeyHint = preload("res://scripts/ui/kit/key_hint.gd")

signal closed()

var _aim_btn: Button
var _aim_desc: Label
var _resume: Button
var _title: Label
var _sub: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # works while training is paused
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(T.INK, 0.6)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	card.custom_minimum_size = Vector2(520, 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)

	var eyebrow := _lbl(v, &"EyebrowLabel", "MENU")
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title = _lbl(v, &"H1Label", "PAUSED")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub = _lbl(v, &"CaptionLabel", "")
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Auto-aim row: label + description on the left, ON / OFF on the right.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	_lbl(col, &"H3Label", "Auto-aim")
	_aim_desc = _lbl(col, &"CaptionLabel", "")
	_aim_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aim_desc.custom_minimum_size.x = 280
	_aim_btn = Button.new()
	_aim_btn.theme_type_variation = &"SecondaryButton"
	_aim_btn.custom_minimum_size = Vector2(130, 52)
	_aim_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_aim_btn.pressed.connect(_toggle_aim)
	row.add_child(_aim_btn)

	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	v.add_child(gap)
	_resume = Button.new()
	_resume.theme_type_variation = &"PrimaryButton"
	_resume.text = "RESUME"
	_resume.custom_minimum_size = Vector2(0, 58)
	_resume.pressed.connect(func(): closed.emit())
	v.add_child(_resume)
	var leave := Button.new()
	leave.theme_type_variation = &"SmallButton"
	leave.text = "LEAVE"
	leave.custom_minimum_size = Vector2(160, 40)
	leave.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	leave.pressed.connect(func():
		var arena := get_tree().current_scene
		if arena and arena.has_method("leave_match"):
			arena.leave_match())
	v.add_child(leave)
	var hints := HBoxContainer.new()
	hints.alignment = BoxContainer.ALIGNMENT_CENTER
	hints.add_theme_constant_override("separation", 18)
	hints.add_child(KeyHint.new().setup("ESC", "RESUME"))
	hints.add_child(KeyHint.new().setup("Q", "AUTO-AIM"))
	v.add_child(hints)
	_refresh()

func open(training: bool) -> void:
	_title.text = "PAUSED" if training else "MENU"
	_sub.text = "Training is paused." if training else "The match is still running for your rival."
	_refresh()
	visible = true
	_resume.grab_focus()

func _toggle_aim() -> void:
	UserSettings.auto_aim = not UserSettings.auto_aim
	UserSettings.save()
	_refresh()

func _refresh() -> void:
	if _aim_btn == null:
		return
	var on := UserSettings.auto_aim
	_aim_btn.text = "ON" if on else "OFF"
	_aim_btn.add_theme_color_override("font_color", T.SUCCESS if on else T.INK_SOFT)
	_aim_desc.text = ("Every power is aimed at your rival. Arrows only move and dodge. Hold SHIFT to aim by hand." if on
			else "Powers fly where you face: the way you move, or turn with SHIFT + ← →.")

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			closed.emit()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Q:
			_toggle_aim()
			get_viewport().set_input_as_handled()

func _lbl(parent: Node, variation: StringName, text: String) -> Label:
	var l := Label.new()
	l.theme_type_variation = variation
	l.text = text
	parent.add_child(l)
	return l
