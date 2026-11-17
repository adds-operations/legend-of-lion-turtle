extends Area2D

## Projectile — a basic attack projectile (fire bolt, etc).
## Spawned by the server, travels in a direction, deals damage on hit.

@export var speed: float = 400.0
@export var damage: int = 10
@export var lifetime: float = 2.0
@export var owner_peer_id: int = -1

var direction: Vector2 = Vector2.RIGHT
var element: int = 0  # GameManager.Element
var age: float = 0.0

const ELEMENT_COLORS = {
	0: Color(1.0, 0.4, 0.1),    # Fire
	1: Color(0.2, 0.5, 1.0),    # Water
	2: Color(0.55, 0.45, 0.25), # Earth
	3: Color(0.7, 0.9, 1.0),    # Air
}

func _ready() -> void:
	# Set visual color based on element
	if has_node("Sprite"):
		$Sprite.modulate = ELEMENT_COLORS.get(element, Color.WHITE)
	
	# Connect hit detection
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	age += delta
	
	if age >= lifetime:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server():
		return
	
	# Don't hit the player who shot it
	if body is CharacterBody2D and body.has_method("take_damage"):
		if body.get("peer_id") != owner_peer_id:
			body.take_damage(damage)
			_destroy.rpc()

@rpc("authority", "reliable", "call_local")
func _destroy() -> void:
	queue_free()

func setup(dir: Vector2, elem: int, owner_id: int, dmg: int = 10) -> void:
	direction = dir.normalized()
	element = elem
	owner_peer_id = owner_id
	damage = dmg
	rotation = dir.angle()
