extends Node2D

## Arena — loads the layout the host picked (assets/avatar_arenas), frames
## its 960×640 painting full-bleed (a camera zooms it to cover the whole
## screen and drifts with the fight — no frame, no borders), spawns both
## fighters from NetworkManager.players on every peer, runs the load
## handshake, replicates projectiles, and ends the round on a defeat.

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const PROJECTILE_SCENE := preload("res://scenes/characters/projectile.tscn")
const DamageNumber = preload("res://scripts/ui/kit/damage_number.gd")
const PowerBloom = preload("res://scripts/fx/power_bloom.gd")
const T = preload("res://scripts/ui/kit/ui_tokens.gd")
const Arenas = preload("res://scripts/data/arenas.gd")
const RaavaEvent = preload("res://scripts/arena/raava_event.gd")
const Elements = preload("res://scripts/data/elements.gd")
const BendingFX = preload("res://scripts/fx/bending_fx.gd")
const FxSprite = preload("res://scripts/fx/fx_sprite.gd")
const INTRO_TIME := 1.2
const FIGHT_BANNER_TIME := 1.0
const RESULT_SCREEN_TIME := 4.0

@onready var world: Node2D = $World
@onready var players_root: Node2D = $World/Players
@onready var projectiles_root: Node2D = $World/Projectiles
@onready var hud = $CanvasLayer/HUD

var arena_id: String = Arenas.DEFAULT_ID
var layout: Node2D  # AvatarArenaLayout

var camera: Camera2D
var raava: Node2D  # RaavaEvent: the mid-round Avatar contest
var _cam_y: float = -1.0
var fighters: Dictionary = {}  # peer_id -> Player
var round_live: bool = false
var _projectile_counter: int = 0
var _debug_log_timer: float = 0.0

func _ready() -> void:
	_load_layout(NetworkManager.selected_arena)
	print("[Arena] %s loaded (peer %d)" % [Arenas.display_name(arena_id), multiplayer.get_unique_id()])
	if NetworkManager.training:
		_start_training()
		return
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		push_warning("[Arena] Opened without a network session. Run from the main menu.")
		hud.show_waiting("No match in progress. Start from the main menu.")
		return
	_spawn_fighters()
	_setup_raava()
	hud.bind(get_local_fighter(), fighters.get(NetworkManager.get_rival_id()))
	hud.show_waiting("Waiting for rival to load...")
	if multiplayer.is_server():
		NetworkManager.all_arena_loaded.connect(_on_all_arena_loaded, CONNECT_ONE_SHOT)
	NetworkManager.report_arena_loaded.rpc_id(1)

## Instance the selected arena scene under World, centered at 1× (crisp pixels),
## and remap the pack's physics layers to this project's layer names.
func _load_layout(id: String) -> void:
	arena_id = id if Arenas.is_valid(id) else Arenas.DEFAULT_ID
	var packed: PackedScene = load(Arenas.scene_path(arena_id))
	layout = packed.instantiate()
	world.add_child(layout)
	world.move_child(layout, 0)
	world.position = Vector2.ZERO
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.position_smoothing_enabled = false
	add_child(camera)
	camera.make_current()
	_update_camera(0.0, true)
	for body in layout.get_children():
		if body is StaticBody2D:
			if body.collision_layer == Arenas.PACK_COVER_LAYER:
				body.collision_layer = Arenas.GAME_OBSTACLES_LAYER
			elif body.collision_layer == Arenas.PACK_BOUNDARY_LAYER:
				body.collision_layer = Arenas.GAME_WALLS_LAYER

## The Raava event lives in World (between the painting and the fighters).
func _setup_raava() -> void:
	raava = RaavaEvent.new()
	raava.name = "Raava"
	world.add_child(raava)
	world.move_child(raava, layout.get_index() + 1)
	raava.warned.connect(hud.on_raava_warned.bind(raava))
	raava.opened.connect(hud.on_raava_opened)
	raava.departed.connect(hud.on_raava_left)
	raava.claim_changed.connect(hud.on_raava_claim)
	raava.fused.connect(func(peer): hud.on_raava_fused(fighters.get(peer)))

# =====================================================================
# Training (single player, offline)
# =====================================================================

const PARTNER_MODES := ["STANDING", "MOVING", "SPARRING"]

func _start_training() -> void:
	_spawn_fighters()
	_setup_raava()
	var me = get_local_fighter()
	var partner = fighters.get(NetworkManager.TRAINING_PARTNER_ID)
	me.free_switch = true
	partner.ai_mode = 0
	hud.bind(me, partner)
	hud.setup_training(PARTNER_MODES[0])
	for f in fighters.values():
		f.net_ready = true
	hud.play_intro(Arenas.display_name(arena_id).to_upper(), "Training")
	await get_tree().create_timer(INTRO_TIME).timeout
	hud.play_fight("Begin!")
	await get_tree().create_timer(FIGHT_BANNER_TIME * 0.35).timeout
	round_live = true
	for f in fighters.values():
		f.can_act = true
	print("[Training] live")
	# test shortcuts: --raava-at=N calls Raava N s in; --partner=moving|sparring
	if NetworkManager.debug_args.has("raava-at"):
		raava.summon(maxf(1.0, float(NetworkManager.debug_args["raava-at"])))
	if NetworkManager.debug_args.has("partner"):
		var i := PARTNER_MODES.find(str(NetworkManager.debug_args["partner"]).to_upper())
		if i >= 0:
			partner.ai_mode = i
			hud.set_partner_mode(PARTNER_MODES[i])

func _training_key(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	match (event as InputEventKey).physical_keycode:
		KEY_T:
			if raava and not raava.is_open():
				raava.summon(3.0)
			return true
		KEY_G:
			var partner = fighters.get(NetworkManager.TRAINING_PARTNER_ID)
			if partner:
				partner.ai_mode = (partner.ai_mode + 1) % PARTNER_MODES.size()
				hud.set_partner_mode(PARTNER_MODES[partner.ai_mode])
			return true
	return false

func _training_revive(peer: int) -> void:
	var f = fighters.get(peer)
	if f == null:
		return
	hud.flash_hint("BACK ON YOUR FEET" if f == get_local_fighter() else "PARTNER RECOVERS", 1.2)
	await get_tree().create_timer(1.4).timeout
	if is_instance_valid(f):
		f.revive()

## Host: anything that should reset a Raava channel (attack, jump, damage).
func on_fighter_disrupted(peer: int) -> void:
	if raava:
		raava.on_fighter_disrupted(peer)

func _spawn_points() -> PackedVector2Array:
	var pts: PackedVector2Array = layout.spawn_points() if layout else PackedVector2Array()
	if pts.size() < 2:
		var v := get_viewport_rect().size
		pts = PackedVector2Array([Vector2(v.x * 0.3, v.y * 0.5), Vector2(v.x * 0.7, v.y * 0.5)])
	return pts

func _spawn_fighters() -> void:
	var spawns := _spawn_points()
	var ids := NetworkManager.get_player_ids_sorted()
	for i in ids.size():
		var id: int = ids[i]
		var info: Dictionary = NetworkManager.players[id]
		var fighter = PLAYER_SCENE.instantiate()
		fighter.setup(id, i, int(info["element"]), players_root.to_local(spawns[mini(i, spawns.size() - 1)]), str(info.get("fighter", "")))
		players_root.add_child(fighter)
		fighters[id] = fighter
		fighter.hp_changed.connect(_on_fighter_hp_changed.bind(fighter))
	print("[Arena] Spawned fighters: %s" % str(fighters.keys()))

func get_local_fighter():
	return fighters.get(multiplayer.get_unique_id())

func _physics_process(_delta: float) -> void:
	# Host: anything that leaves the arena's play area is removed everywhere.
	if not multiplayer.is_server() or layout == null:
		return
	for p in projectiles_root.get_children():
		if p is Area2D and not p.get("_spent") and layout.material_at(p.global_position) == &"outside":
			p.set("_spent", true)
			despawn_projectile(p.name)

## Full-bleed framing: zoom so the painting covers the screen (never shows
## past its edges), then slide along the cropped axis to keep both fighters
## in view. Snapped to whole screen pixels so the pixel art never shimmers.
func _update_camera(delta: float, snap_now: bool = false) -> void:
	if camera == null:
		return
	var view := get_viewport_rect().size
	var z := maxf(view.x / Arenas.CANVAS.x, view.y / Arenas.CANVAS.y)
	camera.zoom = Vector2(z, z)
	var half := view / z / 2.0
	var focus := Arenas.CANVAS / 2.0
	if not fighters.is_empty():
		var sum := Vector2.ZERO
		for f in fighters.values():
			sum += f.global_position + Vector2(0, -30)
		focus = sum / fighters.size()
	var target := Vector2(
		clampf(focus.x, half.x, Arenas.CANVAS.x - half.x),
		clampf(focus.y, half.y, Arenas.CANVAS.y - half.y))
	if snap_now or _cam_y < 0.0:
		camera.set_meta("p", target)
	var p: Vector2 = camera.get_meta("p", target)
	p = p.lerp(target, clampf(delta * 2.5, 0.0, 1.0)) if not snap_now else target
	camera.set_meta("p", p)
	_cam_y = p.y
	var px := 1.0 / z
	camera.position = (p / px).round() * px

func _process(delta: float) -> void:
	_update_camera(delta)
	if NetworkManager.has_debug("log-sync"):
		_debug_log_timer -= delta
		if _debug_log_timer <= 0.0:
			_debug_log_timer = 1.0
			var parts: Array = []
			for id in fighters:
				var f = fighters[id]
				parts.append("%d@(%d,%d) hp=%d%s%s" % [id, f.global_position.x, f.global_position.y, f.hp, " JUMP" if f.is_jumping else "",
						(" AVATAR:%s" % T.ELEMENT_NAMES[f.active_element]) if f.is_avatar else ""])
			print("[Sync peer %d] %s | bolts=%d" % [multiplayer.get_unique_id(), " ".join(parts), projectiles_root.get_child_count()])

# =====================================================================
# Feedback
# =====================================================================

func _on_fighter_hp_changed(new_hp: int, delta: int, fighter) -> void:
	if delta >= 0:
		return
	if NetworkManager.training and fighter != get_local_fighter():
		hud.training_hit(-delta)
	var dmg := DamageNumber.new().setup(-delta, T.SIDE_RIVAL.lightened(0.25) if fighter == get_local_fighter() else T.SIDE_YOU)
	dmg.position = fighter.global_position + Vector2(randf_range(-10, 10), -92)
	add_child(dmg)
	hud.on_fighter_damaged(fighter, -delta)

# =====================================================================
# Round start (host decides, everyone follows)
# =====================================================================

func _on_all_arena_loaded() -> void:
	GameManager.start_round()
	_begin_round.rpc(GameManager.current_round)

@rpc("authority", "reliable", "call_local")
func _begin_round(round_number: int) -> void:
	GameManager.current_round = round_number
	GameManager.current_state = GameManager.GameState.PLAYING
	for f in fighters.values():
		f.net_ready = true
	hud.play_round_intro(round_number, Arenas.display_name(arena_id).to_upper())
	await get_tree().create_timer(INTRO_TIME).timeout
	hud.play_fight()
	await get_tree().create_timer(FIGHT_BANNER_TIME * 0.35).timeout
	round_live = true
	for f in fighters.values():
		f.can_act = true
	if raava:
		raava.running = true
	print("[Arena] Round %d live" % round_number)

# =====================================================================
# Projectiles
# =====================================================================

## Host only. Throws the power on key `slot` for `owner_id`: one or more
## projectiles (fans and rings per scripts/data/elements.gd), the same on every peer.
func spawn_attack(owner_id: int, element: int, slot: int, dir: Vector2, airborne: bool, bend: float = 0.0) -> void:
	if not multiplayer.is_server() or not round_live:
		return
	var caster = fighters.get(owner_id)
	if caster == null:
		return
	var a := Elements.attack(element, slot)
	if a["kind"] == "beam":
		# a beam can't bend: a two-arrow combo sends it on the diagonal instead
		_host_beam(caster, element, slot, dir.rotated(bend * PI / 4.0), airborne, a)
		return
	if a["kind"] == "burst":
		_host_burst(caster, element, slot, airborne, a)
		return
	var count: int = a["count"]
	var spread: float = deg_to_rad(a["spread"])
	for i in count:
		var d := dir
		if count > 1:
			if a["spread"] >= 360.0:
				d = dir.rotated(TAU * i / count)
			else:
				d = dir.rotated(lerpf(-spread / 2.0, spread / 2.0, float(i) / (count - 1)))
		var pos: Vector2 = caster.global_position + d * 24.0
		# Never spawn past a wall or rock: start just in front of it instead.
		var space := get_world_2d().direct_space_state
		var q := PhysicsRayQueryParameters2D.create(caster.global_position, pos, Arenas.GAME_WALLS_LAYER | Arenas.GAME_OBSTACLES_LAYER)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			pos = hit["position"] - d * 6.0
		_projectile_counter += 1
		_spawn_projectile_rpc.rpc("Bolt_%d_%d" % [owner_id, _projectile_counter], owner_id, element, slot, pos, d, airborne, i == 0, bend)

@rpc("authority", "reliable", "call_local")
func _spawn_projectile_rpc(proj_name: String, owner_id: int, element: int, slot: int, pos: Vector2, dir: Vector2, airborne: bool, lead: bool, bend: float = 0.0) -> void:
	var p = PROJECTILE_SCENE.instantiate()
	p.name = proj_name
	p.position = projectiles_root.to_local(pos)
	p.setup(dir, element, owner_id, slot, airborne, bend)
	projectiles_root.add_child(p)
	if lead:
		# this attack's own windup art at the bender's hands
		_windup(element, slot, pos + Vector2(0, -58.0 if airborne else -26.0))
		var caster = fighters.get(owner_id)
		if caster:
			caster.play_strike(dir)

## Lightning: instant along a line (stopped by walls). Hits whoever stands
## on that line at the same height as the caster.
func _host_beam(caster, element: int, slot: int, dir: Vector2, airborne: bool, a: Dictionary) -> void:
	var start: Vector2 = caster.global_position + dir * 18.0
	var end: Vector2 = start + dir * float(a["range"])
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(start, end, Arenas.GAME_WALLS_LAYER | Arenas.GAME_OBSTACLES_LAYER)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		end = hit["position"]
	for f in fighters.values():
		if f == caster or f.is_defeated or f.is_jumping != airborne:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(f.global_position, start, end)
		if closest.distance_to(f.global_position) <= float(a["width"]):
			f.take_damage(combo_damage(caster.peer_id, int(a["dmg"])))
			if float(a["knock"]) > 0.0:
				f.apply_knockback(dir * float(a["knock"]))
	_fx_beam.rpc(caster.peer_id, element, slot, start, end, airborne)

## Ground Slam / Knockback Blast: everyone within the radius, pushed outward.
func _host_burst(caster, element: int, slot: int, airborne: bool, a: Dictionary) -> void:
	var center: Vector2 = caster.global_position
	for f in fighters.values():
		if f == caster or f.is_defeated or f.is_jumping != airborne:
			continue
		var d: Vector2 = f.global_position - center
		if d.length() <= float(a["radius"]):
			f.take_damage(combo_damage(caster.peer_id, int(a["dmg"])))
			if float(a["knock"]) > 0.0:
				f.apply_knockback((d.normalized() if d.length() > 0.1 else caster.aim_direction) * float(a["knock"]))
	_fx_burst.rpc(caster.peer_id, element, slot, center, airborne)

@rpc("authority", "reliable", "call_local")
func _fx_beam(owner_id: int, element: int, slot: int, start: Vector2, end: Vector2, airborne: bool) -> void:
	var fx := BendingFX.fx(element, slot)
	var lift := Vector2(0, -58.0 if airborne else -26.0)
	var tex := BendingFX.frame(element, fx["beam"])
	var length := start.distance_to(end)
	var b := FxSprite.make(tex, (start + end) / 2.0 + lift, 1.0, 0.3)
	b.base_scale = Vector2(length / tex.get_size().x, 0.75)
	b.grow = 0.0
	b.rotation = (end - start).angle()
	projectiles_root.add_child(b)
	_windup(element, slot, start + lift)
	projectiles_root.add_child(FxSprite.make(BendingFX.frame(element, fx["hit"]), end + lift, fx.get("hit_scale", 0.5), 0.35))
	_bloom(end + lift, T.element_glow(element), 34.0, 0.3)
	var caster = fighters.get(owner_id)
	if caster:
		caster.play_strike((end - start).normalized())

@rpc("authority", "reliable", "call_local")
func _fx_burst(owner_id: int, element: int, slot: int, center: Vector2, airborne: bool) -> void:
	var fx := BendingFX.fx(element, slot)
	var a := Elements.attack(element, slot)
	var tex := BendingFX.frame(element, fx["burst"])
	# sized so the art covers the hit radius
	var s := float(a["radius"]) * 2.0 / tex.get_size().x * 1.15
	var lift := Vector2(0, -26.0 if airborne else 0.0)
	var b := FxSprite.make(tex, center + lift, s * 0.6, 0.45, false, BendingFX.frame(element, fx["hit"]))
	b.grow = 0.7
	projectiles_root.add_child(b)
	_windup(element, slot, center + Vector2(0, -26) + lift)
	var caster = fighters.get(owner_id)
	if caster:
		caster.play_strike(caster.aim_direction)

## The attack's windup frame (column 0 of its sheet row), flashed at the hands.
func _windup(element: int, slot: int, at: Vector2) -> void:
	var fx := BendingFX.fx(element, slot)
	if fx.has("wind"):
		var w := FxSprite.make(BendingFX.frame(element, fx["wind"]), at, 0.42, 0.2)
		w.grow = 0.25
		projectiles_root.add_child(w)

# =====================================================================
# Combos (host): hits landed in quick succession chain up. From the 3rd hit
# each one deals more (+15% per hit, up to +60%). The chain drops after
# COMBO_WINDOW seconds without a hit, or when the attacker gets hit.
# =====================================================================

const COMBO_WINDOW := 1.6
var _chain: Dictionary = {}   # attacker peer -> {"n": hits, "t": time of last hit}

func combo_damage(attacker: int, base: int) -> int:
	if not multiplayer.is_server():
		return base
	var now := Time.get_ticks_msec() / 1000.0
	var c: Dictionary = _chain.get(attacker, {"n": 0, "t": -99.0})
	c["n"] = int(c["n"]) + 1 if now - float(c["t"]) <= COMBO_WINDOW else 1
	c["t"] = now
	_chain[attacker] = c
	# getting hit breaks your own chain
	for id in fighters:
		if id != attacker:
			_chain.erase(id)
	var n: int = c["n"]
	var mult := 1.0 + clampf(0.15 * (n - 2), 0.0, 0.6)
	if n >= 2:
		_combo_rpc.rpc(attacker, n, mult)
	return int(round(base * mult))

@rpc("authority", "reliable", "call_local")
func _combo_rpc(attacker: int, hits: int, mult: float) -> void:
	hud.show_combo(attacker == multiplayer.get_unique_id(), hits, mult)

func _bloom(global_pos: Vector2, color: Color, radius: float, duration: float) -> void:
	var b := PowerBloom.new()
	projectiles_root.add_child(b)
	b.setup(global_pos, color, radius, duration)

## Host only. Removes a projectile everywhere.
func despawn_projectile(proj_name: String) -> void:
	if multiplayer.is_server():
		_despawn_projectile_rpc.rpc(proj_name)

@rpc("authority", "reliable", "call_local")
func _despawn_projectile_rpc(proj_name: String) -> void:
	var p := projectiles_root.get_node_or_null(proj_name)
	if p:
		# impact: the power's finish art plus a soft bloom where it landed
		p.play_end()
		_bloom(p.global_position + Vector2(0, -58.0 if p.airborne else -26.0), T.element_glow(p.element), 30.0, 0.25)
		p.queue_free()

# =====================================================================
# Round end
# =====================================================================

## Host only. Called by a fighter when its HP reaches 0.
func on_player_defeated(loser_id: int) -> void:
	if NetworkManager.training:
		_training_revive(loser_id)
		return
	if not multiplayer.is_server() or not round_live:
		return
	var winner_id := -1
	for id in fighters:
		if id != loser_id:
			winner_id = id
	_end_round.rpc(winner_id)
	await get_tree().create_timer(RESULT_SCREEN_TIME).timeout
	if not (multiplayer.is_server() and is_inside_tree()):
		return
	if GameManager.current_state == GameManager.GameState.MATCH_END:
		NetworkManager.return_to_lobby()
		return
	# Best of 3: next round in the same arena. The Avatar is gone, Raava comes again.
	_reset_round.rpc()
	await get_tree().create_timer(0.3).timeout
	if is_inside_tree():
		GameManager.start_round()
		_begin_round.rpc(GameManager.current_round)

@rpc("authority", "reliable", "call_local")
func _reset_round() -> void:
	for p in projectiles_root.get_children():
		p.queue_free()
	var spawns := _spawn_points()
	var ids := NetworkManager.get_player_ids_sorted()
	for i in ids.size():
		var f = fighters.get(ids[i])
		if f:
			f.reset_for_round(players_root.to_local(spawns[mini(i, spawns.size() - 1)]))
	if raava:
		raava.reset_for_round()
	_chain.clear()
	hud.clear_result()
	_update_camera(0.0, true)

@rpc("authority", "reliable", "call_local")
func _end_round(winner_id: int) -> void:
	round_live = false
	if raava:
		raava.stop()
	for p in projectiles_root.get_children():
		p.queue_free()  # clear the field: nothing lands after the result
	for f in fighters.values():
		f.can_act = false
		f.net_ready = false  # stop movement traffic before the scene changes
	GameManager.end_round(NetworkManager.get_player_index(winner_id))
	var won := winner_id == multiplayer.get_unique_id()
	var my_idx := NetworkManager.get_player_index(multiplayer.get_unique_id())
	var winner = fighters.get(winner_id)
	hud.show_result(won, GameManager.scores[my_idx], GameManager.scores[1 - my_idx], RESULT_SCREEN_TIME,
			winner != null and winner.is_avatar, GameManager.current_state == GameManager.GameState.MATCH_END)
	print("[Arena] Round over — winner peer %d" % winner_id)

var _leave_armed_until: float = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if NetworkManager.training and _training_key(event):
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("pause_menu"):
		return
	if NetworkManager.training:
		var t := Time.get_ticks_msec() / 1000.0
		if t < _leave_armed_until:
			NetworkManager.leave_training()
		else:
			_leave_armed_until = t + 2.0
			hud.flash_hint("Press Esc again to leave training")
		return
	# Full match menu (Resume / Request Pause / Leave) arrives with Stage 4.
	# For now: press Esc twice within 2 s to leave the match.
	var now := Time.get_ticks_msec() / 1000.0
	if now < _leave_armed_until:
		NetworkManager.abort_to_menu("You left the match.")
	else:
		_leave_armed_until = now + 2.0
		hud.flash_hint("Press Esc again to leave")
