# Avatar PvP mid-round transformation

This add-on pairs with the final eight-fighter character pack. Each fighter has a transparent four-direction transformation sheet that preserves their costume and proportions. There are four body poses per direction. The sheet shows a grounded channel, Raava entering the body, the peak of fusion with glowing eyes, and the Avatar settling into a ready stance.

Copy `assets/avatar_transformation/` to the same location in the Godot project. The original fighter sheets continue to provide walk, strike, jump, hit and defeat animations. Load the new resource for the fighter's ID and merge its animations into that fighter's existing `SpriteFrames` when creating the fighter.

```gdscript
@onready var body: AnimatedSprite2D = $Body

func install_transformation_frames() -> void:
    var raava := preload("res://assets/avatar_transformation/fighters/stone_warden_avatar.tres")
    body.sprite_frames = AvatarTransformationFrames.combine(body.sprite_frames, raava)
    body.centered = false
    body.offset = Vector2(-48, -80)
    body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
```

Atlas columns are south, west, east, north. Atlas cells are 96 × 96 px with the same ground pivot at (48, 80) as the fighter pack. Use the following names with the current facing suffix.

| Animation | When to play |
| --- | --- |
| `raava_channel_south` | Hold the grounded pose while the host reports active claim progress. Draw the progress meter separately. |
| `raava_fusion_south` | Play once on the host's successful claim. Three frames last about 0.44 seconds at default speed. |
| `avatar_ready_south` | Hold the glowing ready pose while the transformed fighter is stationary. Use normal movement and combat animations when the gameplay state changes. |

## Event and effect timing

- Use `warning_circle.png` at the arena's selected Raava marker when the warning begins at 50 seconds. At 60 seconds use `claim_circle.png` at the ground point and `spirit_descent.png` above it.
- On valid Q hold, enter `raava_channel_<direction>`. The host owns the 1.5-second grounded channel. On contest, interruption, or release, clear the channel animation and return to the applicable gameplay pose.
- On confirmed fusion, remove the beam, draw the spirit briefly traveling into the fighter, and use `fusion.png` as the four-element burst. Keep the burst small enough to leave the opponent, active effects, and cover readable. The transformation poses already have eye highlights where the face is visible. `eye_glow.png` is available for an optional face-aligned accent.
- After fusion, retain the active element in the HUD and display a separate element accent. The body has glowing eyes in the fusion and Avatar-ready poses. Build any persistent eye glow during walk and combat as a separate, direction-aware overlay.
- Drive hit and defeat states from gameplay, including during fusion. The animation grants no healing or invulnerability. Preserve HP, stats, cooldowns, and the equipped special. The host owns element switching and the Avatar state reset at round end.

`transformation.json` maps fighter IDs to their resources and identifies the effect textures. The included Raava effects are reused from the bending pack, so this folder can be imported independently. The built-in image generator used each fighter's existing sprite sheet as the costume, proportions, and pose-angle reference and drew the four transformation poses in four directions.
