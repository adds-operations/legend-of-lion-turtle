# Avatar PvP character sprites · v2

This pack contains eight original pixel-art benders with one woman and one man per element. Stone Warden has redrawn side-facing poses with matching head, torso, and stride direction. Temple Courier has a side braid and a rust flight jacket. Cloud Keeper is an older, stockier bison keeper with gray hair, a beard, and a mustard cape.

## Drop into Godot 4

Copy `assets/avatar_characters/` to the same relative path under the Godot project root. Replace the v1 files if already installed. Fighter IDs and base animation names are compatible with v1. Each `.tres` is directly assignable to an `AnimatedSprite2D`.

```gdscript
@onready var body: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
    body.sprite_frames = preload("res://assets/avatar_characters/stone_warden.tres")
    body.centered = false
    body.offset = Vector2(-48, -80)
    body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    body.play(&"idle_south")
```

All frames are 96 × 96 px with a ground pivot at (48, 80). Atlas columns are south, west, east, and north. The 384 × 384 base PNG rows are idle, stride A, stride B, and strike. The 384 × 480 action PNG rows are takeoff, airborne, landing, hit, and defeat.

| Animation prefix | When to use it |
| --- | --- |
| `idle` | Standing. Loops. |
| `walk` | Ground movement. Loops. |
| `strike` | Generic attack. Plays once. |
| `jump_start` | Show the takeoff pose on launch. |
| `airborne` | Hold the tucked pose in the air. |
| `land` | Play the landing squat, then return to idle or walk. |
| `hit` | Play recoil, then return to the active state. |
| `defeat` | Hold the collapsed pose until the round resets. |

Append `_south`, `_west`, `_east`, or `_north` to any prefix. Switch jump poses on gameplay state changes. Drive jump height by offsetting the sprite node upward from the ground point and keep its shadow at the ground point. Hit stun, attack timings, and collision come from gameplay state. Use separate player outlines and separate elemental effects.

The pack includes a generic strike. Move-specific choreography and the Avatar transformation are separate art passes.

`roster.json` contains IDs, resource paths, and atlas layouts. The preview images show the roster and the new action poses.

## Art direction

The built-in image generator used the prior sprite sheets as references for pixel size, dark outlines, costume, and camera angle. The action prompt called for a transparent four-direction grid with a push-off, tucked airborne pose, grounded landing squat, hit recoil, and collapsed defeat pose. The Stone Warden correction used a right-facing redraw with nose, chest, hips, and boot direction aligned, then mirrored those poses for west. The Air Nomad prompts specified a slim braided courier in a rust flight coat and an older, broad-shouldered keeper with tied gray hair, beard, and a mustard cape. Both designs use uncovered hair and omit arrow markings.
