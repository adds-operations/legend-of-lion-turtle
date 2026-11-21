extends Node

## Network Manager — autoloaded singleton.
## Handles hosting, joining, the player registry, lobby state and scene
## transitions. The host (peer 1) owns all shared state; clients only ask.

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_succeeded()
signal connection_failed()
signal server_disconnected()
signal players_changed()
signal countdown_started(seconds: float)
signal arena_changed(arena_id: String)

const DEFAULT_PORT: int = 7777
const MAX_CLIENTS: int = 1  # host + 1 joining player = 2 fighters
const Roster = preload("res://scripts/data/roster.gd")
const Arenas = preload("res://scripts/data/arenas.gd")
const Specials = preload("res://scripts/data/specials.gd")
const LOBBY_COUNTDOWN: float = 3.0

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const LOBBY_SCENE := "res://scenes/ui/lobby.tscn"
const ARENA_SCENE := "res://scenes/arena/arena.tscn"

# Player info: { peer_id: { "name": String, "element": int, "fighter": String, "ready": bool } }
var players: Dictionary = {}
## Single-player training: an offline session with a sparring partner (peer 2).
var training: bool = false
const TRAINING_PARTNER_ID := 2
var local_peer_id: int = 0
var is_host: bool = false

# Match settings (set by host)
var selected_arena: String = Arenas.DEFAULT_ID
var round_count: int = 3
var round_time: float = 240.0

# Shown on the main menu after an unexpected disconnect.
var last_disconnect_reason: String = ""

# --- Debug / test launch options (see README "Testing on one Mac") ---
# Passed after `--` on the command line, e.g.
#   Godot --path project -- --host --element=fire --auto-ready
var debug_args: Dictionary = {}

var _countdown_running: bool = false
var _arena_loaded_peers: Array = []

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_parse_debug_args()

func _parse_debug_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var a: String = arg.trim_prefix("--")
		if "=" in a:
			var parts := a.split("=", true, 1)
			debug_args[parts[0]] = parts[1]
		else:
			debug_args[a] = true
	if not debug_args.is_empty():
		print("[Network] Debug args: %s" % str(debug_args))

func has_debug(flag: String) -> bool:
	return debug_args.has(flag)

# --- Hosting ---

func host_game(port: int = DEFAULT_PORT) -> Error:
	_reset_state()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		print("[Network] Failed to create server: %s" % error_string(error))
		return error

	multiplayer.multiplayer_peer = peer
	is_host = true
	local_peer_id = 1  # Server is always peer 1
	selected_arena = UserSettings.last_arena if Arenas.is_valid(UserSettings.last_arena) else Arenas.DEFAULT_ID
	if debug_args.has("arena") and Arenas.is_valid(str(debug_args["arena"])):
		selected_arena = str(debug_args["arena"])

	players[1] = _new_player_entry(local_name(), GameManager.Element.FIRE)
	players_changed.emit()
	print("[Network] Hosting on port %d" % port)
	return OK

# --- Joining ---

func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	_reset_state()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		print("[Network] Failed to connect: %s" % error_string(error))
		return error

	multiplayer.multiplayer_peer = peer
	is_host = false
	print("[Network] Connecting to %s:%d" % [address, port])
	return OK

# --- Disconnect ---

func disconnect_from_game() -> void:
	# Reset first so peer_disconnected callbacks fired while closing are ignored.
	_reset_state()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	print("[Network] Disconnected")

func _reset_state() -> void:
	players.clear()
	training = false
	is_host = false
	local_peer_id = 0
	_countdown_running = false
	_arena_loaded_peers.clear()

## Leave the current session and return to the main menu with a message.
func abort_to_menu(reason: String) -> void:
	last_disconnect_reason = reason
	disconnect_from_game()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

# --- Callbacks ---

func _on_peer_connected(id: int) -> void:
	print("[Network] Peer connected: %d" % id)
	if multiplayer.is_server() and players.size() >= 2:
		# Arena is full (ENet max_clients should already prevent this).
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	player_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	print("[Network] Peer disconnected: %d" % id)
	players.erase(id)
	player_disconnected.emit(id)
	if is_host:
		# Opponent left: stop whatever was happening and go back to the menu.
		abort_to_menu("Opponent disconnected.")

func _on_connected_to_server() -> void:
	local_peer_id = multiplayer.get_unique_id()
	print("[Network] Connected to server as peer %d" % local_peer_id)
	_register_player.rpc_id(1, local_name())
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	print("[Network] Connection failed")
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connection_failed.emit()

func _on_server_disconnected() -> void:
	print("[Network] Server disconnected")
	server_disconnected.emit()
	abort_to_menu("Lost connection to the host.")

# --- Registration & lobby (client → host) ---

@rpc("any_peer", "reliable")
func _register_player(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var n := UserSettings.clean_name(player_name)
	if n == players.get(1, {}).get("name", ""):
		n += " 2"  # keep the two plates distinguishable
	players[sender] = _new_player_entry(n, GameManager.Element.WATER)
	print("[Network] Player registered: %d" % sender)
	_sync_player_list.rpc(players)
	_sync_arena.rpc(selected_arena)
	# Both fighters present: move everyone to the lobby.
	if players.size() == 2:
		_start_lobby.rpc()

@rpc("any_peer", "reliable", "call_local")
func request_set_element(element: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := _sender_id()
	if not players.has(sender) or players[sender]["ready"]:
		return
	if element < 0 or element > 3:
		return
	if players[sender]["element"] != element:
		players[sender]["element"] = element
		players[sender]["fighter"] = Roster.default_for(element)
		_revalidate_build(sender)
	_sync_player_list.rpc(players)

## Build (stats + special) from the lobby's build screen. The host keeps a legal copy.
@rpc("any_peer", "reliable", "call_local")
func request_set_build(build: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender := _sender_id()
	if not players.has(sender) or players[sender]["ready"]:
		return
	players[sender]["build"] = build
	_revalidate_build(sender)
	_sync_player_list.rpc(players)

func _revalidate_build(id: int) -> void:
	var p: Dictionary = players[id]
	p["build"] = Specials.sanitize(p.get("build", {}))

## Pick a specific bender. Switching to another element's bender also
## switches the element.
@rpc("any_peer", "reliable", "call_local")
func request_set_fighter(fighter_id: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := _sender_id()
	if not players.has(sender) or players[sender]["ready"]:
		return
	var f: Dictionary = Roster.get_fighter(fighter_id)
	if f.is_empty():
		return
	players[sender]["element"] = int(f["element"])
	players[sender]["fighter"] = fighter_id
	_revalidate_build(sender)
	_sync_player_list.rpc(players)

@rpc("any_peer", "reliable", "call_local")
func request_set_ready(ready: bool) -> void:
	if not multiplayer.is_server():
		return
	var sender := _sender_id()
	if not players.has(sender) or _countdown_running:
		return
	players[sender]["ready"] = ready
	_sync_player_list.rpc(players)

	if players.size() == 2 and _all_ready():
		_countdown_running = true
		_lobby_countdown.rpc(LOBBY_COUNTDOWN)
		await get_tree().create_timer(LOBBY_COUNTDOWN).timeout
		# Someone may have left during the countdown.
		if _countdown_running and players.size() == 2 and _all_ready():
			_start_match.rpc(selected_arena)
		_countdown_running = false

## Host only: pick the arena (from the lobby). Clients just see it.
func set_arena(arena_id: String) -> void:
	if not multiplayer.is_server() or _countdown_running or not Arenas.is_valid(arena_id):
		return
	UserSettings.last_arena = arena_id
	UserSettings.save()
	_sync_arena.rpc(arena_id)

# --- Host → everyone ---

@rpc("authority", "reliable", "call_local")
func _sync_arena(arena_id: String) -> void:
	if Arenas.is_valid(arena_id):
		selected_arena = arena_id
		arena_changed.emit(arena_id)

@rpc("authority", "reliable", "call_local")
func _sync_player_list(player_data: Dictionary) -> void:
	players = player_data
	players_changed.emit()

@rpc("authority", "reliable", "call_local")
func _start_lobby() -> void:
	print("[Network] Entering lobby")
	GameManager.current_state = GameManager.GameState.LOBBY
	get_tree().change_scene_to_file(LOBBY_SCENE)

@rpc("authority", "reliable", "call_local")
func _lobby_countdown(seconds: float) -> void:
	countdown_started.emit(seconds)

@rpc("authority", "reliable", "call_local")
func _start_match(arena_key: String) -> void:
	print("[Network] All players ready — starting match!")
	_arena_loaded_peers.clear()
	GameManager.reset_match()
	if Arenas.is_valid(arena_key):
		selected_arena = arena_key
	get_tree().change_scene_to_file(ARENA_SCENE)

## Host only: send both players back to the lobby with ready flags cleared.
func return_to_lobby() -> void:
	if not multiplayer.is_server():
		return
	for id in players:
		players[id]["ready"] = false
		_revalidate_build(id)
	_sync_player_list.rpc(players)
	_start_lobby.rpc()

# --- Training (single player) ---

## Start an offline training session: you plus a sparring partner, no network.
func start_training(fighter_id: String, arena_id: String) -> void:
	disconnect_from_game()
	training = true
	var me := Roster.get_fighter(fighter_id)
	if me.is_empty():
		me = Roster.FIGHTERS[0]
	# The partner is a bender of the next element, so mirror colors never clash.
	var partner_el := (int(me["element"]) + 1) % 4
	players = {
		1: _new_player_entry(local_name(), int(me["element"])),
		TRAINING_PARTNER_ID: _new_player_entry("Partner", partner_el),
	}
	players[1]["fighter"] = me["id"]
	players[1]["build"] = Specials.sanitize(UserSettings.last_build)
	if Arenas.is_valid(arena_id):
		selected_arena = arena_id
		UserSettings.last_arena = arena_id
	UserSettings.last_fighter = me["id"]
	UserSettings.save()
	GameManager.reset_match()
	print("[Training] %s in %s" % [me["id"], selected_arena])
	get_tree().change_scene_to_file(ARENA_SCENE)

func leave_training() -> void:
	disconnect_from_game()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

# --- Arena load handshake ---
# Each peer reports when its arena scene has spawned both players, so the
# host never sends gameplay RPCs to a node path that does not exist yet.

signal all_arena_loaded()

@rpc("any_peer", "reliable", "call_local")
func report_arena_loaded() -> void:
	if not multiplayer.is_server():
		return
	var sender := _sender_id()
	if sender not in _arena_loaded_peers:
		_arena_loaded_peers.append(sender)
	if _arena_loaded_peers.size() >= players.size():
		all_arena_loaded.emit()

# --- Utility ---

func _sender_id() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()

func _all_ready() -> bool:
	for p in players.values():
		if not p["ready"]:
			return false
	return true

func _new_player_entry(player_name: String, element: int) -> Dictionary:
	var b := Specials.sanitize(UserSettings.last_build if player_name == local_name() else {})
	return {"name": player_name, "element": element, "fighter": Roster.default_for(element), "ready": false, "build": b}

func get_local_ip() -> String:
	var addresses := IP.get_local_addresses()
	for addr in addresses:
		# Prefer typical home/office LAN ranges.
		if addr.begins_with("192.168.") or addr.begins_with("10."):
			return addr
	for addr in addresses:
		if addr.begins_with("172."):
			return addr
	for addr in addresses:
		if addr != "127.0.0.1" and ":" not in addr:
			return addr
	return "127.0.0.1"

func local_name() -> String:
	if debug_args.has("name"):
		return UserSettings.clean_name(str(debug_args["name"]))
	return UserSettings.clean_name(UserSettings.player_name)

## Round-trip time to the other player in ms, or -1 when unknown.
func get_ping_ms() -> int:
	var peer := multiplayer.multiplayer_peer
	if not (peer is ENetMultiplayerPeer) or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return -1
	var other := 1
	if multiplayer.is_server():
		other = -1
		for id in players:
			if id != 1:
				other = id
		if other == -1:
			return -1
	var pp: ENetPacketPeer = (peer as ENetMultiplayerPeer).get_peer(other)
	if pp == null:
		return -1
	return int(pp.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))

## The opponent's peer id, or -1.
func get_rival_id() -> int:
	for id in players:
		if id != multiplayer.get_unique_id():
			return id
	return -1

func get_player_ids_sorted() -> Array:
	var ids := players.keys()
	ids.sort()
	return ids

## 0 for the host's fighter, 1 for the joining fighter.
func get_player_index(peer_id: int) -> int:
	return get_player_ids_sorted().find(peer_id)
