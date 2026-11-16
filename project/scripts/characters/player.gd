extends CharacterBody2D

## Player character controller.
## Handles movement, aiming, jumping, and collision.
## Uses isometric-style top-down with simulated height for jumps.

# --- Config ---
@export var move_speed: float = 200.0
@export var player_index: int = 0  # 0 or 1
@export var element: int = 0  # GameManager.Element

# --- Jump state ---
var is_jumping: bool = false
var jump_timer: float = 0.0
var jump_cooldown_timer: float = 0.0
var jump_height: float = 0.0  # visual-only simulated height
var ground_position: Vector2 = Vector2.ZERO

# --- Aim ---
var aim_direction: Vector2 = Vector2.RIGHT

# --- Nodes ---
@onready var sprite: Sprite2D = $Sprite
@onready var shadow: Sprite2D = $Shadow
@onready var collision_shape: CollisionShape2D = $CollisionShape
@onready var aim_indicator: Node2D = $AimIndicator
@onready var element_label: Label = $ElementLabel
@onready var hp_bar: ProgressBar = $HPBar

# --- Stats ---
var hp: int = 300
var max_hp: int = 300

# --- Element colors ---
const ELEMENT_COLORS = {
	0: Color(1.0, 0.4, 0.1),    # Fire - orange-red
	1: Color(0.2, 0.5, 1.0),    # Water - blue
	2: Color(0.55, 0.45, 0.25), # Earth - brown
	3: Color(0.7, 0.9, 1.0),    # Air - light cyan
}

const ELEMENT_NAMES = {
	0: "Fire",
	1: "Water",
	2: "Earth",
	3: "Air",
}

func _ready() -> void:
	ground_position = position
	hp = GameManager.base_hp
	max_hp = hp
	_update_visuals()

func _update_visuals() -> void:
	var color: Color = ELEMENT_COLORS.get(element, Color.WHITE)
	sprite.modulate = color
	
	element_label.text = ELEMENT_NAMES.get(element, "???")
	element_label.add_theme_color_override("font_color", color)
	
	hp_bar.max_value = max_hp
	hp_bar.value = hp

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_jump(delta)
	_handle_aim()
	_update_sprite_position()
	_update_hp_bar()
	move_and_slide()

func _handle_movement(delta: float) -> void:
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
	
	# Update ground position for shadow tracking
	if not is_jumping:
		ground_position = position

func _handle_jump(delta: float) -> void:
	# Cooldown
	if jump_cooldown_timer > 0:
		jump_cooldown_timer -= delta
	
	# Start jump
	if Input.is_action_just_pressed("jump") and not is_jumping and jump_cooldown_timer <= 0:
		is_jumping = true
		jump_timer = 0.0
	
	# During jump
	if is_jumping:
		jump_timer += delta
		var t = jump_timer / GameManager.jump_airborne_time
		
		if t >= 1.0:
			# Land
			is_jumping = false
			jump_timer = 0.0
			jump_height = 0.0
			jump_cooldown_timer = GameManager.jump_cooldown
			ground_position = position
		else:
			# Parabolic arc: peak at t=0.5
			jump_height = -4.0 * 60.0 * (t * t - t)  # max height ~60px

func _handle_aim() -> void:
	var mouse_pos = get_global_mouse_position()
	aim_direction = (mouse_pos - global_position).normalized()
	
	if aim_indicator:
		aim_indicator.rotation = aim_direction.angle()

func _update_sprite_position() -> void:
	# Sprite moves up visually when jumping, but collision stays on ground
	if sprite:
		sprite.position.y = -jump_height
	
	# Shadow stays at ground level and fades during jump
	if shadow:
		shadow.position = Vector2.ZERO
		var shadow_alpha = 1.0 - (jump_height / 60.0) * 0.5
		shadow.modulate.a = clamp(shadow_alpha, 0.3, 1.0)
		# Shadow scales down when higher
		var shadow_scale = 1.0 - (jump_height / 60.0) * 0.3
		shadow.scale = Vector2(shadow_scale, shadow_scale)

func _update_hp_bar() -> void:
	if hp_bar:
		hp_bar.value = hp

func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)
	_update_hp_bar()
	
	if hp <= 0:
		_on_defeated()

func _on_defeated() -> void:
	print("[Player %d] Defeated!" % player_index)
	# Will trigger round end in multiplayer

func set_element(new_element: int) -> void:
	element = new_element
	_update_visuals()
