extends Control

## Main Menu — Create Arena, Join Arena, or Quit.

@onready var main_buttons = $VBoxContainer
@onready var join_panel = $JoinPanel
@onready var host_panel = $HostPanel
@onready var ip_input = $JoinPanel/VBoxContainer/IPInput
@onready var port_input = $JoinPanel/VBoxContainer/PortInput
@onready var host_ip_label = $HostPanel/VBoxContainer/IPLabel
@onready var host_port_label = $HostPanel/VBoxContainer/PortLabel
@onready var host_status_label = $HostPanel/VBoxContainer/StatusLabel
@onready var join_status_label = $JoinPanel/VBoxContainer/StatusLabel
@onready var title_label = $TitleLabel

func _ready() -> void:
	join_panel.visible = false
	host_panel.visible = false
	
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)

# --- Button handlers ---

func _on_create_pressed() -> void:
	main_buttons.visible = false
	host_panel.visible = true
	
	var error = NetworkManager.host_game()
	if error == OK:
		var ip = NetworkManager.get_local_ip()
		host_ip_label.text = "IP: %s" % ip
		host_port_label.text = "Port: %d" % NetworkManager.DEFAULT_PORT
		host_status_label.text = "Waiting for opponent..."
	else:
		host_status_label.text = "Failed to create server!"

func _on_join_pressed() -> void:
	main_buttons.visible = false
	join_panel.visible = true
	ip_input.text = ""
	port_input.text = str(NetworkManager.DEFAULT_PORT)
	join_status_label.text = "Enter host IP address"

func _on_connect_pressed() -> void:
	var address = ip_input.text.strip_edges()
	var port = int(port_input.text.strip_edges())
	
	if address.is_empty():
		join_status_label.text = "Please enter an IP address"
		return
	
	if port <= 0:
		port = NetworkManager.DEFAULT_PORT
	
	join_status_label.text = "Connecting to %s:%d..." % [address, port]
	var error = NetworkManager.join_game(address, port)
	if error != OK:
		join_status_label.text = "Failed to connect!"

func _on_back_pressed() -> void:
	NetworkManager.disconnect_from_game()
	join_panel.visible = false
	host_panel.visible = false
	main_buttons.visible = true

func _on_quit_pressed() -> void:
	get_tree().quit()

# --- Network callbacks ---

func _on_player_connected(_peer_id: int) -> void:
	if NetworkManager.is_host:
		host_status_label.text = "Opponent connected! Loading lobby..."
		# Short delay then go to lobby
		await get_tree().create_timer(0.5).timeout
		NetworkManager._start_lobby.rpc()

func _on_connection_succeeded() -> void:
	join_status_label.text = "Connected! Waiting for host..."

func _on_connection_failed() -> void:
	join_status_label.text = "Connection failed! Check IP and try again."
