extends Control

## Lobby — element selection, ready up, synchronized countdown, match start.
## All changes are requests to the host; the display always reflects the
## host's synced NetworkManager.players.
## UX: big element cards with attacks, live rival pick, 1-4 / Enter / Esc
## shortcuts, ping, locked state while ready, full-screen countdown.

const T = preload("res://scripts/ui/kit/ui_tokens.gd")
const Roster = preload("res://scripts/data/roster.gd")
const Arenas = preload("res://scripts/data/arenas.gd")
const Specials = preload("res://scripts/data/specials.gd")
const BuildBoard = preload("res://scripts/ui/kit/build_board.gd")
const StepTabs = preload("res://scripts/ui/kit/step_tabs.gd")

@onready var you_plate = $Plates/YouPlate
@onready var rival_plate = $Plates/RivalPlate
@onready var cards: Array = [$Cards/FireCard, $Cards/WaterCard, $Cards/EarthCard, $Cards/AirCard]
@onready var ready_button: Button = $Footer/ReadyButton
@onready var status_label: Label = $Footer/StatusLabel
@onready var arena_chip = $ArenaChip
@onready var backdrop = $Backdrop
@onready var countdown_overlay: Control = $CountdownOverlay
@onready var countdown_banner = $CountdownOverlay/Banner

var _countdown_end: float = -1.0
var _last_count: int = -1
var _ping_t: float = 0.0
var _tabs
var _board
var _mode: int = 0
var _board_key: String = ""
var _nagged: bool = false   # READY with points left asks once
var _msg_until: float = 0.0
var _edit_t: float = -10.0

func _ready() -> void:
	NetworkManager.players_changed.connect(_update_display)
	NetworkManager.countdown_started.connect(_on_countdown_started)
	for c in cards:
		c.bender_chosen.connect(_select_bender)
	arena_chip.arena_id = NetworkManager.selected_arena
	arena_chip.can_change = multiplayer.is_server()
	arena_chip.step_requested.connect(_step_arena)
	NetworkManager.arena_changed.connect(func(id): arena_chip.arena_id = id)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.x = 260
	status_label.add_theme_font_size_override("font_size", 15)
	_build_ui()
	# Bring your saved build to the host (it keeps a legal copy).
	NetworkManager.request_set_build.rpc_id(1, UserSettings.last_build)
	_update_display()
	var me := _me()
	if not me.is_empty():
		cards[int(me["element"])].grab_focus()
	_handle_debug_launch()

# --- Build (stats + special) -------------------------------------------------
# Two steps share the main area: 1 ELEMENT & BENDER (the cards) and
# 2 BUILD & SPECIAL (the build board). B or the tabs switch between them.

func _build_ui() -> void:
	_tabs = StepTabs.new()
	_tabs.position = Vector2(48, 226)
	_tabs.size = Vector2(size.x - 96, 34)
	_tabs.tab_selected.connect(_set_mode)
	add_child(_tabs)
	resized.connect(func(): _tabs.size.x = size.x - 96)
	_board = BuildBoard.new()
	_board.position = Vector2(48, 268)
	_board.size = Vector2(size.x - 96, 332)
	_board.visible = false
	add_child(_board)
	resized.connect(func(): _board.size.x = size.x - 96)
	_board.build_changed.connect(func(b):
		_edit_t = Time.get_ticks_msec() / 1000.0
		UserSettings.last_build = b
		UserSettings.save()
		NetworkManager.request_set_build.rpc_id(1, b)
		_refresh_tabs(b))
	_board.message.connect(_say)

## A status line that stays up for a few seconds over the default prompts.
func _say(t: String) -> void:
	status_label.text = t
	_msg_until = Time.get_ticks_msec() / 1000.0 + 3.0

## 0 = element cards, 1 = build board.
func _set_mode(m: int) -> void:
	_mode = m
	_tabs.active = m
	$Cards.visible = m == 0
	_board.visible = m == 1
	$Header/Titles/Title.text = "CHOOSE YOUR ELEMENT" if m == 0 else "SHAPE YOUR BUILD"
	$Header/Titles/Subtitle.text = ("Both benders may pick the same element. Gold is you, indigo is your rival." if m == 0
			else "Spend 8 points on your stats. Your bender's signature attack is on A.")
	$Footer/HintPick.key_text = "1-4" if m == 0 else "B"
	$Footer/HintPick.label_text = "PICK ELEMENT" if m == 0 else "BACK TO BENDER"
	$Footer/HintSwap.key_text = "TAB" if m == 0 else "← →"
	$Footer/HintSwap.label_text = "SWAP BENDER" if m == 0 else "POINTS"
	_update_display()
	if m == 1:
		_sync_board(true)
	else:
		var me := _me()
		if not me.is_empty():
			cards[int(me["element"])].grab_focus()

func _refresh_tabs(b: Dictionary) -> void:
	_tabs.points_left = Specials.POINTS - Specials.spent(b)
	var fid := str(_me().get("fighter", ""))
	_tabs.summary = "ATK %d  ·  DEF %d  ·  MOB %d  ·  A: %s" % [int(b.get("atk", 0)), int(b.get("def", 0)), int(b.get("mob", 0)),
			str(Specials.info(Specials.signature(fid)).get("name", "—")).to_upper()]

## Load the host's copy into the board when the element, offer or ready state
## changes (not on every echo, so quick clicks never flicker back).
func _sync_board(force: bool = false) -> void:
	var me := _me()
	if me.is_empty():
		return
	var el := int(me["element"])
	var fid := str(me.get("fighter", ""))
	var hb: Dictionary = me.get("build", Specials.empty_build())
	var base := "%d|%s|%s" % [el, fid, _local_ready()]
	var key := base + "|%d,%d,%d" % [int(hb.get("atk", 0)), int(hb.get("def", 0)), int(hb.get("mob", 0))]
	# Right after a local click the host's echo may lag a step behind: skip it
	# unless the element, offer or ready state really changed.
	var settling := Time.get_ticks_msec() / 1000.0 - _edit_t < 0.6 and _board_key.begins_with(base)
	if force or (key != _board_key and not settling):
		_board_key = key
		_board.set_state(el, fid, hb, _local_ready())
		_refresh_tabs(_board.build)

func _handle_debug_launch() -> void:
	if NetworkManager.debug_args.has("element"):
		var wanted := str(NetworkManager.debug_args["element"]).to_upper()
		var idx: int = T.ELEMENT_NAMES.find(wanted)
		if idx >= 0:
			_select_element(idx)
	if NetworkManager.debug_args.has("fighter"):
		_select_bender(str(NetworkManager.debug_args["fighter"]))
	if NetworkManager.has_debug("auto-ready"):
		await get_tree().create_timer(0.5).timeout
		if not _local_ready():
			_nagged = true
			_on_ready_pressed()

func _me() -> Dictionary:
	return NetworkManager.players.get(multiplayer.get_unique_id(), {})

func _rival() -> Dictionary:
	return NetworkManager.players.get(NetworkManager.get_rival_id(), {})

func _local_ready() -> bool:
	return _me().get("ready", false)

func _process(delta: float) -> void:
	if _countdown_end > 0.0:
		var remaining := _countdown_end - Time.get_ticks_msec() / 1000.0
		var n := ceili(maxf(remaining, 0.0))
		if n != _last_count and n > 0:
			_last_count = n
			countdown_banner.play(str(n), T.VERMILION, T.PAPER_LIGHT)
	_ping_t -= delta
	if _ping_t <= 0.0:
		_ping_t = 0.5
		var ping := NetworkManager.get_ping_ms()
		arena_chip.ping_text = ("Q / E to change  ·  " if arena_chip.can_change else "") + "LAN %s" % ("%d ms" % ping if ping >= 0 else "— ms")
		arena_chip.ping_color = T.SUCCESS if ping >= 0 and ping < 60 else (T.WARNING if ping >= 60 else T.INK_FAINT)

func _update_display() -> void:
	var me := _me()
	var rival := _rival()

	you_plate.present = not me.is_empty()
	if not me.is_empty():
		you_plate.player_name = me["name"]
		you_plate.element = int(me["element"])
		you_plate.fighter_id = str(me.get("fighter", ""))
		you_plate.is_ready = me["ready"]
	rival_plate.present = not rival.is_empty()
	if not rival.is_empty():
		rival_plate.player_name = rival["name"]
		rival_plate.element = int(rival["element"])
		rival_plate.fighter_id = str(rival.get("fighter", ""))
		rival_plate.is_ready = rival["ready"]

	var my_el := int(me.get("element", -1))
	var rival_el := int(rival.get("element", -1))
	var ready := _local_ready()
	for i in cards.size():
		cards[i].picked_by_you = i == my_el
		cards[i].picked_by_rival = i == rival_el
		cards[i].your_fighter = str(me.get("fighter", ""))
		cards[i].rival_fighter = str(rival.get("fighter", ""))
		cards[i].disabled = ready

	if _board and not me.is_empty():
		_sync_board()
	ready_button.text = "CANCEL READY" if ready else "READY"
	ready_button.theme_type_variation = &"SecondaryButton" if ready else &"PrimaryButton"
	if Time.get_ticks_msec() / 1000.0 < _msg_until:
		pass
	elif ready and not rival.get("ready", false):
		status_label.text = "Waiting for %s to ready up..." % rival.get("name", "rival")
	elif not ready and rival.get("ready", false):
		status_label.text = "%s is ready. Your move." % rival.get("name", "Rival")
	elif not ready:
		status_label.text = "Pick an element, then press READY." if _mode == 0 else "Spend your points, then READY."
	else:
		status_label.text = ""

# --- Input ----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _countdown_end > 0.0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			_set_mode(1 - _mode)
			get_viewport().set_input_as_handled()
			return
		if _mode == 1:
			if event.keycode == KEY_ESCAPE:
				_set_mode(0)
				get_viewport().set_input_as_handled()
				return
			if _board.key_input(event):
				get_viewport().set_input_as_handled()
				return
		match event.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4:
				_select_element(event.keycode - KEY_1)
				cards[event.keycode - KEY_1].grab_focus()
				get_viewport().set_input_as_handled()
			KEY_LEFT, KEY_RIGHT, KEY_TAB:
				_swap_bender()
				get_viewport().set_input_as_handled()
			KEY_Q, KEY_E:
				_step_arena(-1 if event.keycode == KEY_Q else 1)
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER:
				_on_ready_pressed()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				_on_back_pressed()
				get_viewport().set_input_as_handled()

# --- Element cards --------------------------------------------------------

func _select_element(element: int) -> void:
	if _local_ready():
		status_label.text = "Cancel READY to change your element."
		return
	NetworkManager.request_set_element.rpc_id(1, element)

## Pick a specific bender (clicking a portrait on a card).
func _select_bender(fighter_id: String) -> void:
	if _local_ready():
		status_label.text = "Cancel READY to change your bender."
		return
	NetworkManager.request_set_fighter.rpc_id(1, fighter_id)
	var f := Roster.get_fighter(fighter_id)
	if not f.is_empty():
		cards[int(f["element"])].grab_focus()

## Toggle between the two benders of your current element.
func _swap_bender() -> void:
	var me := _me()
	if me.is_empty():
		return
	var list := Roster.for_element(int(me["element"]))
	var cur := str(me.get("fighter", ""))
	for i in list.size():
		if list[i]["id"] == cur:
			_select_bender(list[(i + 1) % list.size()]["id"])
			return
	_select_bender(list[0]["id"])

## Host only: cycle the arena.
func _step_arena(delta: int) -> void:
	if not multiplayer.is_server():
		return
	NetworkManager.set_arena(Arenas.step(NetworkManager.selected_arena, delta))

# --- Ready / back ---------------------------------------------------------

func _on_ready_pressed() -> void:
	if _countdown_end > 0.0:
		return  # Locked in once the countdown has started.
	if not _local_ready() and not _nagged and _board and _board.points_left() > 0:
		_nagged = true
		_set_mode(1)
		_say("%d build points unspent. Spend them, or press READY again." % _board.points_left())
		return
	NetworkManager.request_set_ready.rpc_id(1, not _local_ready())

func _on_back_pressed() -> void:
	NetworkManager.abort_to_menu("")

func _on_countdown_started(seconds: float) -> void:
	_countdown_end = Time.get_ticks_msec() / 1000.0 + seconds
	countdown_overlay.visible = true
	countdown_overlay.modulate.a = 0.0
	create_tween().tween_property(countdown_overlay, "modulate:a", 1.0, T.T_BASE)
	ready_button.disabled = true
	for c in cards:
		c.disabled = true
