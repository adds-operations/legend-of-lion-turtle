# Avatar PvP arena bundle

Sixteen original hand-styled pixel-art arenas across the Earth Kingdom, Water Tribes, Fire Nation, and Air Nomads. Each has its own background and Godot scene, with four maps per region. All sixteen arenas have wadeable waterways and four solid rock formations, with routes between the rocks and across the water. This bundle replaces the earlier mixed roster. The supplied recording guided the overhead camera, chunky foliage, shaped shallows, reflection blocks, bank details, and subtle water motion.

Copy `assets/avatar_arenas/` to the same relative directory in the Godot 4 project. Read `arenas.json` to populate an arena selector and load the scene for the selected ID.

```gdscript
var arena := preload("res://assets/avatar_arenas/scenes/jade_lotus_court.tscn").instantiate() as AvatarArenaLayout
add_child(arena)
var starts := arena.spawn_points()
var first_player_start := starts[0]
```

## Map geometry

- The artwork canvas is 960 × 640 px. Each arena defines its own smaller playable rectangle.
- `Boundary` is collision layer 4. `SolidCover` is collision layer 2. Set player and attack collision masks to match, or remap the layers to the game conventions.
- `ShallowWater` contains walkable stream and channel polygons and their cosmetic ripple layers. `BendableGround` contains invisible earth regions. `material_at(global_position)` returns `water`, `earth`, `neutral`, or `outside`.
- `spawn_points()` and `raava_points()` return global coordinates for fighter spawning and neutral event placement. The host chooses and synchronizes the Raava marker.
- `source_points(&"water")`, `source_points(&"earth")`, and `source_points(&"metal")` return candidate sources. Metal sources have visible markers. Apply range and line-of-sight checks in combat. The starter layout validation used a 36 px character width and a four-width source radius.
- Water ripples are rendered inside shallow-water polygons. Static reflection, banks, and cover are painted into the art. Cover has separate collision shapes. Environment art does not depend on the existing character or bending packs.
- Treat water coverage, collision footprints, and spawn placement as initial duel tuning. Ground movement, projectile collision, resource consumption, and networking belong to the game.

## Layouts

| Earth Kingdom | Water Tribes | Fire Nation | Air Nomads |
| --- | --- | --- | --- |
| Jade Lotus Court | Moon Oasis | Obsidian Forge | Cloudbell Court |
| Badgermole Quarry | Glacier Switchback | Ember Terrace | Windstep Garden |
| Reedstone Marsh | Tideglass Harbor | Black Sand Basin | Bison Rest |
| Amber Bamboo Ruins | Southern Thaw | Lantern Aqueduct | Summit Cistern |

The built-in image generator used stream and channel plans as layout guides. Individual prompts assigned each arena its own vegetation, architecture, materials, season, and lighting. Painted geometry was then aligned with the gameplay data.
