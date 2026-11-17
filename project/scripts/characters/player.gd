extends CharacterBody2D

## Multiplayer Player Controller.
## Handles local input, synced movement/aim, jumping, and attacks.
## The server is authoritative — inputs are sent, server validates.

# --- Config ---
@export var move_speed: float = 200.0
@export var player_index: int = 0  # 0 or 1 (display order)
@export var element: int = 0       # GameManager.Element
@export var peer_id: int = 1       # multiplayer peer ID that owns this player

# --- Jump state ---
var is_jumping: bool = false
var jump_timer: float = 0.0
var jump_cooldown_timer: float = 0.0
var jump_height: float = 0.0

# --- Aim ---
var aim_direction: Vector2 = Vector2.RIGHT

# --- Attack ---
var attack1_cooldown: float = 0.0
const ATTACK1_COOLDOWN_TIME: float = 0.4  # Quick attack
const PROJECTILE_SCENE_PATH: String = "res://scenes/characters/projectile.tscn"

# --- Stats ---
var hp: int = 300
var max_hp: int = 300

# --- Nodes ---
@onready var sprite: Sprite2D = $Sprite
@onready var shadow: Sprite2D = $Shadow
@onready var aim_indicator: Node2D = $AimIndicator
@onready var element_label: Label = $ElementLabel
@onready var hp_bar: ProgressBar = $HPBar
@onready var name_label: Label = $NameLabel

# --- Element visuals ---
const ELEMENT_COLORS = {
	0: Color(1.0, 0.4, 0.1),    # Fire
	1: Color(0.2, 0.5, 1.0),    # Water
	2: Color(0.55, 0.45, 0.25), # Earth
	3: Color(0.7, 0.9, 1.0),    # Air
}

const ELEMENT_NAMES = {
	0: "Fire",
	1: "Water",
	2: "Earth",
	3: "Air",
}

func _ready() -> void:
	hp = GameManager.base_hp
	max_hp = hp
	_update_visuals()

func _update_visuals() -> void:
	var color: Color = ELEMENT_COLORS.get(element, Color.WHITE)
	if sprite:
		sprite.modulate = color
	if element_label:
		element_label.text = ELEMENT_NAMES.get(element, "???")
		element_label.add_theme_color_override("font_color", color)
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
	if name_label:
		var is_local = (peer_id == multiplayer.get_unique_id())
		name_label.text = "YOU" if is_local else "ENEMY"
		name_label.add_theme_color_override("font_color", Color.GREEN if is_local else Color.RED)

func is_local_player() -> bool:
	return peer_id == multiplayer.get_unique_id()

func _physics_process(delta: float) -> void:
	if is_local_player():
		_handle_local_input(delta)
	
	_handle_jump(delta)
	_update_sprite_position()
	_update_hp_display()
	move_and_slide()

func _handle_local_input(delta: float) -> void:
	# --- Movement ---
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("move_up"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_down"):
		input_dir.y += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	
	if input_dir.length() > 0:
		input_dir = input_dir.normalized()
	
	velocity = input_dir * move_speed
	
	# --- Aiming ---
	var mouse_pos = get_global_mouse_position()
	aim_direction = (mouse_pos - global_position).normalized()
	if aim_indicator:
		aim_indicator.rotation = aim_direction.angle()
	
	# Send state to server
	_send_input.rpc_id(1, input_dir, aim_direction, global_position)
	
	# --- Jump ---
	if Input.is_action_just_pressed("jump") and not is_jumping and jump_cooldown_timer <= 0:
		_request_jump.rpc_id(1)
		# Predict locally
		is_jumping = true
		jump_timer = 0.0
	
	# --- Attack ---
	attack1_cooldown -= delta
	if Input.is_action_just_pressed("attack_1") and attack1_cooldown <= 0:
		_request_attack.rpc_id(1, aim_direction, 1)
		attack1_cooldown = ATTACK1_COOLDOWN_TIME

# --- Server RPCs ---

@rpc("any_peer", "unreliable_ordered")
func _send_input(input_dir: Vector2, aim_dir: Vector2, client_pos: Vector2) -> void:
	if not multiplayer.is_server():
		return
	
	var sender = multiplayer.get_remote_sender_id()
	if sender != peer_id:
		return  # Validate ownership
	
	velocity = input_dir * move_speed
	aim_direction = aim_dir
	
	# Broadcast to other clients
	_sync_state.rpc(global_position, velocity, aim_dir, is_jumping, jump_height)

@rpc("any_peer", "reliable")
func _request_jump() -> void:
	if not multiplayer.is_server():
		return
	if is_jumping or jump_cooldown_timer > 0:
		return
	
	is_jumping = true
	jump_timer = 0.0
	_sync_jump.rpc(true)

@rpc("any_peer", "reliable")
func _request_attack(aim_dir: Vector2, attack_type: int) -> void:
	if not multiplayer.is_server():
		return
	
	var sender = multiplayer.get_remote_sender_id()
	if sender != peer_id:
		return
	
	# Spawn projectile on server
	_spawn_projectile(aim_dir, attack_type)

func _spawn_projectile(aim_dir: Vector2, _attack_type: int) -> void:
	var projectile_scene = load(PROJECTILE_SCENE_PATH)
	if projectile_scene == null:
		print("[Player] Failed to load projectile scene")
		return
	
	var projectile = projectile_scene.instantiate()
	var spawn_pos = global_position + aim_dir * 30
	projectile.global_position = spawn_pos
	projectile.setup(aim_dir, element, peer_id, 10)
	
	# Add to arena
	get_tree().current_scene.add_child(projectile, true)
	print("[Player %d] Fire bolt!" % peer_id)

# --- Sync RPCs (server → clients) ---

@rpc("authority", "unreliable_ordered", "call_remote")
func _sync_state(pos: Vector2, vel: Vector2, aim_dir: Vector2, jumping: bool, height: float) -> void:
	# Remote player — interpolate toward server position
	global_position = global_position.lerp(pos, 0.5)
	velocity = vel
	aim_direction = aim_dir
	is_jumping = jumping
	jump_height = height
	
	if aim_indicator:
		aim_indicator.rotation = aim_dir.angle()

@rpc("authority", "reliable", "call_local")
func _sync_jump(jumping: bool) -> void:
	is_jumping = jumping
	if jumping:
		jump_timer = 0.0

# --- Jump physics (runs on all peers) ---

func _handle_jump(delta: float) -> void:
	if jump_cooldown_timer > 0:
		jump_cooldown_timer -= delta
	
	if is_jumping:
		jump_timer += delta
		var t = jump_timer / GameManager.jump_airborne_time
		
		if t >= 1.0:
			is_jumping = false
			jump_timer = 0.0
			jump_height = 0.0
			jump_cooldown_timer = GameManager.jump_cooldown
		else:
			jump_height = -4.0 * 60.0 * (t * t - t)

func _update_sprite_position() -> void:
	if sprite:
		sprite.position.y = -jump_height
	if shadow:
		shadow.position = Vector2.ZERO
		var shadow_alpha = 1.0 - (jump_height / 60.0) * 0.5
		shadow.modulate.a = clamp(shadow_alpha, 0.3, 1.0)
		var shadow_scale = 1.0 - (jump_height / 60.0) * 0.3
		shadow.scale = Vector2(shadow_scale, shadow_scale)

func _update_hp_display() -> void:
	if hp_bar:
		hp_bar.value = hp

func take_damage(amount: int) -> void:
	if not multiplayer.is_server():
		return
	
	hp = max(0, hp - amount)
	_sync_hp.rpc(hp)
	
	if hp <= 0:
		_on_defeated()

@rpc("authority", "reliable", "call_local")
func _sync_hp(new_hp: int) -> void:
	hp = new_hp
	_update_hp_display()
	
	# Flash on hit
	if sprite:
		sprite.modulate = Color.WHITE
		await get_tree().create_timer(0.1).timeout
		_update_visuals()

func _on_defeated() -> void:
	print("[Player %d] Defeated!" % peer_id)
	var winner_index = 1 if player_index == 0 else 0
	GameManager.end_round(winner_index)

func set_element(new_element: int) -> void:
	element = new_element
	_update_visuals()
