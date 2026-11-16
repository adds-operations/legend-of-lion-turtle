extends Node2D

## Earth Kingdom Courtyard Arena
## Contains terrain zones (water, earth, neutral), obstacles, and spawn points.

@onready var player = $Player
@onready var terrain = $Terrain
@onready var hud = $CanvasLayer/HUD

func _ready() -> void:
	GameManager.start_round()
	print("[Arena] Earth Kingdom Courtyard loaded")

func _process(_delta: float) -> void:
	_update_hud()

func _update_hud() -> void:
	if hud and player:
		hud.update_player_info(player)

func _input(event: InputEvent) -> void:
	# Cycle element with Tab for testing
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		if player:
			var next_elem = (player.element + 1) % 4
			player.set_element(next_elem)
			print("[Arena] Switched to %s" % player.ELEMENT_NAMES[next_elem])
