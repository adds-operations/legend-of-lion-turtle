extends CharacterBody2D

## Networked fighter.
##
## Authority model (see docs/game-design-spec.md §14):
## - The host (peer 1) owns the simulation: position, jumps, cooldowns, HP.
## - The owning peer reads input, moves locally for responsiveness (client
##   prediction) and streams its predicted position + aim to the host.
## - The host validates each move against a speed budget and replays it
##   through its own collision (walls, obstacles, the other fighter), so a
##   client can never move faster or through geometry.
## - The host streams snapshots back; the owner reconciles against them and
##   the other peer interpolates toward them.
##
## Every peer spawns both fighters with the same node name (the peer id), so
## RPCs resolve to the same node path everywhere.

const Roster = preload("res://scripts/data/roster.gd")
const T = preload("res://scripts/ui/kit/ui_tokens.gd")
const AvatarAura = preload("res://scripts/fx/avatar_aura.gd")

signal hp_changed(new_hp: int, delta: int)
signal avatar_changed()        # became the Avatar, or switched element as the Avatar

# --- Config ---
@export var move_speed: float = 200.0
@export var player_index: int = 0  # 0 = host's fighter, 1 = joining fighter
@export var element: int = 0       # GameManager.Element
@export var peer_id: int = 1       # peer that controls this fighter
@export var fighter_id: String = "" # bender from scripts/data/roster.gd

const JUMP_PEAK: float = 60.0
const Elements = preload("res://scripts/data/elements.gd")
## Q W E R throw the bender's four powers straight ahead (the facing);
## as the Avatar they throw Fire, Water, Earth and Air. No mouse aiming.
const SLOTS := 4

# Reconciliation (owner on a client)
const RECONCILE_IGNORE: float = 4.0    # px of error we tolerate silently
const RECONCILE_SNAP: float = 64.0     # px of error that forces a hard snap
const RECONCILE_BLEND: float = 0.25    # fraction of error corrected per snapshot
# Interpolation (non-owner on a client)
const REMOTE_LERP_RATE: float = 18.0

# --- Jump state ---
var is_jumping: bool = false
var jump_timer: float = 0.0
var jump_cooldown_timer: float = 0.0
var jump_height: float = 0.0

# --- Aim ---
var aim_direction: Vector2 = Vector2.RIGHT

# --- Attack ---
var attack_cd: Array = [0.0, 0.0, 0.0, 0.0]      # owner-side per key, gates sending requests
var attack_cd_total: Array = [1.0, 1.0, 1.0, 1.0]
var _host_cd: Array = [0.0, 0.0, 0.0, 0.0]        # host-side per key, validates requests
var _host_cast_t: float = 0.0                       # host: time since the last cast
# Knockback: spread over a few physics ticks on the host and on the owner
var _knock: Vector2 = Vector2.ZERO
var _knock_ticks: int = 0
const KNOCK_TICKS := 6

# --- Raava / Avatar (spec §12) ---
const FUSION_TIME: float = 0.44         # raava_fusion: 3 frames at 8 fps
const SWITCH_RECOVERY: float = 0.3      # Avatar element switch: no attacks for this long
var is_avatar: bool = false
var active_element: int = 0             # the element this fighter bends right now
var channeling: bool = false            # set on every peer from the host's claim state
var channel_held: bool = false          # host: the owner is holding Q
var _q_sent: bool = false               # owner: last Q state sent to the host
var _fusion_t: float = 0.0
var _switch_t: float = 0.0              # every peer: switch recovery left
var _aura: Node2D
var _bot_switch_timer: float = 3.0

# --- Training ---
var free_switch: bool = false           # training: 1–4 switch element without being the Avatar
enum AIMode { NONE = -1, STAND, MOVE, SPAR }
var ai_mode: int = AIMode.NONE          # training partner, simulated on the host
var _ai_t: float = 0.0
var _ai_fire_t: float = 1.5
var _bot_stuck_t: float = 0.0
var _bot_last_pos: Vector2 = Vector2.ZERO

# --- Stats ---
var hp: int = 300
var max_hp: int = 300
var is_defeated: bool = false

# --- Round flags (set by the arena on every peer) ---
var net_ready: bool = false  # both peers have spawned fighters; RPCs are safe
var can_act: bool = false    # round is live; input and attacks are accepted

# --- Networking state ---
var _move_budget: float = 0.0          # host: px a remote owner may still move
var _moved_recently: float = 0.0        # host: seconds since remote fighter last moved
var _input_seq: int = 0                 # owner: last sent input sequence
var _acked_seq: int = 0                 # host: last input sequence applied
var _pending: Dictionary = {}           # owner: seq -> predicted position
var _net_target: Vector2 = Vector2.ZERO # non-owner client: snapshot target
var _has_snapshot: bool = false

# --- Visual state ---
# Animation state (drives the 8 actions x 4 directions of the bender's SpriteFrames)
const STRIKE_TIME: float = 0.3
const HIT_TIME: float = 0.18
const LAND_TIME: float = 0.17
const TAKEOFF_TIME: float = 0.12
var _facing: String = "south"
var _strike_t: float = 0.0
var _hit_t: float = 0.0
var _land_t: float = 0.0
var _air_t: float = 0.0
var _was_jumping: bool = false
var _restart_anim: bool = false
var _tag_y: float = 0.0  # name chip rest height
var _bar_y: float = 0.0  # mini HP bar rest height

# --- Debug bot (--bot) ---
var _bot_time: float = 0.0
var _bot_fire_timer: float = 0.0
var _bot_jump_timer: float = 1.0

# --- Nodes ---
@onready var body: AnimatedSprite2D = $Body
@onready var shadow: Sprite2D = $Shadow
@onready var aim_indicator: Node2D = $AimIndicator
@onready var side_ring: Node2D = $SideRing
@onready var hp_bar: ProgressBar = $HPBar
@onready var name_label: Label = $NameLabel

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

## Called by the arena before add_child().
func setup(id: int, index: int, elem: int, spawn_pos: Vector2, fighter: String = "") -> void:
	peer_id = id
	player_index = index
	element = elem
	active_element = elem
	fighter_id = fighter if Roster.is_valid(fighter, elem) else Roster.default_for(elem)
	name = str(id)
	position = spawn_pos
	_net_target = spawn_pos
	aim_direction = Vector2.RIGHT if index == 0 else Vector2.LEFT

func _ready() -> void:
	hp = GameManager.base_hp
	max_hp = hp
	_style_hp_bar()
	if shadow and shadow.texture == null:
		shadow.texture = _make_shadow_texture()
	_apply_art()
	_update_visuals()
	if name_label:
		_tag_y = name_label.position.y
	if hp_bar:
		_bar_y = hp_bar.position.y

func is_local_player() -> bool:
	return peer_id == multiplayer.get_unique_id()

# =====================================================================
# Main loop
# =====================================================================

func _physics_process(delta: float) -> void:
	var is_host := multiplayer.is_server()
	var local := is_local_player()

	for i in SLOTS:
		attack_cd[i] = maxf(0.0, attack_cd[i] - delta)
		_host_cd[i] = maxf(0.0, _host_cd[i] - delta)
	_host_cast_t += delta
	if _knock_ticks > 0 and (local or is_host):
		_knock_ticks -= 1
		move_and_collide(_knock)
	_switch_t = maxf(0.0, _switch_t - delta)

	if local:
		_owner_tick(delta)
	elif is_host and ai_mode != AIMode.NONE:
		_ai_tick(delta)
	elif is_host:
		# Remote fighter: refill its movement budget (a little headroom for jitter,
		# capped so a burst after a lag spike stays small).
		_move_budget = minf(_move_budget + move_speed * delta * 1.15, move_speed * 0.25)
		_moved_recently += delta

	if local:
		move_and_slide()
	if local or is_host:
		_simulate_jump(delta)
	elif _has_snapshot:
		# Pure display copy on a client: smooth toward the host's position.
		global_position = global_position.lerp(_net_target, clampf(REMOTE_LERP_RATE * delta, 0.0, 1.0))

	if local and not is_host and net_ready and _input_seq > 0:
		_pending[_input_seq] = global_position
		_pending.erase(_input_seq - 180)  # bound history (~3 s) if snapshots stall
		_submit_input.rpc_id(1, _input_seq, global_position, aim_direction)

	if is_host and net_ready:
		_snapshot.rpc(global_position, aim_direction, jump_height, is_jumping, _acked_seq)

	_update_frame_visuals(delta)

# =====================================================================
# Owner: input, prediction, requests
# =====================================================================

func _owner_tick(delta: float) -> void:
	var input := _read_bot_input(delta) if NetworkManager.has_debug("bot") else _read_input()

	if not can_act:
		input["dir"] = Vector2.ZERO
		input["jump"] = false
		input["attack"] = -1
		input["channel"] = false
		input["element"] = -1

	# Raava: Q held is streamed to the host, which runs the 1.5 s channel.
	if net_ready and bool(input.get("channel", false)) != _q_sent:
		_q_sent = bool(input.get("channel", false))
		_request_channel.rpc_id(1, _q_sent)
	# Avatar: 1–4 switch element (host validates and syncs).
	var want: int = input.get("element", -1)
	if free_switch and want >= 0 and want != active_element and _switch_t <= 0.0 and net_ready:
		_request_element.rpc_id(1, want)

	velocity = input["dir"] * move_speed
	if input["aim"] != Vector2.ZERO:
		aim_direction = input["aim"]

	if net_ready and not multiplayer.is_server():
		_input_seq += 1
		# Predicted position is sent after this tick's move in _physics_process().

	if input["jump"] and not is_jumping and jump_cooldown_timer <= 0.0:
		_start_jump()  # predict locally (authoritative if we are the host)
		if not multiplayer.is_server():
			_request_jump.rpc_id(1)

	var slot: int = input.get("attack", -1)
	if slot >= 0 and attack_cd[slot] <= 0.0 and _switch_t <= 0.0:
		var cd: float = Elements.attack(Elements.element_for_slot(active_element, slot, is_avatar), slot)["cd"]
		attack_cd[slot] = cd
		attack_cd_total[slot] = cd
		# Arrow combos: two arrows held together = a curving throw. It launches
		# along the left/right arrow and bends toward the up/down one.
		var held: Vector2 = input["dir"]
		var shot_dir := aim_direction
		var bend := 0.0
		if absf(held.x) > 0.3 and absf(held.y) > 0.3:
			shot_dir = Vector2(signf(held.x), 0.0)
			bend = signf(held.x) * signf(held.y)
		_request_attack.rpc_id(1, shot_dir, slot, bend)

func _read_input() -> Dictionary:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir.length() > 1.0:
		dir = dir.normalized()
	# You aim by facing: powers fly the way you last moved.
	var attack := -1
	for i in SLOTS:
		if Input.is_action_just_pressed(Elements.ACTIONS[i]):
			attack = i
	return {
		"dir": dir,
		"aim": dir.normalized() if dir != Vector2.ZERO else Vector2.ZERO,
		"jump": Input.is_action_just_pressed("jump"),
		"attack": attack,
		"channel": Input.is_action_pressed("special"),
		"element": _element_key(),
	}

func _element_key() -> int:
	for i in 4:
		if Input.is_action_just_pressed("avatar_element_%d" % (i + 1)):
			return i
	return -1

## Scripted input for automated two-instance testing (launch with -- --bot).
func _read_bot_input(delta: float) -> Dictionary:
	_bot_time += delta
	_bot_fire_timer -= delta
	_bot_jump_timer -= delta
	var dir := Vector2(cos(_bot_time * 1.3), sin(_bot_time * 2.1)).normalized()
	var aim := aim_direction
	var arena := get_parent()
	for other in arena.get_children():
		if other != self and other is CharacterBody2D:
			aim = (other.global_position - global_position).normalized()
	var fire := _bot_fire_timer <= 0.0
	if fire:
		_bot_fire_timer = 0.6
	var jump := _bot_jump_timer <= 0.0
	if jump:
		_bot_jump_timer = 2.5
	if NetworkManager.has_debug("bot-passive"):
		fire = false  # testing: walk and jump, never shoot
	var channel := false
	var elem := -1
	# --bot-claim: walk into the Raava beam and hold Q until merged.
	var raava = _raava()
	if NetworkManager.has_debug("bot-claim") and raava and raava.is_open() and not is_avatar:
		var to: Vector2 = raava.point - global_position
		if to.length() > 5.0:
			dir = to.normalized()
			jump = false
			# stuck on cover: sidestep for a moment
			_bot_stuck_t += delta
			if global_position.distance_to(_bot_last_pos) > 8.0:
				_bot_last_pos = global_position
				_bot_stuck_t = 0.0
			if _bot_stuck_t > 0.4:
				dir = (dir.orthogonal() * (1.0 if int(_bot_time) % 4 < 2 else -1.0) + dir * 0.3).normalized()
				if _bot_stuck_t > 1.6:
					_bot_stuck_t = 0.0
		else:
			dir = Vector2.ZERO
			channel = true
			fire = false
			jump = false
	if is_avatar:
		_bot_switch_timer -= delta
		if _bot_switch_timer <= 0.0:
			_bot_switch_timer = 2.0
			elem = (active_element + 1) % 4
	return {"dir": dir, "aim": aim, "jump": jump, "attack": (randi() % SLOTS) if fire else -1, "channel": channel, "element": elem}

func _raava():
	var arena := get_tree().current_scene
	return arena.get("raava") if arena else null

# =====================================================================
# Client → host RPCs
# =====================================================================

@rpc("any_peer", "unreliable_ordered")
func _submit_input(seq: int, desired_pos: Vector2, aim_dir: Vector2) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return  # Only the owner may drive this fighter.
	if seq <= _acked_seq:
		return
	_acked_seq = seq
	if aim_dir.length_squared() > 0.0001:
		aim_direction = aim_dir.normalized()
	if not can_act:
		return
	# Clamp to the speed budget, then replay through host collision.
	var step := (desired_pos - global_position).limit_length(_move_budget)
	if step.length_squared() < 0.0001:
		return
	_move_budget -= step.length()
	_moved_recently = 0.0
	var hit := move_and_collide(step)
	if hit:
		move_and_collide(hit.get_remainder().slide(hit.get_normal()))

@rpc("any_peer", "reliable")
func _request_jump() -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id or not can_act:
		return
	if is_jumping or jump_cooldown_timer > 0.0:
		return
	_start_jump()

## Owner → host: Q pressed/released. The host's Raava event decides whether
## that counts as channeling (in the beam, grounded, still, uncontested).
@rpc("any_peer", "reliable", "call_local")
func _request_channel(held: bool) -> void:
	if not multiplayer.is_server() or NetworkManager._sender_id() != peer_id:
		return
	channel_held = held

## Owner → host: Avatar element switch (1–4).
@rpc("any_peer", "reliable", "call_local")
func _request_element(new_element: int) -> void:
	if not multiplayer.is_server() or NetworkManager._sender_id() != peer_id:
		return
	if not free_switch or is_defeated or not can_act:
		return
	if new_element < 0 or new_element > 3 or new_element == active_element:
		return
	# Respect a committed attack: no switching in the first part of a cast.
	if _host_cast_t < STRIKE_TIME * 0.5:
		return
	_sync_active_element.rpc(new_element)

@rpc("authority", "reliable", "call_local")
func _sync_active_element(new_element: int) -> void:
	active_element = new_element
	_switch_t = SWITCH_RECOVERY
	if _aura:
		_aura.element = new_element
	avatar_changed.emit()

## Training: drop the Avatar state (so Raava can be practiced again).
func clear_avatar() -> void:
	is_avatar = false
	if not free_switch:
		active_element = element
	if _aura:
		_aura.queue_free()
		_aura = null
	avatar_changed.emit()

## New round (every peer): full HP, back at the spawn, Avatar gone, cooldowns
## and jump cleared. The host starts the round with _begin_round afterwards.
func reset_for_round(spawn_pos: Vector2) -> void:
	clear_avatar()
	active_element = element
	is_defeated = false
	hp = max_hp
	_update_hp_display()
	hp_changed.emit(hp, 0)
	can_act = false
	channeling = false
	channel_held = false
	_q_sent = false
	is_jumping = false
	jump_timer = 0.0
	jump_height = 0.0
	jump_cooldown_timer = 0.0
	for i in SLOTS:
		attack_cd[i] = 0.0
		_host_cd[i] = 0.0
	_switch_t = 0.0
	_fusion_t = 0.0
	_hit_t = 0.0
	_knock_ticks = 0
	velocity = Vector2.ZERO
	global_position = spawn_pos
	_net_target = spawn_pos
	_pending.clear()
	_restart_anim = true

## Training: back on your feet with full HP.
func revive() -> void:
	is_defeated = false
	hp = max_hp
	_hit_t = 0.0
	_restart_anim = true
	_update_hp_display()
	hp_changed.emit(hp, 0)
	can_act = true

## Host: the training partner. STAND waits, MOVE strafes around its spot,
## SPAR strafes and throws a bolt at you every so often.
func _ai_tick(delta: float) -> void:
	_ai_t += delta
	var target = null
	var arena := get_tree().current_scene
	if arena and "fighters" in arena:
		for f in arena.fighters.values():
			if f != self:
				target = f
	if target:
		aim_direction = (target.global_position - global_position).normalized()
	var dir := Vector2.ZERO
	if ai_mode != AIMode.STAND and can_act and not is_defeated:
		dir = Vector2(cos(_ai_t * 0.9), sin(_ai_t * 1.7)).normalized()
		if target and global_position.distance_to(target.global_position) < 90.0:
			dir = (dir - aim_direction).normalized()  # keep some room
	var before := global_position
	velocity = dir * move_speed * 0.55
	move_and_slide()
	if global_position.distance_squared_to(before) > 0.01:
		_moved_recently = 0.0
	else:
		_moved_recently += delta
	if ai_mode == AIMode.SPAR and target and can_act:
		_ai_fire_t -= delta
		if _ai_fire_t <= 0.0:
			_ai_fire_t = 1.4
			_host_attack(aim_direction, randi() % SLOTS)

## Every peer, on the host's confirmed merge: become the Avatar for the rest
## of the round. HP, cooldowns and stats are untouched (no heal, no immunity).
func become_avatar() -> void:
	is_avatar = true
	channeling = false
	active_element = element
	_fusion_t = FUSION_TIME
	_restart_anim = true
	if _aura == null:
		_aura = AvatarAura.new()
		_aura.element = active_element
		add_child(_aura)
		move_child(_aura, body.get_index())  # behind the sprite, never over it
	avatar_changed.emit()

@rpc("any_peer", "reliable", "call_local")
func _request_attack(aim_dir: Vector2, attack_type: int, bend: float = 0.0) -> void:
	if not multiplayer.is_server():
		return
	if NetworkManager._sender_id() != peer_id:
		return
	_host_attack(aim_dir, attack_type, bend)

## Host: validate and cast the power on key `slot` (0–3 = Q W E R).
func _host_attack(aim_dir: Vector2, slot: int, bend: float = 0.0) -> void:
	if not can_act or is_defeated or slot < 0 or slot >= SLOTS:
		return
	# Small tolerance for jitter between the owner's and host's clocks.
	if _host_cd[slot] > 0.05 or _switch_t > 0.05:
		return
	var elem := Elements.element_for_slot(active_element, slot, is_avatar)
	_host_cd[slot] = Elements.attack(elem, slot)["cd"]
	_host_cast_t = 0.0
	var dir := aim_dir.normalized() if aim_dir.length_squared() > 0.0001 else aim_direction
	var arena := get_tree().current_scene
	if arena and arena.has_method("spawn_attack"):
		arena.spawn_attack(peer_id, elem, slot, dir, is_jumping, clampf(bend, -1.0, 1.0))
	if arena and arena.has_method("on_fighter_disrupted"):
		arena.on_fighter_disrupted(peer_id)

## Host: push this fighter (from a hit). The owner moves itself the same way
## so prediction and the host agree; the host moves its own copy.
func apply_knockback(v: Vector2) -> void:
	if not multiplayer.is_server():
		return
	_start_knock(v)
	if not is_local_player() and ai_mode == AIMode.NONE and peer_id != multiplayer.get_unique_id():
		_knockback_owner.rpc_id(peer_id, v)

@rpc("authority", "reliable", "call_remote")
func _knockback_owner(v: Vector2) -> void:
	_start_knock(v)

func _start_knock(v: Vector2) -> void:
	_knock = v / KNOCK_TICKS
	_knock_ticks = KNOCK_TICKS

# =====================================================================
# Host → client RPCs
# =====================================================================

@rpc("authority", "unreliable_ordered", "call_remote")
func _snapshot(pos: Vector2, aim_dir: Vector2, height: float, jumping: bool, acked_seq: int) -> void:
	if is_local_player():
		_reconcile(pos, acked_seq)
		return
	_net_target = pos
	if not _has_snapshot:
		global_position = pos
		_has_snapshot = true
	aim_direction = aim_dir
	jump_height = height
	is_jumping = jumping

func _reconcile(server_pos: Vector2, acked_seq: int) -> void:
	if not _pending.has(acked_seq):
		return
	var predicted: Vector2 = _pending[acked_seq]
	# Drop history the host has already processed.
	for seq in _pending.keys():
		if seq <= acked_seq:
			_pending.erase(seq)
	var error := server_pos - predicted
	var dist := error.length()
	var correction := Vector2.ZERO
	if dist > RECONCILE_SNAP:
		correction = error
	elif dist > RECONCILE_IGNORE:
		correction = error * RECONCILE_BLEND
	if correction != Vector2.ZERO:
		global_position += correction
		# Keep un-acked predictions consistent with the corrected position.
		for seq in _pending:
			_pending[seq] += correction

@rpc("authority", "reliable", "call_local")
func _sync_hp(new_hp: int) -> void:
	var delta := new_hp - hp
	hp = new_hp
	_update_hp_display()
	if delta < 0:
		_hit_t = HIT_TIME  # the bender's own "hit" animation shows the recoil
		_restart_anim = true
	hp_changed.emit(hp, delta)

@rpc("authority", "reliable", "call_local")
func _sync_defeated() -> void:
	is_defeated = true
	can_act = false
	velocity = Vector2.ZERO
	_restart_anim = true

# =====================================================================
# Host-side gameplay
# =====================================================================

func take_damage(amount: int) -> void:
	if not multiplayer.is_server() or is_defeated:
		return
	var arena := get_tree().current_scene
	if arena and arena.get("round_live") == false:
		return  # bolts still in flight after the round is decided do nothing
	# Let _sync_hp apply it everywhere (the host included), so every peer sees
	# the same delta: damage numbers, the hit pose and training stats.
	var new_hp: int = maxi(0, hp - amount)
	_sync_hp.rpc(new_hp)
	if arena and arena.has_method("on_fighter_disrupted"):
		arena.on_fighter_disrupted(peer_id)
	if new_hp <= 0:
		_sync_defeated.rpc()
		if arena and arena.has_method("on_player_defeated"):
			arena.on_player_defeated(peer_id)

# =====================================================================
# Jump (simulated by the host and predicted by the owner)
# =====================================================================

func _start_jump() -> void:
	is_jumping = true
	jump_timer = 0.0
	if multiplayer.is_server():
		var arena := get_tree().current_scene
		if arena and arena.has_method("on_fighter_disrupted"):
			arena.on_fighter_disrupted(peer_id)

func _simulate_jump(delta: float) -> void:
	if jump_cooldown_timer > 0.0:
		jump_cooldown_timer -= delta
	if not is_jumping:
		return
	jump_timer += delta
	var t := jump_timer / GameManager.jump_airborne_time
	if t >= 1.0:
		is_jumping = false
		jump_timer = 0.0
		jump_height = 0.0
		jump_cooldown_timer = GameManager.jump_cooldown
	else:
		jump_height = -4.0 * JUMP_PEAK * (t * t - t)

# =====================================================================
# Visuals
# =====================================================================

func _apply_art() -> void:
	if not body:
		return
	var sf := Roster.fighter_frames(fighter_id)  # pack frames + Raava transformation
	if sf == null:
		push_warning("[Player] Missing art for bender '%s'" % fighter_id)
	body.sprite_frames = sf
	body.centered = false
	body.offset = Roster.FRAME_OFFSET
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# The bender's art is shown exactly as drawn: no material, tint or flash.
	# Side markers (ring, name chip, HP bar) live on separate nodes.
	body.material = null
	body.modulate = Color.WHITE
	if sf:
		body.play(&"idle_south")

func _update_visuals() -> void:
	var local := is_local_player()
	var side := T.side_color(local)
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
	if side_ring:
		side_ring.color = side
	if name_label:
		# Skewed side-colored name chip: gold = you, red = rival.
		var pname := str(NetworkManager.players.get(peer_id, {}).get("name", ""))
		name_label.text = (pname if pname != "" else ("YOU" if local else "RIVAL")).to_upper()
		var sb := StyleBoxFlat.new()
		sb.bg_color = side
		sb.border_color = T.INK
		sb.set_border_width_all(1)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		name_label.add_theme_stylebox_override("normal", sb)
		name_label.add_theme_font_override("font", T.font("heading"))
		name_label.add_theme_color_override("font_color", T.text_on_side(local))
		var w := name_label.get_combined_minimum_size().x
		name_label.size.x = w
		name_label.position.x = -w / 2.0

func _update_frame_visuals(delta: float) -> void:
	if body:
		body.position = Vector2(0, -jump_height)
		_animate(delta)
	# Name chip and mini HP bar ride with the body so a jump never hides behind them.
	if name_label:
		name_label.position.y = _tag_y - jump_height
	if hp_bar:
		hp_bar.position.y = _bar_y - jump_height
	if shadow:
		var k := jump_height / JUMP_PEAK
		shadow.modulate.a = clampf(1.0 - k * 0.5, 0.3, 1.0)
		shadow.scale = Vector2.ONE * (1.0 - k * 0.3)
	if aim_indicator:
		aim_indicator.rotation = aim_direction.angle()
		aim_indicator.visible = is_local_player() and not is_defeated
	if side_ring:
		side_ring.aim = aim_direction
		side_ring.visible = not is_defeated

## Picks the bender's animation from gameplay state. Every peer runs this
## from the same synced state (position, aim, jump, HP, strikes).
func _animate(delta: float) -> void:
	if body.sprite_frames == null:
		return
	_strike_t = maxf(0.0, _strike_t - delta)
	_hit_t = maxf(0.0, _hit_t - delta)
	_land_t = maxf(0.0, _land_t - delta)
	_fusion_t = maxf(0.0, _fusion_t - delta)
	if is_jumping and not _was_jumping:
		_air_t = 0.0
		_restart_anim = true
	elif not is_jumping and _was_jumping:
		_land_t = LAND_TIME
		_restart_anim = true
	_was_jumping = is_jumping
	if is_jumping:
		_air_t += delta

	if not is_defeated:
		_facing = Roster.facing(aim_direction)
	var action := "idle"
	if is_defeated:
		action = "defeat"
	elif _hit_t > 0.0:
		action = "hit"
	elif _fusion_t > 0.0:
		action = "raava_fusion"
	elif channeling and not is_jumping:
		action = "raava_channel"
	elif is_jumping:
		action = "jump_start" if _air_t < TAKEOFF_TIME else "airborne"
	elif _land_t > 0.0:
		action = "land"
	elif _strike_t > 0.0:
		action = "strike"
	elif _is_moving():
		action = "walk"
	elif is_avatar:
		action = "avatar_ready"
	var anim := StringName("%s_%s" % [action, _facing])
	if not body.sprite_frames.has_animation(anim):
		anim = StringName("idle_%s" % _facing)
	if _restart_anim or body.animation != anim:
		var keep_frame := 0
		# Keep the walk cycle in step when only the facing changes.
		if action == "walk" and String(body.animation).begins_with("walk_") and not _restart_anim:
			keep_frame = body.frame
		_restart_anim = false
		body.stop()
		body.play(anim)
		body.frame = keep_frame

## Called on every peer when this fighter's attack spawns.
func play_strike(dir: Vector2) -> void:
	if dir != Vector2.ZERO:
		aim_direction = dir.normalized()
	_strike_t = STRIKE_TIME
	_restart_anim = true

static func _make_shadow_texture() -> ImageTexture:
	var w := 34
	var h := 12
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var nx := (x + 0.5 - w / 2.0) / (w / 2.0)
			var ny := (y + 0.5 - h / 2.0) / (h / 2.0)
			var d := nx * nx + ny * ny
			img.set_pixel(x, y, Color(0, 0, 0, clampf(1.0 - d, 0.0, 1.0) * 0.6))
	return ImageTexture.create_from_image(img)

func _is_moving() -> bool:
	if is_local_player():
		return velocity.length_squared() > 1.0
	if multiplayer.is_server():
		return _moved_recently < 0.1
	return global_position.distance_squared_to(_net_target) > 1.0

func _update_hp_display() -> void:
	if hp_bar:
		hp_bar.value = hp

func _style_hp_bar() -> void:
	if not hp_bar:
		return
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.skew = Vector2(T.SKEW, 0)
	var fill := StyleBoxFlat.new()
	fill.skew = Vector2(T.SKEW, 0)
	fill.bg_color = T.side_color(is_local_player())
	hp_bar.add_theme_stylebox_override("background", bg)
	hp_bar.add_theme_stylebox_override("fill", fill)

func set_element(new_element: int) -> void:
	element = new_element
	if not Roster.is_valid(fighter_id, element):
		fighter_id = Roster.default_for(element)
	_apply_art()
	_update_visuals()
