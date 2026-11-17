extends Control

## Lobby — Element selection, ready up, and match start.

@onready var player1_label = $HBoxContainer/Player1Panel/NameLabel
@onready var player1_element = $HBoxContainer/Player1Panel/ElementLabel
@onready var player1_ready = $HBoxContainer/Player1Panel/ReadyLabel
@onready var player2_label = $HBoxContainer/Player2Panel/NameLabel
@onready var player2_element = $HBoxContainer/Player2Panel/ElementLabel
@onready var player2_ready = $HBoxContainer/Player2Panel/ReadyLabel

@onready var element_buttons = $ElementSelection
@onready var ready_button = $ReadyButton
@onready var status_label = $StatusLabel
@onready var countdown_label = $CountdownLabel

var is_ready: bool = false

const ELEMENT_NAMES = ["Fire", "Water", "Earth", "Air"]
const ELEMENT_COLORS = [
	Color(1.0, 0.4, 0.1),   # Fire
	Color(0.2, 0.5, 1.0),   # Water
	Color(0.55, 0.45, 0.25), # Earth
	Color(0.7, 0.9, 1.0),   # Air
]

func _ready() -> void:
	countdown_label.visible = false
	_update_display()

func _process(_delta: float) -> void:
	_update_display()

func _update_display() -> void:
	var ids = NetworkManager.get_player_ids_sorted()
	
	if ids.size() >= 1:
		var p1 = NetworkManager.players[ids[0]]
		player1_label.text = p1["name"]
		player1_element.text = ELEMENT_NAMES[p1["element"]]
		player1_element.add_theme_color_override("font_color", ELEMENT_COLORS[p1["element"]])
		player1_ready.text = "READY ✓" if p1["ready"] else "Not Ready"
		player1_ready.add_theme_color_override("font_color", Color.GREEN if p1["ready"] else Color.GRAY)
	
	if ids.size() >= 2:
		var p2 = NetworkManager.players[ids[1]]
		player2_label.text = p2["name"]
		player2_element.text = ELEMENT_NAMES[p2["element"]]
		player2_element.add_theme_color_override("font_color", ELEMENT_COLORS[p2["element"]])
		player2_ready.text = "READY ✓" if p2["ready"] else "Not Ready"
		player2_ready.add_theme_color_override("font_color", Color.GREEN if p2["ready"] else Color.GRAY)
	else:
		player2_label.text = "Waiting..."
		player2_element.text = "—"
		player2_ready.text = ""

func _on_fire_pressed() -> void:
	_select_element(GameManager.Element.FIRE)

func _on_water_pressed() -> void:
	_select_element(GameManager.Element.WATER)

func _on_earth_pressed() -> void:
	_select_element(GameManager.Element.EARTH)

func _on_air_pressed() -> void:
	_select_element(GameManager.Element.AIR)

func _select_element(element: int) -> void:
	if is_ready:
		return  # Can't change while ready
	NetworkManager.set_player_element.rpc_id(1, NetworkManager.local_peer_id, element)
	status_label.text = "Selected: %s" % ELEMENT_NAMES[element]

func _on_ready_pressed() -> void:
	is_ready = !is_ready
	ready_button.text = "CANCEL" if is_ready else "READY"
	NetworkManager.set_player_ready.rpc_id(1, NetworkManager.local_peer_id, is_ready)

func _on_back_pressed() -> void:
	NetworkManager.disconnect_from_game()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
