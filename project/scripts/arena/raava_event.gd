extends Node2D

## The Raava event (spec §12). One per round:
##   50 s  — warning: the chosen spot shows Raava's ground ring and rising motes.
##   60 s  — Raava descends: the beam rises from the ring with the spirit inside.
##   claim — a fighter inside the circle holds Q (their special button) for
##           1.5 s while grounded and still. Moving, jumping, attacking, taking
##           damage, releasing Q, or the rival entering the circle resets it;
##           with both inside, neither progresses.
##   merge — the host awards it exactly once; the spirit sinks into the
##           fighter as the beam collapses, fusion.png bursts, and they are the
##           Avatar for the rest of the round.
## Beam frames: assets/avatar_transformation/raava/raava_beam.png.
##
## The host owns the clock, the spot, the claim and the merge. Clients only
## draw what the host sends. Positions are in World space (the arena painting).

const Arenas = preload("res://scripts/data/arenas.gd")
const T = preload("res://scripts/ui/kit/ui_tokens.gd")
const Paint = preload("res://scripts/ui/kit/ui_paint.gd")
const PowerBloom = preload("res://scripts/fx/power_bloom.gd")

const FX_DIR := "res://assets/avatar_transformation/raava/"
## raava_beam.png: 12 frames, 4 × 3, each 220 × 400, ground-ring center at (110, 370).
##   0      arriving: ground ring and rising motes (the warning)
##   1–3    the beam rises            4–8  the beam holds (loops)
##   9–11   the spirit sinks into whoever claimed it, the ring fades
const BEAM_CELL := Vector2(220, 400)
const BEAM_PIVOT := Vector2(110, 370)
const BEAM_RISE := [1, 2, 3]
const BEAM_LOOP := [4, 5, 6, 7, 8]
const BEAM_ABSORB := [9, 10, 11]
const BEAM_FPS := 9.0
const WARN_AT := 50.0
const DESCEND_AT := 60.0
const CLAIM_TIME := 1.5
const OPEN_TIME := 20.0        # if nobody merges in this long, Raava leaves (no Avatar this round)
const RADIUS := 30.0           # px from the spot to a fighter's feet
const STILL_EPS := 0.75        # px a fighter may drift per tick and still be "still"
const SYNC_INTERVAL := 0.05

enum State { IDLE, WARNING, OPEN, CLAIMED, GONE }

signal warned(seconds_left: float)
signal opened()
signal claim_changed(claimant: int, progress: float, contested: bool)
signal fused(peer_id: int)
signal departed()

var state: State = State.IDLE
var point: Vector2 = Vector2.ZERO
var claimant: int = -1
var progress: float = 0.0          # seconds channeled (0..CLAIM_TIME)
var contested: bool = false
var avatar_peer: int = -1

# host
var running: bool = false
var clock: float = 0.0
var _warn_at: float = WARN_AT
var _descend_at: float = DESCEND_AT
var _last_pos: Dictionary = {}
var _disrupted: Dictionary = {}
var _sync_t: float = 0.0

# visuals
var _t: float = 0.0
var _beam_a: float = 0.0
var _beam_t: float = 0.0          # seconds since the beam began rising
var _gone_t: float = -1.0         # seconds into the departure frames
var _absorb_t: float = -1.0       # seconds into the absorb frames (merge)
var _burst_t: float = -1.0
var _burst_at: Vector2
var _light: Node2D                # additive layer: beam, glows, motes
var _tex := {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for k in ["raava_beam", "fusion"]:
		_tex[k] = load(FX_DIR + k + ".png")
	_light = Node2D.new()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_light.material = m
	_light.draw.connect(_draw_light)
	add_child(_light)
	# Debug: --raava-at=N descends at N seconds (warning 10 s before).
	if NetworkManager.debug_args.has("raava-at"):
		_descend_at = maxf(1.0, float(NetworkManager.debug_args["raava-at"]))
		_warn_at = maxf(0.0, _descend_at - (DESCEND_AT - WARN_AT))

func fighters() -> Dictionary:
	var arena := get_tree().current_scene
	return arena.fighters if arena and "fighters" in arena else {}

func is_open() -> bool:
	return state == State.OPEN

## Seconds until Raava leaves (while the beam is open).
func seconds_left_open() -> float:
	return maxf(0.0, OPEN_TIME - _beam_t)

## Seconds until Raava descends (for the HUD countdown).
func seconds_to_descend() -> float:
	return maxf(0.0, _descend_at - clock)

# =====================================================================
# Host
# =====================================================================

func on_fighter_disrupted(peer: int) -> void:
	_disrupted[peer] = true

func _physics_process(delta: float) -> void:
	_t += delta
	if not multiplayer.is_server():
		return
	if running:
		clock += delta
	match state:
		State.IDLE:
			if running and clock >= _warn_at:
				_warn.rpc(_choose_point(), clock)
		State.WARNING:
			if running and clock >= _descend_at:
				_open.rpc()
		State.OPEN:
			if running:
				_host_claim(delta)
				if state == State.OPEN and _beam_t >= OPEN_TIME:
					_depart.rpc()
	_disrupted.clear()

func _choose_point() -> Vector2:
	var arena := get_tree().current_scene
	var pts: PackedVector2Array = arena.layout.raava_points() if arena and arena.layout and arena.layout.has_method("raava_points") else PackedVector2Array()
	if pts.is_empty():
		return Arenas.CANVAS / 2.0
	# The most neutral marker: as close to equidistant from both fighters as possible.
	var fs := fighters().values()
	var best := pts[0]
	var best_score := INF
	for p in pts:
		var score := 0.0
		if fs.size() >= 2:
			score = absf(p.distance_to(fs[0].global_position) - p.distance_to(fs[1].global_position))
		if score < best_score:
			best_score = score
			best = p
	return best

func _host_claim(delta: float) -> void:
	var inside: Array = []
	for id in fighters():
		var f = fighters()[id]
		if f.is_defeated:
			continue
		if f.global_position.distance_to(point) <= RADIUS:
			inside.append(f)
	var new_claimant := -1
	var new_contested := inside.size() >= 2
	if inside.size() == 1:
		var f = inside[0]
		var moved: float = f.global_position.distance_to(_last_pos.get(f.peer_id, f.global_position))
		var ok: bool = f.channel_held and not f.is_jumping and moved <= STILL_EPS and not _disrupted.has(f.peer_id)
		if ok:
			new_claimant = f.peer_id
	if new_claimant != claimant:
		progress = 0.0
	claimant = new_claimant
	contested = new_contested
	if claimant != -1:
		progress += delta
	else:
		progress = 0.0
	for id in fighters():
		_last_pos[id] = fighters()[id].global_position
	if claimant != -1 and progress >= CLAIM_TIME:
		_fuse.rpc(claimant)
		return
	_sync_t -= delta
	if _sync_t <= 0.0:
		_sync_t = SYNC_INTERVAL
		_sync_claim.rpc(claimant, progress, contested)

# =====================================================================
# Everyone (host → all)
# =====================================================================

@rpc("authority", "reliable", "call_local")
func _warn(at: Vector2, host_clock: float) -> void:
	point = at
	clock = host_clock
	state = State.WARNING
	print("[Raava] approaching — spot %s" % str(at))
	warned.emit(_descend_at - host_clock)

@rpc("authority", "reliable", "call_local")
func _open() -> void:
	state = State.OPEN
	_beam_t = 0.0
	clock = _descend_at
	print("[Raava] descended")
	opened.emit()

@rpc("authority", "unreliable_ordered", "call_local")
func _sync_claim(who: int, p: float, is_contested: bool) -> void:
	if state != State.OPEN:
		return
	claimant = who
	progress = p
	contested = is_contested
	for id in fighters():
		fighters()[id].channeling = (id == who and p > 0.0)
	claim_changed.emit(who, p, is_contested)

@rpc("authority", "reliable", "call_local")
func _fuse(peer: int) -> void:
	if state == State.CLAIMED:
		return
	state = State.CLAIMED
	avatar_peer = peer
	claimant = -1
	progress = 0.0
	for id in fighters():
		fighters()[id].channeling = false
	var f = fighters().get(peer)
	if f:
		f.become_avatar()
		_burst_at = f.global_position + Vector2(0, -36)
	_absorb_t = 0.0
	print("[Raava] peer %d merged with Raava — the Avatar" % peer)
	fused.emit(peer)

## New round: Raava comes again at the usual time (every peer).
func reset_for_round() -> void:
	_clear()
	_warn_at = WARN_AT
	_descend_at = DESCEND_AT
	if NetworkManager.debug_args.has("raava-at"):
		_descend_at = maxf(1.0, float(NetworkManager.debug_args["raava-at"]))
		_warn_at = maxf(0.0, _descend_at - (DESCEND_AT - WARN_AT))
	running = false

## Training: call Raava now (descends after `delay` seconds). Clears any
## Avatar so the merge can be practiced again and again.
func summon(delay: float = 3.0) -> void:
	for f in fighters().values():
		if f.is_avatar:
			f.clear_avatar()
	_clear()
	_warn_at = 0.0
	_descend_at = delay
	running = true

func _clear() -> void:
	for f in fighters().values():
		f.channeling = false
	state = State.IDLE
	claimant = -1
	progress = 0.0
	contested = false
	avatar_peer = -1
	_absorb_t = -1.0
	_burst_t = -1.0
	_gone_t = -1.0
	_beam_t = 0.0
	_beam_a = 0.0
	_last_pos.clear()
	clock = 0.0

@rpc("authority", "reliable", "call_local")
func _depart() -> void:
	if state != State.OPEN:
		return
	state = State.GONE
	claimant = -1
	progress = 0.0
	_gone_t = 0.0
	for id in fighters():
		fighters()[id].channeling = false
	print("[Raava] left — nobody merged in time")
	departed.emit()

## Round end (every peer): stop the clock and clear any channel.
func stop() -> void:
	running = false
	for id in fighters():
		fighters()[id].channeling = false

# =====================================================================
# Drawing
# =====================================================================

func _process(delta: float) -> void:
	if not multiplayer.is_server() and state != State.IDLE and state != State.CLAIMED:
		clock += delta  # clients only need it for the warning countdown
	var target := 1.0 if state == State.OPEN else 0.0
	_beam_a = move_toward(_beam_a, target, delta / (0.6 if target > 0.0 else 0.3))
	if state == State.OPEN:
		_beam_t += delta
	if _gone_t >= 0.0:
		_gone_t += delta
	if _absorb_t >= 0.0:
		_absorb_t += delta
		if _absorb_t >= BEAM_ABSORB.size() / BEAM_FPS and _burst_t < 0.0 and _absorb_t < 10.0:
			_absorb_t = 10.0  # done; the burst takes over
			_burst_t = 0.0
			_spawn_bloom()
	if _burst_t >= 0.0:
		_burst_t += delta / 0.7
		if _burst_t >= 1.0:
			_burst_t = -1.0
	queue_redraw()
	_light.queue_redraw()

func _spawn_bloom() -> void:
	var f = fighters().get(avatar_peer)
	if f == null:
		return
	_burst_at = f.global_position + Vector2(0, -36)
	var b := PowerBloom.new()
	get_parent().add_child(b)
	get_parent().move_child(b, get_index() + 1)  # under the fighters, never over the sprite
	b.setup(_burst_at, Color(1, 0.97, 0.85), 44.0, 0.45, true)

func _beam_frame(i: int, a: float = 1.0) -> void:
	var tex: Texture2D = _tex["raava_beam"]
	var src := Rect2(Vector2(i % 4, i / 4) * BEAM_CELL, BEAM_CELL)
	draw_texture_rect_region(tex, Rect2(point - BEAM_PIVOT, BEAM_CELL), src, Color(1, 1, 1, a))

func _draw() -> void:
	match state:
		State.WARNING:
			# Raava is arriving: the ground ring and rising motes mark the spot
			_beam_frame(0, 0.75 + 0.25 * sin(_t * 5.0))
		State.OPEN:
			var n := int(_beam_t * BEAM_FPS)
			if n < BEAM_RISE.size():
				_beam_frame(BEAM_RISE[n])
			else:
				_beam_frame(BEAM_LOOP[(n - BEAM_RISE.size()) % BEAM_LOOP.size()])
			_draw_progress()
		State.GONE:
			# the spirit rises away and the ring fades
			if _gone_t >= 0.0 and _gone_t < 0.6:
				_beam_frame(10 if _gone_t < 0.25 else 11, 1.0 - maxf(0.0, _gone_t - 0.25) / 0.35)
		State.CLAIMED:
			if _absorb_t >= 0.0 and _absorb_t < 10.0:
				var k := mini(int(_absorb_t * BEAM_FPS), BEAM_ABSORB.size() - 1)
				_beam_frame(BEAM_ABSORB[k])
	if _burst_t >= 0.0:
		var fusion: Texture2D = _tex["fusion"]
		var s := lerpf(0.55, 1.0, ease(_burst_t, 0.3))   # stays small: ~90 px at its largest
		draw_set_transform(_burst_at, _burst_t * 1.2, Vector2(s, s))
		draw_texture(fusion, -fusion.get_size() / 2.0, Color(1, 1, 1, 1.0 - _burst_t * _burst_t))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Claim progress: a ring around the circle filling in the channeler's side color.
func _draw_progress() -> void:
	draw_set_transform(point, 0.0, Vector2(1.0, 0.24))
	var r := 64.0
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(T.INK, 0.45), 4.0, true)
	if claimant != -1 and progress > 0.0:
		var you := claimant == multiplayer.get_unique_id()
		var frac := clampf(progress / CLAIM_TIME, 0.0, 1.0)
		draw_arc(Vector2.ZERO, r, -PI / 2.0, -PI / 2.0 + TAU * frac, 48, T.side_color(you), 4.0, true)
	elif contested:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(T.VERMILION, 0.5 + 0.4 * sin(_t * 10.0)), 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_light() -> void:
	var gl := Paint.glow()
	if state == State.WARNING:
		_light.draw_texture_rect(gl, Rect2(point - Vector2(60, 18), Vector2(120, 36)), false, Color(0.5, 0.85, 1.0, 0.3 + 0.15 * sin(_t * 5.0)))
	if _beam_a > 0.0:
		# soft light pooling around the beam's base and along its column
		_light.draw_texture_rect(gl, Rect2(point - Vector2(70, 24), Vector2(140, 48)), false, Color(0.55, 0.85, 1.0, 0.55 * _beam_a))
		_light.draw_texture_rect(gl, Rect2(point + Vector2(-60, -330), Vector2(120, 330)), false, Color(0.5, 0.8, 1.0, 0.22 * _beam_a))
	if _burst_t >= 0.0:
		var r := 30.0 + 50.0 * _burst_t
		_light.draw_texture_rect(gl, Rect2(_burst_at - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 0.95, 0.8, 0.6 * (1.0 - _burst_t)))
