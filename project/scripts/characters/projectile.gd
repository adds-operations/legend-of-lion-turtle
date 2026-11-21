extends Area2D

## A thrown power (every attack in scripts/data/elements.gd is one or more).
## The arena spawns an identical copy on every peer (same node name), so all
## players see the same shot. Only the host checks hits and decides when it
## disappears; clients just fly the visual until the host removes it.
##
## Height (spec §4 "jumping must affect gameplay"): a power thrown from the
## ground travels low and only hits fighters on the ground — jump over it. A
## power thrown mid-jump travels high and only hits fighters in the air — stay
## grounded to let it pass. Walls and cover stop both.
## Hits come from any side: the hitbox is the fighter's ground footprint.

const T = preload("res://scripts/ui/kit/ui_tokens.gd")
const Elements = preload("res://scripts/data/elements.gd")
const PowerTrail = preload("res://scripts/fx/power_trail.gd")
const BendingFX = preload("res://scripts/fx/bending_fx.gd")
const FxSprite = preload("res://scripts/fx/fx_sprite.gd")
const AnimFX = preload("res://scripts/fx/anim_fx.gd")
const ANIM_FPS := 14.0
const ANIM_SCALE := 0.5          # animated attack sheets: 128 px cells drawn at 64 px
var _spec: Dictionary = {}       # this attack's animation (BendingFX.anim_spec), if any art is installed
var _anim_t: float = 0.0
var _trail_d: float = 0.0

const LOW_Y := -26.0    # drawn at chest height when thrown from the ground
const HIGH_Y := -58.0   # drawn above the head when thrown mid-jump

@export var owner_peer_id: int = -1

var direction: Vector2 = Vector2.RIGHT
var element: int = 0
var slot: int = 0
var airborne: bool = false
var speed: float = 420.0
var damage: int = 10
var radius: float = 7.0
var knock: float = 0.0
var lifetime: float = 1.6
var pierce: bool = false
var tick: float = 0.5
var power: float = 1.0
const EarthRise = preload("res://scripts/fx/earth_rise.gd")
const RISE_TIME := 0.12          # earth shots lift out of the ground this fast (no added delay)
var _rise_t: float = -1.0
var _rise_to: float = 0.0          # Power Shot combo: drawn bigger
var age: float = 0.0
var _spent: bool = false
var _last_hit: Dictionary = {}   # peer -> age of last hit (pierce)
var _visual: Node2D
var _sprite: Sprite2D
var _fx: Dictionary = {}
var _kind: String = "shot"
var _dropped: float = 0.0       # line attacks: distance since the last eruption
## Curve combo: radians per second the path bends (0 = straight), up to _curve_left in total.
var curve: float = 0.0
var _curve_left: float = 0.0
const CURVE_RATE := 2.4         # rad/s
const CURVE_TOTAL := 1.75       # ≈100°

var trail: Node2D

func setup(dir: Vector2, elem: int, owner_id: int, attack_slot: int, high: bool, bend: float = 0.0) -> void:
	direction = dir.normalized()
	curve = signf(bend) * CURVE_RATE
	_curve_left = CURVE_TOTAL if bend != 0.0 else 0.0
	element = elem
	slot = attack_slot
	owner_peer_id = owner_id
	airborne = high
	var a := Elements.attack(elem, attack_slot)
	speed = a["speed"]
	damage = a["dmg"]
	radius = a["r"]
	knock = a["knock"]
	lifetime = a["life"]
	pierce = a["pierce"]
	tick = a["tick"]
	_kind = a["kind"]
	_fx = BendingFX.fx(elem, attack_slot)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var color := T.element_glow(element)
	var shape := CircleShape2D.new()
	shape.radius = radius
	$CollisionShape.shape = shape
	for n in ["Sprite", "Core"]:
		if has_node(n):
			get_node(n).queue_free()  # the old diamond placeholder
	var upright: bool = _fx.get("upright", false)
	# The visual rides at chest (or above-head) height; the hitbox stays on the ground plane.
	_visual = Node2D.new()
	_visual.position = Vector2(0, (HIGH_Y + 26.0 if airborne else 0.0) if upright else (HIGH_Y if airborne else LOW_Y))
	add_child(_visual)
	_spec = BendingFX.anim_spec(element, slot)
	if _fx.has("fly") and not _spec.is_empty():
		# animated: the travel row loops; art faces right
		_sprite = Sprite2D.new()
		_sprite.texture = BendingFX.part_frame(_spec["t"], 0.0)
		var asc: float = float(_spec["s"]) * (1.3 if power > 1.0 else 1.0)
		_sprite.scale = Vector2(asc, asc)
		if upright:
			_sprite.offset = Vector2(0, -48)        # stands on the ground (art sits on the cell's bottom)
			_sprite.flip_h = direction.x < -0.01
		else:
			_sprite.rotation = direction.angle()
			_sprite.flip_v = direction.x < -0.01    # keep it the right way up going left
		_visual.add_child(_sprite)
	elif _fx.has("fly"):
		_sprite = Sprite2D.new()
		_sprite.texture = BendingFX.frame(element, _fx["fly"])
		var sc: float = _fx.get("scale", 0.5) * (1.3 if power > 1.0 else 1.0)
		_sprite.scale = Vector2(sc, sc)
		if upright:
			_sprite.offset = Vector2(0, -_sprite.texture.get_size().y / 2.0)  # stands on the ground
		if _fx.get("orient", false):
			_sprite.rotation = direction.angle()
			if direction.x < -0.01 and not _fx.get("spin", 0.0):
				_sprite.flip_v = true  # keep crescents and ribbons the right way up
		_visual.add_child(_sprite)
	# a soft ground shadow so height reads at a glance
	if _kind != "line":
		var shadow := Polygon2D.new()
		var pts := PackedVector2Array()
		for i in 12:
			var t := TAU * i / 12.0
			pts.append(Vector2(cos(t) * radius, sin(t) * radius * 0.4))
		shadow.polygon = pts
		shadow.color = Color(0, 0, 0, 0.22 if not airborne else 0.12)
		add_child(shadow)
		move_child(shadow, 0)
	# Blur-gradient trail + halo for things that fly (never on the bender).
	if _kind == "shot" and not upright and (slot == 0 or curve != 0.0):
		trail = PowerTrail.new()
		trail.width = 6.0 + radius * 0.6
		trail.halo = 6.0 + radius * 0.6
		trail.follow(_visual, color)
		get_parent().add_child.call_deferred(trail)
	# Earth comes out of the ground: the rock rises from a crack before it flies.
	if element == 2 and _kind == "shot" and not upright and not airborne:
		_rise_to = _visual.position.y
		_visual.position.y = 0.0
		_rise_t = 0.0
		EarthRise.crack(get_parent(), global_position)

func _physics_process(delta: float) -> void:
	if _rise_t >= 0.0 and _visual:
		_rise_t += delta
		var k := minf(1.0, _rise_t / RISE_TIME)
		_visual.position.y = lerpf(0.0, _rise_to, 1.0 - (1.0 - k) * (1.0 - k))
		if k >= 1.0:
			_rise_t = -1.0
	if _curve_left > 0.0:
		var turn := minf(absf(curve) * delta, _curve_left)
		_curve_left -= turn
		direction = direction.rotated(turn * signf(curve))
		if _sprite and (_fx.get("orient", false) or (not _spec.is_empty() and not _fx.get("upright", false) and float(_spec["spin"]) == 0.0)):
			_sprite.rotation = direction.angle()
	position += direction * speed * delta
	age += delta
	if age >= lifetime:
		# Every peer expires its own copy at the same age; no RPC needed.
		if _kind != "line":
			play_end()
		queue_free()
		return
	if not _spec.is_empty() and _sprite:
		_anim_t += delta
		_sprite.texture = BendingFX.part_frame(_spec["t"], _anim_t, ANIM_FPS)
		if float(_spec["spin"]) != 0.0:
			_sprite.rotation += delta * float(_spec["spin"]) * (1.0 if direction.x >= 0.0 else -1.0)
		_trail_d += speed * delta
		if not (_spec["tr"] as Array).is_empty() and _trail_d >= 38.0 and _kind == "shot":
			_trail_d = 0.0
			var tr := AnimFX.part(_spec["tr"], global_position + _visual.position, float(_spec["s"]) * 0.7, 0.3, false,
					_fx.get("upright", false), 0.0 if _fx.get("upright", false) else direction.angle())
			get_parent().add_child(tr)
	elif _sprite and _fx.get("spin", 0.0):
		_sprite.rotation += delta * float(_fx["spin"]) * (1.0 if direction.x >= 0.0 else -1.0)
	if _kind == "line":
		_dropped += speed * delta
		if _dropped >= float(_fx.get("every", 32.0)):
			_dropped = 0.0
			_erupt()
	if multiplayer.is_server() and not _spent:
		_host_hits()

## Host: check every fighter this frame (not just new contacts), so landing
## from a jump inside a low power still counts.
## The hurtbox is the bender's whole silhouette on the ground plane, not the
## small feet box that blocks movement: a power drawn across the body hits,
## the way it looks. Walls and cover still stop it.
const HURT_HALF_W := 16.0     # px each side of the bender's centre
const HURT_UP := 24.0         # px north of the feet (the drawn body overlaps this band)
const HURT_DOWN := 10.0       # px south of the feet

func _host_hits() -> void:
	var arena := get_tree().current_scene
	var fighters: Array = arena.fighters.values() if arena and "fighters" in arena else []
	for body in fighters:
		if body.peer_id == owner_peer_id or body.is_defeated or body.get("intangible"):
			continue
		if body.is_airborne() != airborne:
			continue  # different height: it passes over / under
		var d: Vector2 = global_position - body.global_position
		if absf(d.x) > HURT_HALF_W + radius or d.y < -(HURT_UP + radius) or d.y > HURT_DOWN + radius:
			continue
		var pid: int = body.peer_id
		if pierce and _last_hit.has(pid) and age - float(_last_hit[pid]) < tick:
			continue
		_last_hit[pid] = age
		body.take_damage(arena.combo_damage(owner_peer_id, damage) if arena.has_method("combo_damage") else damage,
				global_position - direction * 30.0)
		if knock > 0.0 and body.has_method("apply_knockback"):
			body.apply_knockback(direction * knock)
		if not pierce:
			_finish()
			return
	for body in get_overlapping_bodies():
		if body is StaticBody2D:
			if body.has_meta("ice_wall"):
				body.get_meta("ice_wall").wall_hit()
			_finish()  # walls and cover stop every power
			return

## Line attacks: crystals / rocks burst up from the ground behind the front.
func _erupt() -> void:
	if not _spec.is_empty():
		var e := AnimFX.part(_spec["t"], global_position + Vector2(0, 8), float(_spec["s"]), 0.45, false, true)
		e.flip = direction.x < -0.01
		get_parent().add_child(e)
		return
	var f := FxSprite.make(BendingFX.frame(element, _fx["drop"]), global_position + Vector2(0, 8),
			_fx.get("drop_scale", 0.4), 0.5, true, BendingFX.frame(element, _fx["hit"]))
	f.grow = 0.05
	get_parent().add_child(f)

## Every peer, as this power ends (hit, wall, or out of time): its finish art.
func play_end() -> void:
	if not is_inside_tree():
		return
	var at := global_position + (_visual.position if _visual else Vector2.ZERO)
	if not _spec.is_empty():
		var ground: bool = _fx.get("upright", false) or _kind == "line"
		var hs := clampf(float(_spec["s"]) * 1.2, 0.35, 0.6)
		get_parent().add_child(AnimFX.part(_spec["i"], global_position + Vector2(0, 8) if ground else at,
				hs, 0.4, false, ground))
		return
	if not _fx.has("hit"):
		return
	var f := FxSprite.make(BendingFX.frame(element, _fx["hit"]), at, _fx.get("hit_scale", 0.4), 0.35)
	get_parent().add_child(f)

func _finish() -> void:
	_spent = true
	var arena := get_tree().current_scene
	if arena and arena.has_method("despawn_projectile"):
		arena.despawn_projectile(name)
	else:
		queue_free()
