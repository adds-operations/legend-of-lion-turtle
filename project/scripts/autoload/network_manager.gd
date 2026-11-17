extends Node

## Network Manager — autoloaded singleton.
## Handles hosting, joining, peer connections, and scene transitions.

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_succeeded()
signal connection_failed()
signal server_disconnected()

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 2

# Player info: { peer_id: { "name": ..., "element": ..., "ready": ... } }
var players: Dictionary = {}
var local_peer_id: int = 0
var is_host: bool = false

# Match settings (set by host)
var selected_arena: String = "earth_kingdom"
var round_count: int = 3
var round_time: float = 240.0

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# --- Hosting ---

func host_game(port: int = DEFAULT_PORT) -> Error:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_PLAYERS)
	if error != OK:
		print("[Network] Failed to create server: %s" % error_string(error))
		return error
	
	multiplayer.multiplayer_peer = peer
	is_host = true
	local_peer_id = 1  # Server is always peer 1
	
	# Register host as player
	players[1] = {
		"name": "Player 1 (Host)",
		"element": GameManager.Element.FIRE,
		"ready": false
	}
	
	print("[Network] Hosting on port %d" % port)
	return OK

# --- Joining ---

func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, port)
	if error != OK:
		print("[Network] Failed to connect: %s" % error_string(error))
		return error
	
	multiplayer.multiplayer_peer = peer
	is_host = false
	
	print("[Network] Connecting to %s:%d" % [address, port])
	return OK

# --- Disconnect ---

func disconnect_from_game() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	players.clear()
	is_host = false
	local_peer_id = 0
	print("[Network] Disconnected")

# --- Callbacks ---

func _on_peer_connected(id: int) -> void:
	print("[Network] Peer connected: %d" % id)
	player_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	print("[Network] Peer disconnected: %d" % id)
	players.erase(id)
	player_disconnected.emit(id)

func _on_connected_to_server() -> void:
	local_peer_id = multiplayer.get_unique_id()
	print("[Network] Connected to server as peer %d" % local_peer_id)
	
	# Register self on server
	_register_player.rpc_id(1, local_peer_id)
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	print("[Network] Connection failed")
	multiplayer.multiplayer_peer = null
	connection_failed.emit()

func _on_server_disconnected() -> void:
	print("[Network] Server disconnected")
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()

# --- RPCs ---

@rpc("any_peer", "reliable")
func _register_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	
	players[peer_id] = {
		"name": "Player 2",
		"element": GameManager.Element.WATER,
		"ready": false
	}
	
	# Send all player data to everyone
	_sync_player_list.rpc(players)
	print("[Network] Player registered: %d" % peer_id)

@rpc("authority", "reliable", "call_local")
func _sync_player_list(player_data: Dictionary) -> void:
	players = player_data
	print("[Network] Player list synced: %s" % str(players.keys()))

@rpc("any_peer", "reliable")
func set_player_element(peer_id: int, element: int) -> void:
	if players.has(peer_id):
		players[peer_id]["element"] = element
		_sync_player_list.rpc(players)

@rpc("any_peer", "reliable")
func set_player_ready(peer_id: int, ready: bool) -> void:
	if players.has(peer_id):
		players[peer_id]["ready"] = ready
		_sync_player_list.rpc(players)
		
		# Check if all ready
		if multiplayer.is_server() and players.size() == 2:
			var all_ready = true
			for p in players.values():
				if not p["ready"]:
					all_ready = false
					break
			if all_ready:
				_start_match.rpc()

@rpc("authority", "reliable", "call_local")
func _start_match() -> void:
	print("[Network] All players ready — starting match!")
	get_tree().change_scene_to_file("res://scenes/arena/earth_kingdom_arena.tscn")

# --- Utility ---

func get_local_ip() -> String:
	var addresses = IP.get_local_addresses()
	for addr in addresses:
		# Prefer 192.168.x.x or 10.x.x.x local addresses
		if addr.begins_with("192.168.") or addr.begins_with("10."):
			return addr
	# Fallback
	for addr in addresses:
		if addr != "127.0.0.1" and addr != "::1" and ":" not in addr:
			return addr
	return "127.0.0.1"

func get_player_ids_sorted() -> Array:
	var ids = players.keys()
	ids.sort()
	return ids
