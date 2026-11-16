extends Node

## Global game manager — autoloaded singleton.
## Tracks match state, round info, and shared config.

# --- Enums ---
enum Element { FIRE, WATER, EARTH, AIR }
enum GameState { MENU, LOBBY, PLAYING, ROUND_END, MATCH_END }

# --- Match config ---
var rounds_to_win: int = 2  # best-of-3
var round_time: float = 240.0  # 4 minutes
var base_hp: int = 300
var stat_points: int = 8

# --- Match state ---
var current_state: GameState = GameState.MENU
var current_round: int = 0
var scores: Array[int] = [0, 0]  # [player1, player2]

# --- Jump config ---
var jump_airborne_time: float = 0.6
var jump_cooldown: float = 1.0

# --- Arena config ---
var arena_bounds: Rect2 = Rect2(0, 0, 1280, 720)

func _ready() -> void:
	print("[GameManager] Legend of Lion Turtle initialized")

func start_round() -> void:
	current_round += 1
	current_state = GameState.PLAYING
	print("[GameManager] Round %d started" % current_round)

func end_round(winner_index: int) -> void:
	if winner_index >= 0 and winner_index < 2:
		scores[winner_index] += 1
	current_state = GameState.ROUND_END
	
	if scores[0] >= rounds_to_win or scores[1] >= rounds_to_win:
		current_state = GameState.MATCH_END
	
	print("[GameManager] Round ended. Scores: %d - %d" % [scores[0], scores[1]])

func reset_match() -> void:
	current_round = 0
	scores = [0, 0]
	current_state = GameState.LOBBY
