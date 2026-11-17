class_name AvatarArenaLayout
extends Node2D
## Arena-local coordinates match the map art. The host can query these without relying on Area2D overlap timing.

const SOURCE_MARKERS := {"water": "WaterSources", "earth": "EarthSources", "metal": "MetalSources"}

@export var play_rect := Rect2(115.0, 146.0, 730.0, 404.0)

func spawn_points() -> PackedVector2Array:
    return _positions($Spawns)

func raava_points() -> PackedVector2Array:
    return _positions($Raava)

func material_at(world_point: Vector2) -> StringName:
    var point := to_local(world_point)
    if not play_rect.has_point(point):
        return &"outside"
    for region in $ShallowWater.get_children():
        if Geometry2D.is_point_in_polygon(point, region.polygon):
            return &"water"
    for region in $BendableGround.get_children():
        if Geometry2D.is_point_in_polygon(point, region.polygon):
            return &"earth"
    return &"neutral"

func source_points(material: StringName) -> PackedVector2Array:
    var group := str(SOURCE_MARKERS.get(str(material), ""))
    if group.is_empty():
        return PackedVector2Array()
    return _positions(get_node(NodePath(group)))

func _positions(group: Node) -> PackedVector2Array:
    var points := PackedVector2Array()
    for marker: Marker2D in group.get_children():
        points.append(marker.global_position)
    return points
