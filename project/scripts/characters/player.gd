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
const Specials = preload("res://scripts/data/specials.gd")
const SignatureRunner = preload("res://scripts/characters/signature_runner.gd")
const StatusFX = preload("res://scripts/fx/status_fx.gd")
const WaterReserve = preload("res://scripts/fx/water_reserve.gd")
const AimRing = preload("res://scripts/fx/aim_ring.gd")

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
## Z X C V throw the bender's four powers the way they face (360°, from the
## arrows); as the Avatar they throw the best power of Fire, Water, Earth and
## Air. A uses the equipped special. No mouse aiming.
const SLOTS := 4
const BASE_SPEED := 200.0
const STEER_RATE := 12.0      # (unused) old steering rate
const ACCEL_TIME := 0.08      # seconds to reach full speed
const BRAKE_TIME := 0.06      # seconds to stop
const TURN_RATE := 720.0      # degrees/s the facing turns toward where you move
const FINE_TURN := 160.0      # degrees/s while holding SHIFT to aim

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
const AVATAR_TIME := 25.0               # the Avatar state fades after this long
var avatar_t: float = 0.0               # every peer: Avatar time left

# --- Build and special (spec §7–9) ---
var build: Dictionary = Specials.empty_build()
var special: Node2D                      # SignatureRunner, child "Special" (key A)
# --- Statuses (from signatures), set on every peer by apply_status ---
var root_t: float = 0.0                  # frozen / buried: can't move
var slow_t: float = 0.0                  # soaked: 45% slower
var silence_t: float = 0.0               # winded: can't attack, 25% slower
var burn_t: float = 0.0                  # burning: host deals 4 every 0.5 s
var lift_t: float = 0.0                  # swept up: lifted, helpless
var _burn_tick: float = 0.0
var status_fx: Node2D
var water_reserve: Node2D
var aim_ring: Node2D
var flying: bool = false                 # flight special: airborne, over cover
var intangible: bool = false             # spirit form: attacks pass through
var speed_boost: float = 1.0             # earth surfing
var held_t: float = 0.0                  # bloodbent: can't move or act
var immune_t: float = 0.0                # control immunity after a hold
var recover_t: float = 0.0               # rooted while charging / recovering

# --- Arrow combos (owner) ---
## Arrow presses in the last moment, oldest first: [{"d": Vector2, "t": seconds}]
var _presses: Array = []
var _clock: float = 0.0
var _move_dir: Vector2 = Vector2.ZERO
var _diag_aim: Vector2 = Vector2.RIGHT
var aim_angle: float = 0.0              # owner: the facing as an angle (radians)
var fine_aiming: bool = false           # owner: SHIFT held
var lock_target = null                  # owner: the rival the aim assist would lock onto (for the ring)
var vel_est: Vector2 = Vector2.ZERO     # host: smoothed velocity of this fighter
var _last_pos: Vector2 = Vector2.ZERO
const ASSIST_CONE := 24.0               # degrees: a rival this close to your facing gets aimed at
const ASSIST_LEAD := 0.6                # how much of the rival's motion to lead
var _diag_t: float = -10.0
const DIAG_GRACE := 0.12
enum Combo { NONE, DASH, POWER, CURVE, SPREAD }
const COMBO_NAMES := ["", "Dash Strike", "Power Shot", "Curve Shot", "Spread Shot"]

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
	aim_angle = aim_direction.angle()
	var b: Dictionary = NetworkManager.players.get(id, {}).get("build", {})
	if not b.is_empty():
		build = b.duplicate()

func _ready() -> void:
	hp = GameManager.base_hp
	max_hp = hp
	move_speed = BASE_SPEED * Specials.speed_mult(build)
	special = SignatureRunner.new()
	special.name = "Special"
	add_child(special)
	special.equip(Specials.signature(fighter_id))
	if is_local_player():
		aim_ring = AimRing.new()
		aim_ring.name = "AimRing"
		add_child(aim_ring)
		move_child(aim_ring, $Body.get_index())  # on the ground, under the bender
		$AimIndicator.visible = false
	status_fx = StatusFX.new()
	status_fx.name = "StatusFX"
	add_child(status_fx)  # its own node: drawn around the bender, never on the sprite
	water_reserve = WaterReserve.new()
	water_reserve.name = "WaterReserve"
	add_child(water_reserve)
	move_child(water_reserve, $Body.get_index())
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
	if is_host and delta > 0.0:
		# Host's estimate of how this fighter is moving (for aim lead).
		vel_est = vel_est.lerp((global_position - _last_pos) / delta, 0.25)
		_last_pos = global_position
	if _knock_ticks > 0 and (local or is_host):
		_knock_ticks -= 1
		move_and_collide(_knock)
	_switch_t = maxf(0.0, _switch_t - delta)
	held_t = maxf(0.0, held_t - delta)
	immune_t = maxf(0.0, immune_t - delta)
	recover_t = maxf(0.0, recover_t - delta)
	root_t = maxf(0.0, root_t - delta)
	slow_t = maxf(0.0, slow_t - delta)
	silence_t = maxf(0.0, silence_t - delta)
	lift_t = maxf(0.0, lift_t - delta)
	speed_boost = (0.55 if slow_t > 0.0 else 1.0) * (0.75 if silence_t > 0.0 else 1.0)
	if burn_t > 0.0:
		burn_t = maxf(0.0, burn_t - delta)
		_burn_tick += delta
		if _burn_tick >= 0.5:
			_burn_tick = 0.0
			if is_host:
				take_damage(4)
	if is_avatar:
		avatar_t = maxf(0.0, avatar_t - delta)
		if is_host and avatar_t <= 0.0:
			_end_avatar.rpc()

	if local:
		_owner_tick(delta)
	elif is_host and ai_mode != AIMode.NONE:
		_ai_tick(delta)
	elif is_host:
		# Remote fighter: refill its movement budget (a little headroom for jitter,
		# capped so a burst after a lag spike stays small).
		var sp := move_speed * speed_boost
		_move_budget = minf(_move_budget + sp * delta * 1.15, sp * 0.25)
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
	_clock += delta
	var input := _read_bot_input(delta) if NetworkManager.has_debug("bot") else _read_input()

	if _menu_open():
		input = {"dir": Vector2.ZERO, "aim": Vector2.ZERO, "jump": false, "attack": -1, "channel": false, "special": false, "element": -1}
	if not can_act or held_t > 0.0:
		input["dir"] = Vector2.ZERO
		input["jump"] = false
		input["attack"] = -1
		input["channel"] = false
		input["special"] = false
		input["element"] = -1
	if recover_t > 0.0:
		input["dir"] = Vector2.ZERO
		input["attack"] = -1
	if root_t > 0.0:
		input["dir"] = Vector2.ZERO   # frozen / buried: you can still bend
		input["jump"] = false
	if lift_t > 0.0:
		input["dir"] = Vector2.ZERO
		input["attack"] = -1
		input["special"] = false

	# Raava: A held inside her ring is the merge (streamed to the host).
	var raava = _raava()
	var in_ring: bool = raava != null and raava.is_open() and global_position.distance_to(raava.point) <= raava.RADIUS
	var channel: bool = bool(input.get("channel", false)) and (in_ring or NetworkManager.has_debug("bot"))
	if net_ready and channel != _q_sent:
		_q_sent = channel
		_request_channel.rpc_id(1, _q_sent)
	if input.get("special", false) and not in_ring and net_ready and special.cd_left <= 0.0 and not special.active:
		_request_special.rpc_id(1, aim_direction)
	# Training: 1–4 switch element (host validates and syncs).
	var want: int = input.get("element", -1)
	if free_switch and want >= 0 and want != active_element and _switch_t <= 0.0 and net_ready:
		_request_element.rpc_id(1, want)

	# Movement: quick acceleration and braking, so it feels weighty but
	# responsive. Facing (aim) is separate: it turns toward where you move at
	# TURN_RATE, so it can rest at ANY angle, and holding SHIFT stands you still
	# and turns your aim finely with ← → (360° aiming on a keyboard).
	var want_dir: Vector2 = input["dir"]
	var fine: bool = bool(input.get("fine", false))
	if fine:
		fine_aiming = true
		var turn: float = want_dir.x if absf(want_dir.x) > 0.1 else 0.0
		aim_angle = wrapf(aim_angle + turn * deg_to_rad(FINE_TURN) * delta, -PI, PI)
		aim_direction = Vector2.from_angle(aim_angle)
		want_dir = Vector2.ZERO
	else:
		fine_aiming = false
	var target_v: Vector2 = want_dir * move_speed * speed_boost
	var rate: float = move_speed / (ACCEL_TIME if target_v.length() >= velocity.length() else BRAKE_TIME)
	velocity = velocity.move_toward(target_v, rate * delta)
	_move_dir = velocity.normalized() if velocity.length() > 1.0 else Vector2.ZERO
	var rival = _auto_aim_target() if not fine else null
	if rival != null:
		# Auto-aim: face the rival at all times; the arrows only move and dodge.
		aim_direction = (rival.global_position - global_position).normalized()
		aim_angle = aim_direction.angle()
	elif not fine:
		if NetworkManager.has_debug("bot"):
			if input["aim"] != Vector2.ZERO:
				aim_direction = input["aim"]
				aim_angle = aim_direction.angle()
		else:
			_update_aim(want_dir, delta)

	if net_ready and not multiplayer.is_server():
		_input_seq += 1
		# Predicted position is sent after this tick's move in _physics_process().

	if input["jump"] and not is_jumping and not flying and jump_cooldown_timer <= 0.0:
		_start_jump()  # predict locally (authoritative if we are the host)
		if not multiplayer.is_server():
			_request_jump.rpc_id(1)

	var key: int = input.get("attack", -1)
	if key >= 0 and attack_cd[key] <= 0.0 and _switch_t <= 0.0 and can_attack():
		var spec := Elements.attack_for(active_element, key, is_avatar)
		var cd: float = Elements.attack(spec[0], spec[1])["cd"] * float(spec[2])
		attack_cd[key] = cd
		attack_cd_total[key] = cd
		var combo := _read_combo()
		if UserSettings.auto_aim and not fine_aiming:
			combo[1] = aim_direction   # combos still fire at the rival
		_request_attack.rpc_id(1, combo[1], key, combo[2], combo[0])

## Arrow combos, read from the last few arrow presses (the last one sets the
## facing F):  F F = Dash Strike · back F = Power Shot · side F = Curve Shot
## (bends toward that side) · back side F = Spread Shot.  -> [combo, dir, bend]
## The facing follows the smoothed movement, at any angle. Two arrows are never
## released on the same frame, so a diagonal is held for a moment after one
## of them lifts: letting go of ↑→ leaves you facing ↗, not → or ↑.
func _update_aim(want_dir: Vector2, delta: float) -> void:
	var diag := absf(want_dir.x) > 0.1 and absf(want_dir.y) > 0.1
	if diag:
		_diag_aim = want_dir.normalized()
		_diag_t = _clock
	var recent_diag := _clock - _diag_t < DIAG_GRACE
	var target := aim_angle
	if want_dir == Vector2.ZERO:
		if recent_diag:
			target = _diag_aim.angle()
	elif not diag and recent_diag and want_dir.dot(_diag_aim) > 0.6:
		target = _diag_aim.angle()  # one key of the diagonal just lifted
	else:
		target = want_dir.angle()
	# turn toward it at TURN_RATE (a full reversal snaps, so dodging stays sharp)
	var diff := wrapf(target - aim_angle, -PI, PI)
	if absf(diff) > deg_to_rad(150.0):
		aim_angle = target
	else:
		aim_angle = wrapf(aim_angle + clampf(diff, -deg_to_rad(TURN_RATE) * delta, deg_to_rad(TURN_RATE) * delta), -PI, PI)
	aim_direction = Vector2.from_angle(aim_angle)

func _read_combo() -> Array:
	var none := [Combo.NONE, aim_direction, 0.0]
	if _presses.is_empty() or _clock - float(_presses[-1]["t"]) > 0.35:
		return none
	var recent := []
	for i in range(_presses.size() - 1, -1, -1):
		var p: Dictionary = _presses[i]
		if recent.size() > 0 and float(recent[0]["t"]) - float(p["t"]) > 0.4:
			break
		recent.push_front(p)
		if recent.size() == 3:
			break
	_presses.clear()
	if recent.size() < 2:
		return none
	# Combos are taps: an earlier arrow still held down is just steering
	# (holding → and adding ↑ is a diagonal run, not a Curve Shot).
	var last_act: String = recent[-1]["act"]
	for i in recent.size() - 1:
		var act: String = recent[i]["act"]
		if act != last_act and Input.is_action_pressed(act):
			return none
	var f: Vector2 = recent[-1]["d"]
	var a: Vector2 = recent[-2]["d"]
	var rel := rad_to_deg(absf(f.angle_to(a)))
	if recent.size() == 3:
		var a0: Vector2 = recent[0]["d"]
		if rad_to_deg(absf(f.angle_to(a0))) > 140.0 and rel > 50.0 and rel < 130.0:
			return [Combo.SPREAD, f, 0.0]
	if rel < 30.0:
		return [Combo.DASH, f, 0.0]
	if rel > 150.0:
		return [Combo.POWER, f, 0.0]
	if rel > 50.0 and rel < 130.0:
		return [Combo.CURVE, f, signf(f.cross(a))]
	return none

func _note_presses() -> void:
	var dirs := {"move_left": Vector2.LEFT, "move_right": Vector2.RIGHT, "move_up": Vector2.UP, "move_down": Vector2.DOWN}
	for act in dirs:
		if Input.is_action_just_pressed(act):
			var d: Vector2 = dirs[act]
			# Two arrows pressed together count as one diagonal press.
			if not _presses.is_empty() and _clock - float(_presses[-1]["t"]) < 0.07 and absf((_presses[-1]["d"] as Vector2).dot(d)) < 0.5:
				_presses[-1]["d"] = ((_presses[-1]["d"] as Vector2) + d).normalized()
			else:
				_presses.append({"d": d, "t": _clock, "act": act})
	while _presses.size() > 6:
		_presses.pop_front()

func can_attack() -> bool:
	return can_act and not is_defeated and held_t <= 0.0 and recover_t <= 0.0 and not intangible \
			and silence_t <= 0.0 and lift_t <= 0.0

## Host → every peer: a signature's status lands on this fighter.
## Hard control (stun, lift, freeze, bury) can't chain: 1 s of immunity after.
func apply_status(kind: String, seconds: float, src_id: String) -> void:
	if not multiplayer.is_server() or is_defeated:
		return
	if kind in ["stun", "shock", "lift", "freeze", "bury"] and immune_t > 0.0:
		return
	_status_rpc.rpc(kind, seconds, src_id)

@rpc("authority", "reliable", "call_local")
func _status_rpc(kind: String, seconds: float, src_id: String) -> void:
	match kind:
		"stun", "shock":
			held_t = maxf(held_t, seconds)
		"lift":
			held_t = maxf(held_t, seconds)
			lift_t = maxf(lift_t, seconds)
		"freeze", "bury":
			root_t = maxf(root_t, seconds)
		"soak":
			slow_t = maxf(slow_t, seconds)
		"wind":
			silence_t = maxf(silence_t, seconds)
		"burn":
			burn_t = maxf(burn_t, seconds)
			_burn_tick = 0.0
	if kind in ["stun", "shock", "lift", "freeze", "bury"]:
		immune_t = seconds + 1.0
	channel_held = false
	if status_fx:
		status_fx.show_status(kind, seconds, src_id)

func clear_statuses() -> void:
	root_t = 0.0
	slow_t = 0.0
	silence_t = 0.0
	burn_t = 0.0
	lift_t = 0.0
	held_t = 0.0
	if status_fx:
		status_fx.clear()

func is_airborne() -> bool:
	return is_jumping or flying

func damage_mult() -> float:
	return Specials.damage_mult(build)

func _read_input() -> Dictionary:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir.length() > 1.0:
		dir = dir.normalized()
	_note_presses()
	# You aim by facing: powers fly the way you last moved.
	var attack := -1
	for i in SLOTS:
		if Input.is_action_just_pressed(Elements.ACTIONS[i]):
			attack = i
	return {
		"dir": dir,
		"aim": dir.normalized() if dir != Vector2.ZERO else Vector2.ZERO,
		"fine": Input.is_action_pressed("aim_mode"),
		"jump": Input.is_action_just_pressed("jump"),
		"attack": attack,
		"channel": Input.is_action_pressed("special"),
		"special": Input.is_action_just_pressed("special"),
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
	var spc := NetworkManager.has_debug("bot-special") and randf() < 0.01 and not channel
	return {"dir": dir, "aim": aim, "jump": jump, "attack": (randi() % SLOTS) if fire else -1, "channel": channel, "special": spc, "element": elem}

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
	if is_jumping or flying or jump_cooldown_timer > 0.0:
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
	# Training: A follows the element too — the signature of this bender's
	# counterpart in that element (Ember Captain ↔ Ice Guard ↔ Stone Warden ↔ Temple Courier).
	if free_switch and special and not special.active:
		special.equip(Specials.signature(_counterpart(new_element)))
	avatar_changed.emit()

func _counterpart(new_element: int) -> String:
	var mine := Roster.for_element(element)
	var idx := 0
	for i in mine.size():
		if mine[i]["id"] == fighter_id:
			idx = i
	var theirs := Roster.for_element(new_element)
	return theirs[mini(idx, theirs.size() - 1)]["id"]

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
	if special:
		special.reset()
	clear_statuses()
	if water_reserve:
		water_reserve.refill_now()
	set_flying(false)
	intangible = false
	speed_boost = 1.0
	held_t = 0.0
	immune_t = 0.0
	recover_t = 0.0
	active_element = element
	if special:
		special.equip(Specials.signature(fighter_id))
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
	clear_statuses()
	is_defeated = false
	hp = max_hp
	_hit_t = 0.0
	_restart_anim = true
	_update_hp_display()
	hp_changed.emit(hp, 0)
	can_act = true

## Host: the training partner. STAND waits, MOVE strafes around its spot,
## SPAR strafes and throws a bolt at you every so often.
var _ai_orbit: float = 1.0
var _ai_turn_t: float = 0.0
var _ai_stuck_t: float = 0.0

## Is one of `who`'s powers heading this way?
func _threatened(who) -> bool:
	var arena := get_tree().current_scene
	if arena == null or not ("projectiles_root" in arena):
		return false
	for p in arena.projectiles_root.get_children():
		if p is Area2D and p.get("owner_peer_id") == who.peer_id:
			var to: Vector2 = global_position - p.global_position
			if to.length() < 160.0 and p.direction.dot(to.normalized()) > 0.8:
				return true
	return false

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
	if ai_mode != AIMode.STAND and can_act and not is_defeated and target:
		# Circle the player at a fighting distance, switching direction now and
		# then; step in when too far, back off when too close.
		_ai_turn_t -= delta
		if _ai_turn_t <= 0.0:
			_ai_turn_t = randf_range(1.2, 2.6)
			_ai_orbit = -_ai_orbit if randf() < 0.6 else _ai_orbit
		var to: Vector2 = target.global_position - global_position
		var dist := to.length()
		var radial := 0.0
		if dist > 260.0:
			radial = 1.0
		elif dist < 150.0:
			radial = -1.0
		dir = (to.normalized() * radial + to.normalized().orthogonal() * _ai_orbit).normalized()
		# Blocked by a rock or the edge: try the other way round.
		if _ai_stuck_t > 0.35:
			_ai_orbit = -_ai_orbit
			_ai_stuck_t = 0.0
		# Sparring: hop over powers flying at it, sometimes.
		if ai_mode == AIMode.SPAR and not is_jumping and jump_cooldown_timer <= 0.0 and randf() < 0.02 and _threatened(target):
			_start_jump()
	var before := global_position
	if held_t > 0.0 or recover_t > 0.0 or root_t > 0.0:
		dir = Vector2.ZERO
	velocity = dir * move_speed * 0.75 * speed_boost
	move_and_slide()
	var moved := global_position.distance_to(before)
	if moved > 0.1:
		_moved_recently = 0.0
	else:
		_moved_recently += delta
	if dir != Vector2.ZERO and moved < move_speed * 0.75 * delta * 0.3:
		_ai_stuck_t += delta
	else:
		_ai_stuck_t = 0.0
	if ai_mode == AIMode.SPAR and target and can_act:
		_ai_fire_t -= delta
		if _ai_fire_t <= 0.0:
			_ai_fire_t = 1.4
			_host_attack(aim_direction, randi() % SLOTS)
		if randf() < 0.004 and special.id != "":
			special.host_try(aim_direction)

## Every peer, on the host's confirmed merge: become the Avatar for the rest
## of the round. HP, cooldowns and stats are untouched (no heal, no immunity).
func become_avatar() -> void:
	is_avatar = true
	avatar_t = AVATAR_TIME
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
func _request_attack(aim_dir: Vector2, attack_type: int, bend: float = 0.0, combo: int = 0) -> void:
	if not multiplayer.is_server():
		return
	if NetworkManager._sender_id() != peer_id:
		return
	_host_attack(aim_dir, attack_type, bend, combo)

## Owner → host: use the equipped special (A).
@rpc("any_peer", "reliable", "call_local")
func _request_special(aim_dir: Vector2) -> void:
	if not multiplayer.is_server() or NetworkManager._sender_id() != peer_id:
		return
	if not can_act or is_defeated or held_t > 0.0 or recover_t > 0.0:
		return
	var raava = _raava()
	if raava and raava.is_open() and global_position.distance_to(raava.point) <= raava.RADIUS:
		return  # inside Raava's ring, A is the merge
	special.host_try(aim_dir)

## Host: validate and cast the power on key `key` (0–3 = Z X C V).
func _host_attack(aim_dir: Vector2, key: int, bend: float = 0.0, combo: int = 0) -> void:
	if not can_attack() or key < 0 or key >= SLOTS:
		return
	# Small tolerance for jitter between the owner's and host's clocks.
	if _host_cd[key] > 0.05 or _switch_t > 0.05:
		return
	var spec := Elements.attack_for(active_element, key, is_avatar)
	_host_cd[key] = Elements.attack(spec[0], spec[1])["cd"] * float(spec[2])
	_host_cast_t = 0.0
	var dir := aim_dir.normalized() if aim_dir.length_squared() > 0.0001 else aim_direction
	var arena := get_tree().current_scene
	var atk := Elements.attack(spec[0], spec[1])
	if combo != Combo.CURVE and atk["kind"] != "burst":
		dir = assist_aim(dir, float(atk["speed"]), float(atk["speed"]) * float(atk["life"]) if atk["kind"] != "beam" else float(atk["range"]))
	if arena and arena.has_method("on_fighter_disrupted"):
		arena.on_fighter_disrupted(peer_id)
	if combo == Combo.DASH:
		dash(dir * 95.0, 8)
		if not is_local_player() and ai_mode == AIMode.NONE:
			_dash_owner.rpc_id(peer_id, dir * 95.0, 8)
		await get_tree().create_timer(0.13).timeout
		if not is_inside_tree() or not can_attack():
			return
	if combo != Combo.CURVE:
		bend = 0.0
	if arena and arena.has_method("spawn_attack"):
		arena.spawn_attack(peer_id, spec[0], spec[1], dir, is_airborne(), clampf(bend, -1.0, 1.0), combo)
		if combo != Combo.NONE:
			arena.announce_move(peer_id, COMBO_NAMES[combo])

@rpc("authority", "reliable", "call_remote")
func _dash_owner(v: Vector2, ticks: int) -> void:
	dash(v, ticks)

## Move this fighter by `v` over `ticks` physics ticks (dashes, surges).
## Owner: the nearest standing rival, when auto-aim is on (setting in the Esc menu).
func _auto_aim_target():
	if not UserSettings.auto_aim or NetworkManager.has_debug("bot"):
		return null
	var arena := get_tree().current_scene
	if arena == null or not ("fighters" in arena):
		return null
	var best = null
	var best_d := INF
	for other in arena.fighters.values():
		if other == self or other.is_defeated:
			continue
		var d := global_position.distance_squared_to(other.global_position)
		if d < best_d:
			best_d = d
			best = other
	return best

func _menu_open() -> bool:
	var arena := get_tree().current_scene
	return arena != null and arena.get("hud") != null and arena.hud.get("menu_open") == true

## Owner: which rival the assist would lock onto for Z (shown on the AimRing).
func _assist_preview():
	var arena := get_tree().current_scene
	if arena == null or not ("fighters" in arena) or is_defeated:
		return null
	var atk := Elements.attack(Elements.attack_for(active_element, 0, is_avatar)[0], Elements.attack_for(active_element, 0, is_avatar)[1])
	var reach: float = float(atk["speed"]) * float(atk["life"]) + 40.0
	for other in arena.fighters.values():
		if other == self or other.is_defeated:
			continue
		var to: Vector2 = other.global_position - global_position
		if to.length() <= reach and absf(aim_direction.angle_to(to)) <= deg_to_rad(ASSIST_CONE):
			return other
	return null

## Host: soft aim assist. If the rival is within a small cone of where you
## face and within reach, the power goes straight at them (leading a moving
## rival a little), so keyboard aiming in 360° still lands.
func assist_aim(dir: Vector2, speed: float, reach: float) -> Vector2:
	var arena := get_tree().current_scene
	if arena == null or not ("fighters" in arena):
		return dir
	var best := dir
	var best_ang := deg_to_rad(ASSIST_CONE)
	for other in arena.fighters.values():
		if other == self or other.is_defeated:
			continue
		var to: Vector2 = other.global_position - global_position
		var dist := to.length()
		if dist < 1.0 or dist > reach + 40.0:
			continue
		var t := dist / maxf(speed, 1.0) if speed > 0.0 else 0.0
		var lead: Vector2 = to + other.vel_est * t * ASSIST_LEAD
		var ang := absf(dir.angle_to(lead))
		if ang < best_ang:
			best_ang = ang
			best = lead.normalized()
	return best

func dash(v: Vector2, ticks: int) -> void:
	_knock = v / ticks
	_knock_ticks = ticks

func set_flying(on: bool) -> void:
	flying = on
	set_collision_mask_value(4, not on)   # glide over cover (layer value 8); walls still hold

## Host: stop a channel or a held special (Metalbending's shove, getting hit).
func interrupt() -> void:
	channel_held = false
	if special and special.active and special.id in ["bloodbending", "lightning", "combustion"]:
		special.host_interrupt()

func heal(amount: int) -> void:
	if not multiplayer.is_server() or is_defeated:
		return
	var new_hp: int = mini(max_hp, hp + amount)
	if new_hp != hp:
		_sync_hp.rpc(new_hp)

@rpc("authority", "reliable", "call_local")
func _end_avatar() -> void:
	if is_avatar:
		clear_avatar()

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

func take_damage(amount: int, from: Vector2 = Vector2.INF) -> void:
	if not multiplayer.is_server() or is_defeated or intangible:
		return
	var arena := get_tree().current_scene
	if arena and arena.get("round_live") == false:
		return  # bolts still in flight after the round is decided do nothing
	# Defense: 4% per point, all reduction capped at 50%. Then guards and armor.
	amount = int(round(amount * (1.0 - minf(0.5, Specials.reduction(build)))))
	if special:
		amount = special.absorb(amount, from)
	if amount <= 0:
		return
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
		var lift := 0.0
		if lift_t > 0.0:
			lift = 26.0 * minf(1.0, lift_t * 3.0) + sin(Time.get_ticks_msec() / 90.0) * 3.0
		body.position = Vector2(0, -jump_height - (24.0 if flying else 0.0) - lift)
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
		aim_indicator.visible = false   # replaced by the ground AimRing
	if aim_ring:
		lock_target = _assist_preview()
	if side_ring:
		side_ring.aim = aim_direction
		side_ring.visible = not is_defeated and aim_ring == null   # your own ring is the AimRing

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
	elif is_jumping or flying:
		action = "jump_start" if (_air_t < TAKEOFF_TIME and not flying) else "airborne"
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
func play_strike(dir: Vector2, element: int = -1) -> void:
	if dir != Vector2.ZERO:
		aim_direction = dir.normalized()
		aim_angle = aim_direction.angle()
	if element == 1 and water_reserve:
		water_reserve.use()  # water benders bend from the water they hold
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
