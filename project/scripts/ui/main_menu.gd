extends Control

## Main Menu — name, Create Arena, Join Arena, Quit.
## UX: remembers your name and the last host IP, shows every LAN address with a
## one-click copy, times out a stuck join with a clear reason, Enter/Esc work
## everywhere. Once both fighters connect, NetworkManager opens the lobby.

const T = preload("res://scripts/ui/kit/ui_tokens.gd")
const KeyHint = preload("res://scripts/ui/kit/key_hint.gd")
const ScrollPanel = preload("res://scripts/ui/kit/scroll_panel.gd")
const EmblemTile = preload("res://scripts/ui/kit/emblem_tile.gd")
const Roster = preload("res://scripts/data/roster.gd")
const Arenas = preload("res://scripts/data/arenas.gd")

const JOIN_TIMEOUT := 8.0

@onready var name_input: LineEdit = $LeftColumn/NameInput
@onready var create_button: Button = $LeftColumn/Buttons/CreateButton
@onready var join_button: Button = $LeftColumn/Buttons/JoinButton
@onready var info_panel: Control = $RightArea/InfoPanel
@onready var host_panel: Control = $RightArea/HostPanel
@onready var join_panel: Control = $RightArea/JoinPanel
@onready var ip_input: LineEdit = $RightArea/JoinPanel/VBoxContainer/IPInput
@onready var port_input: LineEdit = $RightArea/JoinPanel/VBoxContainer/PortRow/PortInput
@onready var connect_button: Button = $RightArea/JoinPanel/VBoxContainer/ConnectButton
@onready var join_status_label: Label = $RightArea/JoinPanel/VBoxContainer/StatusLabel
@onready var host_ip_label: Label = $RightArea/HostPanel/VBoxContainer/IPLabel
@onready var host_port_label: Label = $RightArea/HostPanel/VBoxContainer/Row/PortLabel
@onready var copy_button: Button = $RightArea/HostPanel/VBoxContainer/Row/CopyButton
@onready var other_ips_label: Label = $RightArea/HostPanel/VBoxContainer/OtherIPs
@onready var host_status_label: Label = $RightArea/HostPanel/VBoxContainer/StatusLabel
@onready var notice_label: Label = $RightArea/NoticeLabel
@onready var hint_back: Control = $Footer/HintBack
@onready var steps_box: VBoxContainer = $RightArea/InfoPanel/VBox/Steps
@onready var controls_box: VBoxContainer = $RightArea/InfoPanel/VBox/Controls

enum Mode { MAIN, HOST, JOIN, TRAIN }
var _mode: Mode = Mode.MAIN
var _joining: bool = false
var _join_started: float = 0.0
var _dots_t: float = 0.0
# Training panel (built in code)
var training_button: Button
var training_panel: Control
var _train_tile: Control
var _train_bender: Label
var _train_element: Label
var _train_arena: Label
var _train_nation: Label
var _train_fighter: int = 0
var _train_arena_id: String = Arenas.DEFAULT_ID
var _train_start: Button

func _ready() -> void:
	GameManager.current_state = GameManager.GameState.MENU
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)

	name_input.text = NetworkManager.local_name()
	_build_info_panel()
	_build_training()
	_show(Mode.MAIN, false)
	info_panel.unroll()
	_show_notice(NetworkManager.last_disconnect_reason)
	NetworkManager.last_disconnect_reason = ""
	create_button.grab_focus()
	_handle_debug_launch()

func _build_info_panel() -> void:
	var steps := [
		["01", "One player picks CREATE ARENA and reads out the IP shown."],
		["02", "The other picks JOIN ARENA and types that IP."],
		["03", "Choose an element, press READY. First to 0 HP loses the round."],
	]
	for s in steps:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var num := Label.new()
		num.theme_type_variation = &"H2Label"
		num.add_theme_color_override("font_color", T.VERMILION)
		num.text = s[0]
		num.custom_minimum_size.x = 36
		row.add_child(num)
		var body := Label.new()
		body.theme_type_variation = &"BodyLabel"
		body.text = s[1]
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(body)
		steps_box.add_child(row)
	var cap := Label.new()
	cap.theme_type_variation = &"CaptionLabel"
	cap.text = "IN THE ARENA"
	controls_box.add_child(cap)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 8)
	for pair in [["ARROWS", "MOVE"], ["Q W E R", "ATTACK"], ["SPACE", "JUMP"], ["HOLD F", "MERGE"], ["ESC ×2", "LEAVE"]]:
		grid.add_child(KeyHint.new().setup(pair[0], pair[1]))
	controls_box.add_child(grid)

# --- Training ---------------------------------------------------------------

func _build_training() -> void:
	# TRAINING sits beside QUIT in the last row so the column keeps its height.
	var quit: Button = $LeftColumn/Buttons/QuitButton
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	$LeftColumn/Buttons.add_child(row)
	$LeftColumn/Buttons.move_child(row, quit.get_index())
	training_button = Button.new()
	training_button.text = "TRAINING"
	training_button.custom_minimum_size = Vector2(0, 46)
	training_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	training_button.pressed.connect(_on_training_pressed)
	row.add_child(training_button)
	quit.reparent(row)
	quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	training_panel = ScrollPanel.new()
	training_panel.visible = false
	training_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	$RightArea.add_child(training_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	training_panel.add_child(v)
	_lbl(v, &"EyebrowLabel", "SINGLE PLAYER")
	_lbl(v, &"H2Label", "TRAINING GROUNDS")
	var intro := _lbl(v, &"BodyLabel", "Practise every power on a sparring partner. Keys 1-4 change element; T calls Raava down to rehearse the merge.")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size.x = 400
	var g := Control.new()
	g.custom_minimum_size.y = 6
	v.add_child(g)

	# bender: portrait + name + arrows
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 14)
	v.add_child(brow)
	_train_tile = EmblemTile.new()
	_train_tile.custom_minimum_size = Vector2(84, 84)
	brow.add_child(_train_tile)
	var bcol := VBoxContainer.new()
	bcol.alignment = BoxContainer.ALIGNMENT_CENTER
	bcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bcol.add_theme_constant_override("separation", 0)
	brow.add_child(bcol)
	_lbl(bcol, &"CaptionLabel", "BENDER")
	_train_bender = _lbl(bcol, &"H2Label", "")
	_train_element = _lbl(bcol, &"CaptionLabel", "")
	brow.add_child(_arrow("<", func(): _step_bender(-1)))
	brow.add_child(_arrow(">", func(): _step_bender(1)))

	# arena: name + arrows
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 14)
	v.add_child(arow)
	var acol := VBoxContainer.new()
	acol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acol.add_theme_constant_override("separation", 0)
	arow.add_child(acol)
	_lbl(acol, &"CaptionLabel", "ARENA")
	_train_arena = _lbl(acol, &"H3Label", "")
	_train_nation = _lbl(acol, &"CaptionLabel", "")
	arow.add_child(_arrow("<", func(): _step_arena(-1)))
	arow.add_child(_arrow(">", func(): _step_arena(1)))

	var g2 := Control.new()
	g2.custom_minimum_size.y = 4
	v.add_child(g2)
	var brow2 := HBoxContainer.new()
	brow2.add_theme_constant_override("separation", 10)
	v.add_child(brow2)
	_train_start = Button.new()
	_train_start.theme_type_variation = &"PrimaryButton"
	_train_start.text = "START TRAINING"
	_train_start.custom_minimum_size = Vector2(260, 56)
	_train_start.pressed.connect(_on_start_training)
	brow2.add_child(_train_start)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(120, 46)
	back.pressed.connect(_on_back_pressed)
	brow2.add_child(back)

	# remembered picks
	var ids := []
	for f in Roster.FIGHTERS:
		ids.append(f["id"])
	_train_fighter = maxi(0, ids.find(UserSettings.last_fighter))
	if Arenas.is_valid(UserSettings.last_arena):
		_train_arena_id = UserSettings.last_arena
	_refresh_training()

func _lbl(parent: Node, variation: StringName, text: String) -> Label:
	var l := Label.new()
	l.theme_type_variation = variation
	l.text = text
	parent.add_child(l)
	return l

func _arrow(glyph: String, cb: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"SmallButton"
	b.text = glyph
	b.custom_minimum_size = Vector2(40, 36)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	return b

func _step_bender(d: int) -> void:
	_train_fighter = posmod(_train_fighter + d, Roster.FIGHTERS.size())
	_refresh_training()

func _step_arena(d: int) -> void:
	_train_arena_id = Arenas.step(_train_arena_id, d)
	_refresh_training()

func _refresh_training() -> void:
	var f: Dictionary = Roster.FIGHTERS[_train_fighter]
	_train_tile.element = int(f["element"])
	_train_tile.fighter_id = f["id"]
	_train_bender.text = f["name"]
	_train_element.text = T.ELEMENT_NAMES[int(f["element"])] + " BENDER"
	_train_element.add_theme_color_override("font_color", T.element_color(int(f["element"])))
	_train_arena.text = Arenas.display_name(_train_arena_id)
	_train_nation.text = Arenas.nation_name(_train_arena_id).to_upper()

func _on_training_pressed() -> void:
	_show_notice("")
	_show(Mode.TRAIN)
	_train_start.grab_focus.call_deferred()

func _on_start_training() -> void:
	NetworkManager.start_training(Roster.FIGHTERS[_train_fighter]["id"], _train_arena_id)

## Command-line shortcuts for fast local testing (see README).
func _handle_debug_launch() -> void:
	if NetworkManager.has_debug("training"):
		_on_training_pressed()
		if NetworkManager.has_debug("fighter"):
			for i in Roster.FIGHTERS.size():
				if Roster.FIGHTERS[i]["id"] == str(NetworkManager.debug_args["fighter"]):
					_train_fighter = i
		if NetworkManager.has_debug("arena") and Arenas.is_valid(str(NetworkManager.debug_args["arena"])):
			_train_arena_id = str(NetworkManager.debug_args["arena"])
		_refresh_training()
		if NetworkManager.has_debug("auto-ready"):
			_on_start_training.call_deferred()
	elif NetworkManager.has_debug("host"):
		_on_create_pressed.call_deferred()
	elif NetworkManager.has_debug("join"):
		var addr = NetworkManager.debug_args["join"]
		_on_join_pressed()
		ip_input.text = "127.0.0.1" if addr is bool else str(addr)
		_on_connect_pressed.call_deferred()

# --- Panels ---------------------------------------------------------------

func _show(mode: Mode, animate: bool = true) -> void:
	_mode = mode
	var target: Control = {Mode.MAIN: info_panel, Mode.HOST: host_panel, Mode.JOIN: join_panel, Mode.TRAIN: training_panel}[mode]
	for p in [info_panel, host_panel, join_panel, training_panel]:
		p.visible = p == target
	create_button.disabled = mode != Mode.MAIN
	join_button.disabled = mode != Mode.MAIN
	training_button.disabled = mode != Mode.MAIN
	name_input.editable = mode == Mode.MAIN
	hint_back.setup("ESC", "BACK" if mode != Mode.MAIN else "QUIT")
	if animate and target.has_method("unroll"):
		target.unroll()

func _show_notice(text: String) -> void:
	notice_label.visible = text != ""
	if text == "":
		return
	notice_label.text = text.to_upper()
	var sb := StyleBoxFlat.new()
	sb.bg_color = T.DANGER
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	notice_label.add_theme_stylebox_override("normal", sb)
	notice_label.add_theme_font_override("font", T.font("heading"))
	notice_label.add_theme_color_override("font_color", T.PAPER_LIGHT)
	notice_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	notice_label.size.x = 0  # shrink to text

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu"):
		get_viewport().set_input_as_handled()
		if _mode == Mode.MAIN:
			_on_quit_pressed()
		else:
			_on_back_pressed()

func _process(delta: float) -> void:
	_dots_t += delta
	var dots := ".".repeat(1 + int(_dots_t * 2.5) % 3)
	if _mode == Mode.HOST and NetworkManager.players.size() < 2 and NetworkManager.is_host:
		host_status_label.text = "Waiting for rival" + dots
	if _joining:
		var waited := Time.get_ticks_msec() / 1000.0 - _join_started
		join_status_label.text = "Connecting to %s%s" % [ip_input.text.strip_edges(), dots]
		if waited > JOIN_TIMEOUT:
			_joining = false
			NetworkManager.disconnect_from_game()
			_join_failed("No answer from %s. Check the IP, that both Macs are on the same Wi-Fi, and that the host clicked Allow on the firewall prompt." % ip_input.text.strip_edges())

# --- Buttons --------------------------------------------------------------

func _on_name_changed(new_text: String) -> void:
	UserSettings.player_name = UserSettings.clean_name(new_text)
	UserSettings.save()

func _on_create_pressed() -> void:
	_show_notice("")
	_show(Mode.HOST)
	copy_button.grab_focus.call_deferred()
	var port := NetworkManager.DEFAULT_PORT
	if NetworkManager.debug_args.has("port"):
		port = int(NetworkManager.debug_args["port"])
	var error := NetworkManager.host_game(port)
	if error == OK:
		var ip := NetworkManager.get_local_ip()
		host_ip_label.text = ip
		host_port_label.text = "PORT %d" % port
		copy_button.disabled = false
		var others: Array = []
		for a in IP.get_local_addresses():
			if a != ip and a != "127.0.0.1" and ":" not in a and not a.begins_with("169.254."):
				others.append(a)
		other_ips_label.text = ("Not working? Also try: " + ", ".join(others)) if not others.is_empty() else ""
	else:
		host_ip_label.text = "—"
		host_port_label.text = ""
		copy_button.disabled = true
		other_ips_label.text = ""
		host_status_label.text = "Couldn't open the arena on port %d. Is another copy of the game already hosting?" % port

func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(host_ip_label.text)
	copy_button.text = "COPIED"
	await get_tree().create_timer(1.4).timeout
	if is_instance_valid(copy_button):
		copy_button.text = "COPY IP"

func _on_join_pressed() -> void:
	_show_notice("")
	_show(Mode.JOIN)
	ip_input.text = UserSettings.last_ip
	port_input.text = str(UserSettings.last_port)
	join_status_label.text = "Last used address filled in." if UserSettings.last_ip != "" else ""
	join_status_label.add_theme_color_override("font_color", T.INK_SOFT)
	connect_button.disabled = false
	ip_input.grab_focus()
	ip_input.caret_column = ip_input.text.length()

func _on_ip_submitted(_text: String) -> void:
	_on_connect_pressed()

func _on_connect_pressed() -> void:
	if _joining:
		return
	var address := ip_input.text.strip_edges()
	var port := int(port_input.text.strip_edges())
	if address.is_empty():
		_join_failed("Type the IP address shown on the host's screen.")
		return
	if not address.is_valid_ip_address() and address != "localhost":
		_join_failed("That doesn't look like an IP address. It should look like 192.168.1.20")
		return
	if port <= 0 or port > 65535:
		port = NetworkManager.DEFAULT_PORT
	join_status_label.add_theme_color_override("font_color", T.INK_SOFT)
	connect_button.disabled = true
	var error := NetworkManager.join_game(address, port)
	if error != OK:
		_join_failed("Couldn't start connecting (%s)." % error_string(error))
		return
	UserSettings.last_ip = address
	UserSettings.last_port = port
	UserSettings.save()
	_joining = true
	_join_started = Time.get_ticks_msec() / 1000.0

func _join_failed(msg: String) -> void:
	join_status_label.text = msg
	join_status_label.add_theme_color_override("font_color", T.WARNING)
	connect_button.disabled = false

func _on_back_pressed() -> void:
	_joining = false
	NetworkManager.disconnect_from_game()
	_show(Mode.MAIN)
	create_button.grab_focus()

func _on_quit_pressed() -> void:
	get_tree().quit()

# --- Network callbacks ----------------------------------------------------

func _on_player_connected(_peer_id: int) -> void:
	if NetworkManager.is_host:
		host_status_label.text = "Rival connected! Opening lobby..."
		host_status_label.add_theme_color_override("font_color", T.SUCCESS)

func _on_connection_succeeded() -> void:
	_joining = false
	join_status_label.text = "Connected! Opening lobby..."
	join_status_label.add_theme_color_override("font_color", T.SUCCESS)

func _on_connection_failed() -> void:
	_joining = false
	_join_failed("Connection failed. Check the IP, that both Macs are on the same Wi-Fi, and that the host clicked Allow on the firewall prompt.")
