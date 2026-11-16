extends CanvasLayer

## HUD overlay — shows HP, element, round info, and aim.

@onready var hp_label: Label = $HPLabel
@onready var element_display: Label = $ElementDisplay
@onready var round_label: Label = $RoundLabel
@onready var controls_label: Label = $ControlsLabel

func _ready() -> void:
	if controls_label:
		controls_label.text = "WASD: Move | Mouse: Aim | Space: Jump | Tab: Switch Element\nLMB: Attack 1 | RMB: Attack 2 | E: Attack 3 | Q: Special"

func update_player_info(player) -> void:
	if hp_label and player:
		hp_label.text = "HP: %d / %d" % [player.hp, player.max_hp]
	
	if element_display and player:
		var elem_name = player.ELEMENT_NAMES.get(player.element, "???")
		element_display.text = elem_name
		element_display.add_theme_color_override("font_color", player.ELEMENT_COLORS.get(player.element, Color.WHITE))
	
	if round_label:
		round_label.text = "Round %d | Score: %d - %d" % [
			GameManager.current_round,
			GameManager.scores[0],
			GameManager.scores[1]
		]
