extends Control

## Match HUD (spec §13 "Match HUD"):
##   top     — both fighters' HP, names, elements, round and score, ping
##   bottom  — your card (emblem, name, big HP number, segmented bar)
##             and your ability slots with keys and cooldowns
##   center  — big moments: round intro, FIGHT!, VICTORY / DEFEAT
##   edges   — red flash when you take damage
##   Raava   — warning countdown, claim progress, the merge, the Avatar's element bar
## Built in code because it is driven entirely by live fighter state.

const T = preload("res://scripts/ui/kit/ui_tokens.gd")
const PaintPanel = preload("res://scripts/ui/kit/paint_panel.gd")
const ScrollPanel = preload("res://scripts/ui/kit/scroll_panel.gd")
const SegBar = preload("res://scripts/ui/kit/seg_bar.gd")
const AbilitySlot = preload("res://scripts/ui/kit/ability_slot.gd")
const SlashBanner = preload("res://scripts/ui/kit/slash_banner.gd")
const KeyHint = preload("res://scripts/ui/kit/key_hint.gd")
const EmblemTile = preload("res://scripts/ui/kit/emblem_tile.gd")
const HurtVignette = preload("res://scripts/ui/kit/hurt_vignette.gd")
const Elements = preload("res://scripts/data/elements.gd")
const Roster = preload("res://scripts/data/roster.gd")
const Emblems = preload("res://scripts/ui/kit/emblems.gd")
const ElementSwitcher = preload("res://scripts/ui/kit/element_switcher.gd")
const BendingFX = preload("res://scripts/fx/bending_fx.gd")
const Specials = preload("res://scripts/data/specials.gd")

var me = null      # local fighter
var rival = null   # opponent fighter

# top plate
var _you_bar: Control
var _rival_bar: Control
var _you_name: Label
var _rival_name: Label
var _you_el: Label
var _rival_el: Label
var _round_label: Label
var _score_label: Label
var _ping_label: Label
# bottom card
var _tile: Control
var _card_name: Label
var _hp_num: Label
var _hp_max: Label
var _card_bar: Control
# abilities
var _slots: Dictionary = {}
# overlays
var _intro_box: Control
var _waiting_box: Control
var _hint_box: Control
var _intro_eyebrow: Label
var _intro_title: Label
var _banner: Control
var _result_box: Control
var _result_score: Label
var _result_sub: Label
var _waiting: Label
var _hint: Label
var _hint_tween: Tween
var _vignette: Control
var _dim: ColorRect

var _ping_t: float = 0.0
## HUD blocks that fade out when a fighter walks behind them.
var _occluders: Array = []
var _result_end: float = -1.0
var _result_note: String = ""
var _result_next: String = "Back to the lobby in %d"
# Raava / Avatar
var _raava_box: Control
var _raava_label: Label
var _raava_src = null           # RaavaEvent while counting down
var _switcher: Control
var _raava_ref = null           # RaavaEvent while its beam is open (leave countdown)
var _combo: Label
var _move: Label
var _move_tween: Tween
var _shown_special: String = "~"
var _was_avatar: bool = false
var _combo_tween: Tween
# Training
var training: bool = false
var _train_box: Control
var _train_stats: Label
var _train_mode: Label
var _train_eyebrow: Label
var _train_hits: int = 0
var _train_damage: int = 0
var _train_recent: Array = []   # [time, amount]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top()
	_build_card()
	_build_abilities()
	_build_overlays()

# =====================================================================
# Build
# =====================================================================

## Anchor to a preset, then place by offsets relative to that anchor.
func _place(c: Control, preset: int, pos: Vector2, sz: Vector2) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = pos.x
	c.offset_top = pos.y
	c.offset_right = pos.x + sz.x
	c.offset_bottom = pos.y + sz.y

func _label(variation: StringName, text: String = "", parent: Node = null) -> Label:
	var l := Label.new()
	l.theme_type_variation = variation
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent:
		parent.add_child(l)
	return l

func _paper(parent: Node, pos: Vector2, sz: Vector2, seed: int, style: int = 0) -> Control:
	var p := PaintPanel.new()
	p.style = style
	p.seed = seed
	p.position = pos
	p.size = sz
	parent.add_child(p)
	return p

func _build_top() -> void:
	var plate := Control.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(plate, Control.PRESET_CENTER_TOP, Vector2(-400, 10), Vector2(800, 78))
	_occluders.append(plate)
	add_child(plate)

	# left: you — paper strip, name, bender, bar anchored at the center
	_paper(plate, Vector2(0, 0), Vector2(318, 74), 21)
	var you_mark := _paper(plate, Vector2(236, 33), Vector2(68, 6), 31, 1)
	you_mark.color = T.SIDE_YOU
	_you_name = _label(&"H3Label", "YOU", plate)
	_you_name.position = Vector2(14, 5)
	_you_name.size = Vector2(290, 26)
	_you_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_you_el = _label(&"CaptionLabel", "", plate)
	_you_el.position = Vector2(16, 13)
	_you_el.size = Vector2(200, 20)
	_you_bar = SegBar.new()
	_you_bar.fill = T.SIDE_YOU
	_you_bar.reverse = true
	_you_bar.position = Vector2(16, 42)
	_you_bar.size = Vector2(288, 18)
	plate.add_child(_you_bar)

	# center: a small horizontal scroll with round + score
	var center := ScrollPanel.new()
	center.horizontal = true
	center.tassels = false
	center.position = Vector2(332, -2)
	center.custom_minimum_size = Vector2(136, 78)
	center.size = Vector2(136, 78)
	center.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	plate.add_child(center)
	_paper(plate, Vector2(334, 0), Vector2(132, 74), 22).move_to_front()
	center.move_to_front()
	_round_label = _label(&"EyebrowLabel", "ROUND 1", plate)
	_round_label.position = Vector2(334, 8)
	_round_label.size = Vector2(132, 20)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label = _label(&"H1Label", "0 : 0", plate)
	_score_label.position = Vector2(334, 22)
	_score_label.size = Vector2(132, 46)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# right: rival
	_paper(plate, Vector2(482, 0), Vector2(318, 74), 23)
	var rival_mark := _paper(plate, Vector2(496, 33), Vector2(68, 6), 32, 1)
	rival_mark.color = T.SIDE_RIVAL
	_rival_name = _label(&"H3Label", "RIVAL", plate)
	_rival_name.position = Vector2(496, 5)
	_rival_name.size = Vector2(290, 26)
	_rival_el = _label(&"CaptionLabel", "", plate)
	_rival_el.position = Vector2(584, 13)
	_rival_el.size = Vector2(200, 20)
	_rival_el.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rival_bar = SegBar.new()
	_rival_bar.fill = T.SIDE_RIVAL
	_rival_bar.position = Vector2(496, 42)
	_rival_bar.size = Vector2(288, 18)
	plate.add_child(_rival_bar)

	# top-right: ping + leave hint on a paper tag
	var tr_bg := PaintPanel.new()
	_place(tr_bg, Control.PRESET_TOP_RIGHT, Vector2(-196, 12), Vector2(180, 60))
	add_child(tr_bg)
	var tr := VBoxContainer.new()
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(tr, Control.PRESET_TOP_RIGHT, Vector2(-186, 18), Vector2(160, 48))
	tr.add_theme_constant_override("separation", 4)
	add_child(tr)
	_ping_label = _label(&"CaptionLabel", "LAN · — ms", tr)
	_ping_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var leave := KeyHint.new().setup("ESC", "MENU")
	leave.alignment = BoxContainer.ALIGNMENT_END
	tr.add_child(leave)

func _build_card() -> void:
	var card := Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(card, Control.PRESET_BOTTOM_LEFT, Vector2(24, -116), Vector2(440, 100))
	_occluders.append(card)
	add_child(card)

	_paper(card, Vector2(40, 10), Vector2(396, 86), 41)

	_tile = EmblemTile.new()
	_tile.position = Vector2(0, 0)
	_tile.size = Vector2(100, 100)
	card.add_child(_tile)

	_card_name = _label(&"H3Label", "", card)
	_card_name.position = Vector2(114, 16)
	_hp_num = _label(&"TitleLabel", "300", card)
	_hp_num.add_theme_font_size_override("font_size", 42)
	_hp_num.position = Vector2(112, 34)
	_hp_max = _label(&"H3Label", "/ 300", card)
	_hp_max.add_theme_color_override("font_color", T.INK_SOFT)
	_hp_max.position = Vector2(196, 50)
	_card_bar = SegBar.new()
	_card_bar.fill = T.SIDE_YOU
	_card_bar.position = Vector2(268, 56)
	_card_bar.size = Vector2(150, 14)
	card.add_child(_card_bar)

func _build_abilities() -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 6)
	var strip := PaintPanel.new()
	strip.style = 2  # ink wash
	strip.color = T.INK_WASH
	_place(strip, Control.PRESET_BOTTOM_RIGHT, Vector2(-470, -126), Vector2(458, 120))
	add_child(strip)
	_place(row, Control.PRESET_BOTTOM_RIGHT, Vector2(-560, -122), Vector2(536, 114))
	_occluders.append(row)
	_occluders.append(strip)
	add_child(row)
	# key, emblem, locked, large
	var defs := [
		["attack_1", "Z", "bolt", false, false],
		["attack_2", "X", "burst", false, false],
		["attack_3", "C", "arc", false, false],
		["attack_4", "V", "special", false, false],
		["special", "A", "special", false, true],
		["jump", "SPACE", "jump", false, false],
	]
	for d in defs:
		var s := AbilitySlot.new()
		s.key_text = d[1]
		s.emblem = d[2]
		s.locked = d[3]
		s.large = d[4]
		s.size_flags_vertical = Control.SIZE_SHRINK_END
		row.add_child(s)
		_slots[d[0]] = s

func _build_overlays() -> void:
	_vignette = HurtVignette.new()
	add_child(_vignette)

	_dim = ColorRect.new()
	_dim.color = Color(T.INK, 0.35)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.visible = false
	add_child(_dim)

	_waiting_box = PanelContainer.new()
	_waiting_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_waiting_box, Control.PRESET_CENTER, Vector2(-220, 90), Vector2(440, 64))
	add_child(_waiting_box)
	_waiting = _label(&"H3Label", "", _waiting_box)
	_waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# round intro: a horizontal scroll that unrolls
	_intro_box = ScrollPanel.new()
	_intro_box.horizontal = true
	_intro_box.tassels = false
	_intro_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_intro_box, Control.PRESET_CENTER, Vector2(-260, -120), Vector2(520, 190))
	_intro_box.visible = false
	add_child(_intro_box)
	var iv := VBoxContainer.new()
	iv.alignment = BoxContainer.ALIGNMENT_CENTER
	iv.add_theme_constant_override("separation", -8)
	_intro_box.add_child(iv)
	_intro_eyebrow = _label(&"EyebrowLabel", "", iv)
	_intro_eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_title = _label(&"DisplayLabel", "", iv)
	_intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_banner = SlashBanner.new()
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.offset_top = -60
	_banner.offset_bottom = -60
	_banner.visible = false
	add_child(_banner)

	_result_box = ScrollPanel.new()
	_result_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_result_box, Control.PRESET_CENTER, Vector2(-170, 44), Vector2(340, 150))
	_result_box.visible = false
	add_child(_result_box)
	var rv := VBoxContainer.new()
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	_result_box.add_child(rv)
	var fs := _label(&"EyebrowLabel", "SCORE", rv)
	fs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_score = _label(&"TitleLabel", "1 : 0", rv)
	_result_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_sub = _label(&"BodyLabel", "", rv)
	_result_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_hint_box = PanelContainer.new()
	_hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_hint_box, Control.PRESET_CENTER_BOTTOM, Vector2(-250, -190), Vector2(500, 56))
	_hint_box.modulate.a = 0.0
	add_child(_hint_box)
	_hint = _label(&"H3Label", "", _hint_box)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Raava status: a paper strip under the score plate
	_raava_box = PanelContainer.new()
	_raava_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_raava_box, Control.PRESET_CENTER_TOP, Vector2(-230, 92), Vector2(460, 50))
	_raava_box.visible = false
	add_child(_raava_box)
	_raava_label = _label(&"H3Label", "", _raava_box)
	_raava_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_raava_label.add_theme_font_size_override("font_size", 17)

	# The Avatar's element bar (1–4) above your card
	_switcher = ElementSwitcher.new()
	_place(_switcher, Control.PRESET_BOTTOM_LEFT, Vector2(140, -204), Vector2(220, 88))
	_switcher.visible = false
	_occluders.append(_switcher)
	add_child(_switcher)

# =====================================================================
# API used by the arena
# =====================================================================

func bind(local_fighter, rival_fighter) -> void:
	me = local_fighter
	rival = rival_fighter
	if me:
		_tile.element = me.element
		_tile.fighter_id = me.fighter_id
		_card_name.text = _name_of(me)
		_you_name.text = _name_of(me)
		_you_el.text = _bender_label(me)
		_you_el.add_theme_color_override("font_color", T.element_color(me.element))
		var el_col := T.element_color(me.element)
		_style_slots()
		_you_bar.max_value = me.max_hp
		_card_bar.max_value = me.max_hp
	if rival:
		_rival_name.text = _name_of(rival)
		_rival_el.text = _bender_label(rival)
		_rival_el.add_theme_color_override("font_color", T.element_color(rival.element))
		_rival_bar.max_value = rival.max_hp
	for f in [me, rival]:
		if f and not f.avatar_changed.is_connected(_refresh_avatar):
			f.avatar_changed.connect(_refresh_avatar)
	# Names sit above the bars; element tags tuck in on the outer edges.
	_you_el.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func _bender_label(f) -> String:
	var b: String = str(Roster.get_fighter(f.fighter_id).get("name", ""))
	if f.is_avatar:
		return "AVATAR  ·  " + T.ELEMENT_NAMES[f.active_element]
	if f.free_switch:
		return (b + "  ·  " if b != "" else "").to_upper() + T.ELEMENT_NAMES[f.active_element]
	return (b + "  ·  " if b != "" else "").to_upper() + T.ELEMENT_NAMES[f.element]

func _name_of(f) -> String:
	return str(NetworkManager.players.get(f.peer_id, {}).get("name", "Bender")).to_upper()

func show_waiting(text: String) -> void:
	_waiting.text = text
	_waiting_box.visible = text != ""

func play_round_intro(round_number: int, arena_name: String) -> void:
	play_intro(arena_name, "Round %d" % round_number)

func play_intro(eyebrow: String, title: String) -> void:
	show_waiting("")
	_intro_eyebrow.text = eyebrow
	_intro_title.text = title
	_intro_box.visible = true
	_intro_box.unroll()

func play_fight(word: String = "Fight!") -> void:
	var tw := create_tween()
	tw.tween_property(_intro_box, "modulate:a", 0.0, T.T_FAST)
	tw.tween_callback(func(): _intro_box.visible = false)
	_banner.play(word, T.INK, T.PAPER_LIGHT)
	await get_tree().create_timer(T.T_HOLD * 0.7).timeout
	_banner.dismiss()

func show_result(won: bool, my_score: int, rival_score: int, seconds: float, winner_was_avatar: bool = false, match_over: bool = true) -> void:
	_result_next = "Back to the lobby in %d" if match_over else "Next round in %d"
	_intro_box.visible = false
	_raava_box.visible = false
	_raava_src = null
	_result_note = ""
	if winner_was_avatar:
		_result_note = "Won as the Avatar" if won else "Your rival won as the Avatar"
	show_waiting("")
	_dim.visible = true
	_dim.modulate.a = 0.0
	create_tween().tween_property(_dim, "modulate:a", 1.0, T.T_SLOW)
	if won:
		_banner.play("Victory" if match_over else "Round Won", T.VERMILION, T.PAPER_LIGHT)
	else:
		_banner.play("Defeat" if match_over else "Round Lost", T.INK, T.PAPER_DARK)
	_result_score.text = "%d : %d" % [my_score, rival_score]
	_result_box.visible = true
	if _train_box:
		_train_box.visible = false   # the score scroll takes the bottom centre
	_result_box.scale = Vector2(1, 0.04)
	get_tree().create_timer(T.T_SLOW).timeout.connect(_result_box.unroll)
	_result_end = Time.get_ticks_msec() / 1000.0 + seconds

## Between rounds: put the arena back to how a round starts.
func clear_result() -> void:
	if _train_box:
		_train_box.visible = true
	_result_box.visible = false
	_result_end = -1.0
	_raava_box.visible = false
	_raava_src = null
	_raava_ref = null
	var tw := create_tween()
	tw.tween_property(_dim, "modulate:a", 0.0, T.T_BASE)
	tw.tween_callback(func(): _dim.visible = false)
	if _banner.visible:
		_banner.dismiss()
	_refresh_avatar()

func flash_hint(text: String, seconds: float = 2.0) -> void:
	_hint.text = text
	if _hint_tween:
		_hint_tween.kill()
	_hint_box.modulate.a = 1.0
	_hint_tween = create_tween()
	_hint_tween.tween_interval(seconds * 0.7)
	_hint_tween.tween_property(_hint_box, "modulate:a", 0.0, seconds * 0.3)

# =====================================================================
# Training
# =====================================================================

func setup_training(partner_mode: String) -> void:
	training = true
	_train_box = Control.new()
	_train_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# between your HP card (ends ~465 px) and the ability strip (starts ~800 px)
	_place(_train_box, Control.PRESET_CENTER_BOTTOM, Vector2(-160, -112), Vector2(320, 98))
	add_child(_train_box)
	_occluders.append(_train_box)
	_paper(_train_box, Vector2.ZERO, Vector2(320, 98), 51)
	var v := VBoxContainer.new()
	v.position = Vector2(12, 12)
	v.size = Vector2(296, 74)
	v.add_theme_constant_override("separation", 2)
	_train_box.add_child(v)
	_train_eyebrow = _label(&"EyebrowLabel", "TRAINING", v)
	_train_eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_train_stats = _label(&"BodyLabel", "", v)
	_train_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_train_stats.add_theme_font_size_override("font_size", 14)
	_train_mode = _label(&"CaptionLabel", "", v)
	_train_mode.add_theme_font_size_override("font_size", 11)
	_train_mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	set_partner_mode(partner_mode)
	_update_training_stats()
	if me:
		me.avatar_changed.emit()  # show the element bar

func set_partner_mode(mode: String) -> void:
	if _train_mode:
		_train_mode.text = "T RAAVA  ·  G PARTNER: %s  ·  SHIFT AIM" % mode
		_train_eyebrow.text = "TRAINING"

func training_hit(amount: int) -> void:
	_train_hits += 1
	_train_damage += amount
	_train_recent.append([Time.get_ticks_msec() / 1000.0, amount])

func _update_training_stats() -> void:
	if _train_stats == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	while not _train_recent.is_empty() and now - float(_train_recent[0][0]) > 5.0:
		_train_recent.pop_front()
	var recent := 0
	for r in _train_recent:
		recent += int(r[1])
	_train_stats.text = "DAMAGE %d  ·  LAST 5 s %d  ·  %.0f/s" % [_train_damage, recent, recent / 5.0]

# =====================================================================
# Raava event
# =====================================================================

func _raava_text(text: String, color: Color = T.INK) -> void:
	_raava_label.text = text
	_raava_label.add_theme_color_override("font_color", color)
	if not _raava_box.visible:
		_raava_box.visible = true
		_raava_box.modulate.a = 0.0
		create_tween().tween_property(_raava_box, "modulate:a", 1.0, T.T_BASE)

func on_raava_warned(_seconds_left: float, src) -> void:
	_raava_src = src
	flash_hint("ENTER THE RING WHEN THE BEAM APPEARS", 4.0)

func on_raava_opened() -> void:
	_raava_src = null
	if me:
		var arena := get_tree().current_scene
		_raava_ref = arena.get("raava") if arena else null
	_raava_text("RAAVA HAS DESCENDED  ·  HOLD A IN THE LIGHT", T.VERMILION)

func on_raava_claim(claimant: int, progress: float, contested: bool) -> void:
	if contested:
		_raava_text("CONTESTED  ·  NEITHER CAN MERGE", T.WARNING)
	elif claimant == -1:
		_raava_text("RAAVA HAS DESCENDED  ·  HOLD A IN THE LIGHT", T.VERMILION)
	else:
		var pct := int(clampf(progress / 1.5, 0.0, 1.0) * 100.0)
		if me and claimant == me.peer_id:
			_raava_text("MERGING WITH RAAVA  ·  %d%%  ·  STAY STILL" % pct, T.INK)
		else:
			_raava_text("%s IS MERGING  ·  %d%%  ·  STOP THEM" % [_name_of(rival) if rival else "RIVAL", pct], T.DANGER)

func on_raava_left() -> void:
	_raava_ref = null
	_raava_box.visible = false
	flash_hint("RAAVA HAS LEFT  ·  NO AVATAR THIS ROUND", 2.5)

func show_combo(mine: bool, hits: int, mult: float) -> void:
	if _combo == null:
		_combo = _label(&"TitleLabel", "", self)
		_combo.add_theme_font_override("font", T.font("display"))
		_combo.add_theme_font_size_override("font_size", 46)
		_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_place(_combo, Control.PRESET_BOTTOM_RIGHT, Vector2(-560, -196), Vector2(530, 70))
	_combo.text = "%d Hit Combo%s" % [hits, ("  ×%.2f" % mult) if mult > 1.0 else ""]
	_combo.add_theme_color_override("font_color", T.VERMILION if mine else T.SIDE_RIVAL)
	_combo.modulate.a = 1.0
	_combo.scale = Vector2(1.15, 1.15)
	_combo.pivot_offset = Vector2(530, 35)
	if _combo_tween:
		_combo_tween.kill()
	_combo_tween = create_tween()
	_combo_tween.tween_property(_combo, "scale", Vector2.ONE, 0.12)
	_combo_tween.tween_interval(1.0)
	_combo_tween.tween_property(_combo, "modulate:a", 0.0, 0.4)

## An arrow combo's name (Dash Strike, Power Shot...) over the ability strip.
var menu_open: bool = false
var _menu: Control

## Esc: open / close the in-game menu. Training pauses underneath it.
func toggle_menu() -> void:
	if _menu == null:
		_menu = load("res://scripts/ui/game_menu.gd").new()
		_menu.visible = false
		_menu.closed.connect(toggle_menu)
		add_child(_menu)
	menu_open = not menu_open
	if menu_open:
		_menu.open(training)
	else:
		_menu.visible = false
	if training:
		get_tree().paused = menu_open

func show_move(mine: bool, move_name: String) -> void:
	if _move == null:
		_move = _label(&"TitleLabel", "", self)
		_move.add_theme_font_override("font", T.font("display"))
		_move.add_theme_font_size_override("font_size", 34)
		_move.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_place(_move, Control.PRESET_BOTTOM_RIGHT, Vector2(-560, -246), Vector2(530, 50))
	_move.text = move_name
	_move.add_theme_color_override("font_color", T.INK if mine else T.SIDE_RIVAL)
	_move.modulate.a = 1.0
	if _move_tween:
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_interval(0.9)
	_move_tween.tween_property(_move, "modulate:a", 0.0, 0.35)

func on_raava_fused(f) -> void:
	_raava_ref = null
	_raava_box.visible = false
	if f == null:
		return
	var mine: bool = f == me
	_banner.play("Avatar", T.VERMILION if mine else T.SIDE_RIVAL, T.PAPER_LIGHT)
	get_tree().create_timer(T.T_HOLD).timeout.connect(_banner.dismiss)
	if mine:
		flash_hint("Z FIRE  ·  X WATER  ·  C EARTH  ·  V AIR  ·  BEST POWERS, HALF COOLDOWN", 3.0)
	else:
		flash_hint("%s IS THE AVATAR" % _name_of(f), 2.5)
	_refresh_avatar()

## Z X C V tiles: the power each key throws right now (as the Avatar, each
## element's best). A: the equipped special.
func _style_slots() -> void:
	if me == null:
		return
	for i in 4:
		var spec := Elements.attack_for(me.active_element, i, me.is_avatar)
		var e: int = spec[0]
		var s = _slots[Elements.ACTIONS[i]]
		s.color = T.element_color(e)
		s.emblem = Emblems.element_kind(e) if me.is_avatar else Elements.get_info(e)["emblems"][i]
		s.icon = BendingFX.icon(e, spec[1])  # the attack's own art
	_slots["jump"].color = T.INK
	var sp = _slots["special"]
	if me.special and me.special.id != "":
		sp.color = T.element_color(int(Specials.info(me.special.id).get("element", me.element)))
		sp.icon = Specials.frame(me.special.id, 1, 0)
		sp.locked = false
	else:
		sp.locked = true

## Element labels, slot colors and the switcher follow each fighter's active element.
func _refresh_avatar() -> void:
	if me:
		var e: int = me.active_element
		_tile.element = e
		var el_col := T.element_color(e)
		_style_slots()
		_you_el.text = _bender_label(me)
		_you_el.add_theme_color_override("font_color", el_col)
		_switcher.visible = me.is_avatar or me.free_switch
		_switcher.title = "AVATAR" if me.is_avatar else "ELEMENTS"
		_switcher.avatar = me.is_avatar
		_switcher.active = e
	if rival:
		_rival_el.text = _bender_label(rival)
		_rival_el.add_theme_color_override("font_color", T.element_color(rival.active_element))

func on_fighter_damaged(fighter, amount: int) -> void:
	if fighter == me:
		_vignette.pulse(clampf(amount / 30.0, 0.5, 1.0))

# =====================================================================
# Live update
# =====================================================================

func _process(delta: float) -> void:
	if me:
		_you_bar.value = me.hp
		_card_bar.value = me.hp
		_hp_num.text = str(me.hp)
		_hp_max.text = "/ %d" % me.max_hp
		_hp_num.add_theme_color_override("font_color", T.DANGER if me.hp <= me.max_hp * 0.25 else T.INK)
		for i in 4:
			_slots[Elements.ACTIONS[i]].set_cooldown(me.attack_cd[i], me.attack_cd_total[i])
		if me.special:
			var sp = _slots["special"]
			sp.set_cooldown(me.special.total if me.special.active else me.special.cd_left,
					me.special.total if me.special.active else me.special.cd_total)
			if me.special.id != _shown_special:
				_shown_special = me.special.id
				_style_slots()
		var jump_cd: float = me.jump_cooldown_timer if not me.is_jumping else GameManager.jump_cooldown
		_slots["jump"].set_cooldown(jump_cd, GameManager.jump_cooldown)
	if rival:
		_rival_bar.value = rival.hp
	if training:
		_round_label.text = "HITS"
		_score_label.text = str(_train_hits)
		_update_training_stats()
	else:
		_round_label.text = "ROUND %d" % maxi(GameManager.current_round, 1)
		var my_idx := NetworkManager.get_player_index(multiplayer.get_unique_id())
		var my_score: int = GameManager.scores[my_idx] if my_idx >= 0 else 0
		var rival_score: int = GameManager.scores[1 - my_idx] if my_idx >= 0 else 0
		_score_label.text = "%d : %d" % [my_score, rival_score]

	_fade_occluders(delta)

	if _raava_src and is_instance_valid(_raava_src) and _raava_src.state == 1:  # WARNING
		_raava_text("RAAVA IS ARRIVING  ·  %d" % ceili(_raava_src.seconds_to_descend()), T.INK)
	if _raava_ref and is_instance_valid(_raava_ref) and _raava_ref.is_open() and _raava_ref.claimant == -1 and not _raava_ref.contested:
		_raava_text("RAAVA HAS DESCENDED  ·  HOLD A IN THE LIGHT  ·  %d" % ceili(_raava_ref.seconds_left_open()), T.VERMILION)
	if me and me.is_avatar:
		_switcher.recovery = 0.0
		_switcher.title = "AVATAR  ·  %d" % ceili(me.avatar_t)
	if me and _was_avatar != me.is_avatar:
		_was_avatar = me.is_avatar
		_refresh_avatar()
		if not me.is_avatar and not training:
			flash_hint("THE AVATAR STATE FADES", 2.0)

	_ping_t -= delta
	if _ping_t <= 0.0:
		_ping_t = 0.5
		var ping := NetworkManager.get_ping_ms()
		if training:
			_ping_label.text = "TRAINING  ·  OFFLINE"
			_ping_label.add_theme_color_override("font_color", T.INK_SOFT)
			return
		_ping_label.text = "LAN  ·  %s" % ("%d ms" % ping if ping >= 0 else "— ms")
		_ping_label.add_theme_color_override("font_color",
				T.SUCCESS if ping >= 0 and ping < 60 else (T.WARNING if ping >= 60 else T.INK_FAINT))
	if _result_end > 0.0:
		var left := ceili(maxf(_result_end - Time.get_ticks_msec() / 1000.0, 0.0))
		_result_sub.text = ("%s\n" % _result_note if _result_note != "" else "") + _result_next % left

## Fade HUD blocks to 30% while a fighter (or its name tag) is behind them,
## so the whole arena stays readable (spec §2: keep the arena visible).
func _fade_occluders(delta: float) -> void:
	var points: Array = []
	for f in [me, rival]:
		if f and is_instance_valid(f):
			var p: Vector2 = f.get_global_transform_with_canvas().origin
			points.append(p)
			points.append(p + Vector2(0, -80))  # name tag + HP bar above the head
	for block in _occluders:
		var r: Rect2 = block.get_global_rect().grow(16)
		var hidden := false
		for p in points:
			if r.has_point(p):
				hidden = true
				break
		block.modulate.a = move_toward(block.modulate.a, 0.3 if hidden else 1.0, delta / T.T_BASE)
