extends Node2D

## A bender's signature attack on key A (see scripts/data/specials.gd).
## Child "Special" of the fighter; draws in world space (top_level) so the
## power can travel the whole arena. Never draws on the character sprite.
##
## Flow: owner presses A → host_try() (host checks cooldown, aims with the
## same soft assist as Z X C V) → _begin() on every peer: a short windup at
## the bender (rooted), then the power travels the same path on every peer.
## The host alone decides hits: damage, knockback and the status.

const Specials = preload("res://scripts/data/specials.gd")
const FxSprite = preload("res://scripts/fx/fx_sprite.gd")
const Arenas = preload("res://scripts/data/arenas.gd")

const ANIM_FPS := 14.0
const HURT_HALF_W := 18.0
const HURT_UP := 28.0
const HURT_DOWN := 12.0
const ERUPT_EVERY := 34.0

var f                          # the fighter (parent)
var id: String = ""
var data: Dictionary = {}
var active: bool = false
var t: float = 0.0             # seconds since activation
var total: float = 1.0         # windup + travel
var cd_left: float = 0.0
var cd_total: float = 1.0
var dir: Vector2 = Vector2.RIGHT
var start: Vector2
var length: float = 0.0        # how far it can go (walls stop it)
var head: float = 0.0          # how far it has gone
var _stopped: bool = false
var _released: bool = false
var _hit: Dictionary = {}      # host: peer -> true
var _erupts: Array = []        # [pos, born_t]
var _next_erupt: float = 0.0
var _fx: Array = []            # [pos, row, born_t, life, scale, rot, bottom]
var _bolt_t: float = -1.0
var _bolt_end: Vector2
var _clock: float = 0.0        # every peer: seconds, for one-shot effects

func _ready() -> void:
	f = get_parent()
	top_level = true
	global_position = Vector2.ZERO
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 2

func equip(sig_id: String) -> void:
	id = sig_id
	data = Specials.info(id)
	cd_total = float(data.get("cd", 15.0))

func reset() -> void:
	active = false
	cd_left = 0.0
	_erupts.clear()
	_fx.clear()
	_bolt_t = -1.0
	queue_redraw()

## Kept for the fighter's interface: signatures can't be interrupted or absorbed.
func host_interrupt() -> void:
	pass

func absorb(amount: int, _from: Vector2) -> int:
	return amount

func _arena():
	return get_tree().current_scene

func _enemies() -> Array:
	var out := []
	var arena = _arena()
	if arena and "fighters" in arena:
		for other in arena.fighters.values():
			if other != f and not other.is_defeated:
				out.append(other)
	return out

# --- Host: activation ---------------------------------------------------------

func host_try(aim: Vector2) -> void:
	if not multiplayer.is_server() or id == "" or active or cd_left > 0.05:
		return
	if not f.can_attack() or f.is_airborne():
		return
	var d: Vector2 = aim.normalized() if aim.length_squared() > 0.0001 else f.aim_direction
	d = f.assist_aim(d, float(data.get("speed", 0.0)), float(data["range"]))
	var arena = _arena()
	if arena and arena.has_method("on_fighter_disrupted"):
		arena.on_fighter_disrupted(f.peer_id)
	_begin.rpc(d, f.global_position)

## Every peer: start (same path everywhere).
@rpc("authority", "reliable", "call_local")
func _begin(d: Vector2, from: Vector2) -> void:
	active = true
	t = 0.0
	dir = d
	start = from + d * 20.0
	head = 0.0
	_stopped = false
	_released = false
	_hit.clear()
	_erupts.clear()
	_next_erupt = 0.0
	length = _clear_length(start, d, float(data["range"]))
	var travel: float = 0.35 if data["mode"] == "bolt" else length / float(data["speed"])
	total = float(data["windup"]) + travel
	f.recover_t = maxf(f.recover_t, float(data["windup"]))   # rooted for the windup
	f.aim_direction = d
	# windup art at the hands (or the ground in front, for ground powers)
	var ground: bool = data["mode"] in ["ground", "wave"]
	var at: Vector2 = from + d * 30.0 + (Vector2(0, 4) if ground else Vector2(0, -30))
	_add_fx(at, 0, float(data["windup"]) + 0.05, 0.55, 0.0, ground)

## Distance until the first wall or cover piece along the path.
func _clear_length(from: Vector2, d: Vector2, dist: float) -> float:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from, from + d * dist, Arenas.GAME_WALLS_LAYER | Arenas.GAME_OBSTACLES_LAYER)
	var hit := space.intersect_ray(q)
	return from.distance_to(hit["position"]) if not hit.is_empty() else dist

# --- Every peer: progress -----------------------------------------------------

func _physics_process(delta: float) -> void:
	cd_left = maxf(0.0, cd_left - delta)
	if active:
		t += delta
		var w: float = data["windup"]
		if t >= w and not _released:
			_released = true
			f.play_strike(dir)
			if data["mode"] == "bolt":
				_bolt_end = start + dir * length
				_bolt_t = 0.0
				_add_fx(_bolt_end + Vector2(0, -26), 2, 0.45, 0.75)
				if multiplayer.is_server():
					_host_bolt()
		if _released and data["mode"] != "bolt" and not _stopped:
			head = minf(length, (t - w) * float(data["speed"]))
			if data["mode"] == "ground":
				while _next_erupt <= head:
					_erupts.append([start + dir * _next_erupt, t])
					_next_erupt += ERUPT_EVERY
			if multiplayer.is_server():
				_host_hits()
			if head >= length and not _stopped:
				_stopped = true
				_impact(start + dir * length)
		if t >= total:
			active = false
			cd_left = cd_total
	if _bolt_t >= 0.0:
		_bolt_t += delta
		if _bolt_t > 0.35:
			_bolt_t = -1.0
	_clock += delta
	_fx = _fx.filter(func(e): return _clock - float(e[2]) < float(e[3]))
	_erupts = _erupts.filter(func(e): return t - float(e[1]) < 0.55) if active else []
	queue_redraw()

func _add_fx(pos: Vector2, row: int, life: float, s: float, rot: float = 0.0, bottom: bool = false) -> void:
	_fx.append([pos, row, _clock, life, s, rot, bottom])

func _draw_off() -> Vector2:
	return Vector2(0, -24) if data["mode"] == "shot" else Vector2.ZERO

## Impact art where it ends: ground powers stand on the ground, the rest
## burst at chest height.
func _impact(at: Vector2) -> void:
	if data["mode"] in ["ground", "wave"]:
		_add_fx(at + Vector2(0, 8), 2, 0.5, 0.75, 0.0, true)
	else:
		_add_fx(at + _draw_off(), 2, 0.45, 0.75)

# --- Host: hits ---------------------------------------------------------------

func _host_bolt() -> void:
	var end := start + dir * length
	for e in _enemies():
		if e.is_airborne() or e.get("intangible"):
			continue
		var c: Vector2 = e.global_position + Vector2(0, -10)
		var p := Geometry2D.get_closest_point_to_segment(c, start, end)
		if p.distance_to(c) <= float(data["width"]) + 14.0:
			_land(e)

func _host_hits() -> void:
	var p := start + dir * head
	var r: float = data["r"]
	for e in _enemies():
		if _hit.has(e.peer_id) or e.is_airborne() or e.get("intangible"):
			continue
		var d: Vector2 = p - e.global_position
		if absf(d.x) > HURT_HALF_W + r or d.y < -(HURT_UP + r) or d.y > HURT_DOWN + r:
			continue
		_hit[e.peer_id] = true
		_land(e)
		if data["mode"] == "shot" or data.get("single", false):
			_stop.rpc(head)
			return

func _land(e) -> void:
	var dmg := int(round(float(data["dmg"]) * f.damage_mult()))
	e.take_damage(dmg, start)
	if float(data["knock"]) > 0.0:
		e.apply_knockback(dir * float(data["knock"]))
	e.apply_status(str(data["status"]), float(data["status_t"]), id)

@rpc("authority", "reliable", "call_local")
func _stop(at_dist: float) -> void:
	_stopped = true
	head = at_dist
	_impact(start + dir * at_dist)
	# the rest of the travel time is the cooldown's business, not a wait
	total = minf(total, t + 0.05)

# --- Drawing (world space) ----------------------------------------------------

func _frame_at(row: int, age: float, loop: bool) -> Texture2D:
	var n := Specials.frames_in_row(id)
	var i := int(age * ANIM_FPS)
	i = posmod(i, n) if loop else mini(i, n - 1)
	return Specials.frame(id, row, i)

func _tex(tex: Texture2D, center: Vector2, s: float, rot: float = 0.0, a: float = 1.0, bottom: bool = false, flip: bool = false) -> void:
	if tex == null:
		return
	var sz := tex.get_size() * s
	var off := -sz / 2.0
	if bottom:
		off.y = -sz.y
	draw_set_transform(center, rot, Vector2(-1.0 if flip else 1.0, 1.0))
	draw_texture_rect(tex, Rect2(off, sz), false, Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw() -> void:
	if id == "":
		return
	# one-shot effects (windup, impacts)
	for e in _fx:
		var age: float = _clock - float(e[2])
		var life: float = e[3]
		var n := Specials.frames_in_row(id)
		var col := mini(int(age / life * n), n - 1)
		var a := 1.0 if age < life * 0.7 else 1.0 - (age - life * 0.7) / (life * 0.3)
		var grow := 1.0 + (0.25 * age / life if n == 1 else 0.0)
		_tex(Specials.frame(id, e[1], col), e[0], float(e[4]) * grow, e[5], a, e[6])
	if not active and _bolt_t < 0.0:
		return
	var mode: String = data["mode"]
	var tt := t - float(data["windup"])
	if mode == "bolt" and _bolt_t >= 0.0:
		var a := 1.0 - _bolt_t / 0.35
		var a0 := start + Vector2(0, -26)
		var a1 := _bolt_end + Vector2(0, -26)
		var seg := a0.distance_to(a1)
		var tex := _frame_at(1, _bolt_t, true)
		var sc := 0.5
		var step := 128.0 * sc
		var core := dir.orthogonal() * (-16.0 * sc) if Specials.has_sheet(id) else Vector2.ZERO
		var k := 0.0
		while k < seg:
			_tex(tex, a0 + core + dir * (k + step * 0.5), sc, dir.angle(), a)
			k += step
	elif _released and not _stopped:
		var p := start + dir * head
		match mode:
			"shot":
				_tex(_frame_at(1, tt, true), p + Vector2(0, -24), 0.62, dir.angle(), 1.0, false)
			"wave":
				_tex(_frame_at(1, tt, true), p + Vector2(0, 8), 0.8, 0.0, 1.0, true, dir.x < 0.0)
	if mode == "ground":
		for e in _erupts:
			var age: float = t - float(e[1])
			var a := 1.0 if age < 0.35 else 1.0 - (age - 0.35) / 0.2
			var rise := minf(1.0, age / 0.08)
			_tex(_frame_at(1, age, false), e[0] + Vector2(0, 6), 0.5 * (0.6 + 0.4 * rise), 0.0, a, true)
