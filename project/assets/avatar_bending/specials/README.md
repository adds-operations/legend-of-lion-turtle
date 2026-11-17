# Avatar PvP special-power sprites

This Godot 4 add-on gives the 20 special moves from the PvP brief dedicated startup, active, and finish artwork. Copy `assets/avatar_bending/specials/` into the same path at the Godot project root. The resources use the move IDs from the bending effects pack.

Each elemental atlas contains five rows of three 128 × 128 transparent cells. A `SpriteFrames` resource is provided for each move. It exposes `windup`, `active`, `impact`, and `expire` for gameplay-driven playback. Impact and expiration use the art in the finish cell. `sequence` plays the three drawings in order for inspection. Keep the effect centered and use nearest filtering.

```gdscript
@onready var cast_fx: AnimatedSprite2D = $CastFX

func show_lightning_release(start: Vector2, end: Vector2) -> void:
    cast_fx.sprite_frames = preload("res://assets/avatar_bending/specials/lightning.tres")
    cast_fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    cast_fx.global_position = (start + end) * 0.5
    cast_fx.global_rotation = (end - start).angle()
    cast_fx.play(&"active")
```

Size and position each effect against actual gameplay. For a bolt, align its visible span with the confirmed start and end points. The square frame includes transparent padding. Hold each phase for the duration of the corresponding gameplay state. Use copies at different anchors for effects that move from the caster to a target. Combat code owns collision, timing, interruption, damage, and status changes.

| Element | Special | Sprite placement |
| --- | --- | --- |
| Fire | Revolving fire rings | Center the ring at the fighter's ground point. |
| Fire | Outward fire wave | Start at the fighter and follow the advancing hit front. |
| Fire | Lightning generation | Charge at the hands, place the active bolt along its verified path, and place sparks at the impact. |
| Fire | Forehead combustion | Place the charge at the forehead, follow the tracer along its path, and put the explosion at the confirmed impact. Use the base bending pack's warning circle on the ground. |
| Fire | Flame guard | Place the crescent in front of the fighter and angle it with the guard. |
| Water | Octopus stance | Center the tentacles around the fighter. Play the breakup after expiration or when intercepts are exhausted. |
| Water | Ice barrier | Place the wall at the confirmed spawn position. Play shards at its location on break. |
| Water | Bloodbending | Show the warning on the target. Stretch and aim the active strands from caster to target during the hold, then snap them when it ends or is interrupted. |
| Water | Healing stance | Center the halo on the fighter for the healing duration. |
| Water | Water surge | Put the startup under the fighter, follow the ribbon along the dash, and splash at its end. |
| Earth | Earth armor | Center the shell around the fighter's torso, then scatter fragments on break or expiration. |
| Earth | Radial ground slam | Center the cracks, rising stone ring, and settling dust on the confirmed ground footprint. |
| Earth | Lavabending | Mark the verified lava area with the crack frame, hold the molten frame, then show the cooled crust. |
| Earth | Metal shell | Draw the rising fragments near the metal source and use the shell and shatter around the fighter. |
| Earth | Earth surfing | Anchor the slab under the fighter along the verified ground path. |
| Air | Tornado | Center the funnel on the fighter and disperse it at expiration. |
| Air | Radial repulsion burst | Expand the wind ring around the confirmed repulsion area. |
| Air | Air sphere flight | Anchor the sphere below the body, keep the ground marker visible, and dissipate the sphere at landing. |
| Air | Spirit Form | Attach the aura to the body and apply the body material during intangibility. |
| Air | Compressed air barrier | Orient the pressure barrier toward the defended direction and break it when its intercept budget ends. |

## Air-only Spirit Form

Apply `AirSpiritVisual` to the fighter's existing `AnimatedSprite2D`. The shader tints the current directional body frame lavender and makes it translucent. It follows idle, walk, and jump without an additional copy of each animation. The phase atlas supplies the separate startup, aura, and fade sprites.

```gdscript
var spirit_visual := AirSpiritVisual.new()

func refresh_spirit_visual() -> void:
    spirit_visual.update(fighter_body, original_element, equipped_special, spirit_active)
```

The helper requires the fighter's original element to be `&"air"` and equipped special to be `&"spirit_form"`. Selecting Air as the Avatar leaves the eligibility decision tied to the original build. Pass confirmed Spirit Form state from the host and clear it on expiration, defeat, or round reset. The helper restores the original material. Enforce the same eligibility in the host's gameplay rules. The shader does not change damage or collision.

The built-in image generator used the prior bending art for style and painted three distinct phases for each special. The fighter's casting poses come from the existing character pack, and the new sprites depict the powers themselves.
